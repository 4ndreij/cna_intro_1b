namespace OrderService.Configuration;

public class ServiceOptions
{
    public const string SectionName = "Services";
    
    public string ProductServiceUrl { get; set; } = "http://localhost:5001";
    public int TimeoutSeconds { get; set; } = 30;
}

public class EventHandlerOptions
{
    public const string SectionName = "EventHandlers";
    
    public int LowStockThreshold { get; set; } = 5;
    public bool EnableCustomerNotifications { get; set; } = true;
    public bool EnableLowStockAlerts { get; set; } = true;
}
