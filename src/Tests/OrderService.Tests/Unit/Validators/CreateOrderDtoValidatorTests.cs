using FluentValidation;
using Shared.DTOs;

namespace OrderService.Tests.Unit.Validators;

public class CreateOrderDtoValidatorTests
{
    private readonly IValidator<CreateOrderDto> _validator;

    public CreateOrderDtoValidatorTests()
    {
        _validator = new OrderService.Validators.CreateOrderDtoValidator();
    }

    [Fact]
    public void Validate_ValidOrder_ShouldPass()
    {
        // Arrange
        var orderDto = new CreateOrderDto(
            ProductId: Guid.NewGuid(),
            CustomerName: "John Doe",
            CustomerEmail: "john.doe@example.com",
            Quantity: 2
        );

        // Act
        var result = _validator.Validate(orderDto);

        // Assert
        result.IsValid.Should().BeTrue();
        result.Errors.Should().BeEmpty();
    }

    [Fact]
    public void Validate_EmptyProductId_ShouldFail()
    {
        // Arrange
        var orderDto = new CreateOrderDto(
            ProductId: Guid.Empty,
            CustomerName: "John Doe",
            CustomerEmail: "john.doe@example.com",
            Quantity: 2
        );

        // Act
        var result = _validator.Validate(orderDto);

        // Assert
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == nameof(CreateOrderDto.ProductId));
    }

    [Theory]
    [InlineData("")]
    [InlineData(" ")]
    [InlineData(null)]
    public void Validate_InvalidCustomerEmail_ShouldFail(string? email)
    {
        // Arrange
        var orderDto = new CreateOrderDto(
            ProductId: Guid.NewGuid(),
            CustomerName: "John Doe",
            CustomerEmail: email!,
            Quantity: 2
        );

        // Act
        var result = _validator.Validate(orderDto);

        // Assert
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == nameof(CreateOrderDto.CustomerEmail));
    }

    [Theory]
    [InlineData("invalid-email")]
    [InlineData("@domain.com")]
    [InlineData("user@")]
    [InlineData("user.domain.com")]
    public void Validate_MalformedEmail_ShouldFail(string email)
    {
        // Arrange
        var orderDto = new CreateOrderDto(
            ProductId: Guid.NewGuid(),
            CustomerName: "John Doe",
            CustomerEmail: email,
            Quantity: 2
        );

        // Act
        var result = _validator.Validate(orderDto);

        // Assert
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == nameof(CreateOrderDto.CustomerEmail));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(-10)]
    public void Validate_InvalidQuantity_ShouldFail(int quantity)
    {
        // Arrange
        var orderDto = new CreateOrderDto(
            ProductId: Guid.NewGuid(),
            CustomerName: "John Doe",
            CustomerEmail: "john.doe@example.com",
            Quantity: quantity
        );

        // Act
        var result = _validator.Validate(orderDto);

        // Assert
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == nameof(CreateOrderDto.Quantity));
    }

    [Theory]
    [InlineData(1001)]
    [InlineData(2000)]
    [InlineData(int.MaxValue)]
    public void Validate_ExcessiveQuantity_ShouldFail(int quantity)
    {
        // Arrange
        var orderDto = new CreateOrderDto(
            ProductId: Guid.NewGuid(),
            CustomerName: "John Doe",
            CustomerEmail: "john.doe@example.com",
            Quantity: quantity
        );

        // Act
        var result = _validator.Validate(orderDto);

        // Assert
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == nameof(CreateOrderDto.Quantity));
    }

    [Theory]
    [InlineData(1)]
    [InlineData(10)]
    [InlineData(100)]
    [InlineData(1000)]
    public void Validate_ValidQuantity_ShouldPass(int quantity)
    {
        // Arrange
        var orderDto = new CreateOrderDto(
            ProductId: Guid.NewGuid(),
            CustomerName: "John Doe",
            CustomerEmail: "john.doe@example.com",
            Quantity: quantity
        );

        // Act
        var result = _validator.Validate(orderDto);

        // Assert
        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void Validate_LongEmail_ShouldFail()
    {
        // Arrange
        var longEmail = new string('a', 300) + "@example.com";
        var orderDto = new CreateOrderDto(
            ProductId: Guid.NewGuid(),
            CustomerName: "John Doe",
            CustomerEmail: longEmail,
            Quantity: 1
        );

        // Act
        var result = _validator.Validate(orderDto);

        // Assert
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == nameof(CreateOrderDto.CustomerEmail));
    }
}
