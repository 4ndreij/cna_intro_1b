namespace ProductService.Configuration;

public class ProductOptions
{
    public const string SectionName = "Product";
    
    public bool EnableEventPublishing { get; set; } = true;
    public int MaxStockLevel { get; set; } = 10000;
    public int MinStockLevel { get; set; } = 0;
}
