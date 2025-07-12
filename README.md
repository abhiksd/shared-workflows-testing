# Production-Grade GitHub Actions Workflow for Azure AKS

This repository contains a comprehensive, production-ready GitHub Actions workflow system for deploying applications to Azure Kubernetes Service (AKS) with support for multiple environments, multiple application types, and advanced deployment strategies.

## 🚀 Features

- **Multi-Environment Support**: Development, Staging, and Production environments
- **Multi-Application Support**: Java Spring Boot and Node.js applications
- **Smart Versioning**: Semantic versioning for production, short SHA for development
- **Helm Chart Deployment**: Dynamic configuration based on environment and application type
- **Release Management**: Automated release creation for production deployments
- **Security**: SBOM generation, security scanning, and secure container practices
- **Monitoring**: Built-in health checks and observability
- **Efficiency**: Docker build caching and conditional deployments

## 📁 Repository Structure

```
.github/
├── workflows/
│   ├── shared-deploy.yml          # Main shared workflow
│   ├── deploy-java-app.yml        # Java application deployment
│   └── deploy-nodejs-app.yml      # Node.js application deployment
└── actions/
    ├── version-strategy/          # Version determination logic
    ├── check-changes/             # Change detection
    ├── docker-build-push/         # Docker build and push
    ├── helm-deploy/               # Helm deployment
    └── create-release/            # Release creation
helm/
└── shared-app/                    # Shared Helm chart
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── deployment.yaml
        ├── service.yaml
        ├── ingress.yaml
        ├── configmap.yaml
        └── _helpers.tpl
```

## 🛠️ Setup Instructions

### 1. Azure Setup

#### Create Azure Service Principal
```bash
# Create service principal
az ad sp create-for-rbac --name "github-actions-sp" --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group} \
  --sdk-auth

# The output will be used as AZURE_CREDENTIALS secret
```

#### Create Azure Container Registry
```bash
# Create ACR
az acr create --resource-group myResourceGroup --name myRegistry --sku Basic
az acr login --name myRegistry

# Get ACR credentials
az acr credential show --name myRegistry
```

#### Create AKS Cluster
```bash
# Create AKS cluster for each environment
az aks create \
  --resource-group myResourceGroup \
  --name myAKSCluster-dev \
  --node-count 1 \
  --enable-addons monitoring \
  --generate-ssh-keys
```

### 2. GitHub Secrets Configuration

Add the following secrets to your GitHub repository:

#### Azure Credentials
- `AZURE_CREDENTIALS`: JSON output from service principal creation
- `ACR_LOGIN_SERVER`: Your ACR login server (e.g., `myregistry.azurecr.io`)
- `ACR_USERNAME`: ACR username
- `ACR_PASSWORD`: ACR password

#### AKS Cluster Information
- `AKS_CLUSTER_NAME_DEV`: Development cluster name
- `AKS_RESOURCE_GROUP_DEV`: Development resource group
- `AKS_CLUSTER_NAME_STAGING`: Staging cluster name
- `AKS_RESOURCE_GROUP_STAGING`: Staging resource group
- `AKS_CLUSTER_NAME_PROD`: Production cluster name
- `AKS_RESOURCE_GROUP_PROD`: Production resource group

### 3. Environment Setup

#### GitHub Environment Protection Rules
1. Go to repository Settings → Environments
2. Create environments: `dev`, `staging`, `production`
3. Configure protection rules for production:
   - Required reviewers
   - Deployment branches (limit to release branches)
   - Environment secrets

## 🔄 Workflow Triggers and Versioning

### Branch Strategy
- `develop` → Development environment
- `main` → Staging environment
- `release/*` → Production environment (with semantic versioning)
- `tags/*` → Production environment (with tag-based versioning)

### Version Strategy
| Branch/Tag | Environment | Version Format | Example |
|------------|-------------|----------------|---------|
| `develop` | dev | `dev-{short-sha}` | `dev-abc1234` |
| `main` | staging | `staging-{short-sha}` | `staging-abc1234` |
| `release/1.2.3` | production | `v1.2.3` | `v1.2.3` |
| `tags/v1.2.3` | production | `v1.2.3` | `v1.2.3` |

### Docker Image Tags
- Development: `myregistry.azurecr.io/app:dev-abc1234`
- Staging: `myregistry.azurecr.io/app:staging-abc1234`
- Production: `myregistry.azurecr.io/app:v1.2.3`

## 📦 Application Setup

### Java Spring Boot Application

1. **Create application workflow** (`.github/workflows/deploy-java-app.yml`):
```yaml
name: Deploy Java Spring Boot Application
on:
  push:
    branches: [main, develop, 'release/**']
    paths: ['apps/java-app/**']

jobs:
  deploy-dev:
    if: github.ref == 'refs/heads/develop'
    uses: ./.github/workflows/shared-deploy.yml
    with:
      environment: dev
      application_name: java-app
      application_type: java-springboot
      build_context: apps/java-app
      dockerfile_path: apps/java-app/Dockerfile
      helm_chart_path: helm/shared-app
    secrets: inherit
```

2. **Directory structure**:
```
apps/java-app/
├── src/
├── pom.xml
├── Dockerfile
└── README.md
```

3. **Dockerfile example**:
```dockerfile
FROM openjdk:17-jre-slim
COPY target/app.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

### Node.js Application

1. **Create application workflow** (`.github/workflows/deploy-nodejs-app.yml`):
```yaml
name: Deploy Node.js Application
on:
  push:
    branches: [main, develop, 'release/**']
    paths: ['apps/nodejs-app/**']

jobs:
  deploy-dev:
    if: github.ref == 'refs/heads/develop'
    uses: ./.github/workflows/shared-deploy.yml
    with:
      environment: dev
      application_name: nodejs-app
      application_type: nodejs
      build_context: apps/nodejs-app
      dockerfile_path: apps/nodejs-app/Dockerfile
      helm_chart_path: helm/shared-app
    secrets: inherit
```

2. **Directory structure**:
```
apps/nodejs-app/
├── src/
├── package.json
├── Dockerfile
└── README.md
```

3. **Dockerfile example**:
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
USER node
CMD ["npm", "start"]
```

## 🎯 Deployment Process

### Development Deployment
1. Push to `develop` branch
2. Workflow builds and deploys to dev environment
3. Uses short SHA for versioning
4. Automatic deployment

### Staging Deployment
1. Merge to `main` branch
2. Workflow builds and deploys to staging environment
3. Uses short SHA for versioning
4. Automatic deployment

### Production Deployment
1. Create release branch: `release/1.2.3`
2. Workflow builds and deploys to production
3. Uses semantic versioning
4. Creates GitHub release
5. Requires manual approval (if configured)

## 🔧 Customization

### Environment-Specific Configuration
The shared Helm chart automatically configures resources based on environment:

```yaml
# Production
replicas: 3
resources:
  limits:
    cpu: 1000m
    memory: 2Gi

# Development
replicas: 1
resources:
  limits:
    cpu: 500m
    memory: 1Gi
```

### Application-Specific Configuration
Different health check paths based on application type:

```yaml
# Java Spring Boot
livenessProbe:
  path: /actuator/health
  port: 8080

# Node.js
livenessProbe:
  path: /health
  port: 3000
```

### Custom Values
Override default values by creating environment-specific values files:

```yaml
# helm/shared-app/values-production.yaml
replicaCount: 5
resources:
  limits:
    cpu: 2000m
    memory: 4Gi
```

## 📊 Monitoring and Observability

### Built-in Health Checks
- Liveness probes for application health
- Readiness probes for traffic routing
- Startup probes for slow-starting applications

### Prometheus Integration
```yaml
monitoring:
  enabled: true
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/actuator/prometheus"
```

### Logging
- Structured logging with environment context
- Centralized log collection
- Log retention policies

## 🛡️ Security Features

### Container Security
- Non-root user execution
- Read-only root filesystem
- Dropped capabilities
- Security context enforcement

### Network Security
- Network policies (optional)
- TLS termination at ingress
- Service mesh integration (optional)

### Supply Chain Security
- SBOM generation
- Container image scanning
- Dependency scanning

## 🚨 Troubleshooting

### Common Issues

1. **Deployment fails with "ImagePullBackOff"**
   - Check ACR credentials
   - Verify image exists in registry
   - Check network connectivity

2. **Health check failures**
   - Verify health endpoint path
   - Check application startup time
   - Review resource limits

3. **Ingress not working**
   - Verify ingress controller is installed
   - Check DNS configuration
   - Verify TLS certificates

### Debug Commands
```bash
# Check pod status
kubectl get pods -n <namespace>

# Check pod logs
kubectl logs -n <namespace> <pod-name>

# Check Helm release
helm list -n <namespace>
helm status <release-name> -n <namespace>

# Check ingress
kubectl get ingress -n <namespace>
```

## 📋 Best Practices

### Branch Management
- Use protected branches for main/master
- Require pull request reviews
- Use semantic versioning for releases

### Security
- Regular dependency updates
- Scan container images
- Use least privilege principles
- Enable audit logging

### Performance
- Use resource limits and requests
- Implement horizontal pod autoscaling
- Use readiness probes for zero-downtime deployments

### Monitoring
- Set up alerts for critical metrics
- Monitor resource usage
- Track deployment success rates

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For issues and questions:
- Create an issue in this repository
- Check existing documentation
- Review troubleshooting guide

---

**Note**: This workflow system is designed for production use. Always test in a non-production environment first and adjust configurations based on your specific requirements.