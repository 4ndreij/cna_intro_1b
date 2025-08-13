using System.ComponentModel.DataAnnotations;
using Shared.Models;

namespace Shared.DTOs;

// Order DTOs
public record CreateOrderDto(
    [Required] Guid ProductId,
    [Required, StringLength(100)] string CustomerName,
    [Required, EmailAddress] string CustomerEmail,
    [Range(1, int.MaxValue)] int Quantity
);

public record UpdateOrderStatusDto(
    [Required] OrderStatus Status
);

public record OrderDto(
    Guid Id,
    Guid ProductId,
    string ProductName,
    string CustomerName,
    string CustomerEmail,
    int Quantity,
    decimal UnitPrice,
    decimal TotalPrice,
    OrderStatus Status,
    DateTime CreatedAt,
    DateTime UpdatedAt
);
