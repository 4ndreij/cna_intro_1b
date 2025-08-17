# Solution Architecture

This document describes the architecture of the Dapr-based microservices solution deployed to Azure Container Apps.

## 🏗️ High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Container Apps                     │
│                                                                │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │ ProductSvc  │    │ OrderSvc    │    │   Redis     │        │
│  │ (External)  │    │ (External)  │    │ (Internal)  │        │
│  │             │    │             │    │             │        │
│  │ ┌─────────┐ │    │ ┌─────────┐ │    │ ┌─────────┐ │        │
│  │ │ App     │ │    │ │ App     │ │    │ │ Redis   │ │        │
│  │ │ :8080   │ │    │ │ :8080   │ │    │ │ :6379   │ │        │
│  │ └─────────┘ │    │ └─────────┘ │    │ └─────────┘ │        │
│  │ ┌─────────┐ │    │ ┌─────────┐ │    │             │        │
│  │ │ Dapr    │ │    │ │ Dapr    │ │    │             │        │
│  │ │ Sidecar │ │    │ │ Sidecar │ │    │             │        │
│  │ └─────────┘ │    │ └─────────┘ │    │             │        │
│  └─────────────┘    └─────────────┘    └─────────────┘        │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Dapr Control Plane                        │   │
│  │  • Service Discovery                                   │   │
│  │  • State Store (Redis)                                │   │
│  │  • Pub/Sub (Redis)                                    │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Supporting Azure Services                    │
│                                                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ Container   │  │    Log      │  │   Application          │  │
│  │ Registry    │  │ Analytics   │  │    Insights            │  │
│  │ (Private)   │  │             │  │  (Monitoring)          │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 🎯 Architecture Principles

### Cloud-Native Design
- **Microservices**: Independently deployable services with single responsibilities
- **Containerized**: All services run in lightweight containers
- **Service Mesh**: Dapr provides service-to-service communication, state management, and pub/sub
- **Observability**: Comprehensive logging, metrics, and tracing

### Scalability
- **Horizontal scaling**: Services can scale independently based on load
- **Auto-scaling**: KEDA-based scaling rules for CPU, memory, and HTTP requests
- **Stateless services**: Business logic services maintain no local state

### Resilience
- **Health checks**: Liveness and readiness probes for all services
- **Circuit breaker**: Dapr provides built-in resilience patterns
- **Graceful degradation**: Services handle dependencies gracefully
- **Retry policies**: Configurable retry and timeout policies

### Security
- **Private registry**: Container images stored in private Azure Container Registry
- **HTTPS only**: External traffic encrypted in transit
- **Network isolation**: Internal services not exposed externally
- **Secrets management**: Sensitive data managed through Container Apps secrets

## 🏢 Service Architecture

### ProductService
```
┌─────────────────────────────────────────┐
│            ProductService               │
├─────────────────────────────────────────┤
│ Controllers:                           │
│ • ProductsController                   │
│   - GET /api/products                  │
│   - GET /api/products/{id}             │
│   - POST /api/products                 │
│   - PUT /api/products/{id}             │
│   - DELETE /api/products/{id}          │
├─────────────────────────────────────────┤
│ Business Logic:                        │
│ • ProductService                       │
│ • IProductRepository                   │
├─────────────────────────────────────────┤
│ Data Layer:                            │
│ • Dapr State Store (Redis)             │
│ • In-Memory Cache                      │
├─────────────────────────────────────────┤
│ Integration:                           │
│ • Dapr HTTP API                        │
│ • Health Checks                        │
│ • Application Insights                 │
└─────────────────────────────────────────┘
```

**Responsibilities:**
- Product catalog management (CRUD operations)
- Product inventory tracking
- Product validation and business rules
- Publishes product events via Dapr pub/sub

**State Management:**
- Uses Dapr state store for persistent product data
- Implements in-memory caching for frequently accessed products
- State is partitioned by tenant/customer for multi-tenancy

### OrderService
```
┌─────────────────────────────────────────┐
│             OrderService                │
├─────────────────────────────────────────┤
│ Controllers:                           │
│ • OrdersController                     │
│   - GET /api/orders                    │
│   - GET /api/orders/{id}               │
│   - POST /api/orders                   │
│   - PUT /api/orders/{id}               │
│   - DELETE /api/orders/{id}            │
├─────────────────────────────────────────┤
│ Business Logic:                        │
│ • OrderService                         │
│ • IOrderRepository                     │
│ • OrderProcessingService               │
├─────────────────────────────────────────┤
│ Data Layer:                            │
│ • Dapr State Store (Redis)             │
│ • Event Store                          │
├─────────────────────────────────────────┤
│ Integration:                           │
│ • Dapr Service Invocation              │
│ • Dapr Pub/Sub                         │
│ • ProductService Integration           │
│ • Health Checks                        │
│ • Application Insights                 │
└─────────────────────────────────────────┘
```

**Responsibilities:**
- Order lifecycle management
- Order validation and processing
- Inventory reservation via ProductService
- Order status tracking and updates
- Subscribes to product events

**Communication:**
- **Synchronous**: Direct service-to-service calls via Dapr for immediate operations
- **Asynchronous**: Pub/sub messaging for event-driven workflows

### Redis Container
```
┌─────────────────────────────────────────┐
│            Redis Container              │
├─────────────────────────────────────────┤
│ Configuration:                         │
│ • TCP Transport (:6379)                │
│ • Persistence enabled                  │
│ • Memory optimization                  │
│ • Logging configured                   │
├─────────────────────────────────────────┤
│ Usage:                                 │
│ • Dapr State Store backend             │
│ • Dapr Pub/Sub message broker          │
│ • Session storage                      │
│ • Distributed cache                    │
├─────────────────────────────────────────┤
│ Access:                                │
│ • Internal TCP ingress only            │
│ • Container-to-container               │
│ • No external exposure                 │
└─────────────────────────────────────────┘
```

**Configuration Details:**
- **Persistence**: Save snapshots every 60 seconds if at least 1 key changed
- **Memory Policy**: `allkeys-lru` for automatic eviction
- **Transport**: TCP protocol for optimal Dapr integration
- **Security**: Internal-only access, no external exposure

## 🔄 Communication Patterns

### Service-to-Service Communication

#### Synchronous Communication (Dapr Service Invocation)
```
OrderService ──HTTP──> Dapr Sidecar ──HTTP──> ProductService
                              │
                              ▼
                     ┌─────────────────┐
                     │ Service Discovery│
                     │ Load Balancing  │
                     │ Retries         │
                     │ Circuit Breaker │
                     └─────────────────┘
```

**Benefits:**
- Built-in service discovery
- Load balancing and failover
- Retry policies and circuit breaker
- Automatic mutual TLS (mTLS)
- Observability and tracing

#### Asynchronous Communication (Pub/Sub)
```
ProductService ──Publish──> Redis ──Subscribe──> OrderService
                             │
                             ▼
                    ┌─────────────────┐
                    │   Topic: products │
                    │   Events:        │
                    │   • Created      │
                    │   • Updated      │
                    │   • Deleted      │
                    │   • StockChanged │
                    └─────────────────┘
```

**Event Flow:**
1. ProductService publishes events to `products` topic
2. OrderService subscribes to `products` topic  
3. Events processed asynchronously
4. Order service updates internal state based on product changes

### Data Flow

#### Order Creation Flow
```sequenceDiagram
    participant Client
    participant OrderService
    participant Dapr
    participant ProductService
    participant Redis

    Client->>OrderService: POST /api/orders
    OrderService->>Dapr: Get product (Service Invocation)
    Dapr->>ProductService: GET /api/products/{id}
    ProductService->>Redis: Get product data
    Redis-->>ProductService: Product details
    ProductService-->>Dapr: Product response
    Dapr-->>OrderService: Product details
    OrderService->>Dapr: Save order (State Store)
    Dapr->>Redis: Store order data
    Redis-->>Dapr: Success
    Dapr-->>OrderService: Success
    OrderService->>Dapr: Publish order event (Pub/Sub)
    Dapr->>Redis: Publish to topic
    OrderService-->>Client: Order created
```

#### State Management Flow
```
Application ──Read/Write──> Dapr State API ──TCP──> Redis
                                 │
                                 ▼
                        ┌─────────────────┐
                        │   Features:     │
                        │   • Consistency │
                        │   • Concurrency │
                        │   • Caching     │
                        │   • Encryption  │
                        └─────────────────┘
```

## 🚀 Deployment Architecture

### Container Apps Environment
```
Container Apps Environment (Dapr-enabled)
├── Networking
│   ├── Virtual Network Integration
│   ├── Internal Load Balancer  
│   └── External Application Gateway
├── Compute
│   ├── Managed Kubernetes (hidden)
│   ├── KEDA-based Autoscaling
│   └── Resource Quotas
├── Dapr Control Plane
│   ├── Dapr Operator
│   ├── Dapr Placement Service
│   └── Dapr Sentry (mTLS CA)
└── Observability
    ├── Log Analytics Integration
    ├── Application Insights
    └── Dapr Telemetry
```

### Resource Distribution

#### Development Environment
| Resource | Configuration | Replicas | CPU | Memory |
|----------|---------------|----------|-----|---------|
| ProductService | Basic | 1-3 | 0.5 | 1Gi |
| OrderService | Basic | 1-3 | 0.5 | 1Gi |
| Redis | Minimal | 1 | 0.25 | 0.5Gi |

#### Production Environment  
| Resource | Configuration | Replicas | CPU | Memory |
|----------|---------------|----------|-----|---------|
| ProductService | High Availability | 2-20 | 1.0 | 2Gi |
| OrderService | High Availability | 2-20 | 1.0 | 2Gi |
| Redis | Persistent | 1-3 | 0.5 | 1Gi |

### Scaling Strategies

#### Auto-scaling Rules
```yaml
# HTTP-based scaling
http:
  concurrentRequests: "50"  # Scale at 50 concurrent requests
  
# CPU-based scaling (future)
cpu:
  utilization: "70"         # Scale at 70% CPU

# Memory-based scaling (future)  
memory:
  utilization: "80"         # Scale at 80% memory
```

#### Scaling Behavior
- **Scale-out**: Gradual increase (1 replica every 30 seconds)
- **Scale-in**: Conservative decrease (1 replica every 2 minutes)
- **Min replicas**: Ensures availability (1 for dev, 2 for prod)
- **Max replicas**: Cost control (3-20 depending on environment)

## 🔒 Security Architecture

### Network Security
```
Internet ──HTTPS──> Application Gateway ──HTTPS──> Container Apps
                                                       │
                                                   Internal
                                                  Communication
                                                       │
                                              ┌─────────────┐
                                              │    Redis    │
                                              │ (Internal)  │
                                              └─────────────┘
```

**Security Layers:**
1. **External**: HTTPS termination at Container Apps ingress
2. **Internal**: Service-to-service via Dapr (automatic mTLS)
3. **Data**: Redis accessible only within environment
4. **Identity**: Managed identity for Azure service authentication

### Container Security
- **Non-root containers**: All services run as non-root users
- **Minimal base images**: Alpine Linux for smaller attack surface
- **Private registry**: Images stored in private Azure Container Registry
- **Image scanning**: Vulnerability scanning in CI/CD pipeline
- **Secrets management**: Environment variables for non-sensitive config, Container Apps secrets for sensitive data

### Compliance
- **Data residency**: All data stored in specified Azure region
- **Encryption**: Data encrypted in transit and at rest
- **Audit logging**: All API calls logged to Log Analytics
- **Access control**: RBAC for Azure resources

## 📊 Observability Architecture

### Logging Strategy
```
Applications ──Logs──> Container Apps ──Forward──> Log Analytics
                                                        │
                                                        ▼
                                              ┌─────────────────┐
                                              │ Structured Logs │
                                              │ • JSON format   │
                                              │ • Correlation   │
                                              │ • Filtering     │
                                              └─────────────────┘
```

### Metrics Collection
```
Dapr Sidecars ──Metrics──> Container Apps Environment
                                      │
                                      ▼
                             Application Insights
                                      │
                                      ▼
                            ┌─────────────────────┐
                            │ Custom Dashboards   │
                            │ • Service Health    │
                            │ • Request Metrics   │
                            │ • Error Rates       │
                            │ • Performance       │
                            └─────────────────────┘
```

### Distributed Tracing
- **W3C Trace Context**: Standard correlation across services
- **Dapr integration**: Automatic trace generation for Dapr operations
- **Custom spans**: Application-specific tracing
- **Correlation IDs**: End-to-end request tracking

## 🔄 CI/CD Architecture

### Pipeline Flow
```
Code Repository ──Push──> Build Pipeline ──Test──> Container Registry
                                                           │
                                                           ▼
Deploy Pipeline ──Pull Images──> Container Apps ──Health Check──> Live
```

### Deployment Strategies
- **Blue-Green**: Zero-downtime deployments
- **Canary**: Gradual traffic shifting
- **Rolling**: Sequential container replacement
- **Feature flags**: Runtime feature control

## 🌐 Multi-Environment Strategy

### Environment Isolation
```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ Development │  │   Staging   │  │ Production  │
│             │  │             │  │             │
│ • 1 Region  │  │ • 1 Region  │  │ • 2 Regions │
│ • Shared    │  │ • Dedicated │  │ • Dedicated │
│ • Basic SKU │  │ • Std SKU   │  │ • Prem SKU  │
└─────────────┘  └─────────────┘  └─────────────┘
```

### Configuration Management
- **Environment-specific parameters**: Bicep parameter files
- **Secret management**: Azure Key Vault integration
- **Feature toggles**: Runtime configuration
- **Infrastructure as Code**: Version-controlled Bicep templates

## 📈 Performance Characteristics

### Throughput (Typical)
- **ProductService**: 1000 req/sec per replica
- **OrderService**: 500 req/sec per replica (includes service calls)
- **Redis**: 10,000 ops/sec

### Latency (95th percentile)
- **ProductService**: < 100ms
- **OrderService**: < 200ms (includes downstream call)
- **Service-to-service**: < 50ms via Dapr

### Resource Utilization
- **CPU**: Target 60-70% utilization for optimal performance
- **Memory**: Target 70-80% utilization with headroom for spikes
- **Network**: Dapr adds ~2ms latency for service calls

## 🔧 Technology Stack

### Runtime
- **.NET 8**: Latest LTS version
- **ASP.NET Core**: Web framework
- **Dapr 1.15**: Service mesh and runtime

### Data
- **Redis 7**: State store and pub/sub
- **JSON**: Serialization format
- **Entity Framework Core**: Data access (future)

### Infrastructure
- **Azure Container Apps**: Compute platform
- **Azure Container Registry**: Private image registry
- **Log Analytics**: Centralized logging
- **Application Insights**: APM and monitoring

### DevOps
- **Bicep**: Infrastructure as Code
- **Azure CLI**: Deployment automation
- **Podman**: Container building
- **GitHub Actions**: CI/CD (configurable)

---

This architecture provides a robust, scalable, and maintainable foundation for cloud-native microservices development using Dapr and Azure Container Apps.