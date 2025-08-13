using Microsoft.EntityFrameworkCore;
using Shared.Models;

namespace ProductService.Data;

public class ProductDbContext : DbContext
{
    public ProductDbContext(DbContextOptions<ProductDbContext> options) : base(options)
    {
    }

    public DbSet<Product> Products { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Product>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Name).IsRequired().HasMaxLength(100);
            entity.Property(e => e.Description).HasMaxLength(500);
            entity.Property(e => e.Price).HasPrecision(18, 2);
            entity.Property(e => e.Stock).IsRequired();
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.UpdatedAt).IsRequired();
            entity.Property(e => e.IsActive).IsRequired();
            
            // Index for common queries
            entity.HasIndex(e => e.IsActive);
            entity.HasIndex(e => e.CreatedAt);
        });
    }
}
