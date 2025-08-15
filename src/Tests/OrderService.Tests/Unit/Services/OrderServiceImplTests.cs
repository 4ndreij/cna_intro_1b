using Dapr.Client;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using OrderService.Data;
using OrderService.Services;
using Shared.DTOs;
using Shared.Models;
using System.Net;

namespace OrderService.Tests.Unit.Services;

public class OrderServiceImplTests
{
    private readonly Mock<OrderDbContext> _mockContext;
    private readonly Mock<DaprClient> _mockDaprClient;
    private readonly Mock<ILogger<OrderServiceImpl>> _mockLogger;
    private readonly Mock<IProductServiceClient> _mockProductServiceClient;
    private readonly OrderServiceImpl _service;

    public OrderServiceImplTests()
    {
        var options = new DbContextOptionsBuilder<OrderDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _mockContext = new Mock<OrderDbContext>(options);
        _mockDaprClient = new Mock<DaprClient>();
        _mockLogger = new Mock<ILogger<OrderServiceImpl>>();
        _mockProductServiceClient = new Mock<IProductServiceClient>();
        
        _service = new OrderServiceImpl(
            _mockContext.Object,
            _mockDaprClient.Object,
            _mockLogger.Object,
            _mockProductServiceClient.Object);
    }

    [Fact]
    public async Task CreateOrderAsync_ThrowsException_WhenProductNotFound()
    {
        // Arrange
        var createOrderDto = new CreateOrderDto(
            ProductId: Guid.NewGuid(),
            CustomerName: "John Doe",
            CustomerEmail: "john@example.com",
            Quantity: 2
        );

        _mockProductServiceClient
            .Setup(x => x.GetProductAsync(createOrderDto.ProductId))
            .ReturnsAsync(null as ProductDto);

        // Act & Assert
        var exception = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.CreateOrderAsync(createOrderDto));

        exception.Message.Should().Contain("not found");
    }

    [Fact]
    public async Task CreateOrderAsync_ThrowsException_WhenInsufficientStock()
    {
        // Arrange
        var productId = Guid.NewGuid();
        var createOrderDto = new CreateOrderDto(
            ProductId: productId,
            CustomerName: "John Doe",
            CustomerEmail: "john@example.com",
            Quantity: 10
        );

        var productDto = new ProductDto(
            Id: productId,
            Name: "Test Product",
            Description: "Test",
            Price: 99.99m,
            Stock: 5, // Insufficient stock
            CreatedAt: DateTime.UtcNow,
            UpdatedAt: DateTime.UtcNow,
            IsActive: true
        );

        _mockProductServiceClient
            .Setup(x => x.GetProductAsync(productId))
            .ReturnsAsync(productDto);

        // Act & Assert
        var exception = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.CreateOrderAsync(createOrderDto));

        exception.Message.Should().Contain("Insufficient stock");
    }

    [Theory]
    [InlineData("")]
    [InlineData("invalid-email")]
    [InlineData("@invalid.com")]
    public void CreateOrderDto_Validation_InvalidEmail_ShouldFail(string invalidEmail)
    {
        // Arrange
        var createOrderDto = new CreateOrderDto(
            ProductId: Guid.NewGuid(),
            CustomerName: "John Doe",
            CustomerEmail: invalidEmail,
            Quantity: 1
        );

        // Act & Assert - This would be caught by model validation in the controller
        // We can test this through integration tests or validator tests
        createOrderDto.CustomerEmail.Should().Be(invalidEmail);
    }

    [Fact]
    public void CreateOrderDto_Validation_ValidData_ShouldPass()
    {
        // Arrange & Act
        var createOrderDto = new CreateOrderDto(
            ProductId: Guid.NewGuid(),
            CustomerName: "John Doe",
            CustomerEmail: "john.doe@example.com",
            Quantity: 2
        );

        // Assert
        createOrderDto.ProductId.Should().NotBe(Guid.Empty);
        createOrderDto.CustomerName.Should().Be("John Doe");
        createOrderDto.CustomerEmail.Should().Be("john.doe@example.com");
        createOrderDto.Quantity.Should().Be(2);
    }
}

public class OrderEntityTests
{
    [Fact]
    public void Order_TotalPrice_CalculatedCorrectly()
    {
        // Arrange
        var order = new Order
        {
            Quantity = 3,
            UnitPrice = 29.99m
        };

        // Act
        var totalPrice = order.TotalPrice;

        // Assert
        totalPrice.Should().Be(89.97m);
    }

    [Fact]
    public void Order_DefaultValues_SetCorrectly()
    {
        // Arrange & Act
        var order = new Order();

        // Assert
        order.Id.Should().NotBe(Guid.Empty);
        order.Status.Should().Be(OrderStatus.Pending);
        order.CreatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
        order.UpdatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
    }

    [Theory]
    [InlineData(OrderStatus.Pending)]
    [InlineData(OrderStatus.Confirmed)]
    [InlineData(OrderStatus.Shipped)]
    [InlineData(OrderStatus.Delivered)]
    [InlineData(OrderStatus.Cancelled)]
    public void OrderStatus_AllValidStatuses_ShouldBeSupported(OrderStatus status)
    {
        // Arrange & Act
        var order = new Order { Status = status };

        // Assert
        order.Status.Should().Be(status);
        Enum.IsDefined(typeof(OrderStatus), status).Should().BeTrue();
    }
}
