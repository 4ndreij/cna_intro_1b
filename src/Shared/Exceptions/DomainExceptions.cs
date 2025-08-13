namespace Shared.Exceptions;

public abstract class DomainException : Exception
{
    protected DomainException(string message) : base(message) { }
    protected DomainException(string message, Exception innerException) : base(message, innerException) { }
}

public class ProductNotFoundException : DomainException
{
    public Guid ProductId { get; }

    public ProductNotFoundException(Guid productId) 
        : base($"Product with ID {productId} was not found.")
    {
        ProductId = productId;
    }
}

public class InsufficientStockException : DomainException
{
    public Guid ProductId { get; }
    public int RequestedQuantity { get; }
    public int AvailableStock { get; }

    public InsufficientStockException(Guid productId, int requestedQuantity, int availableStock)
        : base($"Insufficient stock for product {productId}. Requested: {requestedQuantity}, Available: {availableStock}")
    {
        ProductId = productId;
        RequestedQuantity = requestedQuantity;
        AvailableStock = availableStock;
    }
}

public class ExternalServiceException : DomainException
{
    public string ServiceName { get; }

    public ExternalServiceException(string serviceName, string message) 
        : base($"Error communicating with {serviceName}: {message}")
    {
        ServiceName = serviceName;
    }

    public ExternalServiceException(string serviceName, string message, Exception innerException)
        : base($"Error communicating with {serviceName}: {message}", innerException)
    {
        ServiceName = serviceName;
    }
}
