# AI Observability Logic App MVP

A simplified AI-powered observability system that analyzes DAPR microservices telemetry using Azure Logic Apps and OpenAI GPT-3.5-turbo.

## Overview

This MVP demonstrates how to build an automated observability pipeline that:
- Queries Application Insights for performance, error, and DAPR telemetry data
- Uses Azure OpenAI to analyze the data and provide actionable recommendations
- Simulates email delivery by storing reports in Azure Blob Storage as JSON files
- Runs on a scheduled basis (every 6 hours)

## Architecture

```
Application Insights → Logic App → Azure OpenAI → Blob Storage (Email Simulation)
                                    ↓
                              AI Analysis Engine
```

## Components

### 1. Azure OpenAI Service
- **Model**: GPT-3.5-turbo for cost-effective analysis
- **Purpose**: Analyzes telemetry data and generates recommendations
- **Deployment**: Standard S0 tier with 10 capacity units

### 2. Logic App Workflow
- **Trigger**: Scheduled (every 6 hours)
- **Data Sources**: Application Insights KQL queries
- **Analysis**: AI-powered pattern recognition and recommendations
- **Output**: JSON reports stored in Azure Blob Storage (simulates email delivery)

### 3. Azure Blob Storage
- **Purpose**: Email simulation for environments without Office 365 integration
- **Container**: `emails` for storing observability reports
- **Format**: JSON files with email metadata and AI analysis content

### 4. Application Insights Integration
- **Performance Data**: Request duration, success rates, throughput
- **Error Analysis**: Exception patterns and frequency
- **DAPR Telemetry**: Service invocation metrics and component health

## Key Features

### Intelligent Analysis
- **Pattern Recognition**: Identifies performance trends and anomalies
- **Root Cause Analysis**: Correlates errors across services
- **DAPR-Specific Insights**: Analyzes service communication patterns
- **Actionable Recommendations**: Prioritized improvement suggestions

### Automated Reporting
- **Scheduled Execution**: Runs every 6 hours automatically
- **Blob Storage Output**: JSON files simulating email delivery with structured metadata
- **Structured Data**: JSON-formatted recommendations for easy parsing
- **Historical Context**: 24-hour analysis window with trend identification

### Cost-Optimized Design
- **GPT-3.5-turbo**: Lower cost model for analysis tasks
- **Efficient Queries**: Optimized KQL queries to minimize data transfer
- **Simple Architecture**: No storage requirements, minimal compute overhead

## File Structure

```
deploy/logic-app-observability-mvp/
├── deploy.sh                     # Main deployment script
├── parameters.json                # Configuration parameters
├── logic-app-workflow.json       # Logic App workflow definition
├── prompts/
│   ├── system-prompt.md          # System prompt for OpenAI
│   ├── analysis-prompt-template.md # Analysis request template
│   └── sample-responses.json     # Example AI responses
└── README.md                     # This file
```

## Deployment

### Prerequisites
- Azure CLI installed and authenticated
- Existing Application Insights resource with telemetry data
- Email address for notifications (used in JSON metadata)
- Deployment script automatically creates Application Insights API keys

### Quick Start

1. **Deploy the MVP:**
   ```bash
   cd deploy/logic-app-observability-mvp
   ./deploy.sh -g <resource-group> -a <app-insights-resource-id> -e <notification-email>
   ```

2. **Create Blob Storage Connection:**
   - Go to Azure Portal → Logic App → API connections
   - Create new Azure Blob Storage connection
   - Use the automatically created storage account

3. **Deploy Workflow Definition:**
   ```bash
   # The workflow will be automatically deployed with the Logic App
   # Check Azure Portal for workflow status
   ```

4. **Monitor Reports:**
   ```bash
   # Reports are stored in blob storage
   # Check the emails container for JSON files with observability reports
   ```

### Advanced Configuration

#### Custom Analysis Schedule
Edit `logic-app-workflow.json` to change the trigger frequency:
```json
"recurrence": {
  "frequency": "Hour",
  "interval": 12,  // Change to 12 for twice daily
  "timeZone": "UTC"
}
```

#### Analysis Time Window
Modify the time range in the workflow variables:
```json
"time_range_start": {
  "value": "@formatDateTime(addHours(utcNow(), -48), 'yyyy-MM-ddTHH:mm:ssZ')"  // 48 hours
}
```

## Understanding the Analysis

### KQL Queries
The system runs three main queries against Application Insights:

1. **Performance Query:**
   ```kql
   requests 
   | where timestamp > datetime({{TIME_RANGE}})
   | where name contains 'productservice' or name contains 'orderservice'
   | summarize avg_duration=avg(duration), request_count=count(), success_rate=avg(todouble(success)) * 100 by name
   ```

2. **Error Query:**
   ```kql
   exceptions 
   | where timestamp > datetime({{TIME_RANGE}})
   | where cloud_RoleName contains 'productservice' or cloud_RoleName contains 'orderservice'
   | summarize error_count=count(), unique_errors=dcount(type) by cloud_RoleName
   ```

3. **DAPR Query:**
   ```kql
   traces 
   | where timestamp > datetime({{TIME_RANGE}})
   | where message contains 'dapr' or customDimensions.app_id != ''
   | summarize log_count=count() by cloud_RoleName, severityLevel
   ```

### AI Analysis Output
The AI provides structured recommendations in these categories:
- **Performance**: Response time optimization, caching strategies
- **Reliability**: Error handling, circuit breakers, retry policies
- **Observability**: Monitoring improvements, alerting strategies
- **Cost**: Resource optimization, scaling recommendations

### JSON Report Format
Reports stored in blob storage include:
- **Email Metadata**: Recipients, subject, timestamp, and report type
- **Content Structure**: HTML body content with structured analysis
- **Analysis Data**: JSON-formatted AI recommendations
- 📊 **Analysis Summary**: Overall system health status
- 🚨 **Critical Issues**: Immediate attention items
- 💡 **Recommendations**: Prioritized improvement suggestions
- 📈 **Metrics to Track**: KPIs for monitoring progress
- 📋 **Raw Data Summary**: Query result statistics

## Monitoring and Troubleshooting

### Logic App Execution
Monitor execution in Azure Portal:
- Logic App → Overview → Runs history
- Check for failed runs and error details
- Validate trigger timing and frequency

### Common Issues

1. **Authentication Errors:**
   - Verify Application Insights API key permissions
   - Check OpenAI service key and endpoint

2. **Query Failures:**
   - Validate Application Insights resource ID
   - Ensure services are generating telemetry

3. **Blob Storage Issues:**
   - Verify Azure Blob Storage connection configuration
   - Check storage account permissions and container existence

### Cost Optimization

- **OpenAI Usage**: ~$0.002 per analysis (2000 tokens)
- **Logic App**: ~$0.0001 per action execution
- **Estimated Monthly Cost**: <$5 for 4x daily analysis

## Application Insights Integration

### Automatic SDK Integration
The deployment includes Application Insights SDK integration for .NET services:
- **NuGet Package**: `Microsoft.ApplicationInsights.AspNetCore` 2.22.0
- **Configuration**: Automatic telemetry collection enabled in `Program.cs`
- **Environment Variables**: Both instrumentation key and connection string configured
- **Container Apps**: Environment variables set during deployment

### Real Telemetry Collection
Services automatically send telemetry to Application Insights:
- **Request Telemetry**: HTTP request duration, success rates, and error codes
- **Dependency Telemetry**: External service calls and database operations
- **Exception Telemetry**: Unhandled exceptions with stack traces
- **Custom Telemetry**: DAPR-specific events and custom metrics

### API Key Management
The deployment script automatically creates Application Insights API keys:
- **Dynamic Creation**: No hardcoded keys in deployment scripts
- **Read Permissions**: Limited to telemetry reading only
- **Fallback Handling**: Manual instructions if automatic creation fails
- **Security**: Keys are generated uniquely for each deployment

## Extension Ideas

This MVP can be extended with:
- **Teams/Slack Integration**: Direct notifications to collaboration tools
- **Dashboard Creation**: Automated Power BI report generation
- **Anomaly Detection**: ML-based threshold alerting
- **Incident Correlation**: Link recommendations to actual incidents
- **Historical Trending**: Long-term pattern analysis and prediction
- **Email Integration**: Replace blob storage with actual email sending

## Security Considerations

For production use, consider:
- **Key Vault Integration**: Store API keys securely
- **Managed Identity**: Eliminate stored credentials
- **RBAC**: Limit Application Insights access permissions
- **Network Security**: Private endpoints for all services

## Support

This is a demonstration MVP. For production use:
- Add comprehensive error handling
- Implement retry policies for all external calls
- Add monitoring for the observability system itself
- Consider implementing data retention policies