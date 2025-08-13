using Dapr.Client;
using Microsoft.EntityFrameworkCore;
using ProductService.Data;
using Shared.Models;
using Shared.DTOs;
using Shared.Events;

namespace ProductService.Services;

public class ProductServiceImpl : IProductService
{
    private readonly ProductDbContext _context;
    private readonly DaprClient _daprClient;
    private readonly ILogger<ProductServiceImpl> _logger;
    private const string PubSubName = "product-pubsub";

    public ProductServiceImpl(
        ProductDbContext context,
        DaprClient daprClient,
        ILogger<ProductServiceImpl> logger)
    {
        _context = context;
        _daprClient = daprClient;
        _logger = logger;
    }

    public async Task<IEnumerable<ProductDto>> GetAllProductsAsync()
    {
        var products = await _context.Products
            .Where(p => p.IsActive)
            .OrderBy(p => p.Name)
            .ToListAsync();

        return products.Select(MapToDto);
    }

    public async Task<ProductDto?> GetProductByIdAsync(Guid id)
    {
        var product = await _context.Products
            .FirstOrDefaultAsync(p => p.Id == id && p.IsActive);

        return product != null ? MapToDto(product) : null;
    }

    public async Task<ProductDto> CreateProductAsync(CreateProductDto createProductDto)
    {
        var product = new Product
        {
            Id = Guid.NewGuid(),
            Name = createProductDto.Name,
            Description = createProductDto.Description,
            Price = createProductDto.Price,
            Stock = createProductDto.Stock,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            IsActive = true
        };

        _context.Products.Add(product);
        await _context.SaveChangesAsync();

        // Publish ProductCreated event
        var productCreatedEvent = new ProductCreatedEvent(
            product.Id,
            product.Name,
            product.Description,
            product.Price,
            product.Stock,
            product.CreatedAt
        );

        await PublishEventAsync("product-created", productCreatedEvent);

        _logger.LogInformation("Product created: {ProductId} - {ProductName}", 
            product.Id, product.Name);

        return MapToDto(product);
    }

    public async Task<ProductDto?> UpdateProductAsync(Guid id, UpdateProductDto updateProductDto)
    {
        var product = await _context.Products
            .FirstOrDefaultAsync(p => p.Id == id && p.IsActive);

        if (product == null)
            return null;

        var previousStock = product.Stock;

        product.Name = updateProductDto.Name;
        product.Description = updateProductDto.Description;
        product.Price = updateProductDto.Price;
        product.Stock = updateProductDto.Stock;
        product.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        // Publish ProductUpdated event
        var productUpdatedEvent = new ProductUpdatedEvent(
            product.Id,
            product.Name,
            product.Description,
            product.Price,
            product.Stock,
            product.UpdatedAt
        );

        await PublishEventAsync("product-updated", productUpdatedEvent);

        // If stock changed, publish stock change event
        if (previousStock != product.Stock)
        {
            var stockChangedEvent = new ProductStockChangedEvent(
                product.Id,
                product.Name,
                previousStock,
                product.Stock,
                DateTime.UtcNow
            );

            await PublishEventAsync("product-stock-changed", stockChangedEvent);
        }

        _logger.LogInformation("Product updated: {ProductId} - {ProductName}", 
            product.Id, product.Name);

        return MapToDto(product);
    }

    public async Task<bool> DeleteProductAsync(Guid id)
    {
        var product = await _context.Products
            .FirstOrDefaultAsync(p => p.Id == id && p.IsActive);

        if (product == null)
            return false;

        // Soft delete
        product.IsActive = false;
        product.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        // Publish ProductDeleted event
        var productDeletedEvent = new ProductDeletedEvent(
            product.Id,
            product.Name,
            DateTime.UtcNow
        );

        await PublishEventAsync("product-deleted", productDeletedEvent);

        _logger.LogInformation("Product deleted: {ProductId} - {ProductName}", 
            product.Id, product.Name);

        return true;
    }

    public async Task<bool> UpdateStockAsync(Guid id, int newStock)
    {
        var product = await _context.Products
            .FirstOrDefaultAsync(p => p.Id == id && p.IsActive);

        if (product == null)
            return false;

        var previousStock = product.Stock;
        product.Stock = newStock;
        product.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        // Publish stock change event
        var stockChangedEvent = new ProductStockChangedEvent(
            product.Id,
            product.Name,
            previousStock,
            newStock,
            DateTime.UtcNow
        );

        await PublishEventAsync("product-stock-changed", stockChangedEvent);

        _logger.LogInformation("Product stock updated: {ProductId} - {ProductName}, {PreviousStock} -> {NewStock}", 
            product.Id, product.Name, previousStock, newStock);

        return true;
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

    private static ProductDto MapToDto(Product product) => new(
        product.Id,
        product.Name,
        product.Description,
        product.Price,
        product.Stock,
        product.CreatedAt,
        product.UpdatedAt,
        product.IsActive
    );
}
