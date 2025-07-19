# Production-Grade AKS Deployment Platform

[![Deploy Java App](https://github.com/your-org/your-repo/actions/workflows/deploy-java-app.yml/badge.svg)](https://github.com/your-org/your-repo/actions/workflows/deploy-java-app.yml)
[![Deploy Node.js App](https://github.com/your-org/your-repo/actions/workflows/deploy-nodejs-app.yml/badge.svg)](https://github.com/your-org/your-repo/actions/workflows/deploy-nodejs-app.yml)

A comprehensive, enterprise-ready deployment platform for Java Spring Boot and Node.js applications on Azure Kubernetes Service (AKS) using GitHub Actions and Helm charts.

## 🚀 Quick Start

### Prerequisites
- Azure subscription with AKS cluster
- Azure Container Registry (ACR)
- Azure Key Vault for secret management
- GitHub repository with OIDC authentication configured
- Helm 3.x installed locally (for development)

### 1. Configure Repository Secrets
Set the following secrets in your GitHub repository (`Settings` → `Secrets and variables` → `Actions`):

```bash
# Required secrets
ACR_LOGIN_SERVER          # e.g., myregistry.azurecr.io
AZURE_TENANT_ID           # Azure AD Tenant ID
AZURE_CLIENT_ID           # App Registration Client ID for OIDC
AZURE_SUBSCRIPTION_ID     # Azure Subscription ID
KEYVAULT_NAME            # Azure Key Vault name
```

### 2. Configure Workflow Variables
Update the workflow calls in your specific application workflow files with your AKS cluster details:

```yaml
# In .github/workflows/deploy-java-app.yml
with:
  aks_cluster_name_dev: "your-dev-aks-cluster"
  aks_resource_group_dev: "your-dev-resource-group"
  aks_cluster_name_sqe: "your-staging-aks-cluster"
  aks_resource_group_sqe: "your-staging-resource-group"
  aks_cluster_name_prod: "your-prod-aks-cluster"
  aks_resource_group_prod: "your-prod-resource-group"
```

### 3. Deploy Your Application

#### Automatic Deployment (Recommended)
Push to your designated branches to trigger automatic deployments:
- `N630-6258_Helm_deploy` branch → Dev environment
- `main` branch → Staging environment  
- `release/*` branches → Production environment

#### Manual Deployment
Navigate to `Actions` → Select your deployment workflow → `Run workflow`:
1. Choose the target environment
2. Optionally enable "Force deployment"
3. Click "Run workflow"

## 📋 Table of Contents

- [Architecture Overview](#-architecture-overview)
- [Application Support](#-application-support)
- [Environment Management](#-environment-management)
- [Helm Charts](#-helm-charts)
- [Security & Compliance](#-security--compliance)
- [Monitoring & Observability](#-monitoring--observability)
- [Troubleshooting](#-troubleshooting)
- [Development Guide](#-development-guide)

## 🏗️ Architecture Overview

### Workflow Architecture
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitHub        │    │   GitHub         │    │   Azure         │
│   Repository    │───▶│   Actions        │───▶│   AKS Cluster   │
│   (Source Code) │    │   (CI/CD)        │    │   (Deployment)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Azure         │    │   Helm Charts    │    │   Azure         │
│   Container     │◀───│   (K8s Config)   │───▶│   Key Vault     │
│   Registry      │    │                  │    │   (Secrets)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Key Components
- **Shared Deployment Workflow**: Reusable workflow for all applications
- **Application-Specific Workflows**: Java and Node.js deployment triggers  
- **Composite Actions**: Modular deployment steps
- **Helm Charts**: Kubernetes configuration management
- **Azure Integration**: OIDC authentication, ACR, Key Vault, AKS

## 🎯 Application Support

### Java Spring Boot Applications
- **Framework**: Spring Boot 2.x/3.x
- **Build Tool**: Maven
- **Container**: Multi-stage Docker builds
- **Health Checks**: Actuator endpoints
- **Configuration**: External configuration via ConfigMaps and Secrets

### Node.js Applications  
- **Runtime**: Node.js 18+ LTS
- **Package Manager**: npm/yarn
- **Container**: Optimized production builds
- **Health Checks**: Custom health endpoints
- **Configuration**: Environment variables and config files

## 🌍 Environment Management

### Environment Strategy
| Environment | Branch/Trigger | Purpose | Auto-Deploy |
|-------------|---------------|---------|-------------|
| **Development** | `N630-6258_Helm_deploy` | Feature development and testing | ✅ |
| **Staging** | `main` | Pre-production validation | ✅ |
| **Production** | `release/*` tags | Live production workloads | ✅ |

### Branch Protection Rules
- Development: Pull request required, automated testing
- Staging: Pull request + review required
- Production: Pull request + review + security scans required

### Environment-Specific Configurations
Each environment has dedicated Helm values files:
- `values-dev.yaml` - Development settings (relaxed security, debug enabled)
- `values-staging.yaml` - Staging settings (production-like, monitoring enabled)  
- `values-production.yaml` - Production settings (hardened security, optimized performance)

## ⚙️ Helm Charts

### Available Workflows

| Workflow | Purpose | Trigger | Features |
|----------|---------|---------|----------|
| `deploy-java-app.yml` | Deploy Java applications | Push/Manual | Automated deployment |
| `deploy-nodejs-app.yml` | Deploy Node.js applications | Push/Manual | Automated deployment |
| `shared-deploy.yml` | Reusable deployment logic | Called by other workflows | Multi-environment support |
| `rollback-deployment.yml` | Rollback deployments | Manual only | Multiple rollback strategies |
| `pr-security-check.yml` | Security scanning | Pull requests | Security validation |

### Available Charts

#### Java Application Chart (`helm/java-app/`)
```yaml
# Key features:
- Spring Boot optimized configurations
- Actuator health checks integration
- JVM tuning and garbage collection
- Azure Key Vault CSI driver support
- Horizontal Pod Autoscaling
- Pod Disruption Budgets
- Network Policies
```

#### Node.js Application Chart (`helm/nodejs-app/`)
```yaml
# Key features:
- Node.js runtime optimizations
- Health check endpoints
- Environment-based configuration
- Resource management
- Autoscaling capabilities
- Security policies
```

#### Shared Application Chart (`helm/shared-app/`)
```yaml
# Key features:
- Generic application deployment
- Configurable for multiple runtimes
- Standard Kubernetes resources
- Security best practices
- Monitoring integration
```

### Chart Customization

#### Values Override Structure
```yaml
# Environment-specific values pattern
global:
  environment: dev|staging|production
  applicationName: your-app-name
  applicationType: java-springboot|nodejs

image:
  repository: myregistry.azurecr.io/app-name
  tag: latest
  pullPolicy: Always

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 1000m
    memory: 2Gi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

#### Adding Custom Values
1. Modify the appropriate `values-{environment}.yaml` file
2. Update template files in `templates/` if needed
3. Test locally with `helm template` or `helm install --dry-run`
4. Commit changes to trigger deployment

## 🔐 Security & Compliance

### Authentication & Authorization
- **OIDC Authentication**: GitHub → Azure (no stored credentials)
- **Azure RBAC**: Fine-grained cluster access control
- **Service Accounts**: Kubernetes-native identity management
- **Workload Identity**: Pod-level Azure resource access

### Secret Management
```yaml
# Azure Key Vault integration
azureKeyVault:
  enabled: true
  keyvaultName: "your-keyvault"
  tenantId: "your-tenant-id"
  userAssignedIdentityID: "your-identity-id"
  secrets:
    - objectName: "database-password"
      objectAlias: "db-password"
    - objectName: "api-keys"
      objectAlias: "api-key"
```

### Security Scanning
- **Code Analysis**: SonarQube integration
- **Container Scanning**: Checkmarx security scans
- **Vulnerability Assessment**: Azure Security Center
- **Compliance**: Industry standard security policies

### Network Security
- **Network Policies**: Pod-to-pod communication control
- **Ingress Security**: TLS termination and WAF protection
- **Private Clusters**: VNet-integrated AKS clusters
- **Service Mesh**: Optional Istio integration

## 📊 Monitoring & Observability

### Application Metrics
```yaml
# Java Spring Boot (Actuator)
monitoring:
  enabled: true
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080" 
    prometheus.io/path: "/actuator/prometheus"

# Health check endpoints
livenessProbe:
  httpGet:
    path: /actuator/health
    port: 8080
readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
```

### Infrastructure Monitoring
- **Azure Monitor**: AKS cluster and application insights
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
- **Log Analytics**: Centralized logging and queries

### Alerting Strategy
- **Critical**: Application down, high error rates
- **Warning**: Resource utilization, performance degradation
- **Info**: Deployment events, scaling activities

## 🔧 Troubleshooting

### Common Issues

#### 1. Authentication Failures
```bash
# Check OIDC configuration
az ad app show --id <client-id>

# Verify federated credentials
az ad app federated-credential list --id <client-id>

# Test authentication
az login --service-principal -u <client-id> --tenant <tenant-id> --federated-token $ACTIONS_ID_TOKEN_REQUEST_TOKEN
```

#### 2. Image Pull Errors
```bash
# Check ACR permissions
az acr repository list --name <registry-name>

# Verify image exists
az acr repository show-tags --name <registry-name> --repository <repository-name>

# Check AKS integration
az aks check-acr --name <aks-cluster> --resource-group <rg> --acr <registry-name>
```

#### 3. Helm Deployment Issues
```bash
# Check Helm release status
helm list -n <namespace>

# View deployment history
helm history <release-name> -n <namespace>

# Debug failed deployment
helm get all <release-name> -n <namespace>

# Check pod status
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
```

#### 4. Application Health Issues
```bash
# Check application logs
kubectl logs -l app=<app-name> -n <namespace> --tail=100

# Test health endpoints
kubectl port-forward service/<service-name> 8080:8080 -n <namespace>
curl http://localhost:8080/actuator/health

# Check resource usage
kubectl top pods -n <namespace>
```

### Rollback Procedures

#### Quick Rollback (Previous Version)
```bash
# Rollback to previous version via GitHub Actions
gh workflow run rollback-deployment.yml \
  -f environment=production \
  -f application_name=java-app \
  -f rollback_strategy=previous-version
```

### Cleanup Procedures

#### Quick Cleanup Commands
```bash
# Standard Helm cleanup (recommended)
helm uninstall java-app -n default

# Manual cleanup with kubectl (if Helm cleanup incomplete)
kubectl delete all -l app.kubernetes.io/name=java-app -n default

# Complete cleanup including all resource types
kubectl delete all,configmap,secret,pvc,secretproviderclass,networkpolicy,poddisruptionbudget,hpa -l app.kubernetes.io/name=java-app -n default

# Emergency force cleanup (last resort)
kubectl delete all -l app.kubernetes.io/name=java-app -n default --force --grace-period=0
```

📖 **For comprehensive cleanup procedures, see [Helm Chart Guide - Cleanup Section](docs/HELM_CHART_GUIDE.md#-cleanup-and-resource-removal)**

#### Advanced Rollback Options
```bash
# Rollback to specific version
gh workflow run rollback-deployment.yml \
  -f environment=production \
  -f application_name=java-app \
  -f rollback_strategy=specific-version \
  -f target_version=1.2.3

# Rollback to specific Helm revision
gh workflow run rollback-deployment.yml \
  -f environment=production \
  -f application_name=java-app \
  -f rollback_strategy=specific-revision \
  -f target_revision=5

# Force rollback (even if current deployment is healthy)
gh workflow run rollback-deployment.yml \
  -f environment=production \
  -f application_name=java-app \
  -f rollback_strategy=previous-version \
  -f force_rollback=true
```

### Debugging Commands
```bash
# Workflow debugging
gh run list --workflow=deploy-java-app.yml
gh run view <run-id> --log

# Kubernetes debugging  
kubectl get events --sort-by='.metadata.creationTimestamp' -n <namespace>
kubectl describe deployment <deployment-name> -n <namespace>

# Azure debugging
az aks get-credentials --name <cluster-name> --resource-group <rg>
az aks show --name <cluster-name> --resource-group <rg>
```

## 💻 Development Guide

### Local Development Setup

#### Prerequisites
```bash
# Install required tools
# Helm
curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar xz
sudo mv linux-amd64/helm /usr/local/bin/

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

#### Testing Helm Charts Locally
```bash
# Validate chart syntax
helm lint helm/java-app/

# Test template rendering
helm template my-app helm/java-app/ -f helm/java-app/values-dev.yaml

# Dry run installation
helm install my-app helm/java-app/ -f helm/java-app/values-dev.yaml --dry-run

# Install to local cluster (if available)
helm install my-app helm/java-app/ -f helm/java-app/values-dev.yaml -n dev --create-namespace
```

#### Workflow Testing
```bash
# Install act for local workflow testing
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Test workflow locally (limited functionality)
act -j deploy --container-architecture linux/amd64
```

### Adding New Applications

#### 1. Create Application-Specific Workflow
```yaml
# .github/workflows/deploy-new-app.yml
name: Deploy New Application
on:
  push:
    branches: [main, develop]
    paths: ['apps/new-app/**', 'helm/new-app/**']

jobs:
  deploy:
    uses: ./.github/workflows/shared-deploy.yml
    with:
      application_name: new-app
      application_type: java-springboot  # or nodejs
      helm_chart_path: helm/new-app
      # ... other parameters
```

#### 2. Create Helm Chart
```bash
# Create new chart from template
cp -r helm/java-app helm/new-app
# OR
cp -r helm/nodejs-app helm/new-app

# Update Chart.yaml
sed -i 's/java-app/new-app/g' helm/new-app/Chart.yaml

# Customize values files
# Edit helm/new-app/values.yaml
# Edit helm/new-app/values-dev.yaml
# Edit helm/new-app/values-staging.yaml  
# Edit helm/new-app/values-production.yaml
```

#### 3. Configure Application Code
Ensure your application includes:

**Java Spring Boot:**
```yaml
# application.yml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: always
```

**Node.js:**
```javascript
// health.js
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'UP' });
});

app.get('/ready', (req, res) => {
  // Check dependencies (DB, external services)
  res.status(200).json({ status: 'READY' });
});
```

### Best Practices

#### 1. Version Management
- Use semantic versioning for releases
- Tag releases consistently: `v1.2.3`
- Maintain changelog for major changes

#### 2. Resource Management
```yaml
# Always define resource requests and limits
resources:
  requests:
    cpu: 100m      # Minimum CPU
    memory: 128Mi  # Minimum memory
  limits:
    cpu: 500m      # Maximum CPU  
    memory: 512Mi  # Maximum memory
```

#### 3. Health Checks
```yaml
# Configure appropriate timeouts
livenessProbe:
  initialDelaySeconds: 60  # Application startup time
  periodSeconds: 10        # Check interval
  timeoutSeconds: 5        # Request timeout
  failureThreshold: 3      # Restart threshold

readinessProbe:
  initialDelaySeconds: 30  # Readiness check delay
  periodSeconds: 5         # Check frequency
  failureThreshold: 3      # Remove from service threshold
```

#### 4. Security Hardening
```yaml
# Use non-root containers
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  readOnlyRootFilesystem: true
```

## 📚 Documentation

### Comprehensive Guides
- **[Deployment Guide](docs/DEPLOYMENT_GUIDE.md)**: Detailed deployment scenarios and best practices
- **[Helm Chart Guide](docs/HELM_CHART_GUIDE.md)**: Complete Helm chart customization and management
- **[Azure Setup Guide](docs/AZURE_SETUP_GUIDE.md)**: Step-by-step Azure infrastructure setup
- **[Spring Boot Profiles & Secrets](docs/SPRING_BOOT_PROFILES_AND_SECRETS.md)**: Spring Boot integration with Azure Key Vault
- **[Quick Start Guide](docs/QUICK_START.md)**: 30-minute setup guide for immediate implementation
- **[Integration Complete](docs/INTEGRATION_COMPLETE.md)**: Platform integration summary and validation

## 📞 Support

### Getting Help
1. **Documentation**: Check the comprehensive guides above and inline code comments
2. **Issues**: Create GitHub issues for bugs or feature requests  
3. **Discussions**: Use GitHub Discussions for questions
4. **DevOps Team**: Contact via internal channels for urgent issues

### Contributing
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

### Changelog
See [RELEASES](https://github.com/your-org/your-repo/releases) for version history and changes.

---

**Last Updated**: $(date '+%Y-%m-%d')  
**Version**: 1.0.0  
**Maintained by**: DevOps Team