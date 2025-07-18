# AKS Deployment Troubleshooting Guide

## Error: Input required and not supplied: resource-group

This error occurs when the `azure/aks-set-context@v3` action doesn't receive the required `resource-group` parameter.

## Root Cause Analysis

### 1. **Missing Resource Group Parameter**
```
Error: Input required and not supplied: resource-group
```

**Cause:** The `aks_resource_group` input is empty or not provided to the helm-deploy action.

### 2. **Common Scenarios**
- **Missing AKS secrets** in repository settings
- **Environment detection failure** in validate-environment job
- **Secret name mismatch** between environment and secret names
- **Failed Azure authentication** before AKS context setup

## Enhanced Error Handling

The helm-deploy action now includes comprehensive validation:

```bash
🔍 Validating AKS deployment parameters...
❌ ERROR: aks_resource_group is empty or not provided
This usually means:
  - AKS_RESOURCE_GROUP_* secrets are not set
  - Environment detection failed
  - validate-environment job didn't set outputs correctly
```

## Required Repository Secrets

### For Each Environment
You need to set these secrets in your GitHub repository:

#### Development Environment
- `AKS_CLUSTER_NAME_DEV` - AKS cluster name for dev
- `AKS_RESOURCE_GROUP_DEV` - Resource group for dev AKS cluster

#### Staging Environment
- `AKS_CLUSTER_NAME_STAGING` - AKS cluster name for staging
- `AKS_RESOURCE_GROUP_STAGING` - Resource group for staging AKS cluster

#### Production Environment
- `AKS_CLUSTER_NAME_PROD` - AKS cluster name for production
- `AKS_RESOURCE_GROUP_PROD` - Resource group for production AKS cluster

#### Azure Authentication
- `AZURE_TENANT_ID` - Azure AD tenant ID
- `AZURE_CLIENT_ID` - Service principal client ID
- `AZURE_SUBSCRIPTION_ID` - Azure subscription ID

## Troubleshooting Steps

### 1. **Verify Repository Secrets**
Go to GitHub Repository → Settings → Secrets and variables → Actions

Check that all required secrets are set with correct names:
```
AKS_CLUSTER_NAME_DEV = "your-dev-cluster"
AKS_RESOURCE_GROUP_DEV = "rg-your-app-dev"
AKS_CLUSTER_NAME_STAGING = "your-staging-cluster"
AKS_RESOURCE_GROUP_STAGING = "rg-your-app-staging"
AKS_CLUSTER_NAME_PROD = "your-prod-cluster"
AKS_RESOURCE_GROUP_PROD = "rg-your-app-prod"
```

### 2. **Check Environment Detection**
The workflow auto-detects environment based on branch:
- `develop` branch → `dev` environment
- `main` branch → `staging` environment  
- `release/*` or tags → `production` environment

**Debug:** Look for this in validate-environment job output:
```bash
📊 Environment validation results:
   - Should deploy: true
   - Target environment: dev
   - AKS cluster name: your-dev-cluster
   - AKS resource group: rg-your-app-dev
```

### 3. **Validate Secret Naming Convention**
Secrets must follow exact naming pattern:
```bash
# For dev environment
AKS_CLUSTER_NAME_DEV       # Note: DEV (uppercase)
AKS_RESOURCE_GROUP_DEV     # Note: DEV (uppercase)

# For staging environment  
AKS_CLUSTER_NAME_STAGING   # Note: STAGING (uppercase)
AKS_RESOURCE_GROUP_STAGING # Note: STAGING (uppercase)

# For production environment
AKS_CLUSTER_NAME_PROD      # Note: PROD (uppercase, not PRODUCTION)
AKS_RESOURCE_GROUP_PROD    # Note: PROD (uppercase, not PRODUCTION)
```

### 4. **Test Azure Authentication**
Verify that Azure OIDC authentication is working:

```yaml
- name: Test Azure Login
  run: |
    az account show
    az group list --query "[].{Name:name, Location:location}" -o table
```

### 5. **Check AKS Cluster Access**
Verify the service principal has access to the AKS cluster:

```bash
# Check if cluster exists and is accessible
az aks list --resource-group "your-resource-group" --query "[].name" -o table

# Test AKS access
az aks get-credentials --resource-group "your-resource-group" --name "your-cluster"
kubectl get nodes
```

## Common Issues and Solutions

### 1. **Secret Name Case Sensitivity**
```bash
# WRONG
aks_cluster_name_dev = "cluster"

# CORRECT  
AKS_CLUSTER_NAME_DEV = "cluster"
```

### 2. **Environment Name Mismatch**
```bash
# Workflow detects "dev" but secret is named for "development"
AKS_CLUSTER_NAME_DEVELOPMENT  # ❌ Wrong
AKS_CLUSTER_NAME_DEV         # ✅ Correct
```

### 3. **Missing Azure Permissions**
The Azure service principal needs:
- **Reader** access on the resource group
- **Azure Kubernetes Service Cluster User Role** on the AKS cluster
- **Key Vault Secrets User** (if using Key Vault)

### 4. **Wrong Resource Group Name**
```bash
# Ensure the resource group name in secrets matches Azure exactly
# Check in Azure Portal or with:
az group list --query "[].name" -o table
```

### 5. **AKS Cluster Not Found**
```bash
# Verify cluster exists in the specified resource group
az aks list --resource-group "your-rg" --query "[].name" -o table
```

## Environment-Specific Configuration

### Development Deployment
- **Branch:** `develop`
- **Secrets:** `*_DEV`
- **Trigger:** Push to develop or manual

### Staging Deployment  
- **Branch:** `main`
- **Secrets:** `*_STAGING`
- **Trigger:** Push to main or manual

### Production Deployment
- **Branch:** `release/*` or tags
- **Secrets:** `*_PROD`  
- **Trigger:** Release branch, tags, or manual

## Debugging Commands

### Check Secret Values (Locally)
```bash
# In your workflow, add debugging (be careful not to expose secrets):
echo "Environment: ${{ needs.validate-environment.outputs.target_environment }}"
echo "Cluster: ${{ needs.validate-environment.outputs.aks_cluster_name }}"
echo "Resource Group: ${{ needs.validate-environment.outputs.aks_resource_group }}"
```

### Verify Azure Resources
```bash
# List all resource groups
az group list --query "[].name" -o table

# List AKS clusters in a resource group
az aks list --resource-group "your-rg" --query "[].{Name:name, Status:powerState.code}" -o table

# Check service principal permissions
az role assignment list --assignee "your-service-principal-id" --query "[].{Role:roleDefinitionName, Scope:scope}" -o table
```

## Quick Fix Checklist

✅ **All required secrets are set with correct names**  
✅ **Secret names match environment detection (DEV/STAGING/PROD)**  
✅ **Azure service principal has AKS access**  
✅ **Resource group names are exact matches**  
✅ **AKS clusters exist in specified resource groups**  
✅ **Branch triggers match environment rules**  

## Related Files

- `.github/workflows/shared-deploy.yml` - Environment validation and secret mapping
- `.github/actions/helm-deploy/action.yml` - AKS authentication and deployment
- Enhanced error messages now provide specific guidance for missing parameters

The AKS deployment process now includes comprehensive validation and clear error messages to help identify and resolve configuration issues quickly.