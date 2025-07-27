# Azure Utility Scripts

This directory contains utility scripts for managing Azure resources and identity verification.

## 📋 Available Scripts

### 1. Azure Identity Check Script (`azure-identity-check.sh`)

Comprehensive script for verifying Azure CLI configuration, identity, and permissions.

#### Features
- **Azure CLI Validation**: Check installation and configuration
- **Identity Information**: Display current user and service principal details
- **Subscription Access**: Verify access to Azure subscriptions
- **Resource Access**: Test access to subscriptions and resource groups
- **Permission Checking**: Display role assignments and permissions
- **Network Connectivity**: Test Azure endpoint connectivity

#### Usage Examples

```bash
# Basic identity check
./azure-identity-check.sh

# Verbose output with detailed information
./azure-identity-check.sh -v

# Check permissions and role assignments
./azure-identity-check.sh -p

# Check access to specific resource group
./azure-identity-check.sh -g myapp-rg

# Comprehensive check with specific subscription
./azure-identity-check.sh --detailed -s subscription-id
```

#### Available Commands
- Basic identity check (default)
- Verbose logging (`-v`)
- Permission checking (`-p`)
- Resource group access testing (`-g`)
- Subscription-specific checks (`-s`)

#### Command Line Options
- `-v, --verbose` - Enable verbose output
- `-p, --check-permissions` - Check detailed permissions and role assignments
- `-g, --resource-group NAME` - Check access to specific resource group
- `-s, --subscription ID` - Check specific subscription
- `--detailed` - Show detailed information for all checks
- `-h, --help` - Show help message

### 2. Deploy Monitoring Script (`deploy-monitoring.sh`)

Script for deploying monitoring stack to AKS clusters.

#### Features
- **Environment Support**: Deploy to dev/staging/production
- **Helm Integration**: Uses Helm charts for deployment
- **Configuration Management**: Environment-specific configurations

#### Usage Examples

```bash
# Deploy monitoring to development
./deploy-monitoring.sh -e dev

# Deploy to production with specific cluster
./deploy-monitoring.sh -e production -c prod-cluster -g prod-rg
```

### 3. Repository Migration Script (`migrate-to-separate-repos.sh`)

Script for migrating monorepo structure to separate repositories.

#### Features
- **App Extraction**: Extract individual applications to separate repos
- **History Preservation**: Maintain git history for each application
- **Configuration Migration**: Move app-specific configurations

## 🔧 Required Permissions

#### For Resource Operations:
- **Contributor** or **Reader** role on target subscriptions
- **Resource Group Contributor** for resource group operations
- Appropriate RBAC permissions for target resources

#### For Identity Verification:
- **Directory Reader** role in Azure AD (for identity information)
- Access to query user and service principal details

## 📚 Usage Examples

### Quick Start

```bash
# Verify your Azure identity and permissions
./scripts/azure-identity-check.sh --detailed

# Deploy monitoring to development environment  
./scripts/deploy-monitoring.sh -e dev
```

### Advanced Usage

```bash
# Check specific resource group access
./scripts/azure-identity-check.sh -p -g myapp-dev-rg

# Comprehensive identity check with verbose output
./scripts/azure-identity-check.sh -v --detailed -s your-subscription-id
```

### Environment-Specific Operations

```bash
# Development environment setup
./scripts/azure-identity-check.sh -g myapp-dev-rg
./scripts/deploy-monitoring.sh -e dev

# Production environment verification
./scripts/azure-identity-check.sh -p -g myapp-prod-rg --detailed
./scripts/deploy-monitoring.sh -e production
```

## 🔒 Security Best Practices

- **Use Azure RBAC**: Assign minimum required permissions
- **Regular Access Reviews**: Periodically verify permissions
- **Service Principals**: Use service principals for automation
- **Audit Logging**: Enable Azure activity logs for monitoring

## 🐛 Troubleshooting

#### Common Issues

#### "Subscription not found or access denied"
```bash
# Check your Azure CLI login
az account show

# List available subscriptions
az account list --output table

# Set correct subscription
az account set --subscription "your-subscription-id"
```

#### "Resource group access denied" 
```bash
# Verify permissions with detailed check
./scripts/azure-identity-check.sh -p -g your-resource-group

# Check role assignments
az role assignment list --assignee $(az account show --query user.name -o tsv) --output table
```

#### Debug Mode
```bash
# Run with debug output
bash -x ./scripts/azure-identity-check.sh -v --detailed
```

## 🚀 CI/CD Integration

These scripts can be integrated into GitHub Actions workflows:

```yaml
- name: Check Azure Identity
  run: |
    ./scripts/azure-identity-check.sh --detailed \
    -g ${{ vars.RESOURCE_GROUP_NAME }}

- name: Deploy Monitoring
  run: |
    ./scripts/deploy-monitoring.sh -e ${{ inputs.environment }}
```

## 📝 Script Output

The identity check script provides comprehensive output about your Azure environment, helping you verify proper setup and permissions for deployment operations.

### Example Output
```
🔍 Azure Identity and Authentication Check
✅ Azure CLI is installed
✅ Successfully logged in to Azure
✅ Current subscription: Production Subscription
✅ Resource Group (myapp-prod-rg): ✅ Accessible
✅ Identity check completed successfully!
```