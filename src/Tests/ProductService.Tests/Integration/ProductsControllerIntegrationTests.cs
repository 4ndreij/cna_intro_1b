using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using ProductService.Data;
using Shared.DTOs;
using Shared.Models;

namespace ProductService.Tests.Integration;

public class ProductsControllerIntegrationTests : IClassFixture<ProductServiceWebApplicationFactory>
{
    private readonly HttpClient _client;
    private readonly ProductServiceWebApplicationFactory _factory;

    public ProductsControllerIntegrationTests(ProductServiceWebApplicationFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetProducts_ReturnsEmptyList_WhenNoProducts()
    {
        // Act
        var response = await _client.GetAsync("/api/products");
        var products = await response.Content.ReadFromJsonAsync<List<ProductDto>>();

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        products.Should().NotBeNull();
        products.Should().BeEmpty();
    }

    [Fact]
    public async Task CreateProduct_ReturnsCreated_WhenValidProduct()
    {
        // Arrange
        var createProductDto = new CreateProductDto(
            Name: "Test Laptop",
            Description: "A test laptop for integration testing",
            Price: 999.99m,
            Stock: 10
        );

        // Act
        var response = await _client.PostAsJsonAsync("/api/products", createProductDto);
        var createdProduct = await response.Content.ReadFromJsonAsync<ProductDto>();

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Created);
        createdProduct.Should().NotBeNull();
        createdProduct!.Name.Should().Be(createProductDto.Name);
        createdProduct.Description.Should().Be(createProductDto.Description);
        createdProduct.Price.Should().Be(createProductDto.Price);
        createdProduct.Stock.Should().Be(createProductDto.Stock);
        createdProduct.Id.Should().NotBe(Guid.Empty);
        createdProduct.IsActive.Should().BeTrue();
    }

    [Fact]
    public async Task GetProduct_ReturnsProduct_WhenProductExists()
    {
        // Arrange
        var product = await CreateTestProductAsync();

        // Act
        var response = await _client.GetAsync($"/api/products/{product.Id}");
        var retrievedProduct = await response.Content.ReadFromJsonAsync<ProductDto>();

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        retrievedProduct.Should().NotBeNull();
        retrievedProduct!.Id.Should().Be(product.Id);
        retrievedProduct.Name.Should().Be(product.Name);
    }

    [Fact]
    public async Task GetProduct_ReturnsNotFound_WhenProductDoesNotExist()
    {
        // Act
        var response = await _client.GetAsync($"/api/products/{Guid.NewGuid()}");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task UpdateProduct_ReturnsOk_WhenValidUpdate()
    {
        // Arrange
        var product = await CreateTestProductAsync();
        var updateDto = new UpdateProductDto(
            Name: "Updated Laptop",
            Description: "Updated description",
            Price: 1299.99m,
            Stock: 15
        );

        // Act
        var response = await _client.PutAsJsonAsync($"/api/products/{product.Id}", updateDto);
        var updatedProduct = await response.Content.ReadFromJsonAsync<ProductDto>();

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        updatedProduct.Should().NotBeNull();
        updatedProduct!.Name.Should().Be(updateDto.Name);
        updatedProduct.Description.Should().Be(updateDto.Description);
        updatedProduct.Price.Should().Be(updateDto.Price);
        updatedProduct.Stock.Should().Be(updateDto.Stock);
    }

    [Fact]
    public async Task DeleteProduct_ReturnsNoContent_WhenProductExists()
    {
        // Arrange
        var product = await CreateTestProductAsync();

        // Act
        var response = await _client.DeleteAsync($"/api/products/{product.Id}");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.NoContent);

        // Verify product is deleted
        var getResponse = await _client.GetAsync($"/api/products/{product.Id}");
        getResponse.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task CreateProduct_ReturnsBadRequest_WhenInvalidData()
    {
        // Arrange
        var invalidProduct = new CreateProductDto(
            Name: "", // Invalid: empty name
            Description: "Test",
            Price: -1, // Invalid: negative price
            Stock: -5  // Invalid: negative stock
        );

        // Act
        var response = await _client.PostAsJsonAsync("/api/products", invalidProduct);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task UpdateStock_UpdatesProductStock_WhenValidRequest()
    {
        // Arrange
        var product = await CreateTestProductAsync();
        var newStock = 25;

        // Act
        var response = await _client.PutAsJsonAsync($"/api/products/{product.Id}/stock", new { stock = newStock });
        var updatedProduct = await response.Content.ReadFromJsonAsync<ProductDto>();

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        updatedProduct.Should().NotBeNull();
        updatedProduct!.Stock.Should().Be(newStock);
    }

    [Fact]
    public async Task HealthCheck_ReturnsHealthy()
    {
        // Act
        var response = await _client.GetAsync("/health");
        var healthStatus = await response.Content.ReadAsStringAsync();

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        healthStatus.Should().Be("Healthy");
    }

    private async Task<ProductDto> CreateTestProductAsync()
    {
        var createProductDto = new CreateProductDto(
            Name: "Test Product",
            Description: "A test product",
            Price: 99.99m,
            Stock: 50
        );

        var response = await _client.PostAsJsonAsync("/api/products", createProductDto);
        response.EnsureSuccessStatusCode();

        var product = await response.Content.ReadFromJsonAsync<ProductDto>();
        return product!;
    }
}
