namespace Shared.Events;

// Product Events
public record ProductCreatedEvent(
    Guid ProductId,
    string Name,
    string Description,
    decimal Price,
    int Stock,
    DateTime CreatedAt
);

public record ProductUpdatedEvent(
    Guid ProductId,
    string Name,
    string Description,
    decimal Price,
    int Stock,
    DateTime UpdatedAt
);

public record ProductDeletedEvent(
    Guid ProductId,
    string Name,
    DateTime DeletedAt
);

public record ProductStockChangedEvent(
    Guid ProductId,
    string Name,
    int PreviousStock,
    int NewStock,
    DateTime ChangedAt
);
