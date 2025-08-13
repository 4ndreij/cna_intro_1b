using Shared.DTOs;
using Shared.Models;
using System.ComponentModel.DataAnnotations;

namespace Shared.Tests.Unit.DTOs;

public class OrderDtoTests
{
    [Fact]
    public void CreateOrderDto_ValidData_ShouldCreateSuccessfully()
    {
        // Arrange
        var productId = Guid.NewGuid();

        // Act
        var dto = new CreateOrderDto(
            ProductId: productId,
            CustomerName: "John Doe",
            CustomerEmail: "john.doe@example.com",
            Quantity: 2
        );

        // Assert
        dto.ProductId.Should().Be(productId);
        dto.CustomerName.Should().Be("John Doe");
        dto.CustomerEmail.Should().Be("john.doe@example.com");
        dto.Quantity.Should().Be(2);
    }

    [Fact]
    public void OrderDto_AllProperties_ShouldBeSet()
    {
        // Arrange
        var id = Guid.NewGuid();
        var productId = Guid.NewGuid();
        var createdAt = DateTime.UtcNow;
        var updatedAt = DateTime.UtcNow.AddMinutes(10);

        // Act
        var dto = new OrderDto(
            Id: id,
            ProductId: productId,
            ProductName: "Test Product",
            CustomerName: "Jane Doe",
            CustomerEmail: "jane.doe@example.com",
            Quantity: 3,
            UnitPrice: 99.99m,
            TotalPrice: 299.97m,
            Status: OrderStatus.Confirmed,
            CreatedAt: createdAt,
            UpdatedAt: updatedAt
        );

        // Assert
        dto.Id.Should().Be(id);
        dto.ProductId.Should().Be(productId);
        dto.ProductName.Should().Be("Test Product");
        dto.CustomerName.Should().Be("Jane Doe");
        dto.CustomerEmail.Should().Be("jane.doe@example.com");
        dto.Quantity.Should().Be(3);
        dto.UnitPrice.Should().Be(99.99m);
        dto.TotalPrice.Should().Be(299.97m);
        dto.Status.Should().Be(OrderStatus.Confirmed);
        dto.CreatedAt.Should().Be(createdAt);
        dto.UpdatedAt.Should().Be(updatedAt);
    }

    [Fact]
    public void CreateOrderDto_EmptyProductId_ShouldFailValidation()
    {
        // Arrange
        var dto = new CreateOrderDto(
            ProductId: Guid.Empty,
            CustomerName: "John Doe",
            CustomerEmail: "john.doe@example.com",
            Quantity: 1
        );

        var validationContext = new ValidationContext(dto);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(dto, validationContext, results, true);

        // Assert
        isValid.Should().BeFalse();
        results.Should().Contain(r => r.MemberNames.Contains(nameof(CreateOrderDto.ProductId)));
    }

    [Theory]
    [InlineData("")]
    [InlineData(" ")]
    [InlineData(null)]
    public void CreateOrderDto_InvalidCustomerName_ShouldFailValidation(string? customerName)
    {
        // Arrange
        var dto = new CreateOrderDto(
            ProductId: Guid.NewGuid(),
            CustomerName: customerName!,
            CustomerEmail: "john.doe@example.com",
            Quantity: 1
        );

        var validationContext = new ValidationContext(dto);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(dto, validationContext, results, true);

        // Assert
        isValid.Should().BeFalse();
        results.Should().Contain(r => r.MemberNames.Contains(nameof(CreateOrderDto.CustomerName)));
    }

    [Fact]
    public void CreateOrderDto_LongCustomerName_ShouldFailValidation()
    {
        // Arrange
        var longName = new string('A', 101); // Exceeds 100 character limit
        var dto = new CreateOrderDto(
            ProductId: Guid.NewGuid(),
            CustomerName: longName,
            CustomerEmail: "john.doe@example.com",
            Quantity: 1
        );

        var validationContext = new ValidationContext(dto);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(dto, validationContext, results, true);

        // Assert
        isValid.Should().BeFalse();
        results.Should().Contain(r => r.MemberNames.Contains(nameof(CreateOrderDto.CustomerName)));
    }

    [Theory]
    [InlineData("")]
    [InlineData(" ")]
    [InlineData(null)]
    [InlineData("invalid-email")]
    [InlineData("@domain.com")]
    [InlineData("user@")]
    public void CreateOrderDto_InvalidEmail_ShouldFailValidation(string? email)
    {
        // Arrange
        var dto = new CreateOrderDto(
            ProductId: Guid.NewGuid(),
            CustomerName: "John Doe",
            CustomerEmail: email!,
            Quantity: 1
        );

        var validationContext = new ValidationContext(dto);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(dto, validationContext, results, true);

        // Assert
        isValid.Should().BeFalse();
        results.Should().Contain(r => r.MemberNames.Contains(nameof(CreateOrderDto.CustomerEmail)));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(-10)]
    public void CreateOrderDto_InvalidQuantity_ShouldFailValidation(int quantity)
    {
        // Arrange
        var dto = new CreateOrderDto(
            ProductId: Guid.NewGuid(),
            CustomerName: "John Doe",
            CustomerEmail: "john.doe@example.com",
            Quantity: quantity
        );

        var validationContext = new ValidationContext(dto);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(dto, validationContext, results, true);

        // Assert
        isValid.Should().BeFalse();
        results.Should().Contain(r => r.MemberNames.Contains(nameof(CreateOrderDto.Quantity)));
    }

    [Fact]
    public void UpdateOrderStatusDto_ValidStatus_ShouldCreateSuccessfully()
    {
        // Arrange & Act
        var dto = new UpdateOrderStatusDto(Status: OrderStatus.Shipped);

        // Assert
        dto.Status.Should().Be(OrderStatus.Shipped);
    }

    [Fact]
    public void UpdateOrderStatusDto_AllOrderStatuses_ShouldBeValid()
    {
        // Arrange & Act & Assert
        foreach (OrderStatus status in Enum.GetValues<OrderStatus>())
        {
            var dto = new UpdateOrderStatusDto(Status: status);
            dto.Status.Should().Be(status);
        }
    }
}
