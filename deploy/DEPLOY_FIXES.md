# Deploy Scripts Fixes

This document describes the fixes applied to the deployment scripts based on manual deployment testing.

## Fixed Issues

### 1. Application Insights Provisioning
**Problem**: The `--daily-quota-gb` parameter is not supported in current Azure CLI versions and the workspace reference format was incorrect.

**Fix**:
- Removed `--daily-quota-gb` parameter from Log Analytics workspace creation
- Added proper Application Insights extension installation check
- Fixed workspace reference to use full ARM resource ID format
- Separated instrumentation key retrieval into separate variable for clarity

### 2. Container Registry Authentication
**Problem**: The original script used `az acr login` which requires Docker to be installed, but we're using Podman.

**Fix**:
- Updated build-and-push.sh to use `podman login` with Azure Container Registry credentials
- Added proper credential retrieval using `az acr credential show`
- Added registry authentication to container app deployments

### 3. Dapr Component Configuration
**Problem**: The `sed` substitution for `{{REDIS_HOST}}` was not working correctly and creating empty values.

**Fix**:
- Replaced `sed` substitution with direct `cat` heredoc generation
- Ensures proper variable substitution and cleaner YAML generation
- Improved error handling and debugging output

### 4. Missing Color Variables
**Problem**: `CYAN` color variable was missing from build-and-push.sh causing script failures.

**Fix**:
- Added missing `CYAN='\033[0;36m'` color definition
- Standardized color definitions across all scripts

### 5. In-Memory Database Seeding in Production
**Problem**: ProductService was not seeding sample data in Production environment, causing empty product lists in deployed environment.

**Fix**:
- Updated ProductService Program.cs to seed data regardless of environment
- Since we're using in-memory database for demo purposes, sample data is needed in all environments
- Removed the `app.Environment.IsDevelopment()` condition for seeding
- Ensures consistent behavior across Development and Production deployments

### 6. Enhanced Validation Script
**Improvements**: Updated validate.sh to comprehensively test the fixes and refactored functionality.

**Enhancements**:
- Added seeded data verification test to catch the production seeding issue
- Added comprehensive ProductServiceClient integration tests:
  - Tests `GetProductAsync()` during order creation
  - Tests `UpdateProductStockAsync()` during order creation (stock reduction)
  - Tests `UpdateProductStockAsync()` during order cancellation (stock restoration)
- Added prerequisite checks for `jq` and `curl` dependencies
- Improved test output with detailed stock tracking and validation

## Deployment Flow

The corrected deployment process now works as follows:

1. **Infrastructure Setup** (`infrastructure.sh`):
   - Creates Container Registry with admin enabled
   - Creates Log Analytics workspace (without deprecated parameters)
   - Creates Application Insights with proper workspace linking
   - Creates Container Apps Environment with Dapr and monitoring integration

2. **Image Build & Push** (`build-and-push.sh`):
   - Authenticates to ACR using podman with retrieved credentials
   - Builds ProductService and OrderService images
   - Tags and pushes images to Azure Container Registry

3. **Application Deployment** (`deploy.sh`):
   - Deploys Redis container for Dapr state store and pub/sub
   - Creates Dapr components with proper Redis host configuration
   - Deploys ProductService and OrderService with:
     - Proper registry authentication
     - Dapr integration
     - External HTTPS ingress
     - Production environment variables

## Testing Verification

The refactored solution was successfully deployed and tested:

- ✅ ProductService API responding correctly with seeded sample products
- ✅ OrderService API creating orders successfully
- ✅ **Refactored ProductServiceClient** working correctly via Dapr service invocation
- ✅ Stock updates happening correctly through consolidated ProductServiceClient
- ✅ Order cancellation restoring stock through ProductServiceClient
- ✅ In-memory database properly seeded with sample data in Production environment

## Usage

```bash
# Deploy to a new environment
./scripts/deploy.sh --resource-group myapp-rg --environment dev

# Deploy with existing infrastructure
./scripts/deploy.sh --resource-group myapp-rg --skip-infrastructure

# Build and push images only
./scripts/build-and-push.sh myapp-rg myappregistry
```

All scripts now properly handle Azure Container Apps deployment with Dapr integration and the refactored microservices architecture.