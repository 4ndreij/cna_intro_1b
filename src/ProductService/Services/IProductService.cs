using Shared.Models;
using Shared.DTOs;

namespace ProductService.Services;

public interface IProductService
{
    Task<IEnumerable<ProductDto>> GetAllProductsAsync();
    Task<ProductDto?> GetProductByIdAsync(Guid id);
    Task<ProductDto> CreateProductAsync(CreateProductDto createProductDto);
    Task<ProductDto?> UpdateProductAsync(Guid id, UpdateProductDto updateProductDto);
    Task<bool> DeleteProductAsync(Guid id);
    Task<bool> UpdateStockAsync(Guid id, int newStock);
}
