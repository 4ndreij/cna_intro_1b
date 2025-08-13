using FluentValidation;
using Shared.DTOs;

namespace OrderService.Validators;

public class CreateOrderDtoValidator : AbstractValidator<CreateOrderDto>
{
    public CreateOrderDtoValidator()
    {
        RuleFor(x => x.ProductId)
            .NotEmpty()
            .WithMessage("Product ID is required");

        RuleFor(x => x.Quantity)
            .GreaterThan(0)
            .WithMessage("Quantity must be greater than 0")
            .LessThanOrEqualTo(1000)
            .WithMessage("Quantity cannot exceed 1000");

        RuleFor(x => x.CustomerEmail)
            .NotEmpty()
            .WithMessage("Customer email is required")
            .EmailAddress()
            .WithMessage("Invalid email format")
            .MaximumLength(320)
            .WithMessage("Email cannot exceed 320 characters");
    }
}
