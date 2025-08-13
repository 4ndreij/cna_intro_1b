using System.ComponentModel.DataAnnotations;

namespace Shared.Models;

public class Order
{
    public Guid Id { get; set; } = Guid.NewGuid();
    
    [Required]
    public Guid ProductId { get; set; }
    
    [Required]
    [StringLength(100)]
    public string CustomerName { get; set; } = string.Empty;
    
    [Required]
    [EmailAddress]
    public string CustomerEmail { get; set; } = string.Empty;
    
    [Range(1, int.MaxValue, ErrorMessage = "Quantity must be at least 1")]
    public int Quantity { get; set; }
    
    [Range(0.01, double.MaxValue, ErrorMessage = "Unit price must be greater than 0")]
    public decimal UnitPrice { get; set; }
    
    public decimal TotalPrice => Quantity * UnitPrice;
    
    public OrderStatus Status { get; set; } = OrderStatus.Pending;
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    
    // Product information cached at order time
    public string ProductName { get; set; } = string.Empty;
}

public enum OrderStatus
{
    Pending,
    Confirmed,
    Processing,
    Shipped,
    Delivered,
    Cancelled
}
