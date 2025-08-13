using FluentValidation;
using Shared.DTOs;

namespace ProductService.Validators;

public class CreateProductDtoValidator : AbstractValidator<CreateProductDto>
{
    public CreateProductDtoValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty()
            .WithMessage("Product name is required")
            .MaximumLength(200)
            .WithMessage("Product name cannot exceed 200 characters");

        RuleFor(x => x.Description)
            .MaximumLength(1000)
            .WithMessage("Description cannot exceed 1000 characters");

        RuleFor(x => x.Price)
            .GreaterThan(0)
            .WithMessage("Price must be greater than 0")
            .LessThanOrEqualTo(999999.99m)
            .WithMessage("Price cannot exceed 999,999.99");

        RuleFor(x => x.Stock)
            .GreaterThanOrEqualTo(0)
            .WithMessage("Stock cannot be negative")
            .LessThanOrEqualTo(10000)
            .WithMessage("Stock cannot exceed 10,000");
    }
}

public class UpdateProductDtoValidator : AbstractValidator<UpdateProductDto>
{
    public UpdateProductDtoValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty()
            .WithMessage("Product name is required")
            .MaximumLength(200)
            .WithMessage("Product name cannot exceed 200 characters");

        RuleFor(x => x.Description)
            .MaximumLength(1000)
            .WithMessage("Description cannot exceed 1000 characters");

        RuleFor(x => x.Price)
            .GreaterThan(0)
            .WithMessage("Price must be greater than 0")
            .LessThanOrEqualTo(999999.99m)
            .WithMessage("Price cannot exceed 999,999.99");

        RuleFor(x => x.Stock)
            .GreaterThanOrEqualTo(0)
            .WithMessage("Stock cannot be negative")
            .LessThanOrEqualTo(10000)
            .WithMessage("Stock cannot exceed 10,000");
    }
}
