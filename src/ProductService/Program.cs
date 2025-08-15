using Dapr.Client;
using Microsoft.EntityFrameworkCore;
using ProductService.Data;
using ProductService.Services;
using ProductService.Configuration;
using ProductService.Middleware;
using Serilog;
using System.Text.Json;
using FluentValidation;

var builder = WebApplication.CreateBuilder(args);

// Configure Serilog
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.WithProperty("Service", "ProductService")
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
builder.Services.AddDbContext<ProductDbContext>(options =>
    options.UseInMemoryDatabase("ProductsDb"));

// Register services
builder.Services.AddScoped<IProductService, ProductServiceImpl>();
builder.Services.AddValidatorsFromAssemblyContaining<Program>();

// Configuration
builder.Services.Configure<ProductOptions>(builder.Configuration.GetSection(ProductOptions.SectionName));

// Register HttpClient for external service calls (if needed)
builder.Services.AddHttpClient();

// Health checks
builder.Services.AddHealthChecks()
    .AddDbContextCheck<ProductDbContext>();

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { 
        Title = "Product Service API", 
        Version = "v1",
        Description = "Product management service with Dapr integration"
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "Product Service API v1");
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

// Seed data for in-memory database (Development and Production demo)
// Since we're using in-memory database, we need to seed data every time
using var scope = app.Services.CreateScope();
var context = scope.ServiceProvider.GetRequiredService<ProductDbContext>();
await SeedData.Initialize(context);

try
{
    Log.Information("Starting ProductService");
    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "ProductService terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}

// Make the Program class public for testing
public partial class Program { }
