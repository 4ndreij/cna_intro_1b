#!/bin/bash

# Resource Cleanup Script
# Safely removes Azure resources created by the deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
RESOURCE_GROUP=""
PREFIX=""
CONFIRM="false"
DRY_RUN="false"

show_help() {
    cat << EOF
Azure Container Apps Cleanup Script

USAGE:
    $0 --resource-group <name> --prefix <prefix> [OPTIONS]

REQUIRED:
    -g, --resource-group NAME    Azure Resource Group name
    -p, --prefix PREFIX          Resource name prefix used during deployment

OPTIONS:
    --confirm                    Confirm deletion (required for actual cleanup)
    --dry-run                   Show what would be deleted without executing
    -h, --help                  Show this help message

EXAMPLES:
    # Dry run to see what would be deleted
    $0 -g myapp-dev-rg -p daprmicro --dry-run

    # Delete resources (requires confirmation)
    $0 -g myapp-dev-rg -p daprmicro --confirm

SAFETY:
    This script requires explicit confirmation to prevent accidental deletions.
    Use --dry-run first to verify what will be deleted.

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -p|--prefix)
            PREFIX="$2"
            shift 2
            ;;
        --confirm)
            CONFIRM="true"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$RESOURCE_GROUP" ]]; then
    echo -e "${RED}❌ Resource group is required${NC}"
    show_help
    exit 1
fi

if [[ -z "$PREFIX" ]]; then
    echo -e "${RED}❌ Prefix is required${NC}"
    show_help
    exit 1
fi

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${RED}❌ Resource group '$RESOURCE_GROUP' does not exist${NC}"
    exit 1
fi

# Resource names based on deployment patterns
REGISTRY_NAME="${PREFIX}registry"
ENVIRONMENT_NAME="${PREFIX}-env"
LOG_ANALYTICS_NAME="${PREFIX}-logs"
APP_INSIGHTS_NAME="${PREFIX}-insights"
PRODUCTSERVICE_NAME="${PREFIX}-productservice"
ORDERSERVICE_NAME="${PREFIX}-orderservice"
REDIS_NAME="${PREFIX}-redis"

echo -e "${CYAN}🗑️ Azure Container Apps Cleanup${NC}"
echo -e "${CYAN}===============================${NC}"
echo -e "   Resource Group: $RESOURCE_GROUP"
echo -e "   Prefix: $PREFIX"

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}🔍 DRY RUN MODE - No actual changes will be made${NC}"
elif [[ "$CONFIRM" != "true" ]]; then
    echo -e "${RED}⚠️ CONFIRMATION REQUIRED - Use --confirm to proceed${NC}"
fi

echo ""

# List resources that would be deleted
echo -e "${YELLOW}📋 Resources that will be deleted:${NC}"

# Check and list Container Apps
echo -e "${BLUE}Container Apps:${NC}"
for app_name in "$PRODUCTSERVICE_NAME" "$ORDERSERVICE_NAME" "$REDIS_NAME"; do
    if az containerapp show --name "$app_name" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "   ✓ $app_name"
    else
        echo -e "   - $app_name (not found)"
    fi
done

# Check Container Apps Environment
echo -e "${BLUE}Container Apps Environment:${NC}"
if az containerapp env show --name "$ENVIRONMENT_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "   ✓ $ENVIRONMENT_NAME"
else
    echo -e "   - $ENVIRONMENT_NAME (not found)"
fi

# Check Container Registry
echo -e "${BLUE}Container Registry:${NC}"
if az acr show --name "$REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "   ✓ $REGISTRY_NAME"
else
    echo -e "   - $REGISTRY_NAME (not found)"
fi

# Check Application Insights
echo -e "${BLUE}Application Insights:${NC}"
if az monitor app-insights component show --app "$APP_INSIGHTS_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "   ✓ $APP_INSIGHTS_NAME"
else
    echo -e "   - $APP_INSIGHTS_NAME (not found)"
fi

# Check Log Analytics
echo -e "${BLUE}Log Analytics:${NC}"
if az monitor log-analytics workspace show --workspace-name "$LOG_ANALYTICS_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "   ✓ $LOG_ANALYTICS_NAME"
else
    echo -e "   - $LOG_ANALYTICS_NAME (not found)"
fi

echo ""

# Exit if dry run or not confirmed
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${GREEN}🔍 Dry run complete. Use --confirm to proceed with deletion.${NC}"
    exit 0
fi

if [[ "$CONFIRM" != "true" ]]; then
    echo -e "${RED}⚠️ Deletion not confirmed. Use --confirm to proceed.${NC}"
    exit 1
fi

# Perform actual cleanup
echo -e "${RED}🗑️ Starting resource cleanup...${NC}"

# Delete Container Apps
for app_name in "$PRODUCTSERVICE_NAME" "$ORDERSERVICE_NAME" "$REDIS_NAME"; do
    echo -e "${YELLOW}Deleting Container App: $app_name${NC}"
    if az containerapp show --name "$app_name" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        az containerapp delete --name "$app_name" --resource-group "$RESOURCE_GROUP" --yes --output none
        echo -e "${GREEN}✅ Deleted: $app_name${NC}"
    else
        echo -e "${YELLOW}⏭️ Not found: $app_name${NC}"
    fi
done

# Delete Container Apps Environment (after apps are deleted)
echo -e "${YELLOW}Deleting Container Apps Environment: $ENVIRONMENT_NAME${NC}"
if az containerapp env show --name "$ENVIRONMENT_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    az containerapp env delete --name "$ENVIRONMENT_NAME" --resource-group "$RESOURCE_GROUP" --yes --output none
    echo -e "${GREEN}✅ Deleted: $ENVIRONMENT_NAME${NC}"
else
    echo -e "${YELLOW}⏭️ Not found: $ENVIRONMENT_NAME${NC}"
fi

# Delete Container Registry
echo -e "${YELLOW}Deleting Container Registry: $REGISTRY_NAME${NC}"
if az acr show --name "$REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    az acr delete --name "$REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --yes --output none
    echo -e "${GREEN}✅ Deleted: $REGISTRY_NAME${NC}"
else
    echo -e "${YELLOW}⏭️ Not found: $REGISTRY_NAME${NC}"
fi

# Delete Application Insights
echo -e "${YELLOW}Deleting Application Insights: $APP_INSIGHTS_NAME${NC}"
if az monitor app-insights component show --app "$APP_INSIGHTS_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    az monitor app-insights component delete --app "$APP_INSIGHTS_NAME" --resource-group "$RESOURCE_GROUP" --output none
    echo -e "${GREEN}✅ Deleted: $APP_INSIGHTS_NAME${NC}"
else
    echo -e "${YELLOW}⏭️ Not found: $APP_INSIGHTS_NAME${NC}"
fi

# Delete Log Analytics Workspace
echo -e "${YELLOW}Deleting Log Analytics Workspace: $LOG_ANALYTICS_NAME${NC}"
if az monitor log-analytics workspace show --workspace-name "$LOG_ANALYTICS_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    az monitor log-analytics workspace delete --workspace-name "$LOG_ANALYTICS_NAME" --resource-group "$RESOURCE_GROUP" --force true --yes --output none
    echo -e "${GREEN}✅ Deleted: $LOG_ANALYTICS_NAME${NC}"
else
    echo -e "${YELLOW}⏭️ Not found: $LOG_ANALYTICS_NAME${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Cleanup Complete!${NC}"
echo -e "${GREEN}==================${NC}"
echo -e "${GREEN}✅ All resources with prefix '$PREFIX' have been removed from resource group '$RESOURCE_GROUP'${NC}"
echo ""
echo -e "${BLUE}💡 Note: The resource group itself was not deleted.${NC}"
echo -e "   To delete the entire resource group, run:"
echo -e "   ${CYAN}az group delete --name $RESOURCE_GROUP --yes${NC}"