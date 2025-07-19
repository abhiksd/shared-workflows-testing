# Quick Start Guide

Get your production-grade AKS deployment platform up and running in 30 minutes.

## 🚀 Prerequisites (5 minutes)

### 1. Required Accounts & Permissions
- Azure subscription with **Contributor** access
- GitHub repository with **Admin** access
- Azure AD **Application Administrator** role

### 2. Install Required Tools
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh

# Login to both services
az login
gh auth login
```

## ⚙️ Infrastructure Setup (15 minutes)

### 1. Set Environment Variables
```bash
export SUBSCRIPTION_ID="your-subscription-id"
export TENANT_ID="your-tenant-id"
export LOCATION="East US 2"
export PROJECT_NAME="myapp"
export GITHUB_REPO="your-org/your-repo"
```

### 2. Run Quick Setup Script
```bash
# Create and run the setup script
cat > quick-setup.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting Quick AKS Platform Setup..."

# Set subscription
az account set --subscription $SUBSCRIPTION_ID

# Create resource groups
echo "📦 Creating resource groups..."
az group create --name "rg-${PROJECT_NAME}-dev" --location "$LOCATION" --tags Environment=dev
az group create --name "rg-${PROJECT_NAME}-shared" --location "$LOCATION" --tags Environment=shared

# Create AKS cluster (dev only for quick start)
echo "🏗️ Creating AKS cluster (this takes ~10 minutes)..."
az aks create \
  --resource-group "rg-${PROJECT_NAME}-dev" \
  --name "aks-${PROJECT_NAME}-dev" \
  --node-count 2 \
  --node-vm-size Standard_D2s_v3 \
  --enable-addons monitoring,azure-keyvault-secrets-provider \
  --enable-managed-identity \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --generate-ssh-keys \
  --network-plugin azure \
  --kubernetes-version 1.28.3 &

# Create ACR (runs in parallel with AKS)
echo "📦 Creating Azure Container Registry..."
az acr create \
  --resource-group "rg-${PROJECT_NAME}-shared" \
  --name "acr${PROJECT_NAME}shared" \
  --sku Standard \
  --location "$LOCATION"

# Create Key Vault
echo "🔐 Creating Key Vault..."
az keyvault create \
  --name "kv-${PROJECT_NAME}-dev" \
  --resource-group "rg-${PROJECT_NAME}-dev" \
  --location "$LOCATION" \
  --enable-rbac-authorization true

# Wait for AKS creation to complete
wait
echo "✅ AKS cluster created successfully!"

# Get ACR login server
export ACR_LOGIN_SERVER=$(az acr show --name "acr${PROJECT_NAME}shared" --resource-group "rg-${PROJECT_NAME}-shared" --query "loginServer" --output tsv)

# Attach ACR to AKS
az aks update \
  --resource-group "rg-${PROJECT_NAME}-dev" \
  --name "aks-${PROJECT_NAME}-dev" \
  --attach-acr "acr${PROJECT_NAME}shared"

echo "🎉 Infrastructure setup completed!"
echo "ACR Login Server: $ACR_LOGIN_SERVER"
EOF

chmod +x quick-setup.sh
./quick-setup.sh
```

## 🔑 GitHub Integration (5 minutes)

### 1. Create GitHub OIDC App Registration
```bash
# Create app registration for GitHub OIDC
APP_ID=$(az ad app create --display-name "GitHub-OIDC-${PROJECT_NAME}" --query appId --output tsv)
az ad sp create --id $APP_ID

# Assign necessary roles
az role assignment create --assignee $APP_ID --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-${PROJECT_NAME}-dev"
az role assignment create --assignee $APP_ID --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-${PROJECT_NAME}-shared"
az role assignment create --assignee $APP_ID --role "AcrPush" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-${PROJECT_NAME}-shared/providers/Microsoft.ContainerRegistry/registries/acr${PROJECT_NAME}shared"
az role assignment create --assignee $APP_ID --role "Key Vault Secrets User" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-${PROJECT_NAME}-dev/providers/Microsoft.KeyVault/vaults/kv-${PROJECT_NAME}-dev"

echo "App Registration ID: $APP_ID"
```

### 2. Configure Federated Credentials
```bash
# Create federated credential for develop branch
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "GitHub-Actions-Develop",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:'$GITHUB_REPO':ref:refs/heads/N630-6258_Helm_deploy",
  "description": "GitHub Actions for develop branch",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

### 3. Set GitHub Secrets
```bash
# Get required values
ACR_LOGIN_SERVER=$(az acr show --name "acr${PROJECT_NAME}shared" --resource-group "rg-${PROJECT_NAME}-shared" --query "loginServer" --output tsv)

# Set GitHub repository secrets
gh secret set ACR_LOGIN_SERVER --body "$ACR_LOGIN_SERVER" --repo $GITHUB_REPO
gh secret set AZURE_TENANT_ID --body "$TENANT_ID" --repo $GITHUB_REPO
gh secret set AZURE_CLIENT_ID --body "$APP_ID" --repo $GITHUB_REPO
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --repo $GITHUB_REPO
gh secret set KEYVAULT_NAME --body "kv-${PROJECT_NAME}-dev" --repo $GITHUB_REPO

echo "✅ GitHub secrets configured!"
```

## 🎯 Test Deployment (5 minutes)

### 1. Update Workflow Configuration
Create or update `.github/workflows/deploy-java-app.yml`:

```bash
# Update the workflow with your cluster details
cat > .github/workflows/deploy-java-app.yml << EOF
name: Deploy Java Spring Boot Application
permissions:
  id-token: write
  contents: read
  actions: read
on:
  push:
    branches:
      - N630-6258_Helm_deploy
    paths:
      - './**'
      - 'helm/java-app/**'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        type: choice
        options:
          - dev
        default: dev
      force_deploy:
        description: 'Force deployment even if no changes'
        required: false
        type: boolean
        default: false

jobs:
  deploy:
    uses: ./.github/workflows/shared-deploy.yml
    with:
      environment: \${{ github.event.inputs.environment || 'auto' }}
      application_name: java-app
      application_type: java-springboot
      build_context: ./
      dockerfile_path: ./Dockerfile
      helm_chart_path: helm/java-app
      force_deploy: \${{ github.event.inputs.force_deploy == 'true' }}
      aks_cluster_name_dev: "aks-${PROJECT_NAME}-dev"
      aks_resource_group_dev: "rg-${PROJECT_NAME}-dev"
      aks_cluster_name_sqe: "aks-${PROJECT_NAME}-staging"
      aks_resource_group_sqe: "rg-${PROJECT_NAME}-staging"
      aks_cluster_name_prod: "aks-${PROJECT_NAME}-prod"
      aks_resource_group_prod: "rg-${PROJECT_NAME}-prod"
    secrets:
      ACR_LOGIN_SERVER: \${{ secrets.ACR_LOGIN_SERVER }}
      KEYVAULT_NAME: \${{ secrets.KEYVAULT_NAME }}
      AZURE_TENANT_ID: \${{ secrets.AZURE_TENANT_ID }}
      AZURE_CLIENT_ID: \${{ secrets.AZURE_CLIENT_ID }}
      AZURE_SUBSCRIPTION_ID: \${{ secrets.AZURE_SUBSCRIPTION_ID }}
EOF
```

### 2. Create Sample Application
If you don't have an application yet, create a simple Spring Boot app:

```bash
# Create sample Dockerfile
cat > Dockerfile << 'EOF'
FROM openjdk:17-jre-slim

WORKDIR /app
COPY target/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF

# Create sample pom.xml
cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
        <relativePath/>
    </parent>
    <groupId>com.example</groupId>
    <artifactId>demo-app</artifactId>
    <version>1.0.0</version>
    
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
    </dependencies>
</project>
EOF
```

### 3. Deploy to Dev Environment
```bash
# Commit and push to trigger deployment
git add .
git commit -m "feat: initial deployment setup"
git push origin N630-6258_Helm_deploy

# Monitor deployment
gh run list --workflow=deploy-java-app.yml --limit=1
```

## ✅ Verification

### 1. Check Deployment Status
```bash
# Get AKS credentials
az aks get-credentials --resource-group "rg-${PROJECT_NAME}-dev" --name "aks-${PROJECT_NAME}-dev"

# Check pods
kubectl get pods -n default

# Check services
kubectl get svc -n default

# Check ingress (if configured)
kubectl get ingress -n default
```

### 2. Test Application Health
```bash
# Port forward to test locally
kubectl port-forward service/java-app 8080:8080 &

# Test health endpoint
curl http://localhost:8080/actuator/health

# Kill port forward
pkill kubectl
```

## 🎉 What's Next?

### Immediate Next Steps
1. **Add more environments**: Follow the [Azure Setup Guide](docs/AZURE_SETUP_GUIDE.md) to create staging and production
2. **Customize Helm charts**: Modify `helm/java-app/values-dev.yaml` for your needs
3. **Add monitoring**: Configure Application Insights and Log Analytics
4. **Set up ingress**: Configure external access to your application

### Scaling Up
1. **Production deployment**: Create release branches for production deployments
2. **Security hardening**: Enable Azure Key Vault secrets and network policies
3. **Monitoring & alerts**: Set up comprehensive monitoring and alerting
4. **CI/CD enhancements**: Add security scanning and testing gates

## 📚 Additional Resources

- **[Complete Documentation](README.md)**: Full platform documentation
- **[Deployment Guide](docs/DEPLOYMENT_GUIDE.md)**: Detailed deployment scenarios
- **[Helm Chart Guide](docs/HELM_CHART_GUIDE.md)**: Comprehensive Helm chart documentation
- **[Azure Setup Guide](docs/AZURE_SETUP_GUIDE.md)**: Complete Azure infrastructure setup

## 🆘 Troubleshooting

### Common Issues

1. **Authentication errors**: Verify GitHub secrets and federated credentials
2. **Image pull errors**: Check ACR integration with AKS
3. **Pod startup failures**: Review application logs and health checks
4. **Permission denied**: Verify Azure role assignments

### Get Help
```bash
# Check workflow logs
gh run view --log

# Check pod logs
kubectl logs -l app=java-app

# Check AKS cluster status
az aks show --resource-group "rg-${PROJECT_NAME}-dev" --name "aks-${PROJECT_NAME}-dev" --output table
```

---

**Estimated Setup Time**: 30 minutes  
**Difficulty**: Beginner  
**Last Updated**: $(date '+%Y-%m-%d')