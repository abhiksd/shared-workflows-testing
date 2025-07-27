# Repository Migration Guide

This guide explains how to migrate from the current monorepo structure to separate repositories for each backend service, while maintaining centralized shared workflows.

## 🎯 **Migration Strategy Overview**

### **Current State: Monorepo with Self-Contained Backends**
```
📁 shared-workflows-be (this repo)
├── apps/
│   ├── java-backend1/              # 🎁 Self-contained with helm chart
│   │   ├── .github/workflows/deploy.yml
│   │   ├── src/, pom.xml, Dockerfile
│   │   ├── helm/                   # ✅ Now included!
│   │   └── DEPLOYMENT.md
│   ├── java-backend2/              # 🎁 Self-contained with helm chart
│   ├── java-backend3/              # 🎁 Self-contained with helm chart
│   ├── nodejs-backend1/            # 🎁 Self-contained with helm chart
│   ├── nodejs-backend2/            # 🎁 Self-contained with helm chart
│   └── nodejs-backend3/            # 🎁 Self-contained with helm chart
├── .github/workflows/
│   └── shared-deploy.yml           # 🔄 Will become external
└── scripts/deploy-all-backends.sh
```

### **Target State: Separate Repositories**
```
📁 java-backend1-repo              # 🚀 Independent repository
├── .github/workflows/deploy.yml   # Calls external shared workflow
├── src/, pom.xml, Dockerfile     # All source code
├── helm/                          # ✅ Included Helm chart
└── DEPLOYMENT.md                  # Service-specific documentation

📁 java-backend2-repo              # 🚀 Independent repository
📁 java-backend3-repo              # 🚀 Independent repository  
📁 nodejs-backend1-repo            # 🚀 Independent repository
📁 nodejs-backend2-repo            # 🚀 Independent repository
📁 nodejs-backend3-repo            # 🚀 Independent repository

📁 shared-workflows-repo           # 🛠️ Centralized workflow management
├── .github/workflows/
│   ├── shared-deploy.yml          # Reusable workflow
│   ├── rollback-deployment.yml    # Reusable rollback
│   └── pr-security-check.yml      # Reusable security checks
└── README.md                      # Workflow documentation
```

## 📋 **Migration Steps**

### **Step 1: Create Shared Workflows Repository**

```bash
# Create the central shared workflows repository
gh repo create your-org/shared-workflows --public

# Clone and setup
git clone https://github.com/your-org/shared-workflows.git
cd shared-workflows

# Copy shared infrastructure
cp ../shared-workflows-be/.github/workflows/shared-deploy.yml .github/workflows/
cp ../shared-workflows-be/.github/workflows/rollback-deployment.yml .github/workflows/
cp ../shared-workflows-be/.github/workflows/pr-security-check.yml .github/workflows/
cp ../shared-workflows-be/.github/workflows/deploy-monitoring.yml .github/workflows/

# Create documentation
echo "# Shared GitHub Actions Workflows

This repository contains reusable GitHub Actions workflows for all microservices.

## Available Workflows

### shared-deploy.yml
- Handles Java Spring Boot and Node.js deployments
- Supports multiple environments (dev, sqe, production)
- Integrates with Azure Container Registry and AKS

### rollback-deployment.yml
- Provides rollback capabilities for failed deployments
- Supports Helm-based rollbacks

## Usage

Reference these workflows from your service repositories:

\`\`\`yaml
jobs:
  deploy:
    uses: your-org/shared-workflows/.github/workflows/shared-deploy.yml@main
    with:
      application_name: your-service-name
      application_type: java-springboot # or nodejs
\`\`\`
" > README.md

# Commit and push
git add .
git commit -m "Initial shared workflows setup"
git push origin main
```

### **Step 2: Create Individual Backend Repositories**

```bash
# Create repositories for each backend
gh repo create your-org/java-backend1-user-management --public
gh repo create your-org/java-backend2-product-catalog --public
gh repo create your-org/java-backend3-order-management --public
gh repo create your-org/nodejs-backend1-notification --public
gh repo create your-org/nodejs-backend2-analytics --public
gh repo create your-org/nodejs-backend3-file-management --public
```

### **Step 3: Migrate Each Backend (Example: java-backend1)**

```bash
# Clone the new repository
git clone https://github.com/your-org/java-backend1-user-management.git
cd java-backend1-user-management

# Copy all files from the monorepo backend
cp -r ../shared-workflows-be/apps/java-backend1/* .

# Update workflow to use external shared workflow
sed -i 's|uses: ./.github/workflows/shared-deploy.yml|uses: your-org/shared-workflows/.github/workflows/shared-deploy.yml@main|g' .github/workflows/deploy.yml

# Update build context paths (since we're now at repo root)
sed -i 's|build_context: apps/java-backend1|build_context: .|g' .github/workflows/deploy.yml
sed -i 's|dockerfile_path: apps/java-backend1/Dockerfile|dockerfile_path: ./Dockerfile|g' .github/workflows/deploy.yml
sed -i 's|helm_chart_path: helm|helm_chart_path: ./helm|g' .github/workflows/deploy.yml

# Update path triggers (since we're now at repo root)
sed -i 's|apps/java-backend1/\*\*|**|g' .github/workflows/deploy.yml

# Create repository-specific README
echo "# Java Backend 1 - User Management Service

A Spring Boot microservice handling user authentication, authorization, and profile management.

## 🚀 Quick Start

### Local Development
\`\`\`bash
mvn spring-boot:run
\`\`\`

### Docker Build
\`\`\`bash
docker build -t java-backend1 .
\`\`\`

### Deployment
See [DEPLOYMENT.md](./DEPLOYMENT.md) for comprehensive deployment instructions.

## 🏗️ Architecture

- **Framework**: Spring Boot 3.x
- **Java Version**: 17
- **Database**: PostgreSQL
- **Monitoring**: Prometheus + Grafana
- **Deployment**: Kubernetes with Helm

## 📊 Health Checks

- Health: \`/actuator/health\`
- Metrics: \`/actuator/prometheus\`
- API Status: \`/api/status\`

## 🔗 API Endpoints

- \`GET /api/users\` - List users
- \`POST /api/users\` - Create user
- \`PUT /api/users/{id}\` - Update user
- \`DELETE /api/users/{id}\` - Delete user
" > README.md

# Commit and push
git add .
git commit -m "Initial commit: User Management Service

- Complete Spring Boot application with REST APIs
- Kubernetes Helm charts for deployment
- GitHub Actions workflow for CI/CD
- Comprehensive deployment documentation"
git push origin main
```

### **Step 4: Repeat for All Backends**

```bash
# Script to migrate all backends
#!/bin/bash

backends=(
    "java-backend2:java-backend2-product-catalog:Product Catalog Service"
    "java-backend3:java-backend3-order-management:Order Management Service"
    "nodejs-backend1:nodejs-backend1-notification:Notification Service"
    "nodejs-backend2:nodejs-backend2-analytics:Analytics Service"
    "nodejs-backend3:nodejs-backend3-file-management:File Management Service"
)

for backend_info in "${backends[@]}"; do
    IFS=':' read -r backend_dir repo_name service_name <<< "$backend_info"
    
    echo "Migrating $backend_dir to $repo_name"
    
    # Clone repository
    git clone https://github.com/your-org/$repo_name.git
    cd $repo_name
    
    # Copy files
    cp -r ../shared-workflows-be/apps/$backend_dir/* .
    
    # Update workflow references
    sed -i 's|uses: ./.github/workflows/shared-deploy.yml|uses: your-org/shared-workflows/.github/workflows/shared-deploy.yml@main|g' .github/workflows/deploy.yml
    sed -i "s|build_context: apps/$backend_dir|build_context: .|g" .github/workflows/deploy.yml
    sed -i "s|dockerfile_path: apps/$backend_dir/Dockerfile|dockerfile_path: ./Dockerfile|g" .github/workflows/deploy.yml
    sed -i 's|helm_chart_path: helm|helm_chart_path: ./helm|g' .github/workflows/deploy.yml
    sed -i "s|apps/$backend_dir/\*\*|**|g" .github/workflows/deploy.yml
    
    # Create README
    echo "# $service_name" > README.md
    
    # Commit and push
    git add .
    git commit -m "Initial commit: $service_name"
    git push origin main
    
    cd ..
done
```

## 🔧 **Updated Workflow Configuration**

After migration, each service's `deploy.yml` will look like:

```yaml
name: Deploy Java Backend 1 - User Management Service

permissions:
  id-token: write
  contents: read
  actions: read

on:
  push:
    branches:
      - main
      - develop
      - 'release/**'
      - 'feature/**'
    paths:
      - '**'                    # ✅ Now monitors entire repo
  pull_request:
    branches:
      - main
      - develop
    paths:
      - '**'                    # ✅ Now monitors entire repo
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        type: choice
        options:
          - dev
          - sqe
          - production

jobs:
  deploy:
    uses: your-org/shared-workflows/.github/workflows/shared-deploy.yml@main  # ✅ External reference
    with:
      environment: ${{ github.event.inputs.environment || 'auto' }}
      application_name: java-backend1
      application_type: java-springboot
      build_context: .                    # ✅ Root of repo
      dockerfile_path: ./Dockerfile       # ✅ Root of repo
      helm_chart_path: ./helm             # ✅ Local helm chart
    secrets:
      ACR_LOGIN_SERVER: ${{ secrets.ACR_LOGIN_SERVER }}
      AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      # ... other secrets
```

## ✅ **Benefits After Migration**

### **🏗️ True Microservices Independence**
- ✅ Each service has its own Git repository
- ✅ Independent versioning and release cycles
- ✅ Team ownership per repository
- ✅ No cross-service dependencies

### **🔄 Centralized Workflow Management**
- ✅ Single source of truth for deployment logic
- ✅ Easy to update deployment standards across all services
- ✅ Consistent deployment patterns
- ✅ Reduced maintenance overhead

### **🚀 Enhanced Development Velocity**
- ✅ Faster CI/CD (only builds what changed)
- ✅ Clear ownership boundaries
- ✅ Simplified repository permissions
- ✅ Service-specific commit history

### **🛡️ Operational Excellence**
- ✅ Independent testing and deployment
- ✅ Isolated failure domains
- ✅ Service-specific scaling
- ✅ Clear troubleshooting scope

## 🎯 **Testing the Migration**

After migration, test each service independently:

```bash
# Navigate to individual service repository
cd java-backend1-user-management

# Test manual deployment
gh workflow run deploy.yml -f environment=dev

# Test automatic deployment
git commit --allow-empty -m "test: trigger deployment"
git push origin develop

# Verify deployment
curl https://dev.mydomain.com/backend1/actuator/health
```

## 📞 **Post-Migration Support**

1. **Update CI/CD Documentation**: Update all documentation to reference new repositories
2. **Team Training**: Train teams on new repository structure
3. **Access Control**: Set up repository-level permissions
4. **Monitoring**: Update monitoring dashboards with new repository names
5. **Dependencies**: Update any inter-service dependencies

This migration provides the foundation for true microservices architecture with centralized workflow management! 🚀