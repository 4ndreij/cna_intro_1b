#!/bin/bash

# AI Observability Logic App MVP Deployment
# Simple deployment script for demonstrating AI-powered log analysis

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
LOCATION="eastus2"
APP_INSIGHTS_ID=""
NOTIFICATION_EMAIL=""
PREFIX="aiobs"

show_help() {
    cat << EOF
AI Observability Logic App MVP Deployment

USAGE:
    $0 --resource-group <name> --app-insights-id <id> --notification-email <email> [OPTIONS]

REQUIRED:
    -g, --resource-group NAME       Azure Resource Group name
    -a, --app-insights-id ID        Application Insights resource ID
    -e, --notification-email EMAIL  Email for notifications

OPTIONS:
    -l, --location LOCATION         Azure region [default: eastus2]
    -p, --prefix PREFIX            Resource name prefix [default: aiobs]
    -h, --help                     Show this help message

EXAMPLES:
    # Deploy AI observability system
    $0 -g myapp-rg -a "/subscriptions/.../resourceGroups/.../providers/Microsoft.Insights/components/myapp-insights" -e admin@company.com

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -a|--app-insights-id)
            APP_INSIGHTS_ID="$2"
            shift 2
            ;;
        -e|--notification-email)
            NOTIFICATION_EMAIL="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -p|--prefix)
            PREFIX="$2"
            shift 2
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

if [[ -z "$APP_INSIGHTS_ID" ]]; then
    echo -e "${RED}❌ Application Insights resource ID is required${NC}"
    show_help
    exit 1
fi

if [[ -z "$NOTIFICATION_EMAIL" ]]; then
    echo -e "${RED}❌ Notification email is required${NC}"
    show_help
    exit 1
fi

# Resource names
OPENAI_NAME="${PREFIX}-openai"
LOGIC_APP_NAME="${PREFIX}-logicapp"
STORAGE_NAME="${PREFIX//[-]/}storage$(date +%s)"
SERVICE_PLAN_NAME="${PREFIX}-plan"

echo -e "${CYAN}🤖 AI Observability Logic App MVP Deployment${NC}"
echo -e "${CYAN}=============================================${NC}"
echo -e "   Resource Group: $RESOURCE_GROUP"
echo -e "   Location: $LOCATION"
echo -e "   OpenAI Service: $OPENAI_NAME"
echo -e "   Logic App: $LOGIC_APP_NAME"
echo -e "   App Insights ID: $APP_INSIGHTS_ID"
echo -e "   Notification Email: $NOTIFICATION_EMAIL"
echo ""

# Check prerequisites
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI not found${NC}"
    exit 1
fi

if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not logged into Azure. Run 'az login'${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Create resource group if it doesn't exist
echo -e "${YELLOW}🏗️ Ensuring resource group exists...${NC}"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
echo -e "${GREEN}✅ Resource group ready${NC}"

# Deploy Azure OpenAI service
echo -e "${YELLOW}🧠 Deploying Azure OpenAI service...${NC}"
if ! az cognitiveservices account show --name "$OPENAI_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    az cognitiveservices account create \
        --name "$OPENAI_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --kind "OpenAI" \
        --sku "S0" \
        --output none
    
    echo -e "${GREEN}✅ Azure OpenAI service created${NC}"
else
    echo -e "${YELLOW}⏭️ Azure OpenAI service already exists${NC}"
fi

# Deploy GPT-3.5-turbo model
echo -e "${YELLOW}🤖 Deploying GPT-3.5-turbo model...${NC}"
if ! az cognitiveservices account deployment show \
    --name "$OPENAI_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --deployment-name "gpt-35-turbo" &> /dev/null; then
    
    az cognitiveservices account deployment create \
        --name "$OPENAI_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --deployment-name "gpt-35-turbo" \
        --model-name "gpt-35-turbo" \
        --model-version "0125" \
        --model-format "OpenAI" \
        --scale-capacity 10 \
        --output none
    
    echo -e "${GREEN}✅ GPT-3.5-turbo model deployed${NC}"
else
    echo -e "${YELLOW}⏭️ GPT-3.5-turbo model already exists${NC}"
fi

# Get OpenAI service details
echo -e "${YELLOW}🔑 Getting OpenAI service details...${NC}"
OPENAI_ENDPOINT=$(az cognitiveservices account show \
    --name "$OPENAI_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.endpoint" \
    --output tsv)

OPENAI_API_KEY=$(az cognitiveservices account keys list \
    --name "$OPENAI_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "key1" \
    --output tsv)

echo -e "${GREEN}✅ OpenAI service details retrieved${NC}"

# Extract Application Insights details
echo -e "${YELLOW}📊 Getting Application Insights details...${NC}"
APP_INSIGHTS_APP_ID=$(az monitor app-insights component show \
    --ids "$APP_INSIGHTS_ID" \
    --query "appId" \
    --output tsv)

echo -e "${GREEN}✅ Application Insights details retrieved${NC}"

# Deploy Storage Account for email simulation
echo -e "${YELLOW}💾 Deploying Storage Account for email simulation...${NC}"
if ! az storage account show --name "$STORAGE_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    az storage account create \
        --name "$STORAGE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku "Standard_LRS" \
        --kind "StorageV2" \
        --access-tier "Hot" \
        --output none
    
    echo -e "${GREEN}✅ Storage Account created${NC}"
else
    echo -e "${YELLOW}⏭️ Storage Account already exists${NC}"
fi

# Create emails container in storage account
echo -e "${YELLOW}📁 Creating emails container...${NC}"
STORAGE_KEY=$(az storage account keys list \
    --account-name "$STORAGE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[0].value" \
    --output tsv)

az storage container create \
    --name "emails" \
    --account-name "$STORAGE_NAME" \
    --account-key "$STORAGE_KEY" \
    --output none

echo -e "${GREEN}✅ Emails container created${NC}"

# Create Application Insights API Key dynamically
echo -e "${YELLOW}🔑 Creating Application Insights API Key for Logic App...${NC}"

# Extract Application Insights app name from the resource ID
APP_INSIGHTS_NAME=$(echo "$APP_INSIGHTS_ID" | sed 's|.*/providers/Microsoft.Insights/components/||')

APP_INSIGHTS_API_KEY_NAME="logic-app-observability-$(date +%s)"
APP_INSIGHTS_API_KEY=$(az monitor app-insights api-key create \
    --app "$APP_INSIGHTS_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --api-key "$APP_INSIGHTS_API_KEY_NAME" \
    --read-properties ReadTelemetry \
    --query apiKey \
    --output tsv 2>/dev/null)

if [ -z "$APP_INSIGHTS_API_KEY" ]; then
    echo -e "${RED}❌ Failed to create Application Insights API key${NC}"
    echo -e "${YELLOW}⚠️  Trying alternative method with extracted name: $APP_INSIGHTS_NAME${NC}"
    
    # Alternative: Try using the full resource ID
    APP_INSIGHTS_API_KEY=$(az monitor app-insights api-key create \
        --ids "$APP_INSIGHTS_ID" \
        --api-key "$APP_INSIGHTS_API_KEY_NAME" \
        --read-properties ReadTelemetry \
        --query apiKey \
        --output tsv 2>/dev/null)
    
    if [ -z "$APP_INSIGHTS_API_KEY" ]; then
        echo -e "${RED}❌ Failed to create Application Insights API key using both methods${NC}"
        echo -e "${YELLOW}⚠️  Manual step required: Please create API key in Azure Portal${NC}"
        echo -e "${YELLOW}   1. Go to: https://portal.azure.com${NC}"
        echo -e "${YELLOW}   2. Navigate to Application Insights: $APP_INSIGHTS_NAME${NC}"
        echo -e "${YELLOW}   3. Go to API Access -> Create API Key${NC}"
        echo -e "${YELLOW}   4. Grant 'Read telemetry' permission${NC}"
        APP_INSIGHTS_API_KEY="REPLACE_WITH_MANUAL_API_KEY"
    else
        echo -e "${GREEN}✅ Application Insights API Key created (alternative method): $APP_INSIGHTS_API_KEY_NAME${NC}"
    fi
else
    echo -e "${GREEN}✅ Application Insights API Key created: $APP_INSIGHTS_API_KEY_NAME${NC}"
fi

# Create Azure Blob Storage API Connection for Logic App
echo -e "${YELLOW}🔗 Creating Azure Blob Storage API Connection...${NC}"
STORAGE_KEY=$(az storage account keys list \
    --account-name "$STORAGE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[0].value" \
    --output tsv)

# Create the Azure Blob Storage API connection with correct parameters
az resource create \
    --resource-group "$RESOURCE_GROUP" \
    --resource-type "Microsoft.Web/connections" \
    --name "azureblob" \
    --location "$LOCATION" \
    --properties '{
        "displayName": "Azure Blob Storage",
        "api": {
            "id": "/subscriptions/'$(az account show --query id --output tsv)'/providers/Microsoft.Web/locations/'$LOCATION'/managedApis/azureblob"
        },
        "parameterValues": {
            "accountName": "'$STORAGE_NAME'",
            "accessKey": "'$STORAGE_KEY'"
        }
    }' --output none

echo -e "${GREEN}✅ Azure Blob Storage connection created${NC}"


# Deploy Logic App with full workflow
echo -e "${YELLOW}🔄 Deploying Logic App with complete observability workflow...${NC}"

# Update the workflow template with current parameters
cp logic-app-workflow.json logic-app-workflow-deploy.json

# Update parameters with actual values
sed -i 's|"defaultValue": "867042431c75441bafa312eead733c7d"|"defaultValue": "'$OPENAI_API_KEY'"|' logic-app-workflow-deploy.json
sed -i 's|"defaultValue": "0662b407-b62e-4e2d-a8b0-a9f0dc28893f"|"defaultValue": "'$APP_INSIGHTS_APP_ID'"|' logic-app-workflow-deploy.json
sed -i 's|"defaultValue": "cheqc2k6xt4gd5ddidkxrnsers4wtwl8enpm7z8e"|"defaultValue": "'$APP_INSIGHTS_API_KEY'"|' logic-app-workflow-deploy.json
sed -i 's|"defaultValue": "admin@example.com"|"defaultValue": "'$NOTIFICATION_EMAIL'"|' logic-app-workflow-deploy.json
sed -i 's|"defaultValue": "aiobsstorage1755328600"|"defaultValue": "'$STORAGE_NAME'"|' logic-app-workflow-deploy.json

# Update connection references to use current resource group and subscription
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
sed -i 's|cna-observability-demo-rg|'$RESOURCE_GROUP'|g' logic-app-workflow-deploy.json
sed -i 's|b4852309-dbd4-4520-9c64-3e8ea7353799|'$SUBSCRIPTION_ID'|g' logic-app-workflow-deploy.json

# Deploy the full workflow
az logic workflow create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$LOGIC_APP_NAME" \
    --location "$LOCATION" \
    --definition @logic-app-workflow-deploy.json \
    --output none

# Clean up temporary file
rm -f logic-app-workflow-deploy.json

echo -e "${GREEN}✅ Logic App with complete workflow deployed${NC}"

# Verify Logic App deployment
echo -e "${YELLOW}🔍 Verifying Logic App deployment...${NC}"
LOGIC_APP_STATE=$(az logic workflow show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$LOGIC_APP_NAME" \
    --query "state" \
    --output tsv)

if [ "$LOGIC_APP_STATE" = "Enabled" ]; then
    echo -e "${GREEN}✅ Logic App is enabled and ready${NC}"
else
    echo -e "${YELLOW}⚠️  Logic App state: $LOGIC_APP_STATE${NC}"
fi

# Display post-deployment instructions
echo ""
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo -e "${GREEN}========================${NC}"
echo -e "${GREEN}✅ Azure OpenAI Service: $OPENAI_NAME${NC}"
echo -e "${GREEN}✅ Logic App: $LOGIC_APP_NAME${NC}"
echo -e "${GREEN}✅ Storage Account: $STORAGE_NAME${NC}"
echo ""
echo -e "${BLUE}📋 Deployment Summary:${NC}"
echo -e "${GREEN}✅ All components automatically configured:${NC}"
echo -e "   • Azure OpenAI Service: $OPENAI_NAME"
echo -e "   • Logic App with full workflow: $LOGIC_APP_NAME" 
echo -e "   • Storage Account: $STORAGE_NAME"
echo -e "   • Blob Storage connection: azureblob"
if [[ "$APP_INSIGHTS_API_KEY" != "REPLACE_WITH_MANUAL_API_KEY" ]]; then
    echo -e "   • Application Insights API key: $APP_INSIGHTS_API_KEY_NAME"
fi
echo ""
echo -e "${BLUE}📊 Observability System Status:${NC}"
echo -e "${GREEN}✅ Scheduled Analysis: Every 6 hours (UTC)${NC}"
echo -e "${GREEN}✅ Email Reports: Stored in $STORAGE_NAME/emails/${NC}"
echo -e "${GREEN}✅ AI Analysis: GPT-3.5-turbo powered insights${NC}"
echo ""
if [[ "$APP_INSIGHTS_API_KEY" == "REPLACE_WITH_MANUAL_API_KEY" ]]; then
    echo -e "${YELLOW}⚠️  Manual Action Required:${NC}"
    echo -e "   Create Application Insights API Key:"
    echo -e "   1. Go to: https://portal.azure.com"
    echo -e "   2. Navigate to Application Insights: $APP_INSIGHTS_NAME"
    echo -e "   3. Go to API Access -> Create API Key"
    echo -e "   4. Grant 'Read telemetry' permission"
    echo -e "   5. Update the workflow parameters in Azure Portal"
    echo ""
fi
echo -e "${BLUE}🧪 Testing:${NC}"
echo -e "   You can manually trigger the Logic App to test:"
echo -e "   - Go to Logic App in Azure Portal"
echo -e "   - Click 'Run Trigger' -> 'scheduled_analysis'"
echo -e "   - Check $STORAGE_NAME/emails/ for generated reports"
echo ""
echo -e "${BLUE}🔗 Resource URLs:${NC}"
echo -e "   Logic App: https://portal.azure.com/#@/resource${RESOURCE_GROUP}/providers/Microsoft.Logic/workflows/${LOGIC_APP_NAME}"
echo -e "   OpenAI: https://portal.azure.com/#@/resource${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${OPENAI_NAME}"
echo -e "   Storage: https://portal.azure.com/#@/resource${RESOURCE_GROUP}/providers/Microsoft.Storage/storageAccounts/${STORAGE_NAME}"