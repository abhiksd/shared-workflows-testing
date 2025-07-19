# Secret Inheritance and Dynamic Fetching Approach

## Overview

This document explains the enhanced secret inheritance approach implemented for AKS deployments. Instead of using a JSON configuration, this approach uses GitHub Actions' `secrets: inherit` feature combined with dynamic secret fetching based on the target environment.

## How It Works

### 1. **Secret Inheritance Flow**
```
Caller Workflow → secrets: inherit → Shared Workflow → Dynamic Fetching → Helm Deploy Action
```

### 2. **OIDC Authentication Setup**
All workflows require specific permissions for Azure OIDC authentication:
```yaml
permissions:
  id-token: write      # Required for OIDC token generation
  contents: read       # Required for repository access
  actions: read        # Required for workflow execution
```

### 3. **Dynamic Secret Fetching**
The `validate-environment` job in the shared workflow dynamically fetches the appropriate AKS secrets based on the detected or specified environment:

```bash
case "$TARGET_ENV" in
  "dev")
    AKS_CLUSTER="${{ secrets.AKS_CLUSTER_NAME_DEV }}"
    AKS_RG="${{ secrets.AKS_RESOURCE_GROUP_DEV }}"
    ;;
  "staging")
    AKS_CLUSTER="${{ secrets.AKS_CLUSTER_NAME_STAGING }}"
    AKS_RG="${{ secrets.AKS_RESOURCE_GROUP_STAGING }}"
    ;;
  "production")
    AKS_CLUSTER="${{ secrets.AKS_CLUSTER_NAME_PROD }}"
    AKS_RG="${{ secrets.AKS_RESOURCE_GROUP_PROD }}"
    ;;
esac
```

### 4. **Enhanced Logging and Context Passing**
- Comprehensive logging throughout the deployment pipeline
- Deployment context creation and passing between jobs
- Environment-specific deployment information
- Enhanced error handling and debugging

## Implementation Details

### Caller Workflows (Java & Node.js)
```yaml
name: Deploy Java Spring Boot Application

# Required permissions for OIDC authentication with Azure
permissions:
  id-token: write
  contents: read
  actions: read

jobs:
  deploy:
    uses: ./.github/workflows/shared-deploy.yml
    with:
      environment: ${{ github.event.inputs.environment || 'auto' }}
      application_name: java-app
      application_type: java-springboot
      # ... other inputs
    secrets: inherit # All secrets are inherited automatically
```

### Shared Workflow
```yaml
name: Shared AKS Deployment Workflow

# Required permissions for OIDC authentication with Azure
permissions:
  id-token: write
  contents: read
  actions: read

secrets:
  # Core Azure secrets
  ACR_LOGIN_SERVER:
    required: true
  AZURE_TENANT_ID:
    required: true
  AZURE_CLIENT_ID:
    required: true
  AZURE_SUBSCRIPTION_ID:
    required: true
  KEYVAULT_NAME:
    required: true
  
  # Environment-specific AKS secrets - inherited dynamically
  AKS_CLUSTER_NAME_DEV:
    required: false
  AKS_RESOURCE_GROUP_DEV:
    required: false
  AKS_CLUSTER_NAME_STAGING:
    required: false
  AKS_RESOURCE_GROUP_STAGING:
    required: false
  AKS_CLUSTER_NAME_PROD:
    required: false
  AKS_RESOURCE_GROUP_PROD:
    required: false
```

### Helm Deploy Action
- Receives dynamically fetched AKS configuration
- Gets deployment context with enhanced metadata
- Provides comprehensive logging throughout deployment

## Required Setup

### 1. Azure OIDC Configuration
Before using these workflows, ensure you have set up OIDC authentication between GitHub and Azure:

1. **Create Azure AD App Registration**
2. **Configure Federated Credentials** for your GitHub repository
3. **Assign appropriate Azure permissions** to the service principal

For detailed setup instructions, see: [Azure Login Action Documentation](https://github.com/Azure/login#configure-a-service-principal-with-a-federated-credential-to-use-oidc-based-authentication)

### 2. Repository Secrets
Set these secrets in your GitHub repository settings:

#### Core Azure Secrets
- `ACR_LOGIN_SERVER`: Azure Container Registry URL
- `AZURE_TENANT_ID`: Azure AD Tenant ID  
- `AZURE_CLIENT_ID`: Service Principal Client ID (App Registration)
- `AZURE_SUBSCRIPTION_ID`: Azure Subscription ID
- `KEYVAULT_NAME`: Azure Key Vault name

#### Environment-Specific AKS Secrets
- `AKS_CLUSTER_NAME_DEV`: Development AKS cluster name
- `AKS_RESOURCE_GROUP_DEV`: Development resource group
- `AKS_CLUSTER_NAME_STAGING`: Staging AKS cluster name
- `AKS_RESOURCE_GROUP_STAGING`: Staging resource group
- `AKS_CLUSTER_NAME_PROD`: Production AKS cluster name
- `AKS_RESOURCE_GROUP_PROD`: Production resource group

### 3. Workflow Permissions
Ensure all workflows have the required permissions:
```yaml
permissions:
  id-token: write      # Critical for Azure OIDC authentication
  contents: read       # Required for repository access
  actions: read        # Required for workflow execution
```

## Enhanced Logging Features

### Environment Validation Phase
```
🚀 Starting enhanced environment validation and AKS configuration
==================================================================
📝 Input Parameters:
   - Environment: staging
   - Application: my-app
   - Application Type: java-springboot
   - GitHub Ref: refs/heads/main
   - Event: push
   - Force Deploy: false

🔧 Dynamically fetching AKS configuration for environment: staging
   🎭 Staging Environment Configuration:
      - Purpose: Pre-production testing
      - Monitoring: Enhanced logging and monitoring
   ✅ AKS Configuration retrieved:
      - Cluster: my-staging-cluster
      - Resource Group: my-staging-rg

🛡️ Validating deployment rules...
   ✅ Staging deployment approved: main branch or manual trigger

📊 Final validation and configuration results:
==================================================================
   🎯 Target Environment: staging
   🚦 Should Deploy: true
   🏗️ AKS Cluster: my-staging-cluster
   📂 AKS Resource Group: my-staging-rg
   📋 Deployment Context: {"timestamp":"2024-01-15T10:30:00Z",...}
```

### Helm Deployment Phase
```
🚀 Helm Deployment Action Started with Enhanced Logging
========================================================
📋 Inherited Deployment Context:
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
  "forceDeploy": false,
  "workflowRun": "123456789",
  "gitSha": "abc123def456"
}

🎯 Deployment Session Information:
   - Application: my-app
   - Environment: staging
   - Initiated: 2024-01-15T10:30:00Z
   - Workflow Run: 123456789
   - Git SHA: abc123def456
```

## Benefits of This Approach

### 1. **Simplified Secret Management**
- Uses standard GitHub Actions secret inheritance
- No need for complex JSON configurations
- Familiar secret naming conventions

### 2. **Enhanced Debugging**
- Comprehensive logging with emojis and structure
- Deployment context tracking throughout pipeline
- Environment-specific deployment information
- Clear error messages with actionable guidance

### 3. **Flexible Configuration**
- Easy to add new environments
- Supports existing secret naming conventions
- Backward compatible with current setups

### 4. **Better Error Handling**
- Dynamic validation of secret availability
- Clear indication of missing configuration
- Environment-specific error messages

### 5. **Rich Deployment Context**
- Full deployment metadata tracking
- Enhanced Helm values with deployment information
- Comprehensive deployment summaries

## Environment-Specific Features

### Development Environment
```
🧪 Development Environment Configuration:
   - Purpose: Testing and development
   - Monitoring: Basic logging enabled

🧪 Development deployment completed successfully!
   - Quick iteration and testing enabled
   - Auto-scaling and monitoring configured
```

### Staging Environment
```
🎭 Staging Environment Configuration:
   - Purpose: Pre-production testing
   - Monitoring: Enhanced logging and monitoring

🎭 Staging deployment completed successfully!
   - Pre-production validation environment ready
   - Enhanced monitoring and alerting active
```

### Production Environment
```
🏭 Production Environment Configuration:
   - Purpose: Live production workload
   - Monitoring: Full observability stack

🏭 Production deployment completed successfully!
   - Live workload deployment complete
   - Full SLA monitoring and alerting active
```

## Deployment Context Schema

The deployment context passed between jobs includes:

```json
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
  "forceDeploy": false,
  "workflowRun": "123456789",
  "gitSha": "abc123def456"
}
```

## Troubleshooting

### Common Issues

#### 1. OIDC Authentication Errors
**Error**: `Failed to fetch federated token from GitHub`
**Solution**: 
- Ensure `id-token: write` permission is set in workflow
- Verify Azure OIDC configuration is correct
- Check that `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, and `AZURE_SUBSCRIPTION_ID` are set

**Error**: `Unable to get ACTIONS_ID_TOKEN_REQUEST_URL env variable`
**Solution**: Add the required permissions block to your workflow:
```yaml
permissions:
  id-token: write
  contents: read  
  actions: read
```

#### 2. Missing AKS Secrets
**Error**: `AKS cluster name is empty for environment 'dev'`
**Solution**: Ensure `AKS_CLUSTER_NAME_DEV` and `AKS_RESOURCE_GROUP_DEV` secrets are configured

#### 3. Secret Inheritance Not Working
**Error**: Parameter validation failed
**Solution**: Verify that caller workflow uses `secrets: inherit`

#### 4. Environment Detection Issues
**Error**: Auto environment detection failed
**Solution**: Check branch naming and deployment rules

### Debug Information

The enhanced logging provides comprehensive debug information:
- OIDC authentication status
- Parameter validation results
- Secret availability status
- Environment detection logic
- AKS cluster connectivity tests
- Deployment context details

## Migration from Previous Approaches

### From Individual Secret Passing
If you were previously passing secrets individually:
```yaml
# Old approach
secrets:
  ACR_LOGIN_SERVER: ${{ secrets.ACR_LOGIN_SERVER }}
  AKS_CLUSTER_NAME_DEV: ${{ secrets.AKS_CLUSTER_NAME_DEV }}
  # ... many more secrets

# New approach
secrets: inherit
```

### From JSON Configuration
If you were using JSON-based configuration, simply:
1. Keep your existing environment-specific secrets
2. Update caller workflows to use `secrets: inherit`
3. Remove any JSON configuration secrets

## Best Practices

### 1. **Secret Naming**
- Use consistent naming: `AKS_CLUSTER_NAME_{ENV}` and `AKS_RESOURCE_GROUP_{ENV}`
- Environment suffixes: `DEV`, `STAGING`, `PROD`

### 2. **Environment Management**
- Use automatic environment detection when possible
- Provide manual override through workflow dispatch

### 3. **Monitoring**
- Review deployment logs for comprehensive information
- Use deployment context for tracking and debugging

### 4. **Security**
- Keep environment-specific secrets separate
- Use least privilege access for service principals
- Regularly rotate secrets

## Future Enhancements

The secret inheritance approach enables:
- Additional environment types (e.g., UAT, TEST)
- Custom deployment parameters per environment
- Enhanced monitoring and alerting configurations
- Integration with external configuration management systems

This approach provides the best balance of simplicity, security, and observability for AKS deployments across multiple environments.