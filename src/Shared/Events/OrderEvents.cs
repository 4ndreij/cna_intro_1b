using Shared.Models;

namespace Shared.Events;

// Order Events
public record OrderCreatedEvent(
    Guid OrderId,
    Guid ProductId,
    string ProductName,
    string CustomerName,
    string CustomerEmail,
    int Quantity,
    decimal UnitPrice,
    decimal TotalPrice,
    DateTime CreatedAt
);

public record OrderStatusChangedEvent(
    Guid OrderId,
    Guid ProductId,
    OrderStatus PreviousStatus,
    OrderStatus NewStatus,
    string CustomerEmail,
    DateTime ChangedAt
);

public record OrderCancelledEvent(
    Guid OrderId,
    Guid ProductId,
    int Quantity,
    string Reason,
    DateTime CancelledAt
);
