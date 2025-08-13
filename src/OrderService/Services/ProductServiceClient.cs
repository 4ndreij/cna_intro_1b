using Dapr.Client;
using Shared.DTOs;
using Shared.Exceptions;

namespace OrderService.Services;

/// <summary>
/// Service for communicating with external Product Service
/// </summary>
public interface IProductServiceClient
{
    Task<ProductDto?> GetProductAsync(Guid productId, CancellationToken cancellationToken = default);
    Task UpdateProductStockAsync(Guid productId, int newStock, CancellationToken cancellationToken = default);
}

public class ProductServiceClient : IProductServiceClient
{
    private readonly DaprClient _daprClient;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<ProductServiceClient> _logger;
    private const string ProductServiceName = "productservice";

    public ProductServiceClient(
        DaprClient daprClient,
        IHttpClientFactory httpClientFactory,
        ILogger<ProductServiceClient> logger)
    {
        _daprClient = daprClient;
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    public async Task<ProductDto?> GetProductAsync(Guid productId, CancellationToken cancellationToken = default)
    {
        try
        {
            // Try Dapr service invocation first
            var response = await _daprClient.InvokeMethodAsync<ProductDto>(
                ProductServiceName, 
                $"api/products/{productId}", 
                cancellationToken);
            
            return response;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Dapr service invocation failed for product {ProductId}, trying direct HTTP call", productId);
            
            // Fallback to direct HTTP call through ProductService
            try
            {
                using var httpClient = _httpClientFactory.CreateClient("ProductService");
                var directResponse = await httpClient.GetFromJsonAsync<ProductDto>(
                    $"api/products/{productId}", cancellationToken);
                
                _logger.LogInformation("Successfully retrieved product {ProductId} via direct HTTP call", productId);
                return directResponse;
            }
            catch (Exception directEx)
            {
                _logger.LogError(directEx, "Both Dapr service invocation and direct HTTP call failed for product {ProductId}", productId);
                throw new ExternalServiceException("ProductService", $"Failed to retrieve product {productId}", directEx);
            }
        }
    }

    public async Task UpdateProductStockAsync(Guid productId, int newStock, CancellationToken cancellationToken = default)
    {
        try
        {
            // Try Dapr service invocation first with HttpRequestMessage for PATCH
            using var request = _daprClient.CreateInvokeMethodRequest(
                ProductServiceName,
                $"api/products/{productId}/stock",
                new { stock = newStock });
            request.Method = HttpMethod.Patch;
            
            await _daprClient.InvokeMethodAsync(request, cancellationToken);
            
            _logger.LogInformation("Successfully updated stock for product {ProductId} via Dapr service invocation", productId);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Dapr service invocation failed for updating stock of product {ProductId}, trying direct HTTP call", productId);
            
            // Fallback to direct HTTP call with PATCH method
            try
            {
                using var httpClient = _httpClientFactory.CreateClient("ProductService");
                var stockUpdate = new { stock = newStock };
                var response = await httpClient.PatchAsJsonAsync($"api/products/{productId}/stock", stockUpdate, cancellationToken);
                response.EnsureSuccessStatusCode();
                
                _logger.LogInformation("Successfully updated stock for product {ProductId} via direct HTTP call", productId);
            }
            catch (Exception directEx)
            {
                _logger.LogError(directEx, "Both Dapr service invocation and direct HTTP call failed for updating stock of product {ProductId}", productId);
                throw new ExternalServiceException("ProductService", $"Failed to update stock for product {productId}", directEx);
            }
        }
    }
}
