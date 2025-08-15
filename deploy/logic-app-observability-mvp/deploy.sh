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

# Create API key for Application Insights (note: this requires manual creation in portal for security)
echo -e "${YELLOW}⚠️  Note: Application Insights API key needs to be created manually${NC}"
echo -e "${YELLOW}   1. Go to Azure Portal -> Application Insights -> API Access${NC}"
echo -e "${YELLOW}   2. Create a new API key with 'Read telemetry' permission${NC}"
echo -e "${YELLOW}   3. Update the Logic App settings with the API key${NC}"


# Deploy Logic App (Consumption Plan)
echo -e "${YELLOW}🔄 Deploying Logic App (Consumption)...${NC}"

# Create Logic App using consumption plan
az logic workflow create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$LOGIC_APP_NAME" \
    --location "$LOCATION" \
    --definition '{}' \
    --output none

echo -e "${GREEN}✅ Logic App created${NC}"

echo -e "${YELLOW}🔧 Logic App created - workflow will be configured manually${NC}"
echo -e "${GREEN}✅ Logic App ready for workflow deployment${NC}"

# Display post-deployment instructions
echo ""
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo -e "${GREEN}========================${NC}"
echo -e "${GREEN}✅ Azure OpenAI Service: $OPENAI_NAME${NC}"
echo -e "${GREEN}✅ Logic App: $LOGIC_APP_NAME${NC}"
echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo -e "${YELLOW}1. Create Application Insights API Key:${NC}"
echo -e "   - Go to: https://portal.azure.com"
echo -e "   - Navigate to your Application Insights resource"
echo -e "   - Go to API Access -> Create API Key"
echo -e "   - Grant 'Read telemetry' permission"
echo -e "   - Copy the API key"
echo ""
echo -e "${YELLOW}2. Update Logic App API Key:${NC}"
echo -e "   az logicapp config appsettings set \\"
echo -e "     --resource-group '$RESOURCE_GROUP' \\"
echo -e "     --name '$LOGIC_APP_NAME' \\"
echo -e "     --settings 'APP_INSIGHTS_API_KEY=<YOUR_API_KEY>'"
echo ""
echo -e "${YELLOW}3. Deploy Logic App Workflow:${NC}"
echo -e "   - The workflow definition will be deployed next"
echo -e "   - Check the logic-app-workflow.json file"
echo ""
echo -e "${BLUE}🔗 Resource URLs:${NC}"
echo -e "   Logic App: https://portal.azure.com/#@/resource${RESOURCE_GROUP}/providers/Microsoft.Logic/workflows/${LOGIC_APP_NAME}"
echo -e "   OpenAI: https://portal.azure.com/#@/resource${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${OPENAI_NAME}"