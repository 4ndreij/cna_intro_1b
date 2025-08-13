using Dapr.Client;
using Microsoft.EntityFrameworkCore;
using OrderService.Data;
using Shared.Models;
using Shared.DTOs;
using Shared.Events;

namespace OrderService.Services;

public class OrderServiceImpl : IOrderService
{
    private readonly OrderDbContext _context;
    private readonly DaprClient _daprClient;
    private readonly ILogger<OrderServiceImpl> _logger;
    private readonly IHttpClientFactory _httpClientFactory;
    private const string PubSubName = "product-pubsub";
    private const string ProductServiceName = "productservice";

    public OrderServiceImpl(
        OrderDbContext context,
        DaprClient daprClient,
        ILogger<OrderServiceImpl> logger,
        IHttpClientFactory httpClientFactory)
    {
        _context = context;
        _daprClient = daprClient;
        _logger = logger;
        _httpClientFactory = httpClientFactory;
    }

    public async Task<IEnumerable<OrderDto>> GetAllOrdersAsync()
    {
        var orders = await _context.Orders
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync();

        return orders.Select(MapToDto);
    }

    public async Task<OrderDto?> GetOrderByIdAsync(Guid id)
    {
        var order = await _context.Orders
            .FirstOrDefaultAsync(o => o.Id == id);

        return order != null ? MapToDto(order) : null;
    }

    public async Task<IEnumerable<OrderDto>> GetOrdersByCustomerEmailAsync(string customerEmail)
    {
        var orders = await _context.Orders
            .Where(o => o.CustomerEmail == customerEmail)
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync();

        return orders.Select(MapToDto);
    }

    public async Task<OrderDto> CreateOrderAsync(CreateOrderDto createOrderDto)
    {
        // Get product details from ProductService via Dapr service invocation
        var productDto = await GetProductFromProductServiceAsync(createOrderDto.ProductId);
        
        if (productDto == null)
        {
            throw new InvalidOperationException($"Product {createOrderDto.ProductId} not found");
        }

        if (productDto.Stock < createOrderDto.Quantity)
        {
            throw new InvalidOperationException($"Insufficient stock. Available: {productDto.Stock}, Requested: {createOrderDto.Quantity}");
        }

        var order = new Order
        {
            Id = Guid.NewGuid(),
            ProductId = createOrderDto.ProductId,
            CustomerName = createOrderDto.CustomerName,
            CustomerEmail = createOrderDto.CustomerEmail,
            Quantity = createOrderDto.Quantity,
            UnitPrice = productDto.Price,
            ProductName = productDto.Name,
            Status = OrderStatus.Pending,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.Orders.Add(order);
        await _context.SaveChangesAsync();

        // Update product stock
        var newStock = productDto.Stock - createOrderDto.Quantity;
        await UpdateProductStockAsync(createOrderDto.ProductId, newStock);

        // Publish OrderCreated event
        var orderCreatedEvent = new OrderCreatedEvent(
            order.Id,
            order.ProductId,
            order.ProductName,
            order.CustomerName,
            order.CustomerEmail,
            order.Quantity,
            order.UnitPrice,
            order.TotalPrice,
            order.CreatedAt
        );

        await PublishEventAsync("order-created", orderCreatedEvent);

        _logger.LogInformation("Order created: {OrderId} for customer {CustomerEmail}", 
            order.Id, order.CustomerEmail);

        return MapToDto(order);
    }

    public async Task<OrderDto?> UpdateOrderStatusAsync(Guid id, OrderStatus newStatus)
    {
        var order = await _context.Orders
            .FirstOrDefaultAsync(o => o.Id == id);

        if (order == null)
            return null;

        var previousStatus = order.Status;
        order.Status = newStatus;
        order.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        // Publish OrderStatusChanged event
        var statusChangedEvent = new OrderStatusChangedEvent(
            order.Id,
            order.ProductId,
            previousStatus,
            newStatus,
            order.CustomerEmail,
            DateTime.UtcNow
        );

        await PublishEventAsync("order-status-changed", statusChangedEvent);

        _logger.LogInformation("Order status updated: {OrderId}, {PreviousStatus} -> {NewStatus}", 
            order.Id, previousStatus, newStatus);

        return MapToDto(order);
    }

    public async Task<bool> CancelOrderAsync(Guid id, string reason)
    {
        var order = await _context.Orders
            .FirstOrDefaultAsync(o => o.Id == id);

        if (order == null || order.Status == OrderStatus.Cancelled)
            return false;

        // If order is not yet shipped, restore stock
        if (order.Status is OrderStatus.Pending or OrderStatus.Confirmed or OrderStatus.Processing)
        {
            var productDto = await GetProductFromProductServiceAsync(order.ProductId);
            if (productDto != null)
            {
                var newStock = productDto.Stock + order.Quantity;
                await UpdateProductStockAsync(order.ProductId, newStock);
            }
        }

        order.Status = OrderStatus.Cancelled;
        order.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        // Publish OrderCancelled event
        var orderCancelledEvent = new OrderCancelledEvent(
            order.Id,
            order.ProductId,
            order.Quantity,
            reason,
            DateTime.UtcNow
        );

        await PublishEventAsync("order-cancelled", orderCancelledEvent);

        _logger.LogInformation("Order cancelled: {OrderId}, Reason: {Reason}", order.Id, reason);

        return true;
    }

    private async Task<ProductDto?> GetProductFromProductServiceAsync(Guid productId)
    {
        try
        {
            // Try Dapr service invocation first
            var response = await _daprClient.InvokeMethodAsync<ProductDto>(
                ProductServiceName, 
                $"api/products/{productId}");
            
            return response;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Dapr service invocation failed for product {ProductId}, trying direct HTTP call", productId);
            
            // Fallback to direct HTTP call through ProductService
            try
            {
                using var httpClient = _httpClientFactory.CreateClient("ProductService");
                var directResponse = await httpClient.GetFromJsonAsync<ProductDto>(
                    $"api/products/{productId}");
                
                _logger.LogInformation("Successfully retrieved product {ProductId} via direct HTTP call", productId);
                return directResponse;
            }
            catch (Exception directEx)
            {
                _logger.LogError(directEx, "Both Dapr service invocation and direct HTTP call failed for product {ProductId}", productId);
                return null;
            }
        }
    }

    private async Task UpdateProductStockAsync(Guid productId, int newStock)
    {
        try
        {
            // Try Dapr service invocation first with HttpRequestMessage for PATCH
            using var request = _daprClient.CreateInvokeMethodRequest(
                ProductServiceName,
                $"api/products/{productId}/stock",
                new { stock = newStock });
            request.Method = HttpMethod.Patch;
            
            await _daprClient.InvokeMethodAsync(request);
            
            _logger.LogInformation("Successfully updated stock for product {ProductId} via Dapr service invocation", productId);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Dapr service invocation failed for updating stock of product {ProductId}, trying direct HTTP call", productId);
            
            // Fallback to direct HTTP call with PATCH method
            try
            {
                using var httpClient = _httpClientFactory.CreateClient("ProductService");
                var stockUpdate = new { stock = newStock };
                var response = await httpClient.PatchAsJsonAsync($"api/products/{productId}/stock", stockUpdate);
                response.EnsureSuccessStatusCode();
                
                _logger.LogInformation("Successfully updated stock for product {ProductId} via direct HTTP call", productId);
            }
            catch (Exception directEx)
            {
                _logger.LogError(directEx, "Both Dapr service invocation and direct HTTP call failed for updating stock of product {ProductId}", productId);
                throw;
            }
        }
    }

    private async Task PublishEventAsync<T>(string topicName, T eventData)
    {
        try
        {
            await _daprClient.PublishEventAsync(PubSubName, topicName, eventData);
            _logger.LogDebug("Published event {TopicName}: {@EventData}", topicName, eventData);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to publish event {TopicName}: {@EventData}", topicName, eventData);
            throw;
        }
    }

    private static OrderDto MapToDto(Order order) => new(
        order.Id,
        order.ProductId,
        order.ProductName,
        order.CustomerName,
        order.CustomerEmail,
        order.Quantity,
        order.UnitPrice,
        order.TotalPrice,
        order.Status,
        order.CreatedAt,
        order.UpdatedAt
    );
}
