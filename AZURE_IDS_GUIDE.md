# Azure IDs Reference Guide

## Overview
This guide explains where to find the Azure Tenant ID and Client ID required for Azure Key Vault integration in your GitHub Actions workflows.

## Required Azure IDs

### 1. **Azure Tenant ID** (`azure_tenant_id`)
**What it is:** Unique identifier for your Azure Active Directory (AAD) tenant

### 2. **Azure Client ID** (`azure_client_id`) 
**What it is:** Unique identifier for your Managed Identity or Service Principal that accesses Key Vault

## Where to Find These IDs

### 🔍 **Method 1: Azure Portal (Recommended)**

#### **Finding Azure Tenant ID:**

1. **Go to Azure Portal:** https://portal.azure.com
2. **Navigate to Azure Active Directory:**
   - Click "Azure Active Directory" in the left sidebar
   - OR search "Azure Active Directory" in the top search bar
3. **Find Tenant ID:**
   - In the AAD overview page, look for "Tenant ID"
   - Copy the GUID value (e.g., `12345678-1234-1234-1234-123456789012`)

**Alternative locations in Azure Portal:**
- **Azure Active Directory > Properties > Tenant ID**
- **Any resource > JSON View > tenantId field**
- **Account settings (click your profile) > Directory + subscription**

#### **Finding Azure Client ID (Managed Identity):**

1. **Go to Azure Portal:** https://portal.azure.com
2. **Navigate to Managed Identities:**
   - Search "Managed Identities" in the top search bar
   - OR go to "All services" > "Managed Identities"
3. **Find your Managed Identity:**
   - Look for the managed identity used by your AKS cluster or GitHub Actions
   - Common names: `<cluster-name>-agentpool`, `<app-name>-identity`
4. **Get Client ID:**
   - Click on the managed identity
   - Copy the "Client ID" value (GUID format)

**Alternative: Through AKS cluster:**
1. Go to your **AKS cluster** in Azure Portal
2. Navigate to **Identity** section
3. Find the **System-assigned** or **User-assigned** managed identity
4. Click on the identity to get the Client ID

### 🔍 **Method 2: Azure CLI**

#### **Get Tenant ID:**
```bash
# Get current tenant ID
az account show --query tenantId -o tsv

# List all tenants you have access to
az account tenant list --query '[].tenantId' -o table
```

#### **Get Managed Identity Client ID:**
```bash
# List all managed identities in a resource group
az identity list --resource-group <your-resource-group> --query '[].{Name:name, ClientId:clientId}' -o table

# Get specific managed identity
az identity show --name <identity-name> --resource-group <resource-group> --query clientId -o tsv

# Get AKS cluster managed identity
az aks show --name <cluster-name> --resource-group <resource-group> --query identity.principalId -o tsv
```

#### **Get AKS Cluster Identities:**
```bash
# Get all identities associated with AKS cluster
az aks show --name <cluster-name> --resource-group <resource-group> --query '{SystemAssigned:identity.principalId, UserAssigned:identityProfile}' -o yaml

# For user-assigned identities
az aks show --name <cluster-name> --resource-group <resource-group> --query 'identityProfile.kubeletidentity.clientId' -o tsv
```

### 🔍 **Method 3: PowerShell (Windows)**

#### **Get Tenant ID:**
```powershell
# Connect to Azure
Connect-AzAccount

# Get tenant ID
(Get-AzContext).Tenant.Id

# List all tenants
Get-AzTenant | Select-Object Id, Name
```

#### **Get Managed Identity Client ID:**
```powershell
# Get managed identities in resource group
Get-AzUserAssignedIdentity -ResourceGroupName "<resource-group>" | Select-Object Name, ClientId

# Get specific managed identity
(Get-AzUserAssignedIdentity -ResourceGroupName "<resource-group>" -Name "<identity-name>").ClientId
```

## Common Scenarios and Identity Types

### 🏗️ **For AKS Clusters:**

#### **System-Assigned Managed Identity (Default):**
- **When:** AKS cluster creates its own managed identity
- **Where to find:** AKS cluster > Identity > System assigned
- **Note:** Principal ID and Client ID are the same for system-assigned

#### **User-Assigned Managed Identity:**
- **When:** You create a dedicated managed identity for the cluster
- **Where to find:** Managed Identities > Your custom identity
- **Benefit:** Can be reused across multiple resources

### 🔄 **For GitHub Actions:**

#### **Service Principal (Legacy approach):**
```bash
# Create service principal (if using this approach)
az ad sp create-for-rbac --name "github-actions-sp" --role contributor --scopes /subscriptions/<subscription-id>

# Output includes:
# - appId (This is your Client ID)
# - tenant (This is your Tenant ID)
```

#### **Managed Identity (Recommended):**
- Use the same managed identity that your AKS cluster uses
- More secure as no stored credentials required

## Configuration Examples

### 🔧 **GitHub Repository Secrets:**

Based on the IDs you found, configure these secrets in your GitHub repository:

```yaml
# GitHub Repository Secrets (Settings > Secrets and variables > Actions)
AZURE_TENANT_ID: "12345678-1234-1234-1234-123456789012"    # From Azure AD
AZURE_CLIENT_ID: "87654321-4321-4321-4321-210987654321"    # From Managed Identity
KEYVAULT_NAME: "my-app-prod-kv"                            # Your Key Vault name
```

### 🔧 **Workflow Usage:**
```yaml
- name: Azure Login
  uses: azure/login@v1
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

## Verification Commands

### ✅ **Verify Your Setup:**

```bash
# Verify tenant access
az account show

# Verify managed identity access to Key Vault
az keyvault secret list --vault-name <your-keyvault-name>

# Test Key Vault access with specific identity
az keyvault secret show --vault-name <vault-name> --name <secret-name>
```

### ✅ **Check Permissions:**

```bash
# Check Key Vault access policies
az keyvault show --name <vault-name> --query properties.accessPolicies

# Check RBAC assignments (if using RBAC instead of access policies)
az role assignment list --assignee <client-id> --scope /subscriptions/<subscription-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>
```

## Troubleshooting

### ❌ **Common Issues:**

1. **"Tenant ID not found"**
   - Verify you're logged into the correct Azure subscription
   - Check if you have access to multiple tenants

2. **"Client ID not found"** 
   - Ensure the managed identity exists
   - Verify you're looking in the correct resource group

3. **"Access denied to Key Vault"**
   - Check Key Vault access policies
   - Verify RBAC role assignments
   - Ensure managed identity has proper permissions

### 🔧 **Permission Requirements:**

Your managed identity needs these Key Vault permissions:
```bash
# For reading secrets
az keyvault set-policy --name <vault-name> --object-id <managed-identity-principal-id> --secret-permissions get list

# Or using RBAC (recommended)
az role assignment create --assignee <client-id> --role "Key Vault Secrets User" --scope /subscriptions/<subscription-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>
```

## Quick Reference

| What you need | Where to find | Format |
|---------------|---------------|---------|
| **Tenant ID** | Azure AD > Properties | GUID (36 characters) |
| **Client ID** | Managed Identities > Your identity | GUID (36 characters) |
| **Subscription ID** | Subscriptions > Your subscription | GUID (36 characters) |
| **Key Vault Name** | Key Vaults > Your vault | String (alphanumeric + hyphens) |

## Security Best Practices

1. **✅ Use Managed Identities** instead of Service Principals when possible
2. **✅ Enable RBAC** on Key Vault instead of access policies
3. **✅ Use least privilege** - grant only required permissions
4. **✅ Rotate secrets regularly** in Key Vault
5. **✅ Monitor access** using Azure Monitor and Key Vault logs