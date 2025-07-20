# Independent Backends Architecture Guide

This document describes the comprehensive setup of 6 independent backend applications with their own source code, Docker builds, Helm charts, and **individual deployment workflows**.

## 🧹 **Clean Repository Structure**

This repository has been cleaned up to focus on the independent backend architecture:

### ✅ **What's Included**
- 6 independent backend applications (3 Java + 3 Node.js)
- Individual Helm charts for each backend
- **Individual deployment workflows within each backend codebase**
- Comprehensive monitoring and documentation

### 🗑️ **What Was Removed**
- Old monolithic `java-app` and `nodejs-app` directories
- Legacy single-app deployment workflows
- Outdated documentation files
- Unused composite actions
- Redundant Helm charts
- **Centralized backend deployment workflows (moved to individual backends)**

## Architecture Overview

### 🏗️ **Backend Applications**

#### Java Applications (Spring Boot)
1. **Java Backend 1 - User Management Service**
   - Path: `apps/java-backend1/`
   - Purpose: Handles user authentication, authorization, and profile management
   - Port: 8080
   - Endpoints: `/api/users`, `/api/status`, `/actuator/health`
   - **Workflow**: `apps/java-backend1/.github/workflows/deploy.yml`

2. **Java Backend 2 - Product Catalog Service**
   - Path: `apps/java-backend2/`
   - Purpose: Manages product catalog, inventory, and pricing information
   - Port: 8080
   - Endpoints: `/api/products`, `/api/status`, `/actuator/health`
   - **Workflow**: `apps/java-backend2/.github/workflows/deploy.yml`

3. **Java Backend 3 - Order Management Service**
   - Path: `apps/java-backend3/`
   - Purpose: Handles order processing, payment integration, and fulfillment
   - Port: 8080
   - Endpoints: `/api/orders`, `/api/status`, `/actuator/health`
   - **Workflow**: `apps/java-backend3/.github/workflows/deploy.yml`

#### Node.js Applications (Express.js)
1. **Node.js Backend 1 - Notification Service**
   - Path: `apps/nodejs-backend1/`
   - Purpose: Handles email notifications, push notifications, and real-time messaging
   - Port: 3000
   - Endpoints: `/api/notifications`, `/api/status`, `/health`, `/metrics`
   - **Workflow**: `apps/nodejs-backend1/.github/workflows/deploy.yml`

2. **Node.js Backend 2 - Analytics Service**
   - Path: `apps/nodejs-backend2/`
   - Purpose: Handles analytics, reporting, and business intelligence
   - Port: 3000
   - Endpoints: `/api/analytics`, `/api/reports`, `/health`, `/metrics`
   - **Workflow**: `apps/nodejs-backend2/.github/workflows/deploy.yml`

3. **Node.js Backend 3 - File Management Service**
   - Path: `apps/nodejs-backend3/`
   - Purpose: Handles file uploads, storage, and content management
   - Port: 3000
   - Endpoints: `/api/files`, `/api/status`, `/health`, `/metrics`
   - **Workflow**: `apps/nodejs-backend3/.github/workflows/deploy.yml`

## Clean Project Structure

```
├── apps/                                    # All backend applications
│   ├── java-backend1/                      # User Management Service
│   │   ├── .github/workflows/deploy.yml    # 🆕 Individual deployment workflow
│   │   ├── src/main/java/
│   │   ├── pom.xml
│   │   ├── Dockerfile
│   │   └── DEPLOYMENT.md                   # 🆕 Service-specific deployment guide
│   ├── java-backend2/                      # Product Catalog Service
│   │   ├── .github/workflows/deploy.yml    # 🆕 Individual deployment workflow
│   │   ├── src/main/java/
│   │   ├── pom.xml
│   │   ├── Dockerfile
│   │   └── DEPLOYMENT.md                   # 🆕 Service-specific deployment guide
│   ├── java-backend3/                      # Order Management Service
│   │   ├── .github/workflows/deploy.yml    # 🆕 Individual deployment workflow
│   │   ├── src/main/java/
│   │   ├── pom.xml
│   │   ├── Dockerfile
│   │   └── DEPLOYMENT.md                   # 🆕 Service-specific deployment guide
│   ├── nodejs-backend1/                    # Notification Service
│   │   ├── .github/workflows/deploy.yml    # 🆕 Individual deployment workflow
│   │   ├── src/index.js
│   │   ├── package.json
│   │   ├── Dockerfile
│   │   └── DEPLOYMENT.md                   # 🆕 Service-specific deployment guide
│   ├── nodejs-backend2/                    # Analytics Service
│   │   ├── .github/workflows/deploy.yml    # 🆕 Individual deployment workflow
│   │   ├── src/index.js
│   │   ├── package.json
│   │   ├── Dockerfile
│   │   └── DEPLOYMENT.md                   # 🆕 Service-specific deployment guide
│   └── nodejs-backend3/                    # File Management Service
│       ├── .github/workflows/deploy.yml    # 🆕 Individual deployment workflow
│       ├── src/index.js
│       ├── package.json
│       ├── Dockerfile
│       └── DEPLOYMENT.md                   # 🆕 Service-specific deployment guide
├── helm/                                   # Helm charts
│   ├── java-backend1/                     # Independent chart
│   ├── java-backend2/                     # Independent chart
│   ├── java-backend3/                     # Independent chart
│   ├── nodejs-backend1/                   # Independent chart
│   ├── nodejs-backend2/                   # Independent chart
│   ├── nodejs-backend3/                   # Independent chart
│   └── monitoring/                        # Shared monitoring stack
├── .github/workflows/                     # 🔄 Centralized Infrastructure Workflows
│   ├── shared-deploy.yml                  # ✅ Shared deployment infrastructure
│   ├── deploy-monitoring.yml              # ✅ Monitoring deployment
│   ├── rollback-deployment.yml            # ✅ Rollback capability
│   └── pr-security-check.yml              # ✅ Security validation
├── scripts/                               # Deployment scripts
│   └── deploy-all-backends.sh             # Bulk deployment
└── docs/                                  # Documentation
    └── (additional documentation)
```

## 🚀 **Individual Deployment Workflows**

Each backend now has its **own deployment workflow** within its codebase, providing:

### **Key Benefits of Individual Workflows:**
- ✅ **True Independence**: Each backend manages its own deployment lifecycle
- ✅ **Service-Specific Configuration**: Customized triggers and deployment parameters
- ✅ **Clear Ownership**: Each team owns their backend's deployment process
- ✅ **Reduced Conflicts**: No centralized workflow conflicts between teams
- ✅ **Easier Maintenance**: Service-specific changes don't affect other backends

### **Workflow Structure (Each Backend):**
```yaml
name: Deploy [Backend Name] - [Service Description]

permissions:
  id-token: write
  contents: read
  actions: read

on:
  push:
    branches: [main, develop, 'release/**', 'feature/**']
    paths:
      - 'apps/[backend-name]/**'
      - 'helm/[backend-name]/**'
      - '.github/workflows/deploy.yml'
  pull_request:
    branches: [main, develop]
    paths:
      - 'apps/[backend-name]/**'
      - 'helm/[backend-name]/**'
  workflow_dispatch:
    inputs:
      environment: {dev, staging, production}
      force_deploy: {true, false}

jobs:
  deploy:
    uses: ./.github/workflows/shared-deploy.yml  # 🔄 Reuses shared infrastructure
    with:
      application_name: [backend-name]
      application_type: {java-springboot|nodejs}
      build_context: apps/[backend-name]
      dockerfile_path: apps/[backend-name]/Dockerfile
      helm_chart_path: helm/[backend-name]
```

## 📖 **Deployment Documentation**

Each backend includes comprehensive deployment documentation:

### **Individual Service Guides:**
- `apps/java-backend1/DEPLOYMENT.md` - User Management Service deployment
- `apps/java-backend2/DEPLOYMENT.md` - Product Catalog Service deployment
- `apps/java-backend3/DEPLOYMENT.md` - Order Management Service deployment
- `apps/nodejs-backend1/DEPLOYMENT.md` - Notification Service deployment
- `apps/nodejs-backend2/DEPLOYMENT.md` - Analytics Service deployment
- `apps/nodejs-backend3/DEPLOYMENT.md` - File Management Service deployment

Each guide covers:
- 🚀 **Deployment Methods**: Automatic and manual deployment options
- 🌍 **Environment Configuration**: Dev, staging, and production settings
- 📊 **Monitoring & Health Checks**: Service-specific endpoints and monitoring
- 🎯 **API Endpoints**: Service-specific API documentation
- 🚨 **Rollback Procedures**: Service-specific rollback instructions
- 🔍 **Troubleshooting**: Common issues and solutions

## Ingress Routing Configuration

Each backend is accessible through environment-specific domains with path-based routing:

### Environment-Based Routing
```
dev.mydomain.com/backend1 → java-backend1 OR nodejs-backend1
dev.mydomain.com/backend2 → java-backend2 OR nodejs-backend2
dev.mydomain.com/backend3 → java-backend3 OR nodejs-backend3

staging.mydomain.com/backend1 → java-backend1 OR nodejs-backend1
staging.mydomain.com/backend2 → java-backend2 OR nodejs-backend2
staging.mydomain.com/backend3 → java-backend3 OR nodejs-backend3

production.mydomain.com/backend1 → java-backend1 OR nodejs-backend1
production.mydomain.com/backend2 → java-backend2 OR nodejs-backend2
production.mydomain.com/backend3 → java-backend3 OR nodejs-backend3
```

## 🎯 **Deployment Examples**

### **Individual Backend Deployment:**
```bash
# Navigate to specific backend
cd apps/java-backend1

# Trigger manual deployment via GitHub CLI
gh workflow run deploy.yml -f environment=dev -f force_deploy=false

# Or through GitHub UI:
# Actions → Deploy Java Backend 1 - User Management Service → Run workflow
```

### **Automatic Deployment:**
```bash
# Push changes to trigger automatic deployment
git add apps/java-backend1/
git commit -m "feat: update user management service"
git push origin develop  # Deploys to dev environment
```

### **Bulk Deployment (All Backends):**
```bash
# Deploy all backends to development
./scripts/deploy-all-backends.sh dev

# Deploy all backends to production
./scripts/deploy-all-backends.sh production
```

## Key Benefits

### 🔄 **Clean Architecture**
- Removed legacy code and redundant files
- Clear separation between backends
- **Individual workflow ownership per service**
- Easy to navigate and maintain

### 📦 **True Independent Deployment**
- Each backend deploys completely independently
- **Service-specific deployment workflows**
- No cross-dependencies or conflicts
- **Customizable deployment parameters per service**

### 🚀 **Enhanced Scalability**
- Each backend can scale independently
- Different resource requirements per service
- Individual monitoring and alerting
- **Service-specific deployment strategies**

### 💡 **Operational Efficiency**
- **Reuses existing shared deployment infrastructure**
- **Service-specific deployment configuration**
- Consistent deployment patterns across services
- **Clear service ownership and responsibility**

### 👥 **Team Autonomy**
- **Each team controls their service's deployment**
- Service-specific deployment schedules
- Independent release cycles
- **Reduced coordination overhead**

## Quick Start Commands

### Deploy Individual Backend
```bash
# Navigate to backend directory
cd apps/java-backend1

# Manual deployment
gh workflow run deploy.yml -f environment=dev

# Check deployment status
gh run list --workflow=deploy.yml
```

### Test Deployments
```bash
# Java backend health checks
curl https://dev.mydomain.com/backend1/actuator/health
curl https://dev.mydomain.com/backend2/actuator/health
curl https://dev.mydomain.com/backend3/actuator/health

# Node.js backend health checks
curl https://dev.mydomain.com/backend1/health
curl https://dev.mydomain.com/backend2/health
curl https://dev.mydomain.com/backend3/health
```

## Repository Maintenance

This repository follows clean architecture principles with **service-specific deployment workflows**:

### ✅ **Best Practices Implemented**
- **Individual deployment workflows per service**
- Single responsibility per backend
- Clear naming conventions
- Consistent directory structure
- **Service-specific deployment documentation**

### 🔄 **Regular Maintenance**
- Remove unused files and dependencies
- Update documentation when adding features
- **Keep individual workflows synchronized with shared infrastructure**
- Monitor and optimize resource usage per service

## Troubleshooting

### Common Issues

1. **Build Failures**
   ```bash
   # Check specific backend workflow logs
   cd apps/java-backend1
   gh run list --workflow=deploy.yml
   ```

2. **Deployment Issues**
   ```bash
   # Verify Helm release
   helm status java-backend1-dev -n dev
   ```

3. **Workflow Permissions**
   ```bash
   # Ensure each backend has proper permissions configured
   # Check individual workflow YAML files for permissions block
   ```

## Future Enhancements

1. **Service Discovery**: Implement service-to-service communication
2. **API Gateway**: Centralized routing and rate limiting
3. **Event Streaming**: Add message queues for event-driven architecture
4. **Database Per Service**: Implement database isolation
5. **Blue-Green Deployments**: Zero-downtime deployment strategies
6. ****Advanced Workflow Features**: Add service-specific deployment strategies

This clean, focused architecture with **individual deployment workflows** provides a solid foundation for microservices development while maintaining simplicity and leveraging existing infrastructure. Each service is truly independent with its own deployment lifecycle! 🚀