# AI Observability Analysis Prompt Template

## Context
Analyze telemetry data from DAPR microservices (productservice and orderservice) running on Azure Container Apps. The system uses DAPR for state management, pub/sub messaging, and service-to-service communication.

## System Architecture
- **ProductService**: Manages product catalog, inventory, and stock updates
- **OrderService**: Handles order creation, cancellation, and communicates with ProductService via DAPR service invocation
- **Infrastructure**: Azure Container Apps environment with Redis state store and pub/sub components
- **Observability**: Application Insights with custom telemetry and DAPR instrumentation

## Data Analysis Request

### Time Range
Analyze telemetry data from the last **{{TIME_RANGE_HOURS}}** hours ({{TIME_RANGE_START}} to {{ANALYSIS_TIMESTAMP}}).

### Performance Data
```
{{PERFORMANCE_DATA}}
```

### Error Data  
```
{{ERROR_DATA}}
```

### DAPR Telemetry
```
{{DAPR_DATA}}
```

## Analysis Requirements

Please analyze this data and provide insights focusing on:

1. **Performance Patterns**: 
   - Identify slow endpoints and response time trends
   - Analyze request volumes and success rates
   - Detect performance degradation patterns

2. **Error Analysis**:
   - Categorize error types and frequencies
   - Identify error correlation between services
   - Find recurring failure patterns

3. **DAPR-Specific Issues**:
   - Service invocation latency and failures
   - State store performance and reliability
   - Pub/sub message processing issues
   - Component health and configuration problems

4. **Resource Optimization**:
   - Container scaling recommendations
   - Resource utilization patterns
   - Cost optimization opportunities

5. **Reliability Improvements**:
   - Circuit breaker and retry pattern effectiveness
   - Fault tolerance gaps
   - Monitoring and alerting gaps

## Expected Output

Provide analysis in the specified JSON format with:
- Clear summary of system health status
- Critical issues requiring immediate attention
- Prioritized recommendations with implementation guidance
- Specific metrics to track for continuous improvement
- Focus areas for next analysis cycle

## Constraints
- Focus on actionable recommendations over generic advice
- Consider Azure Container Apps limitations and best practices
- Prioritize DAPR-enabled microservices optimization
- Balance performance improvements with cost considerations