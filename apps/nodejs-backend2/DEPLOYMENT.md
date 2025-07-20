# Node.js Backend 2 - Analytics Service Deployment

This document describes how to deploy the Analytics Service using the integrated GitHub Actions workflow.

## 🏗️ **Service Overview**

**Java Backend 1** is a Express.js application that handles:
- Analytics data processing
- Business intelligence reports
- Data visualization

## 🚀 **Deployment Methods**

### 1. **Automatic Deployment (Push-based)**

The deployment workflow automatically triggers when:

```yaml
# Automatic triggers
on:
  push:
    branches:
      - main          # Production deployments
      - develop       # Development deployments
      - 'release/**'  # Release candidate deployments
      - 'feature/**'  # Feature branch deployments
    paths:
      - 'apps/nodejs-backend2/**'        # Source code changes
      - 'helm/nodejs-backend2/**'        # Helm chart changes
      - '.github/workflows/deploy.yml' # Workflow changes
```

### 2. **Manual Deployment (Workflow Dispatch)**

Trigger manual deployments through GitHub Actions:

```bash
# Using GitHub CLI
gh workflow run deploy.yml -f environment=dev
gh workflow run deploy.yml -f environment=staging
gh workflow run deploy.yml -f environment=production

# Or through GitHub UI:
# Actions → Deploy Node.js Backend 2 - Analytics Service → Run workflow
```

**Manual deployment options:**
- **Environment**: `dev`, `staging`, or `production`
- **Force Deploy**: Deploy even if no changes detected

### 3. **Pull Request Validation**

Deployment validation runs on pull requests to:
- `main` branch (production readiness)
- `develop` branch (integration testing)

## 🔧 **Workflow Configuration**

The deployment workflow uses the shared deployment infrastructure:

```yaml
jobs:
  deploy:
    uses: ./.github/workflows/shared-deploy.yml
    with:
      application_name: nodejs-backend2
      application_type: nodejs
      build_context: apps/nodejs-backend2
      dockerfile_path: apps/nodejs-backend2/Dockerfile
      helm_chart_path: helm/nodejs-backend2
```

## 🌍 **Environment-Specific Deployments**

### Development Environment
- **Branch**: `develop`, `feature/**`
- **URL**: `https://dev.mydomain.com/backend2`
- **Namespace**: `dev`
- **Auto-deploy**: ✅ On push

### Staging Environment
- **Branch**: `release/**`
- **URL**: `https://staging.mydomain.com/backend2`
- **Namespace**: `staging`
- **Auto-deploy**: ✅ On push

### Production Environment
- **Branch**: `main`
- **URL**: `https://production.mydomain.com/backend2`
- **Namespace**: `production`
- **Auto-deploy**: ✅ On push

## 📊 **Monitoring & Health Checks**

### Health Endpoints
```bash
# Application health
curl https://dev.mydomain.com/backend2/health

# Application status
curl https://dev.mydomain.com/backend2/api/status

# Metrics (Prometheus)
curl https://dev.mydomain.com/backend2/metrics
```

### Kubernetes Resources
```bash
# Check deployment status
kubectl get deployment nodejs-backend2-dev -n dev

# Check pod logs
kubectl logs -f deployment/nodejs-backend2-dev -n dev

# Check service status
kubectl get service nodejs-backend2-dev -n dev
```

## 🎯 **Service Endpoints**

### Analytics API
```bash
# Get analytics
curl https://dev.mydomain.com/backend2/api/users

# Health check
curl https://dev.mydomain.com/backend2/health

# Service status
curl https://dev.mydomain.com/backend2/api/status
```

## 🔐 **Authentication & Secrets**

The deployment workflow requires these secrets:
- `ACR_LOGIN_SERVER` - Azure Container Registry
- `KEYVAULT_NAME` - Azure Key Vault for secrets
- `AZURE_TENANT_ID` - Azure tenant
- `AZURE_CLIENT_ID` - Azure service principal
- `AZURE_SUBSCRIPTION_ID` - Azure subscription

## 📋 **Deployment Checklist**

Before deploying to production:

- [ ] Code reviewed and approved
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Security scan completed
- [ ] Performance testing completed
- [ ] Helm chart values updated
- [ ] Environment variables configured
- [ ] Database migrations ready (if applicable)
- [ ] Monitoring alerts configured

## 🚨 **Rollback Procedure**

If deployment fails or issues are detected:

```bash
# Quick rollback using Helm
helm rollback nodejs-backend2-production --namespace production

# Or use the centralized rollback workflow
gh workflow run rollback-deployment.yml \
  -f application_name=nodejs-backend2 \
  -f environment=production \
  -f revision=previous
```

## 🔍 **Troubleshooting**

### Common Issues

1. **Build Failures**
   ```bash
   # Check build logs in GitHub Actions
   # Verify Dockerfile and dependencies
   ```

2. **Deployment Issues**
   ```bash
   # Check Helm release status
   helm status nodejs-backend2-dev -n dev
   
   # Check pod events
   kubectl describe pod -l app=nodejs-backend2 -n dev
   ```

3. **Service Unavailable**
   ```bash
   # Check ingress configuration
   kubectl get ingress -n dev
   
   # Verify service endpoints
   kubectl get endpoints nodejs-backend2-dev -n dev
   ```

## 📞 **Support**

For deployment issues:
1. Check GitHub Actions logs
2. Review Kubernetes pod logs
3. Check Azure Container Registry access
4. Verify Azure Key Vault permissions
5. Contact DevOps team if issues persist

---

**🏗️ Service**: Analytics Service  
**🔗 Repository**: `/apps/nodejs-backend2/`  
**📊 Monitoring**: Prometheus + Grafana  
**🚀 Deployment**: GitHub Actions + Helm