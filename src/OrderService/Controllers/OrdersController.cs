using Microsoft.AspNetCore.Mvc;
using OrderService.Services;
using Shared.DTOs;
using Shared.Models;

namespace OrderService.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly IOrderService _orderService;
    private readonly ILogger<OrdersController> _logger;

    public OrdersController(IOrderService orderService, ILogger<OrdersController> logger)
    {
        _orderService = orderService;
        _logger = logger;
    }

    /// <summary>
    /// Get all orders
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IEnumerable<OrderDto>>> GetOrders()
    {
        try
        {
            var orders = await _orderService.GetAllOrdersAsync();
            return Ok(orders);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting orders");
            return StatusCode(500, "An error occurred while retrieving orders");
        }
    }

    /// <summary>
    /// Get an order by ID
    /// </summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<OrderDto>> GetOrder(Guid id)
    {
        try
        {
            var order = await _orderService.GetOrderByIdAsync(id);
            if (order == null)
            {
                return NotFound($"Order with ID {id} not found");
            }

            return Ok(order);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting order {OrderId}", id);
            return StatusCode(500, "An error occurred while retrieving the order");
        }
    }

    /// <summary>
    /// Get orders by customer email
    /// </summary>
    [HttpGet("customer/{email}")]
    public async Task<ActionResult<IEnumerable<OrderDto>>> GetOrdersByCustomer(string email)
    {
        try
        {
            var orders = await _orderService.GetOrdersByCustomerEmailAsync(email);
            return Ok(orders);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting orders for customer {CustomerEmail}", email);
            return StatusCode(500, "An error occurred while retrieving customer orders");
        }
    }

    /// <summary>
    /// Create a new order
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<OrderDto>> CreateOrder([FromBody] CreateOrderDto createOrderDto)
    {
        try
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            var order = await _orderService.CreateOrderAsync(createOrderDto);
            return CreatedAtAction(nameof(GetOrder), new { id = order.Id }, order);
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning("Invalid order creation attempt: {Message}", ex.Message);
            return BadRequest(ex.Message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating order");
            return StatusCode(500, "An error occurred while creating the order");
        }
    }

    /// <summary>
    /// Update order status
    /// </summary>
    [HttpPut("{id}/status")]
    public async Task<ActionResult<OrderDto>> UpdateOrderStatus(Guid id, [FromBody] UpdateOrderStatusDto updateOrderStatusDto)
    {
        try
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            var order = await _orderService.UpdateOrderStatusAsync(id, updateOrderStatusDto.Status);
            if (order == null)
            {
                return NotFound($"Order with ID {id} not found");
            }

            return Ok(order);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating order status {OrderId}", id);
            return StatusCode(500, "An error occurred while updating the order status");
        }
    }

    /// <summary>
    /// Cancel an order
    /// </summary>
    [HttpPost("{id}/cancel")]
    public async Task<ActionResult> CancelOrder(Guid id, [FromBody] CancelOrderDto cancelOrderDto)
    {
        try
        {
            var result = await _orderService.CancelOrderAsync(id, cancelOrderDto.Reason);
            if (!result)
            {
                return NotFound($"Order with ID {id} not found or already cancelled");
            }

            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error cancelling order {OrderId}", id);
            return StatusCode(500, "An error occurred while cancelling the order");
        }
    }
}

public record CancelOrderDto(string Reason);
