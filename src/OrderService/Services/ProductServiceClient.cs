using Dapr.Client;
using Shared.DTOs;

namespace OrderService.Services;

/// <summary>
/// Service for communicating with external Product Service
/// </summary>
public interface IProductServiceClient
{
    Task<ProductDto?> GetProductAsync(Guid productId);
    Task UpdateProductStockAsync(Guid productId, int newStock);
}

public class ProductServiceClient(
    DaprClient daprClient,
    IHttpClientFactory httpClientFactory,
    ILogger<ProductServiceClient> logger) : IProductServiceClient
{
    private const string ProductServiceName = "productservice";

    public async Task<ProductDto?> GetProductAsync(Guid productId)
    {
        try
        {
            // Try Dapr service invocation first
            var response = await daprClient.InvokeMethodAsync<ProductDto>(
                HttpMethod.Get,
                ProductServiceName, 
                $"api/products/{productId}");
            
            return response;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Dapr service invocation failed for product {ProductId}, trying direct HTTP call", productId);
            
            // Fallback to direct HTTP call through ProductService
            try
            {
                using var httpClient = httpClientFactory.CreateClient("ProductService");
                var directResponse = await httpClient.GetFromJsonAsync<ProductDto>(
                    $"api/products/{productId}");
                
                logger.LogInformation("Successfully retrieved product {ProductId} via direct HTTP call", productId);
                return directResponse;
            }
            catch (Exception directEx)
            {
                logger.LogError(directEx, "Both Dapr service invocation and direct HTTP call failed for product {ProductId}", productId);
                return null;
            }
        }
    }

    public async Task UpdateProductStockAsync(Guid productId, int newStock)
    {
        try
        {
            // Try Dapr service invocation first with HttpRequestMessage for PATCH
            using var request = daprClient.CreateInvokeMethodRequest(
                ProductServiceName,
                $"api/products/{productId}/stock",
                new { stock = newStock });
            request.Method = HttpMethod.Patch;
            
            await daprClient.InvokeMethodAsync(request);
            
            logger.LogInformation("Successfully updated stock for product {ProductId} via Dapr service invocation", productId);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Dapr service invocation failed for updating stock of product {ProductId}, trying direct HTTP call", productId);
            
            // Fallback to direct HTTP call with PATCH method
            try
            {
                using var httpClient = httpClientFactory.CreateClient("ProductService");
                var stockUpdate = new { stock = newStock };
                var response = await httpClient.PatchAsJsonAsync($"api/products/{productId}/stock", stockUpdate);
                response.EnsureSuccessStatusCode();
                
                logger.LogInformation("Successfully updated stock for product {ProductId} via direct HTTP call", productId);
            }
            catch (Exception directEx)
            {
                logger.LogError(directEx, "Both Dapr service invocation and direct HTTP call failed for updating stock of product {ProductId}", productId);
                throw;
            }
        }
    }
}
