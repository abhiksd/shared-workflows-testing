# Azure Key Vault Integration Setup Guide

This guide explains how to set up and use Azure Key Vault integration with your Helm charts for secure secrets management in AKS.

## Prerequisites

1. **Azure Key Vault** with secrets stored
2. **AKS cluster** with CSI Secrets Store driver installed
3. **Azure Managed Identity** with Key Vault access
4. **GitHub repository secrets** configured

## Architecture Overview

```
GitHub Actions → Azure Key Vault → AKS Secrets Store CSI → Pod Volume Mount
```

The integration works by:
1. GitHub Actions injects Key Vault configuration into Helm values
2. Helm creates SecretProviderClass resources
3. CSI Secrets Store driver mounts secrets from Azure Key Vault
4. Applications read secrets from mounted files

## Setup Steps

### 1. Azure Key Vault Setup

Create secrets in your Azure Key Vault:

```bash
# Example secrets for Java application
az keyvault secret set --vault-name "java-app-prod-kv" --name "db-password" --value "your-db-password"
az keyvault secret set --vault-name "java-app-prod-kv" --name "api-key" --value "your-api-key"
az keyvault secret set --vault-name "java-app-prod-kv" --name "jwt-secret" --value "your-jwt-secret"
az keyvault secret set --vault-name "java-app-prod-kv" --name "redis-password" --value "your-redis-password"

# Example secrets for Node.js application
az keyvault secret set --vault-name "nodejs-app-prod-kv" --name "db-connection-string" --value "your-connection-string"
az keyvault secret set --vault-name "nodejs-app-prod-kv" --name "api-key" --value "your-api-key"
az keyvault secret set --vault-name "nodejs-app-prod-kv" --name "session-secret" --value "your-session-secret"
az keyvault secret set --vault-name "nodejs-app-prod-kv" --name "redis-url" --value "your-redis-url"
```

### 2. AKS Cluster Setup

Install the Azure Key Vault Provider for Secrets Store CSI driver:

```bash
# Enable the add-on
az aks enable-addons --addons azure-keyvault-secrets-provider --name myAKSCluster --resource-group myResourceGroup

# Verify installation
kubectl get pods -n kube-system | grep secrets-store
```

### 3. Azure Managed Identity Setup

Create a managed identity and assign Key Vault permissions:

```bash
# Create managed identity
az identity create --name myAKSKeyVaultIdentity --resource-group myResourceGroup

# Get the identity details
IDENTITY_CLIENT_ID=$(az identity show --name myAKSKeyVaultIdentity --resource-group myResourceGroup --query clientId -o tsv)
IDENTITY_OBJECT_ID=$(az identity show --name myAKSKeyVaultIdentity --resource-group myResourceGroup --query principalId -o tsv)

# Assign Key Vault permissions
az keyvault set-policy --name myKeyVault --object-id $IDENTITY_OBJECT_ID --secret-permissions get list

# Associate identity with AKS cluster
az aks pod-identity add --resource-group myResourceGroup --cluster-name myAKSCluster --namespace default --name myAKSKeyVaultIdentity --identity-resource-id /subscriptions/SUBSCRIPTION_ID/resourcegroups/myResourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/myAKSKeyVaultIdentity
```

### 4. GitHub Repository Secrets

Configure the following secrets in your GitHub repository:

- `AZURE_TENANT_ID`: Your Azure tenant ID
- `AZURE_CLIENT_ID`: The client ID of your managed identity
- `KEYVAULT_NAME`: Name of your Azure Key Vault

## Configuration

### Helm Values Configuration

Enable Azure Key Vault in your environment-specific values files:

#### Production Configuration (`values-production.yaml`)

```yaml
azureKeyVault:
  enabled: true
  keyvaultName: "java-app-prod-kv"  # Will be overridden by GitHub Actions
  tenantId: ""  # Will be injected by GitHub Actions
  userAssignedIdentityID: ""  # Will be injected by GitHub Actions
  mountPath: "/mnt/secrets-store"
  secrets:
    - objectName: "db-password"
      objectAlias: "db-password"
    - objectName: "api-key"
      objectAlias: "api-key"
    - objectName: "jwt-secret"
      objectAlias: "jwt-secret"
    - objectName: "redis-password"
      objectAlias: "redis-password"
  secretObjects:
    - secretName: "app-secrets"
      type: "Opaque"
      data:
        - objectName: "db-password"
          key: "db-password"
        - objectName: "api-key"
          key: "api-key"
        - objectName: "jwt-secret"
          key: "jwt-secret"
        - objectName: "redis-password"
          key: "redis-password"
```

### Application Usage

#### Java Spring Boot Application

Read secrets from mounted files:

```java
@Value("${secrets.mount.path:/mnt/secrets-store}")
private String secretsMountPath;

public String getDatabasePassword() {
    try {
        return Files.readString(Paths.get(secretsMountPath, "db-password"));
    } catch (IOException e) {
        throw new RuntimeException("Failed to read database password", e);
    }
}
```

Or use Kubernetes secrets (created by secretObjects):

```yaml
# application.yaml
spring:
  datasource:
    password: ${DB_PASSWORD}
```

```yaml
# In your deployment, add environment variables:
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: app-secrets
        key: db-password
```

#### Node.js Application

Read secrets from mounted files:

```javascript
const fs = require('fs').promises;
const path = require('path');

const SECRETS_PATH = process.env.SECRETS_MOUNT_PATH || '/mnt/secrets-store';

async function getSecret(secretName) {
    try {
        const secretPath = path.join(SECRETS_PATH, secretName);
        const secret = await fs.readFile(secretPath, 'utf8');
        return secret.trim();
    } catch (error) {
        throw new Error(`Failed to read secret ${secretName}: ${error.message}`);
    }
}

// Usage
const dbConnectionString = await getSecret('db-connection-string');
```

## Deployment

The Azure Key Vault integration is automatically handled by GitHub Actions when:

1. Azure Key Vault is enabled in your values files
2. Required GitHub secrets are configured
3. The deployment workflow runs

The workflow will:
- Inject Azure tenant ID, client ID, and Key Vault name into Helm values
- Deploy the SecretProviderClass and application
- Mount secrets from Azure Key Vault into your pods

## Troubleshooting

### Check SecretProviderClass

```bash
kubectl get secretproviderclass -n your-namespace
kubectl describe secretproviderclass your-app-keyvault -n your-namespace
```

### Check Pod Events

```bash
kubectl describe pod your-pod -n your-namespace
```

### Check Secrets Store CSI Driver Logs

```bash
kubectl logs -n kube-system -l app=secrets-store-csi-driver
```

### Verify Secret Mount

```bash
kubectl exec -it your-pod -n your-namespace -- ls -la /mnt/secrets-store/
kubectl exec -it your-pod -n your-namespace -- cat /mnt/secrets-store/db-password
```

### Common Issues

1. **Permission Denied**: Ensure the managed identity has proper Key Vault permissions
2. **Mount Failures**: Check if the CSI driver is properly installed and running
3. **Secret Not Found**: Verify secret names match between Key Vault and configuration
4. **Authentication Failures**: Ensure the correct tenant ID and client ID are configured

## Security Best Practices

1. **Least Privilege**: Grant minimum required Key Vault permissions
2. **Network Security**: Use private endpoints for Key Vault when possible
3. **Secret Rotation**: Implement regular secret rotation policies
4. **Monitoring**: Enable Key Vault audit logging
5. **Environment Separation**: Use separate Key Vaults for different environments

## Example Deployment Commands

Manual deployment with Key Vault enabled:

```bash
helm upgrade --install my-java-app ./helm/java-app \
  --namespace production \
  --values ./helm/java-app/values-production.yaml \
  --set azureKeyVault.tenantId="your-tenant-id" \
  --set azureKeyVault.userAssignedIdentityID="your-client-id" \
  --set azureKeyVault.keyvaultName="java-app-prod-kv"
```