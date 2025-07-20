# Independent Backends Architecture Guide

This document describes the comprehensive setup of 6 independent backend applications with their own source code, Docker builds, Helm charts, and deployment workflows.

## 🧹 **Clean Repository Structure**

This repository has been cleaned up to focus on the independent backend architecture:

### ✅ **What's Included**
- 6 independent backend applications (3 Java + 3 Node.js)
- Individual Helm charts for each backend
- Minimal caller workflows using existing shared infrastructure
- Comprehensive monitoring and documentation

### 🗑️ **What Was Removed**
- Old monolithic `java-app` and `nodejs-app` directories
- Legacy single-app deployment workflows
- Outdated documentation files
- Unused composite actions
- Redundant Helm charts

## Architecture Overview

### 🏗️ **Backend Applications**

#### Java Applications (Spring Boot)
1. **Java Backend 1 - User Management Service**
   - Path: `apps/java-backend1/`
   - Purpose: Handles user authentication, authorization, and profile management
   - Port: 8080
   - Endpoints: `/api/users`, `/api/status`, `/actuator/health`

2. **Java Backend 2 - Product Catalog Service**
   - Path: `apps/java-backend2/`
   - Purpose: Manages product catalog, inventory, and pricing information
   - Port: 8080
   - Endpoints: `/api/products`, `/api/status`, `/actuator/health`

3. **Java Backend 3 - Order Management Service**
   - Path: `apps/java-backend3/`
   - Purpose: Handles order processing, payment integration, and fulfillment
   - Port: 8080
   - Endpoints: `/api/orders`, `/api/status`, `/actuator/health`

#### Node.js Applications (Express.js)
1. **Node.js Backend 1 - Notification Service**
   - Path: `apps/nodejs-backend1/`
   - Purpose: Handles email notifications, push notifications, and real-time messaging
   - Port: 3000
   - Endpoints: `/api/notifications`, `/api/status`, `/health`, `/metrics`

2. **Node.js Backend 2 - Analytics Service**
   - Path: `apps/nodejs-backend2/`
   - Purpose: Handles analytics, reporting, and business intelligence
   - Port: 3000
   - Endpoints: `/api/analytics`, `/api/reports`, `/health`, `/metrics`

3. **Node.js Backend 3 - File Management Service**
   - Path: `apps/nodejs-backend3/`
   - Purpose: Handles file uploads, storage, and content management
   - Port: 3000
   - Endpoints: `/api/files`, `/api/status`, `/health`, `/metrics`

## Clean Project Structure

```
├── apps/                           # All backend applications
│   ├── java-backend1/             # User Management Service
│   │   ├── src/main/java/
│   │   ├── pom.xml
│   │   └── Dockerfile
│   ├── java-backend2/             # Product Catalog Service
│   │   ├── src/main/java/
│   │   ├── pom.xml
│   │   └── Dockerfile
│   ├── java-backend3/             # Order Management Service
│   │   ├── src/main/java/
│   │   ├── pom.xml
│   │   └── Dockerfile
│   ├── nodejs-backend1/           # Notification Service
│   │   ├── src/index.js
│   │   ├── package.json
│   │   └── Dockerfile
│   ├── nodejs-backend2/           # Analytics Service
│   │   ├── src/index.js
│   │   ├── package.json
│   │   └── Dockerfile
│   └── nodejs-backend3/           # File Management Service
│       ├── src/index.js
│       ├── package.json
│       └── Dockerfile
├── helm/                          # Helm charts
│   ├── java-backend1/            # Independent chart
│   ├── java-backend2/            # Independent chart
│   ├── java-backend3/            # Independent chart
│   ├── nodejs-backend1/          # Independent chart
│   ├── nodejs-backend2/          # Independent chart
│   ├── nodejs-backend3/          # Independent chart
│   └── monitoring/               # Shared monitoring stack
├── .github/workflows/            # Deployment workflows
│   ├── shared-deploy.yml         # Existing shared workflow
│   ├── deploy-java-backend1.yml  # Minimal caller
│   ├── deploy-java-backend2.yml  # Minimal caller
│   ├── deploy-java-backend3.yml  # Minimal caller
│   ├── deploy-nodejs-backend1.yml # Minimal caller
│   ├── deploy-nodejs-backend2.yml # Minimal caller
│   ├── deploy-nodejs-backend3.yml # Minimal caller
│   ├── deploy-monitoring.yml     # Monitoring deployment
│   └── rollback-deployment.yml   # Rollback capability
├── scripts/                      # Deployment scripts
│   └── deploy-all-backends.sh    # Bulk deployment
└── docs/                         # Documentation
    └── (additional documentation)
```

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

## Deployment Workflows

Each backend uses **minimal caller workflows** that leverage the existing **`shared-deploy.yml`**:

### Java Backend Example
```yaml
name: Deploy Java Backend 1

on:
  push:
    paths:
      - 'apps/java-backend1/**'
      - 'helm/java-backend1/**'

jobs:
  deploy:
    uses: ./.github/workflows/shared-deploy.yml
    with:
      application_name: 'java-backend1'
      application_type: 'java-springboot'
      build_context: 'apps/java-backend1'
      helm_chart_path: 'helm/java-backend1'
```

### Node.js Backend Example
```yaml
name: Deploy Node.js Backend 1

on:
  push:
    paths:
      - 'apps/nodejs-backend1/**'
      - 'helm/nodejs-backend1/**'

jobs:
  deploy:
    uses: ./.github/workflows/shared-deploy.yml
    with:
      application_name: 'nodejs-backend1'
      application_type: 'nodejs'
      build_context: 'apps/nodejs-backend1'
      helm_chart_path: 'helm/nodejs-backend1'
```

## Key Benefits

### 🔄 **Clean Architecture**
- Removed legacy code and redundant files
- Clear separation between backends
- Focused repository structure
- Easy to navigate and maintain

### 📦 **Independent Deployment**
- Each backend deploys independently
- Leverages existing shared workflow infrastructure
- No cross-dependencies or conflicts
- Minimal workflow configuration

### 🚀 **Scalability**
- Each backend can scale independently
- Different resource requirements per service
- Individual monitoring and alerting
- Isolated failure domains

### 💡 **Efficiency**
- Reuses existing shared workflow
- Minimal code duplication
- Consistent deployment patterns
- Shared monitoring infrastructure

## Quick Start Commands

### Deploy Individual Backend
```bash
# Manual deployment
gh workflow run deploy-java-backend1.yml -f environment=dev

# Direct Helm deployment
helm upgrade --install java-backend1-dev ./helm/java-backend1 \
  --namespace dev \
  --values ./helm/java-backend1/values-dev.yaml
```

### Deploy All Backends
```bash
# Deploy all backends to development
./scripts/deploy-all-backends.sh dev

# Deploy all backends to production
./scripts/deploy-all-backends.sh production
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

This repository follows clean architecture principles:

### ✅ **Best Practices Implemented**
- Single responsibility per backend
- Clear naming conventions
- Consistent directory structure
- Minimal workflow duplication
- Comprehensive documentation

### 🔄 **Regular Maintenance**
- Remove unused files and dependencies
- Update documentation when adding features
- Keep workflows synchronized with shared infrastructure
- Monitor and optimize resource usage

## Troubleshooting

### Common Issues

1. **Build Failures**
   ```bash
   # Check specific backend logs
   kubectl logs -f deployment/java-backend1-dev -n dev
   ```

2. **Deployment Issues**
   ```bash
   # Verify Helm release
   helm status java-backend1-dev -n dev
   ```

3. **Ingress Routing**
   ```bash
   # Check ingress configuration
   kubectl get ingress -n dev
   ```

## Future Enhancements

1. **Service Discovery**: Implement service-to-service communication
2. **API Gateway**: Centralized routing and rate limiting
3. **Event Streaming**: Add message queues for event-driven architecture
4. **Database Per Service**: Implement database isolation
5. **Blue-Green Deployments**: Zero-downtime deployment strategies

This clean, focused architecture provides a solid foundation for microservices development while maintaining simplicity and leveraging existing infrastructure. 🚀