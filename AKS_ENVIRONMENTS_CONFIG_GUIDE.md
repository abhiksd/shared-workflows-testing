# AKS Environments Configuration Guide

## Overview

This guide explains the new dynamic AKS configuration approach that replaces the previous environment-specific secrets with a single JSON-based configuration secret. This change improves maintainability, reduces secret proliferation, and provides better logging and debugging capabilities.

## Migration from Environment-Specific Secrets

### Previous Approach (Deprecated)
```yaml
# Old secret configuration - NO LONGER USED
AKS_CLUSTER_NAME_DEV: "my-dev-cluster"
AKS_RESOURCE_GROUP_DEV: "my-dev-rg"
AKS_CLUSTER_NAME_STAGING: "my-staging-cluster"
AKS_RESOURCE_GROUP_STAGING: "my-staging-rg"
AKS_CLUSTER_NAME_PROD: "my-prod-cluster"
AKS_RESOURCE_GROUP_PROD: "my-prod-rg"
```

### New Approach (Current)
```yaml
# Single secret with JSON configuration
AKS_ENVIRONMENTS_CONFIG: |
  {
    "dev": {
      "cluster": "my-dev-cluster",
      "resourceGroup": "my-dev-rg"
    },
    "staging": {
      "cluster": "my-staging-cluster", 
      "resourceGroup": "my-staging-rg"
    },
    "production": {
      "cluster": "my-prod-cluster",
      "resourceGroup": "my-prod-rg"
    }
  }
```

## Configuration Format

### JSON Schema
```json
{
  "environment_name": {
    "cluster": "aks-cluster-name",
    "resourceGroup": "resource-group-name"
  }
}
```

### Required Fields
- **cluster**: The name of the AKS cluster for the environment
- **resourceGroup**: The Azure resource group containing the AKS cluster

### Supported Environments
- `dev`: Development environment
- `staging`: Staging/pre-production environment  
- `production`: Production environment

## Setting Up the Secret

### GitHub Repository Secrets
1. Navigate to your repository's **Settings** → **Secrets and variables** → **Actions**
2. Create a new repository secret named `AKS_ENVIRONMENTS_CONFIG`
3. Set the value to your JSON configuration (see examples below)

### Example Configurations

#### Basic Configuration
```json
{
  "dev": {
    "cluster": "contoso-dev-aks",
    "resourceGroup": "contoso-dev-rg"
  },
  "staging": {
    "cluster": "contoso-staging-aks",
    "resourceGroup": "contoso-staging-rg"
  },
  "production": {
    "cluster": "contoso-prod-aks",
    "resourceGroup": "contoso-prod-rg"
  }
}
```

#### Multi-Region Configuration
```json
{
  "dev": {
    "cluster": "contoso-dev-eastus-aks",
    "resourceGroup": "contoso-dev-eastus-rg"
  },
  "staging": {
    "cluster": "contoso-staging-westus2-aks",
    "resourceGroup": "contoso-staging-westus2-rg"
  },
  "production": {
    "cluster": "contoso-prod-centralus-aks",
    "resourceGroup": "contoso-prod-centralus-rg"
  }
}
```

#### Organization with Naming Conventions
```json
{
  "dev": {
    "cluster": "org-myapp-dev-aks-001",
    "resourceGroup": "rg-org-myapp-dev-001"
  },
  "staging": {
    "cluster": "org-myapp-stage-aks-001", 
    "resourceGroup": "rg-org-myapp-stage-001"
  },
  "production": {
    "cluster": "org-myapp-prod-aks-001",
    "resourceGroup": "rg-org-myapp-prod-001"
  }
}
```

## Benefits of the New Approach

### 1. **Centralized Configuration**
- Single source of truth for all environment configurations
- Easier to maintain and update cluster information
- Reduced number of secrets to manage

### 2. **Enhanced Logging and Debugging**
- Comprehensive logging during environment validation
- Clear error messages when configuration is missing or invalid
- Deployment context tracking throughout the pipeline

### 3. **Improved Flexibility**
- Easy to add new environments without code changes
- Supports complex naming conventions and multi-region deployments
- JSON format allows for future extensibility

### 4. **Better Error Handling**
- Validates JSON format and required fields
- Lists available environments when errors occur
- Fails fast with clear error messages

### 5. **Security Benefits**
- Reduces secret sprawl in GitHub repository
- Easier to audit and rotate credentials
- Centralized access control

## Enhanced Logging Features

The new implementation provides comprehensive logging throughout the deployment process:

### Environment Validation Phase
```
🚀 Starting environment validation and AKS configuration setup
===============================================================
📝 Input Parameters:
   - Environment: staging
   - Application: my-app
   - Application Type: java-springboot
   - GitHub Ref: refs/heads/main
   - Event: push
   - Force Deploy: false

🔧 Parsing AKS environments configuration...
   📄 AKS Config received (length: 387 characters)
   🔎 Extracting configuration for environment: staging
   ✅ AKS Configuration found:
      - Cluster: my-staging-cluster
      - Resource Group: my-staging-rg

🛡️ Validating deployment rules...
   ✅ Staging deployment approved: main branch or manual trigger

📊 Final validation results:
===============================================================
   🎯 Target Environment: staging
   🚦 Should Deploy: true
   🏗️ AKS Cluster: my-staging-cluster
   📂 AKS Resource Group: my-staging-rg
   📋 Deployment Context: {"timestamp":"2024-01-15T10:30:00Z",...}
```

### Helm Deployment Phase
```
🚀 Helm Deployment Action Started
===============================================================
📋 Deployment Context:
{
  "timestamp": "2024-01-15T10:30:00Z",
  "environment": "staging",
  "application": "my-app",
  "applicationType": "java-springboot",
  "branch": "refs/heads/main",
  "event": "push",
  "shouldDeploy": true,
  "aksCluster": "my-staging-cluster",
  "aksResourceGroup": "my-staging-rg",
  "forceDeploy": false
}

🎯 Deployment initiated for:
   - Application: my-app
   - Environment: staging
   - Timestamp: 2024-01-15T10:30:00Z
```

## Troubleshooting

### Common Issues

#### 1. Invalid JSON Format
**Error**: `parse error: Invalid JSON at line X`
**Solution**: Validate your JSON using a JSON validator before setting the secret

#### 2. Missing Environment Configuration
**Error**: `No AKS cluster configured for environment 'dev'`
**Solution**: Ensure your JSON includes the required environment with proper field names

#### 3. Empty or Missing Secret
**Error**: `AKS_ENVIRONMENTS_CONFIG secret is empty or not set`
**Solution**: Create the secret in your repository settings with proper JSON content

### Validation Commands

To validate your JSON configuration locally:

```bash
# Validate JSON syntax
echo '{"dev":{"cluster":"test","resourceGroup":"test-rg"}}' | jq '.'

# Extract specific environment
echo '{"dev":{"cluster":"test","resourceGroup":"test-rg"}}' | jq '.dev.cluster'
```

## Migration Steps

### 1. Create the New Secret
1. Prepare your JSON configuration using the examples above
2. Add the `AKS_ENVIRONMENTS_CONFIG` secret to your repository
3. Validate the JSON format

### 2. Update Workflow Files
The workflow files have been updated to use the new secret format. No manual changes needed if using the provided templates.

### 3. Remove Old Secrets (Optional)
After successful deployment with the new configuration, you can remove the old environment-specific secrets:
- `AKS_CLUSTER_NAME_DEV`
- `AKS_RESOURCE_GROUP_DEV`
- `AKS_CLUSTER_NAME_STAGING`
- `AKS_RESOURCE_GROUP_STAGING`
- `AKS_CLUSTER_NAME_PROD`
- `AKS_RESOURCE_GROUP_PROD`

### 4. Test Deployments
Run deployments for each environment to ensure the new configuration works correctly.

## Advanced Configuration

### Adding Custom Environments
You can add custom environments by extending the JSON:

```json
{
  "dev": {
    "cluster": "contoso-dev-aks",
    "resourceGroup": "contoso-dev-rg"
  },
  "test": {
    "cluster": "contoso-test-aks",
    "resourceGroup": "contoso-test-rg"
  },
  "uat": {
    "cluster": "contoso-uat-aks", 
    "resourceGroup": "contoso-uat-rg"
  },
  "production": {
    "cluster": "contoso-prod-aks",
    "resourceGroup": "contoso-prod-rg"
  }
}
```

### Future Extensibility
The JSON format supports future enhancements such as:
- Region-specific configurations
- Environment-specific resource quotas
- Custom deployment parameters
- Integration with multiple cloud providers

## Support

For issues or questions related to the AKS environments configuration:
1. Check the deployment logs for detailed error messages
2. Validate your JSON configuration syntax
3. Ensure all required Azure permissions are in place
4. Review the troubleshooting section above

The enhanced logging provides comprehensive information to help diagnose and resolve configuration issues quickly.