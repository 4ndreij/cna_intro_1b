#!/bin/bash

# Deploy Container Apps Script
# This script deploys ProductService and OrderService to Container Apps

set -euo pipefail

# Configuration
RESOURCE_GROUP="aj-microservices-rg"
ENVIRONMENT_NAME="ajdaprmicro-env"
REGISTRY_NAME="ajdaprmicroregistry.azurecr.io"

echo "🚀 Deploying Applications to Container Apps"
echo "==========================================="

# Deploy ProductService
echo "📦 Deploying ProductService..."
az containerapp create \
    --resource-group $RESOURCE_GROUP \
    --name ajdaprmicro-productservice \
    --environment $ENVIRONMENT_NAME \
    --image ${REGISTRY_NAME}/productservice:latest \
    --target-port 8080 \
    --ingress external \
    --min-replicas 1 \
    --max-replicas 3 \
    --cpu 0.5 \
    --memory 1Gi \
    --enable-dapr \
    --dapr-app-id productservice \
    --dapr-app-port 8080 \
    --registry-server $REGISTRY_NAME \
    --env-vars \
        ASPNETCORE_ENVIRONMENT=Production \
        ASPNETCORE_URLS=http://+:8080

echo "✅ ProductService deployed"

# Deploy OrderService  
echo "📦 Deploying OrderService..."
az containerapp create \
    --resource-group $RESOURCE_GROUP \
    --name ajdaprmicro-orderservice \
    --environment $ENVIRONMENT_NAME \
    --image ${REGISTRY_NAME}/orderservice:latest \
    --target-port 8080 \
    --ingress external \
    --min-replicas 1 \
    --max-replicas 3 \
    --cpu 0.5 \
    --memory 1Gi \
    --enable-dapr \
    --dapr-app-id orderservice \
    --dapr-app-port 8080 \
    --registry-server $REGISTRY_NAME \
    --env-vars \
        ASPNETCORE_ENVIRONMENT=Production \
        ASPNETCORE_URLS=http://+:8080 \
        Services__ProductServiceUrl=http://productservice

echo "✅ OrderService deployed"

# Get service URLs
echo ""
echo "🌐 Service URLs:"
PRODUCT_URL=$(az containerapp show --name ajdaprmicro-productservice --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn --output tsv)
ORDER_URL=$(az containerapp show --name ajdaprmicro-orderservice --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn --output tsv)

echo "ProductService: https://$PRODUCT_URL"
echo "OrderService: https://$ORDER_URL"

echo ""
echo "🧪 Test commands:"
echo "curl https://$PRODUCT_URL/health"
echo "curl https://$PRODUCT_URL/api/products"
echo "curl https://$ORDER_URL/health"
echo "curl https://$ORDER_URL/api/orders"

echo ""
echo "🎉 Deployment complete!"