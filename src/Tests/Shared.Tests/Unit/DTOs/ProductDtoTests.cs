using Shared.DTOs;
using System.ComponentModel.DataAnnotations;

namespace Shared.Tests.Unit.DTOs;

public class ProductDtoTests
{
    [Fact]
    public void CreateProductDto_ValidData_ShouldCreateSuccessfully()
    {
        // Arrange & Act
        var dto = new CreateProductDto(
            Name: "Test Product",
            Description: "A test product description",
            Price: 99.99m,
            Stock: 50
        );

        // Assert
        dto.Name.Should().Be("Test Product");
        dto.Description.Should().Be("A test product description");
        dto.Price.Should().Be(99.99m);
        dto.Stock.Should().Be(50);
    }

    [Fact]
    public void UpdateProductDto_ValidData_ShouldCreateSuccessfully()
    {
        // Arrange & Act
        var dto = new UpdateProductDto(
            Name: "Updated Product",
            Description: "Updated description",
            Price: 149.99m,
            Stock: 25
        );

        // Assert
        dto.Name.Should().Be("Updated Product");
        dto.Description.Should().Be("Updated description");
        dto.Price.Should().Be(149.99m);
        dto.Stock.Should().Be(25);
    }

    [Fact]
    public void ProductDto_AllProperties_ShouldBeSet()
    {
        // Arrange
        var id = Guid.NewGuid();
        var createdAt = DateTime.UtcNow;
        var updatedAt = DateTime.UtcNow.AddMinutes(5);

        // Act
        var dto = new ProductDto(
            Id: id,
            Name: "Test Product",
            Description: "Description",
            Price: 99.99m,
            Stock: 10,
            CreatedAt: createdAt,
            UpdatedAt: updatedAt,
            IsActive: true
        );

        // Assert
        dto.Id.Should().Be(id);
        dto.Name.Should().Be("Test Product");
        dto.Description.Should().Be("Description");
        dto.Price.Should().Be(99.99m);
        dto.Stock.Should().Be(10);
        dto.CreatedAt.Should().Be(createdAt);
        dto.UpdatedAt.Should().Be(updatedAt);
        dto.IsActive.Should().BeTrue();
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(-100)]
    [InlineData(0)]
    public void CreateProductDto_InvalidPrice_ShouldFailValidation(decimal invalidPrice)
    {
        // Arrange
        var dto = new CreateProductDto(
            Name: "Test Product",
            Description: "Description",
            Price: invalidPrice,
            Stock: 10
        );

        var validationContext = new ValidationContext(dto);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(dto, validationContext, results, true);

        // Assert
        isValid.Should().BeFalse();
        results.Should().Contain(r => r.MemberNames.Contains(nameof(CreateProductDto.Price)));
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(-100)]
    public void CreateProductDto_InvalidStock_ShouldFailValidation(int invalidStock)
    {
        // Arrange
        var dto = new CreateProductDto(
            Name: "Test Product",
            Description: "Description",
            Price: 99.99m,
            Stock: invalidStock
        );

        var validationContext = new ValidationContext(dto);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(dto, validationContext, results, true);

        // Assert
        isValid.Should().BeFalse();
        results.Should().Contain(r => r.MemberNames.Contains(nameof(CreateProductDto.Stock)));
    }

    [Fact]
    public void CreateProductDto_EmptyName_ShouldFailValidation()
    {
        // Arrange
        var dto = new CreateProductDto(
            Name: "",
            Description: "Description",
            Price: 99.99m,
            Stock: 10
        );

        var validationContext = new ValidationContext(dto);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(dto, validationContext, results, true);

        // Assert
        isValid.Should().BeFalse();
        results.Should().Contain(r => r.MemberNames.Contains(nameof(CreateProductDto.Name)));
    }

    [Fact]
    public void CreateProductDto_LongName_ShouldFailValidation()
    {
        // Arrange
        var longName = new string('A', 101); // Exceeds 100 character limit
        var dto = new CreateProductDto(
            Name: longName,
            Description: "Description",
            Price: 99.99m,
            Stock: 10
        );

        var validationContext = new ValidationContext(dto);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(dto, validationContext, results, true);

        // Assert
        isValid.Should().BeFalse();
        results.Should().Contain(r => r.MemberNames.Contains(nameof(CreateProductDto.Name)));
    }

    [Fact]
    public void CreateProductDto_LongDescription_ShouldFailValidation()
    {
        // Arrange
        var longDescription = new string('A', 501); // Exceeds 500 character limit
        var dto = new CreateProductDto(
            Name: "Test Product",
            Description: longDescription,
            Price: 99.99m,
            Stock: 10
        );

        var validationContext = new ValidationContext(dto);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(dto, validationContext, results, true);

        // Assert
        isValid.Should().BeFalse();
        results.Should().Contain(r => r.MemberNames.Contains(nameof(CreateProductDto.Description)));
    }
}
