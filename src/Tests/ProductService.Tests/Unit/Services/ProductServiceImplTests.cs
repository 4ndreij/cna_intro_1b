using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using ProductService.Data;
using ProductService.Services;
using Shared.DTOs;
using Shared.Models;
using Dapr.Client;
using Moq;
using FluentAssertions;

namespace ProductService.Tests.Unit.Services;

public class ProductServiceImplTests : IDisposable
{
    private readonly Mock<ILogger<ProductServiceImpl>> _mockLogger;
    private readonly Mock<DaprClient> _mockDaprClient;
    private readonly ProductDbContext _context;
    private readonly ProductServiceImpl _service;

    public ProductServiceImplTests()
    {
        _mockLogger = new Mock<ILogger<ProductServiceImpl>>();
        _mockDaprClient = new Mock<DaprClient>();
        
        var options = new DbContextOptionsBuilder<ProductDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        
        _context = new ProductDbContext(options);
        _service = new ProductServiceImpl(_context, _mockDaprClient.Object, _mockLogger.Object);
    }

    public void Dispose()
    {
        _context.Dispose();
    }

    [Fact]
    public async Task GetAllProductsAsync_ReturnsAllProducts()
    {
        // Arrange
        var products = new List<Product>
        {
            new() { Name = "Product 1", Price = 10.0m, Stock = 5, Description = "Desc 1" },
            new() { Name = "Product 2", Price = 20.0m, Stock = 10, Description = "Desc 2" },
            new() { Name = "Product 3", Price = 30.0m, Stock = 15, Description = "Desc 3", IsActive = false }
        };

        _context.Products.AddRange(products);
        await _context.SaveChangesAsync();

        // Act
        var result = await _service.GetAllProductsAsync();

        // Assert
        result.Should().HaveCount(2); // Only active products
        result.Should().OnlyContain(p => p.IsActive);
    }

    [Fact]
    public async Task GetProductByIdAsync_ReturnsProduct_WhenProductExists()
    {
        // Arrange
        var product = new Product 
        { 
            Name = "Test Product", 
            Price = 99.99m, 
            Stock = 5, 
            Description = "Test Description" 
        };
        
        _context.Products.Add(product);
        await _context.SaveChangesAsync();

        // Act
        var result = await _service.GetProductByIdAsync(product.Id);

        // Assert
        result.Should().NotBeNull();
        result!.Id.Should().Be(product.Id);
        result.Name.Should().Be(product.Name);
        result.Price.Should().Be(product.Price);
    }

    [Fact]
    public async Task GetProductByIdAsync_ReturnsNull_WhenProductDoesNotExist()
    {
        // Act
        var result = await _service.GetProductByIdAsync(Guid.NewGuid());

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task CreateProductAsync_CreatesAndReturnsProduct()
    {
        // Arrange
        var createDto = new CreateProductDto(
            Name: "New Product",
            Description: "New Description", 
            Price: 149.99m,
            Stock: 20
        );

        // Act
        var result = await _service.CreateProductAsync(createDto);

        // Assert
        result.Should().NotBeNull();
        result.Name.Should().Be(createDto.Name);
        result.Description.Should().Be(createDto.Description);
        result.Price.Should().Be(createDto.Price);
        result.Stock.Should().Be(createDto.Stock);
        result.Id.Should().NotBe(Guid.Empty);
        result.IsActive.Should().BeTrue();

        // Verify it was saved to database
        var savedProduct = await _context.Products.FindAsync(result.Id);
        savedProduct.Should().NotBeNull();
        savedProduct!.Name.Should().Be(createDto.Name);
    }

    [Fact]
    public async Task UpdateProductAsync_UpdatesAndReturnsProduct_WhenProductExists()
    {
        // Arrange
        var product = new Product 
        { 
            Name = "Original Product", 
            Price = 50.0m, 
            Stock = 10, 
            Description = "Original Description" 
        };
        
        _context.Products.Add(product);
        await _context.SaveChangesAsync();

        var updateDto = new UpdateProductDto(
            Name: "Updated Product",
            Description: "Updated Description",
            Price: 75.0m,
            Stock: 15
        );

        // Act
        var result = await _service.UpdateProductAsync(product.Id, updateDto);

        // Assert
        result.Should().NotBeNull();
        result!.Name.Should().Be(updateDto.Name);
        result.Description.Should().Be(updateDto.Description);
        result.Price.Should().Be(updateDto.Price);
        result.Stock.Should().Be(updateDto.Stock);

        // Verify database was updated
        var updatedProduct = await _context.Products.FindAsync(product.Id);
        updatedProduct!.Name.Should().Be(updateDto.Name);
        updatedProduct.UpdatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
    }

    [Fact]
    public async Task UpdateProductAsync_ReturnsNull_WhenProductDoesNotExist()
    {
        // Arrange
        var updateDto = new UpdateProductDto(
            Name: "Updated Product",
            Description: "Updated Description",
            Price: 75.0m,
            Stock: 15
        );

        // Act
        var result = await _service.UpdateProductAsync(Guid.NewGuid(), updateDto);

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task DeleteProductAsync_SoftDeletesProduct_WhenProductExists()
    {
        // Arrange
        var product = new Product 
        { 
            Name = "Product to Delete", 
            Price = 25.0m, 
            Stock = 5, 
            Description = "Will be deleted" 
        };
        
        _context.Products.Add(product);
        await _context.SaveChangesAsync();

        // Act
        var result = await _service.DeleteProductAsync(product.Id);

        // Assert
        result.Should().BeTrue();

        // Verify product is soft deleted (IsActive = false)
        var deletedProduct = await _context.Products.FindAsync(product.Id);
        deletedProduct.Should().NotBeNull();
        deletedProduct!.IsActive.Should().BeFalse();
    }

    [Fact]
    public async Task DeleteProductAsync_ReturnsFalse_WhenProductDoesNotExist()
    {
        // Act
        var result = await _service.DeleteProductAsync(Guid.NewGuid());

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task UpdateStockAsync_UpdatesStock_WhenProductExists()
    {
        // Arrange
        var product = new Product 
        { 
            Name = "Stock Product", 
            Price = 10.0m, 
            Stock = 100, 
            Description = "Stock test" 
        };
        
        _context.Products.Add(product);
        await _context.SaveChangesAsync();

        var newStock = 75;

        // Act
        var result = await _service.UpdateStockAsync(product.Id, newStock);

        // Assert
        result.Should().BeTrue();

        // Verify database was updated
        var updatedProduct = await _context.Products.FindAsync(product.Id);
        updatedProduct!.Stock.Should().Be(newStock);
    }

    [Fact]
    public async Task UpdateStockAsync_ReturnsNull_WhenProductDoesNotExist()
    {
        // Act
        var result = await _service.UpdateStockAsync(Guid.NewGuid(), 50);

        // Assert
        result.Should().BeFalse();
    }
}
