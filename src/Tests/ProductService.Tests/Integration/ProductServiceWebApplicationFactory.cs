using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using ProductService.Data;

namespace ProductService.Tests.Integration;

public class ProductServiceWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            // Remove the actual database context
            var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(DbContextOptions<ProductDbContext>));
            if (descriptor != null)
                services.Remove(descriptor);

            // Add in-memory database for testing
            services.AddDbContext<ProductDbContext>(options =>
            {
                options.UseInMemoryDatabase("InMemoryProductDb");
            });

            // Ensure the database is created
            var serviceProvider = services.BuildServiceProvider();
            using var scope = serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<ProductDbContext>();
            context.Database.EnsureCreated();
        });
    }
}
