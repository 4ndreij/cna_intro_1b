using System.ComponentModel.DataAnnotations;

namespace Shared.DTOs;

// Product DTOs
public record CreateProductDto(
    [Required, StringLength(100, MinimumLength = 1)] string Name,
    [StringLength(500)] string Description,
    [Range(0.01, double.MaxValue)] decimal Price,
    [Range(0, int.MaxValue)] int Stock
);

public record UpdateProductDto(
    [Required, StringLength(100, MinimumLength = 1)] string Name,
    [StringLength(500)] string Description,
    [Range(0.01, double.MaxValue)] decimal Price,
    [Range(0, int.MaxValue)] int Stock
);

public record ProductDto(
    Guid Id,
    string Name,
    string Description,
    decimal Price,
    int Stock,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    bool IsActive
);
