using Shared.Models;

namespace Shared.Tests.Unit.Models;

public class ProductTests
{
    [Fact]
    public void Product_DefaultConstructor_SetsDefaults()
    {
        // Arrange & Act
        var product = new Product();

        // Assert
        product.Id.Should().NotBe(Guid.Empty);
        product.Name.Should().Be(string.Empty);
        product.Description.Should().Be(string.Empty);
        product.Price.Should().Be(0m);
        product.Stock.Should().Be(0);
        product.CreatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
        product.UpdatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
        product.IsActive.Should().BeTrue();
    }

    [Fact]
    public void Product_SetProperties_ShouldStoreValues()
    {
        // Arrange
        var id = Guid.NewGuid();
        var createdAt = DateTime.UtcNow.AddDays(-1);
        var updatedAt = DateTime.UtcNow;

        // Act
        var product = new Product
        {
            Id = id,
            Name = "Test Product",
            Description = "Test Description",
            Price = 99.99m,
            Stock = 50,
            CreatedAt = createdAt,
            UpdatedAt = updatedAt,
            IsActive = true
        };

        // Assert
        product.Id.Should().Be(id);
        product.Name.Should().Be("Test Product");
        product.Description.Should().Be("Test Description");
        product.Price.Should().Be(99.99m);
        product.Stock.Should().Be(50);
        product.CreatedAt.Should().Be(createdAt);
        product.UpdatedAt.Should().Be(updatedAt);
        product.IsActive.Should().BeTrue();
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void Product_IsActiveProperty_ShouldAcceptBooleanValues(bool isActive)
    {
        // Arrange & Act
        var product = new Product { IsActive = isActive };

        // Assert
        product.IsActive.Should().Be(isActive);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(1)]
    [InlineData(100)]
    [InlineData(int.MaxValue)]
    public void Product_StockProperty_ShouldAcceptNonNegativeValues(int stock)
    {
        // Arrange & Act
        var product = new Product { Stock = stock };

        // Assert
        product.Stock.Should().Be(stock);
    }

    [Theory]
    [InlineData(0.01)]
    [InlineData(99.99)]
    [InlineData(1000.00)]
    [InlineData(999999.99)]
    public void Product_PriceProperty_ShouldAcceptPositiveValues(decimal price)
    {
        // Arrange & Act
        var product = new Product { Price = price };

        // Assert
        product.Price.Should().Be(price);
    }
}

public class OrderTests
{
    [Fact]
    public void Order_DefaultConstructor_SetsDefaults()
    {
        // Arrange & Act
        var order = new Order();

        // Assert
        order.Id.Should().NotBe(Guid.Empty);
        order.ProductId.Should().Be(Guid.Empty);
        order.CustomerName.Should().Be(string.Empty);
        order.CustomerEmail.Should().Be(string.Empty);
        order.Quantity.Should().Be(0);
        order.UnitPrice.Should().Be(0m);
        order.Status.Should().Be(OrderStatus.Pending);
        order.CreatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
        order.UpdatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
        order.ProductName.Should().Be(string.Empty);
    }

    [Theory]
    [InlineData(1, 10.00, 10.00)]
    [InlineData(2, 25.50, 51.00)]
    [InlineData(5, 99.99, 499.95)]
    [InlineData(10, 150.75, 1507.50)]
    public void Order_TotalPrice_CalculatesCorrectly(int quantity, decimal unitPrice, decimal expectedTotal)
    {
        // Arrange & Act
        var order = new Order
        {
            Quantity = quantity,
            UnitPrice = unitPrice
        };

        // Assert
        order.TotalPrice.Should().Be(expectedTotal);
    }

    [Fact]
    public void Order_TotalPrice_IsReadOnly()
    {
        // Arrange
        var order = new Order
        {
            Quantity = 3,
            UnitPrice = 25.00m
        };

        // Act & Assert
        order.TotalPrice.Should().Be(75.00m);
        
        // Change quantity and verify total updates
        order.Quantity = 5;
        order.TotalPrice.Should().Be(125.00m);

        // Change unit price and verify total updates
        order.UnitPrice = 10.00m;
        order.TotalPrice.Should().Be(50.00m);
    }

    [Fact]
    public void Order_SetAllProperties_ShouldStoreValues()
    {
        // Arrange
        var id = Guid.NewGuid();
        var productId = Guid.NewGuid();
        var createdAt = DateTime.UtcNow.AddHours(-1);
        var updatedAt = DateTime.UtcNow;

        // Act
        var order = new Order
        {
            Id = id,
            ProductId = productId,
            CustomerName = "John Doe",
            CustomerEmail = "john.doe@example.com",
            Quantity = 2,
            UnitPrice = 149.99m,
            Status = OrderStatus.Confirmed,
            CreatedAt = createdAt,
            UpdatedAt = updatedAt,
            ProductName = "Test Product"
        };

        // Assert
        order.Id.Should().Be(id);
        order.ProductId.Should().Be(productId);
        order.CustomerName.Should().Be("John Doe");
        order.CustomerEmail.Should().Be("john.doe@example.com");
        order.Quantity.Should().Be(2);
        order.UnitPrice.Should().Be(149.99m);
        order.TotalPrice.Should().Be(299.98m);
        order.Status.Should().Be(OrderStatus.Confirmed);
        order.CreatedAt.Should().Be(createdAt);
        order.UpdatedAt.Should().Be(updatedAt);
        order.ProductName.Should().Be("Test Product");
    }
}

public class OrderStatusTests
{
    [Fact]
    public void OrderStatus_AllEnumValues_ShouldBeDefined()
    {
        // Arrange & Act
        var statuses = Enum.GetValues<OrderStatus>();

        // Assert
        statuses.Should().Contain(OrderStatus.Pending);
        statuses.Should().Contain(OrderStatus.Confirmed);
        statuses.Should().Contain(OrderStatus.Shipped);
        statuses.Should().Contain(OrderStatus.Delivered);
        statuses.Should().Contain(OrderStatus.Cancelled);
        statuses.Should().HaveCount(5);
    }

    [Theory]
    [InlineData(OrderStatus.Pending, 0)]
    [InlineData(OrderStatus.Confirmed, 1)]
    [InlineData(OrderStatus.Shipped, 2)]
    [InlineData(OrderStatus.Delivered, 3)]
    [InlineData(OrderStatus.Cancelled, 4)]
    public void OrderStatus_EnumValues_ShouldHaveCorrectIntegerValues(OrderStatus status, int expectedValue)
    {
        // Act & Assert
        ((int)status).Should().Be(expectedValue);
    }

    [Fact]
    public void OrderStatus_DefaultValue_ShouldBePending()
    {
        // Arrange & Act
        var order = new Order();

        // Assert
        order.Status.Should().Be(OrderStatus.Pending);
        ((int)order.Status).Should().Be(0);
    }
}
