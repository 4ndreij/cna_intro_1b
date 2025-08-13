using Shared.Models;
using Shared.DTOs;

namespace OrderService.Services;

public interface IOrderService
{
    Task<IEnumerable<OrderDto>> GetAllOrdersAsync();
    Task<OrderDto?> GetOrderByIdAsync(Guid id);
    Task<IEnumerable<OrderDto>> GetOrdersByCustomerEmailAsync(string customerEmail);
    Task<OrderDto> CreateOrderAsync(CreateOrderDto createOrderDto);
    Task<OrderDto?> UpdateOrderStatusAsync(Guid id, OrderStatus newStatus);
    Task<bool> CancelOrderAsync(Guid id, string reason);
}
