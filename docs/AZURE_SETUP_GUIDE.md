# Azure Infrastructure Setup Guide

This guide provides step-by-step instructions for setting up the complete Azure infrastructure required for the production-grade AKS deployment platform.

## 📋 Table of Contents

- [Prerequisites](#-prerequisites)
- [Azure Resource Setup](#-azure-resource-setup)
- [AKS Cluster Configuration](#-aks-cluster-configuration)
- [Azure Container Registry](#-azure-container-registry)

- [Azure Active Directory Configuration](#-azure-active-directory-configuration)
- [GitHub OIDC Integration](#-github-oidc-integration)
- [Network Security](#-network-security)
- [Monitoring & Logging](#-monitoring--logging)
- [Validation & Testing](#-validation--testing)

## 🚀 Prerequisites

### Required Tools
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar xz
sudo mv linux-amd64/helm /usr/local/bin/

# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh
```

### Azure Permissions Required
- **Subscription Contributor** or higher
- **Application Administrator** in Azure AD
- **Global Reader** in Azure AD (for verification)

### Environment Variables
```bash
# Set these variables for your environment
export SUBSCRIPTION_ID="your-subscription-id"
export TENANT_ID="your-tenant-id"
export LOCATION="East US 2"
export RESOURCE_GROUP_PREFIX="rg-aks-platform"
export PROJECT_NAME="aks-platform"
export GITHUB_REPO="your-org/your-repo"
```

## 🏗️ Azure Resource Setup

### 1. Login and Set Subscription
```bash
# Login to Azure
az login

# Set subscription
az account set --subscription $SUBSCRIPTION_ID

# Verify subscription
az account show --output table
```

### 2. Create Resource Groups
```bash
# Development Environment
az group create \
  --name "${RESOURCE_GROUP_PREFIX}-dev" \
  --location "$LOCATION" \
  --tags Environment=development Project=$PROJECT_NAME

# Staging Environment  
az group create \
  --name "${RESOURCE_GROUP_PREFIX}-staging" \
  --location "$LOCATION" \
  --tags Environment=staging Project=$PROJECT_NAME

# Production Environment
az group create \
  --name "${RESOURCE_GROUP_PREFIX}-prod" \
  --location "$LOCATION" \
  --tags Environment=production Project=$PROJECT_NAME

# Shared Resources (ACR)
az group create \
  --name "${RESOURCE_GROUP_PREFIX}-shared" \
  --location "$LOCATION" \
  --tags Environment=shared Project=$PROJECT_NAME
```

## ⚙️ AKS Cluster Configuration

### 1. Create AKS Clusters

#### Development Cluster
```bash
az aks create \
  --resource-group "${RESOURCE_GROUP_PREFIX}-dev" \
  --name "aks-${PROJECT_NAME}-dev" \
  --node-count 2 \
  --node-vm-size Standard_D2s_v3 \
  --enable-addons monitoring \
  --enable-managed-identity \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --generate-ssh-keys \
  --network-plugin azure \
  --network-policy azure \
  --load-balancer-sku standard \
  --vm-set-type VirtualMachineScaleSets \
  --kubernetes-version 1.28.3 \
  --tags Environment=development Project=$PROJECT_NAME
```

#### Staging Cluster
```bash
az aks create \
  --resource-group "${RESOURCE_GROUP_PREFIX}-staging" \
  --name "aks-${PROJECT_NAME}-staging" \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --enable-addons monitoring \
  --enable-managed-identity \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --enable-auto-scaling \
  --min-count 2 \
  --max-count 10 \
  --generate-ssh-keys \
  --network-plugin azure \
  --network-policy azure \
  --load-balancer-sku standard \
  --vm-set-type VirtualMachineScaleSets \
  --kubernetes-version 1.28.3 \
  --tags Environment=staging Project=$PROJECT_NAME
```

#### Production Cluster
```bash
az aks create \
  --resource-group "${RESOURCE_GROUP_PREFIX}-prod" \
  --name "aks-${PROJECT_NAME}-prod" \
  --node-count 5 \
  --node-vm-size Standard_D8s_v3 \
  --enable-addons monitoring \
  --enable-managed-identity \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --enable-auto-scaling \
  --min-count 3 \
  --max-count 50 \
  --generate-ssh-keys \
  --network-plugin azure \
  --network-policy azure \
  --load-balancer-sku standard \
  --vm-set-type VirtualMachineScaleSets \
  --kubernetes-version 1.28.3 \
  --enable-private-cluster \
  --tags Environment=production Project=$PROJECT_NAME
```

### 2. Configure Kubectl Access
```bash
# Development
az aks get-credentials \
  --resource-group "${RESOURCE_GROUP_PREFIX}-dev" \
  --name "aks-${PROJECT_NAME}-dev" \
  --context "aks-${PROJECT_NAME}-dev"

# Staging
az aks get-credentials \
  --resource-group "${RESOURCE_GROUP_PREFIX}-staging" \
  --name "aks-${PROJECT_NAME}-staging" \
  --context "aks-${PROJECT_NAME}-staging"

# Production
az aks get-credentials \
  --resource-group "${RESOURCE_GROUP_PREFIX}-prod" \
  --name "aks-${PROJECT_NAME}-prod" \
  --context "aks-${PROJECT_NAME}-prod"

# Verify access
kubectl config get-contexts
```

## 📦 Azure Container Registry

### 1. Create ACR
```bash
az acr create \
  --resource-group "${RESOURCE_GROUP_PREFIX}-shared" \
  --name "acr${PROJECT_NAME}shared" \
  --sku Premium \
  --location "$LOCATION" \
  --admin-enabled false \
  --tags Environment=shared Project=$PROJECT_NAME

# Get ACR login server
export ACR_LOGIN_SERVER=$(az acr show \
  --name "acr${PROJECT_NAME}shared" \
  --resource-group "${RESOURCE_GROUP_PREFIX}-shared" \
  --query "loginServer" --output tsv)

echo "ACR Login Server: $ACR_LOGIN_SERVER"
```

### 2. Integrate ACR with AKS
```bash
# Development
az aks update \
  --resource-group "${RESOURCE_GROUP_PREFIX}-dev" \
  --name "aks-${PROJECT_NAME}-dev" \
  --attach-acr "acr${PROJECT_NAME}shared"

# Staging
az aks update \
  --resource-group "${RESOURCE_GROUP_PREFIX}-staging" \
  --name "aks-${PROJECT_NAME}-staging" \
  --attach-acr "acr${PROJECT_NAME}shared"

# Production
az aks update \
  --resource-group "${RESOURCE_GROUP_PREFIX}-prod" \
  --name "aks-${PROJECT_NAME}-prod" \
  --attach-acr "acr${PROJECT_NAME}shared"
```

### 3. Configure ACR Security
```bash
# Enable vulnerability scanning
az acr task create \
  --registry "acr${PROJECT_NAME}shared" \
  --name security-scan \
  --image mcr.microsoft.com/azure-cli:latest \
  --context /dev/null \
  --file - <<EOF
version: v1.1.0
steps:
  - cmd: echo "Security scan placeholder"
EOF

# Configure content trust (optional)
az acr config content-trust update \
  --registry "acr${PROJECT_NAME}shared" \
  --status enabled
```


## 🔑 Azure Active Directory Configuration

### 1. Create App Registration for GitHub OIDC
```bash
# Create app registration
APP_ID=$(az ad app create \
  --display-name "GitHub-OIDC-${PROJECT_NAME}" \
  --query appId \
  --output tsv)

echo "App Registration ID: $APP_ID"

# Create service principal
az ad sp create --id $APP_ID

# Get service principal object ID
SP_OBJECT_ID=$(az ad sp show --id $APP_ID --query id --output tsv)
echo "Service Principal Object ID: $SP_OBJECT_ID"
```

### 2. Assign Azure Roles
```bash
# Assign Contributor role for resource groups
for env in dev staging prod shared; do
  az role assignment create \
    --assignee $APP_ID \
    --role "Contributor" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/${RESOURCE_GROUP_PREFIX}-${env}"
done

# Assign ACR roles
az role assignment create \
  --assignee $APP_ID \
  --role "AcrPush" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/${RESOURCE_GROUP_PREFIX}-shared/providers/Microsoft.ContainerRegistry/registries/acr${PROJECT_NAME}shared"


```

### 3. Create Managed Identities for Workload Identity
```bash
# Function to create managed identity
create_managed_identity() {
  local env=$1
  local rg="${RESOURCE_GROUP_PREFIX}-${env}"
  local cluster_name="aks-${PROJECT_NAME}-${env}"
  
  # Create managed identity
  az identity create \
    --name "id-${PROJECT_NAME}-${env}" \
    --resource-group "$rg" \
    --tags Environment=$env Project=$PROJECT_NAME
  
  # Get identity details
  local identity_id=$(az identity show \
    --name "id-${PROJECT_NAME}-${env}" \
    --resource-group "$rg" \
    --query id --output tsv)
  
  local client_id=$(az identity show \
    --name "id-${PROJECT_NAME}-${env}" \
    --resource-group "$rg" \
    --query clientId --output tsv)
  

  
  echo "Managed Identity for $env: $client_id"
}

# Create managed identities for all environments
create_managed_identity "dev"
create_managed_identity "staging"
create_managed_identity "prod"
```

## 🔗 GitHub OIDC Integration

### 1. Configure Federated Credentials
```bash
# Get repository details
REPO_OWNER=$(echo $GITHUB_REPO | cut -d'/' -f1)
REPO_NAME=$(echo $GITHUB_REPO | cut -d'/' -f2)

# Create federated credential for main branch (staging)
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "GitHub-Actions-Main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_REPO':ref:refs/heads/main",
    "description": "GitHub Actions for main branch",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for develop branch (development)
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "GitHub-Actions-Develop",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_REPO':ref:refs/heads/N630-6258_Helm_deploy",
    "description": "GitHub Actions for develop branch",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for release branches (production)
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "GitHub-Actions-Release",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_REPO':ref:refs/heads/release/*",
    "description": "GitHub Actions for release branches",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for tags (production)
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "GitHub-Actions-Tags",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_REPO':ref:refs/tags/*",
    "description": "GitHub Actions for tags",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### 2. Set GitHub Repository Secrets
```bash
# Authenticate with GitHub
gh auth login

# Set repository secrets
gh secret set ACR_LOGIN_SERVER --body "$ACR_LOGIN_SERVER" --repo $GITHUB_REPO
gh secret set AZURE_TENANT_ID --body "$TENANT_ID" --repo $GITHUB_REPO
gh secret set AZURE_CLIENT_ID --body "$APP_ID" --repo $GITHUB_REPO
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --repo $GITHUB_REPO



# Verify secrets
gh secret list --repo $GITHUB_REPO
```

## 🛡️ Network Security

### 1. Configure Network Security Groups
```bash
# Function to create NSG rules
create_nsg_rules() {
  local env=$1
  local rg="${RESOURCE_GROUP_PREFIX}-${env}"
  
  # Create NSG
  az network nsg create \
    --name "nsg-aks-${env}" \
    --resource-group "$rg" \
    --location "$LOCATION"
  
  # Allow inbound HTTPS
  az network nsg rule create \
    --name "AllowHTTPS" \
    --nsg-name "nsg-aks-${env}" \
    --resource-group "$rg" \
    --priority 1000 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --destination-port-ranges 443
  
  # Allow inbound HTTP (staging/dev only)
  if [[ "$env" != "prod" ]]; then
    az network nsg rule create \
      --name "AllowHTTP" \
      --nsg-name "nsg-aks-${env}" \
      --resource-group "$rg" \
      --priority 1001 \
      --direction Inbound \
      --access Allow \
      --protocol Tcp \
      --destination-port-ranges 80
  fi
}

# Create NSG rules for all environments
create_nsg_rules "dev"
create_nsg_rules "staging"
create_nsg_rules "prod"
```

### 2. Configure Private Endpoints (Production)
```bash

```

## 📊 Monitoring & Logging

### 1. Create Log Analytics Workspaces
```bash
# Function to create Log Analytics workspace
create_log_analytics() {
  local env=$1
  local rg="${RESOURCE_GROUP_PREFIX}-${env}"
  
  az monitor log-analytics workspace create \
    --name "law-${PROJECT_NAME}-${env}" \
    --resource-group "$rg" \
    --location "$LOCATION" \
    --retention-time 30 \
    --tags Environment=$env Project=$PROJECT_NAME
}

# Create workspaces for all environments
create_log_analytics "dev"
create_log_analytics "staging"
create_log_analytics "prod"
```

### 2. Configure Application Insights
```bash
# Function to create Application Insights
create_app_insights() {
  local env=$1
  local rg="${RESOURCE_GROUP_PREFIX}-${env}"
  
  az monitor app-insights component create \
    --app "ai-${PROJECT_NAME}-${env}" \
    --location "$LOCATION" \
    --resource-group "$rg" \
    --workspace "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.OperationalInsights/workspaces/law-${PROJECT_NAME}-${env}" \
    --tags Environment=$env Project=$PROJECT_NAME
}

# Create Application Insights for all environments
create_app_insights "dev"
create_app_insights "staging"
create_app_insights "prod"
```

### 3. Enable Container Insights
```bash
# Function to enable container insights
enable_container_insights() {
  local env=$1
  local rg="${RESOURCE_GROUP_PREFIX}-${env}"
  local cluster_name="aks-${PROJECT_NAME}-${env}"
  
  az aks enable-addons \
    --resource-group "$rg" \
    --name "$cluster_name" \
    --addons monitoring \
    --workspace-resource-id "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.OperationalInsights/workspaces/law-${PROJECT_NAME}-${env}"
}

# Enable for all environments
enable_container_insights "dev"
enable_container_insights "staging"
enable_container_insights "prod"
```

## ✅ Validation & Testing

### 1. Verify AKS Clusters
```bash
# Function to test AKS cluster
test_aks_cluster() {
  local env=$1
  local rg="${RESOURCE_GROUP_PREFIX}-${env}"
  local cluster_name="aks-${PROJECT_NAME}-${env}"
  
  echo "Testing AKS cluster: $cluster_name"
  
  # Get credentials
  az aks get-credentials --resource-group "$rg" --name "$cluster_name" --overwrite-existing
  
  # Test cluster connectivity
  kubectl cluster-info
  
  # Check node status
  kubectl get nodes
  
  # Check system pods
  kubectl get pods -n kube-system
  

}

# Test all clusters
test_aks_cluster "dev"
test_aks_cluster "staging"
test_aks_cluster "prod"
```

### 2. Test ACR Integration
```bash
# Test ACR authentication
az acr login --name "acr${PROJECT_NAME}shared"

# Test image push (using hello-world as example)
docker pull hello-world:latest
docker tag hello-world:latest "$ACR_LOGIN_SERVER/test/hello-world:latest"
docker push "$ACR_LOGIN_SERVER/test/hello-world:latest"

# Verify image in ACR
az acr repository list --name "acr${PROJECT_NAME}shared" --output table
```

### 3. Test GitHub OIDC Authentication
```bash
# Create a test workflow file to verify OIDC
cat > .github/workflows/test-azure-auth.yml << 'EOF'
name: Test Azure Authentication
on:
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  test-auth:
    runs-on: ubuntu-latest
    steps:
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Test Azure CLI
        run: |
          az account show
          az group list --query "[?contains(name, 'aks-platform')].name" --output table
EOF

echo "Test workflow created. Commit and push to test OIDC authentication."
```

## 🚀 Post-Setup Configuration

### 1. Install Required Add-ons
```bash
# Function to install common add-ons
install_addons() {
  local env=$1
  local rg="${RESOURCE_GROUP_PREFIX}-${env}"
  local cluster_name="aks-${PROJECT_NAME}-${env}"
  
  # Set kubectl context
  az aks get-credentials --resource-group "$rg" --name "$cluster_name" --overwrite-existing
  
  # Install NGINX Ingress Controller
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update
  
  helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
  
  # Install cert-manager (for TLS certificates)
  helm repo add jetstack https://charts.jetstack.io
  helm repo update
  
  helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --set installCRDs=true
}

# Install add-ons for all environments
install_addons "dev"
install_addons "staging"
install_addons "prod"
```

### 2. Configure Workload Identity
```bash
# Function to configure workload identity
configure_workload_identity() {
  local env=$1
  local rg="${RESOURCE_GROUP_PREFIX}-${env}"
  local cluster_name="aks-${PROJECT_NAME}-${env}"
  
  # Get OIDC issuer URL
  local oidc_issuer=$(az aks show --resource-group "$rg" --name "$cluster_name" --query "oidcIssuerProfile.issuerUrl" --output tsv)
  
  # Create federated credential for the managed identity
  local client_id=$(az identity show \
    --name "id-${PROJECT_NAME}-${env}" \
    --resource-group "$rg" \
    --query clientId --output tsv)
  
  az identity federated-credential create \
    --name "kubernetes-federated-credential" \
    --identity-name "id-${PROJECT_NAME}-${env}" \
    --resource-group "$rg" \
    --issuer "$oidc_issuer" \
    --subject "system:serviceaccount:default:java-app" \
    --audience api://AzureADTokenExchange
  
  echo "Workload Identity configured for $env environment"
  echo "Client ID: $client_id"
  echo "OIDC Issuer: $oidc_issuer"
}

# Configure workload identity for all environments
configure_workload_identity "dev"
configure_workload_identity "staging"
configure_workload_identity "prod"
```

## 📋 Summary and Next Steps

### Infrastructure Summary
After completing this setup, you will have:

- ✅ **3 AKS clusters** (dev, staging, production)
- ✅ **1 Azure Container Registry** (shared)

- ✅ **GitHub OIDC integration** configured
- ✅ **Monitoring and logging** enabled
- ✅ **Network security** configured
- ✅ **Workload identity** ready

### Resource Overview
```bash
# Get resource summary
az resource list --query "[?contains(resourceGroup, 'aks-platform')].{Name:name, Type:type, ResourceGroup:resourceGroup}" --output table
```

### Important Values to Note
```bash
echo "=== IMPORTANT VALUES FOR GITHUB SECRETS ==="
echo "ACR_LOGIN_SERVER: $ACR_LOGIN_SERVER"
echo "AZURE_TENANT_ID: $TENANT_ID"
echo "AZURE_CLIENT_ID: $APP_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo ""

echo "AKS Cluster Names:"
echo "- Development: aks-${PROJECT_NAME}-dev"
echo "- Staging: aks-${PROJECT_NAME}-staging" 
echo "- Production: aks-${PROJECT_NAME}-prod"
```

### Next Steps
1. **Update GitHub repository secrets** with the values above
2. **Customize Helm charts** in the `helm/` directory
3. **Configure your applications** with proper health check endpoints
4. **Test deployments** starting with the development environment
5. **Set up monitoring dashboards** in Azure Monitor
6. **Configure alerting rules** for production monitoring

### Cleanup (if needed)
```bash
# WARNING: This will delete all resources!
# Uncomment only if you need to clean up everything

# az group delete --name "${RESOURCE_GROUP_PREFIX}-dev" --yes --no-wait
# az group delete --name "${RESOURCE_GROUP_PREFIX}-staging" --yes --no-wait
# az group delete --name "${RESOURCE_GROUP_PREFIX}-prod" --yes --no-wait
# az group delete --name "${RESOURCE_GROUP_PREFIX}-shared" --yes --no-wait
# az ad app delete --id $APP_ID
```

---

**Last Updated**: $(date '+%Y-%m-%d')  
**Version**: 1.0.0  
**Maintained by**: DevOps Team