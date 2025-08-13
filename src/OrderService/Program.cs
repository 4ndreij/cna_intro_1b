using Dapr.Client;
using Microsoft.EntityFrameworkCore;
using OrderService.Data;
using OrderService.Services;
using OrderService.Configuration;
using OrderService.Middleware;
using Serilog;
using System.Text.Json;
using FluentValidation;

var builder = WebApplication.CreateBuilder(args);

// Configure Serilog
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.WithProperty("Service", "OrderService")
    .CreateLogger();

builder.Host.UseSerilog();

// Add services to the container
builder.Services.AddControllers()
    .AddDapr(daprClientBuilder =>
    {
        daprClientBuilder.UseJsonSerializationOptions(new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });
    });

// Add DbContext - using InMemory for development, can be swapped for production
builder.Services.AddDbContext<OrderDbContext>(options =>
    options.UseInMemoryDatabase("OrdersDb"));

// Register services
builder.Services.AddScoped<IOrderService, OrderServiceImpl>();
builder.Services.AddScoped<IProductServiceClient, ProductServiceClient>();
builder.Services.AddValidatorsFromAssemblyContaining<Program>();

// Configuration
builder.Services.Configure<ServiceOptions>(builder.Configuration.GetSection(ServiceOptions.SectionName));
builder.Services.Configure<EventHandlerOptions>(builder.Configuration.GetSection(EventHandlerOptions.SectionName));

// Register HttpClient for external service calls
var serviceOptions = builder.Configuration.GetSection(ServiceOptions.SectionName).Get<ServiceOptions>() ?? new ServiceOptions();
builder.Services.AddHttpClient("ProductService", client =>
{
    client.BaseAddress = new Uri(serviceOptions.ProductServiceUrl);
    client.Timeout = TimeSpan.FromSeconds(serviceOptions.TimeoutSeconds);
});

// Health checks
builder.Services.AddHealthChecks()
    .AddDbContextCheck<OrderDbContext>();

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { 
        Title = "Order Service API", 
        Version = "v1",
        Description = "Order management service with Dapr integration"
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "Order Service API v1");
        c.RoutePrefix = string.Empty; // Serve Swagger UI at root
    });
}

app.UseSerilogRequestLogging();

// Global exception handling
app.UseMiddleware<GlobalExceptionHandlingMiddleware>();

app.UseRouting();
app.UseCloudEvents();
app.MapSubscribeHandler();
app.MapControllers();

// Health check endpoint
app.MapHealthChecks("/health");

try
{
    Log.Information("Starting OrderService");
    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "OrderService terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
