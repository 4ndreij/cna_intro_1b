using Microsoft.EntityFrameworkCore;
using Shared.Models;

namespace ProductService.Data;

public static class SeedData
{
    public static async Task Initialize(ProductDbContext context)
    {
        // Check if data already exists
        if (await context.Products.AnyAsync())
        {
            return; // DB has been seeded
        }

        var products = new[]
        {
            new Product
            {
                Id = Guid.NewGuid(),
                Name = "Laptop Pro 15",
                Description = "High-performance laptop with 15-inch display, perfect for developers and professionals",
                Price = 1299.99m,
                Stock = 50,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                IsActive = true
            },
            new Product
            {
                Id = Guid.NewGuid(),
                Name = "Wireless Mouse",
                Description = "Ergonomic wireless mouse with precision tracking and long battery life",
                Price = 29.99m,
                Stock = 200,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                IsActive = true
            },
            new Product
            {
                Id = Guid.NewGuid(),
                Name = "USB-C Hub",
                Description = "Multi-port USB-C hub with HDMI, USB 3.0, and power delivery support",
                Price = 49.99m,
                Stock = 75,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                IsActive = true
            },
            new Product
            {
                Id = Guid.NewGuid(),
                Name = "Mechanical Keyboard",
                Description = "RGB mechanical gaming keyboard with customizable keys and tactile switches",
                Price = 129.99m,
                Stock = 30,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                IsActive = true
            }
        };

        await context.Products.AddRangeAsync(products);
        await context.SaveChangesAsync();
    }
}
