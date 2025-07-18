# Azure Login Troubleshooting Guide

## 🚨 **Current Error Analysis**

### **Error Message:**
```
Attempting Azure CLI login by using user-assigned managed identity...
Error: Identity not found
Error: Interactive authentication is needed. Please run: az login
Error: Login failed with Error: The process '/usr/bin/az' failed with exit code 1
```

### **Root Cause:**
The `azure/login@v2` action is configured with `auth-type: IDENTITY` which expects a user-assigned managed identity, but GitHub Actions cannot directly use Azure managed identities. This authentication method is designed for Azure VMs, not GitHub-hosted runners.

## 🔧 **Solutions**

### **Solution 1: Use OpenID Connect (OIDC) - Recommended**

This is the most secure and modern approach for GitHub Actions to Azure authentication.

#### **Step 1: Create Azure AD App Registration**

```bash
# Set variables
APP_NAME="github-actions-oidc"
SUBSCRIPTION_ID="your-subscription-id"
RESOURCE_GROUP="your-resource-group"

# Create app registration
az ad app create --display-name $APP_NAME

# Get the application ID
APP_ID=$(az ad app list --display-name $APP_NAME --query '[0].appId' -o tsv)
echo "Application ID: $APP_ID"

# Create service principal
az ad sp create --id $APP_ID

# Get the object ID
OBJECT_ID=$(az ad sp list --display-name $APP_NAME --query '[0].id' -o tsv)
echo "Service Principal Object ID: $OBJECT_ID"
```

#### **Step 2: Configure Federated Credentials**

```bash
# Create federated credential for main branch
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for pull requests
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_ORG/YOUR_REPO:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

#### **Step 3: Assign Azure Permissions**

```bash
# Assign Contributor role to subscription (adjust scope as needed)
az role assignment create \
  --assignee $APP_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# Assign ACR push/pull permissions
az role assignment create \
  --assignee $APP_ID \
  --role "AcrPush" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
```

#### **Step 4: Update GitHub Secrets**

```yaml
# Add these to your GitHub repository secrets:
AZURE_CLIENT_ID: "your-app-id-from-step-1"
AZURE_TENANT_ID: "your-tenant-id"
AZURE_SUBSCRIPTION_ID: "your-subscription-id"
```

#### **Step 5: Update Docker Build Action**

```yaml
# Update .github/actions/docker-build-push/action.yml
- name: Azure Login with OIDC
  uses: azure/login@v2
  with:
    client-id: ${{ inputs.azure_client_id }}
    tenant-id: ${{ inputs.azure_tenant_id }}
    subscription-id: ${{ inputs.azure_subscription_id }}
```

### **Solution 2: Use Service Principal (Alternative)**

If OIDC is not available, use traditional service principal authentication.

#### **Step 1: Create Service Principal**

```bash
# Create service principal with Contributor role
SUBSCRIPTION_ID="your-subscription-id"
SP_NAME="github-actions-sp"

az ad sp create-for-rbac \
  --name $SP_NAME \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID" \
  --sdk-auth

# Output will look like:
{
  "clientId": "your-client-id",
  "clientSecret": "your-client-secret",
  "subscriptionId": "your-subscription-id",
  "tenantId": "your-tenant-id"
}
```

#### **Step 2: Add GitHub Secrets**

```yaml
# Add these to your GitHub repository secrets:
AZURE_CREDENTIALS: '{
  "clientId": "your-client-id",
  "clientSecret": "your-client-secret", 
  "subscriptionId": "your-subscription-id",
  "tenantId": "your-tenant-id"
}'
```

#### **Step 3: Update Action**

```yaml
# Update .github/actions/docker-build-push/action.yml
- name: Azure Login with Service Principal
  uses: azure/login@v2
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}
```

## 🛠️ **Fix Current Docker Build Action**

Let me provide the corrected version of your docker-build-push action:

### **Option A: OIDC Authentication (Recommended)**

```yaml
inputs:
  azure_tenant_id:
    description: 'Azure Tenant ID'
    required: true
  azure_client_id:
    description: 'Azure Client ID (App Registration)'
    required: true
  azure_subscription_id:
    description: 'Azure Subscription ID'
    required: true

steps:
  - name: Azure Login with OIDC
    uses: azure/login@v2
    with:
      client-id: ${{ inputs.azure_client_id }}
      tenant-id: ${{ inputs.azure_tenant_id }}
      subscription-id: ${{ inputs.azure_subscription_id }}

  - name: Login to Azure Container Registry
    run: |
      # Extract ACR name from registry URL
      ACR_NAME=$(echo "${{ inputs.registry }}" | cut -d'.' -f1)
      echo "Logging into ACR: $ACR_NAME"
      
      # Login to ACR using the authenticated Azure CLI
      az acr login --name $ACR_NAME
    shell: bash
```

### **Option B: Service Principal Authentication**

```yaml
inputs:
  azure_credentials:
    description: 'Azure Service Principal credentials (JSON)'
    required: true

steps:
  - name: Azure Login with Service Principal
    uses: azure/login@v2
    with:
      creds: ${{ inputs.azure_credentials }}

  - name: Login to Azure Container Registry
    run: |
      ACR_NAME=$(echo "${{ inputs.registry }}" | cut -d'.' -f1)
      az acr login --name $ACR_NAME
    shell: bash
```

## 🔍 **Debugging Commands**

### **Test Azure CLI Authentication**

```bash
# Check current authentication
az account show

# List available subscriptions
az account list --output table

# Test ACR access
az acr list --output table

# Test specific ACR login
az acr login --name your-acr-name --debug
```

### **Verify GitHub OIDC Setup**

```bash
# Check federated credentials
az ad app federated-credential list --id $APP_ID

# Verify service principal permissions
az role assignment list --assignee $APP_ID --output table
```

## 🚨 **Common Issues & Fixes**

### **Issue 1: "Identity not found"**
- **Cause:** Using `auth-type: IDENTITY` in GitHub Actions
- **Fix:** Switch to OIDC or Service Principal authentication

### **Issue 2: "Insufficient privileges"**
- **Cause:** Service principal lacks required permissions
- **Fix:** Assign proper Azure roles (Contributor, AcrPush, etc.)

### **Issue 3: "Invalid audience"**
- **Cause:** Incorrect federated credential configuration
- **Fix:** Ensure audience is `api://AzureADTokenExchange`

### **Issue 4: "Subject claim validation failed"**
- **Cause:** Incorrect repository path in federated credential
- **Fix:** Use exact format: `repo:owner/repository:ref:refs/heads/branch`

## 📋 **Migration Checklist**

### **For OIDC Setup:**
- [ ] Create Azure AD App Registration
- [ ] Configure federated credentials for your repository
- [ ] Assign required Azure permissions
- [ ] Update GitHub repository secrets
- [ ] Update GitHub Actions workflow
- [ ] Test authentication

### **For Service Principal Setup:**
- [ ] Create service principal with required permissions
- [ ] Add AZURE_CREDENTIALS secret to GitHub
- [ ] Update GitHub Actions workflow
- [ ] Test authentication

## 🔧 **Quick Fix Commands**

### **Get Your Current Setup Info:**
```bash
# Get tenant ID
az account show --query tenantId -o tsv

# Get subscription ID  
az account show --query id -o tsv

# List your ACRs
az acr list --query '[].{Name:name,LoginServer:loginServer}' -o table
```

### **Test Your Service Principal:**
```bash
# Test login with service principal
az login --service-principal \
  --username "your-client-id" \
  --password "your-client-secret" \
  --tenant "your-tenant-id"

# Test ACR access
az acr login --name your-acr-name
```

## 🎯 **Recommended Solution**

**Use OIDC authentication** as it's:
- ✅ More secure (no stored secrets)
- ✅ Microsoft recommended approach
- ✅ Better audit trail
- ✅ Automatic token rotation
- ✅ Supports conditional access policies

The current `auth-type: IDENTITY` approach won't work in GitHub Actions because GitHub-hosted runners can't access Azure managed identities directly. You need to use either OIDC or Service Principal authentication methods.