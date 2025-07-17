# Helm Charts for Production-Grade Deployments

This directory contains Helm charts for deploying applications across different environments with production-grade configurations.

## Structure

```
helm/
├── shared-app/                 # Base shared Helm chart
│   ├── Chart.yaml
│   ├── values.yaml            # Default values
│   └── templates/             # Kubernetes resource templates
├── java-app/                  # Java Spring Boot application chart
│   ├── Chart.yaml
│   ├── values.yaml            # Base values
│   ├── values-dev.yaml        # Development environment
│   ├── values-staging.yaml    # Staging environment
│   └── values-production.yaml # Production environment
└── nodejs-app/                # Node.js application chart
    ├── Chart.yaml
    ├── values.yaml            # Base values
    ├── values-dev.yaml        # Development environment
    ├── values-staging.yaml    # Staging environment
    └── values-production.yaml # Production environment
```

## Environment-Specific Configurations

### Development Environment
- **Purpose**: Local development and testing
- **Characteristics**:
  - Single replica
  - Relaxed health checks
  - Debug logging enabled
  - No SSL/TLS requirements
  - Lower resource limits
  - All actuator endpoints exposed (Java)

### Staging Environment
- **Purpose**: Pre-production testing and validation
- **Characteristics**:
  - Multiple replicas (2)
  - Production-like resource limits
  - SSL/TLS enabled with staging certificates
  - Autoscaling enabled
  - Pod disruption budgets
  - Network policies enabled
  - Anti-affinity rules

### Production Environment
- **Purpose**: Live production workloads
- **Characteristics**:
  - High availability (3+ replicas)
  - Maximum resource allocation
  - Strict security settings
  - SSL/TLS with production certificates
  - Advanced autoscaling with behavior policies
  - Pod disruption budgets for zero-downtime
  - Network policies for security
  - Required anti-affinity rules
  - Security headers and rate limiting
  - Node selectors and tolerations

## Key Features

### Security
- **Non-root containers**: All containers run as non-root users
- **Read-only root filesystem**: Enhanced security posture
- **Security contexts**: Proper privilege escalation controls
- **Network policies**: Traffic isolation between environments
- **Pod security standards**: Baseline security requirements

### Monitoring & Observability
- **Health checks**: Comprehensive liveness and readiness probes
- **Metrics collection**: Prometheus metrics endpoints
- **Logging**: Structured logging with appropriate levels
- **Tracing**: Application performance monitoring ready

### High Availability
- **Pod disruption budgets**: Ensure minimum availability during updates
- **Anti-affinity rules**: Distribute pods across nodes
- **Autoscaling**: Horizontal pod autoscaling based on CPU/memory
- **Rolling updates**: Zero-downtime deployments

### Resource Management
- **Resource requests/limits**: Proper resource allocation
- **Quality of Service**: Guaranteed QoS for production workloads
- **Node affinity**: Optimal pod placement

## Usage

### Automatic Environment Detection
The deployment workflows automatically detect the target environment based on the git branch:
- `develop` branch → `dev` environment
- `main` branch → `staging` environment
- `release/*` branches/tags → `production` environment

### Manual Environment Override
You can manually specify the environment using workflow dispatch:
```yaml
environment: dev|staging|production
```

### Values File Precedence
The deployment system uses multiple values files in order of precedence:
1. **Base values**: `values.yaml` (lowest priority)
2. **Environment-specific values**: `values-{environment}.yaml`
3. **Runtime values**: Auto-generated with dynamic image tags and metadata (highest priority)

## Java Application Configuration

### Development
- JVM: `-Xms256m -Xmx512m -XX:+UseG1GC`
- Logging: Debug level
- Endpoints: All actuator endpoints exposed
- Resources: 100m CPU, 256Mi memory

### Staging
- JVM: `-Xms512m -Xmx1g -XX:+UseG1GC -XX:+UseStringDeduplication`
- Logging: Info level
- Endpoints: Limited actuator endpoints
- Resources: 500m CPU, 1Gi memory

### Production
- JVM: `-Xms1g -Xmx2g -XX:+UseG1GC -XX:+UseStringDeduplication -XX:+DisableExplicitGC -server`
- Logging: Warn level
- Endpoints: Minimal actuator endpoints
- Resources: 1000m CPU, 2Gi memory

## Node.js Application Configuration

### Development
- Node.js: `--max-old-space-size=256 --inspect=0.0.0.0:9229`
- Logging: Debug level with all modules
- Resources: 50m CPU, 128Mi memory

### Staging
- Node.js: `--max-old-space-size=512`
- Logging: Info level
- Resources: 250m CPU, 512Mi memory

### Production
- Node.js: `--max-old-space-size=1024 --enable-source-maps`
- Logging: Warn level
- Resources: 500m CPU, 1Gi memory

## Security Considerations

### Production Security Features
- **Strict Transport Security**: HSTS headers enforced
- **Content Security Policy**: XSS protection
- **Rate limiting**: Request throttling
- **Certificate management**: Auto-renewal with cert-manager
- **Network isolation**: Pod-to-pod communication policies
- **Secret management**: Azure Key Vault integration

### Compliance
- **Pod Security Standards**: Restricted profile compliance
- **Resource quotas**: Namespace-level resource management
- **RBAC**: Role-based access control
- **Audit logging**: Kubernetes audit trail

## Troubleshooting

### Common Issues
1. **Values file not found**: Ensure environment-specific values file exists
2. **Resource constraints**: Check namespace resource quotas
3. **Image pull errors**: Verify registry credentials and image tags
4. **Health check failures**: Review probe configurations and application startup time

### Debug Commands
```bash
# Check Helm release status
helm status <release-name> -n <namespace>

# View applied values
helm get values <release-name> -n <namespace>

# Debug template rendering
helm template <release-name> ./helm/<app-name> -f ./helm/<app-name>/values-<env>.yaml
```