# Azure Utility Scripts

This directory contains utility scripts for managing Azure resources, Key Vault secrets, identity verification, deployment verification, and repository migration.

## 📋 Available Scripts

### 1. Health Check Script (`health-check.sh`)

Comprehensive deployment verification script that checks all components and services after deployment.

#### Features
- **Backend Services**: Verify all Java and Node.js backend health endpoints
- **API Testing**: Test REST API endpoints and JSON responses
- **Monitoring Stack**: Check Prometheus, Grafana, AlertManager, and Loki
- **Performance Testing**: Measure response times and identify slow services
- **Infrastructure**: Verify Kubernetes resources, SSL certificates, and DNS
- **Comprehensive Reporting**: Detailed success/failure reporting with exit codes

#### Usage Examples

```bash
# Check dev environment (default)
./health-check.sh

# Check staging environment
./health-check.sh staging

# Check production with verbose output
./health-check.sh production true

# Get help
./health-check.sh --help
```

#### Exit Codes
- `0` - All checks passed (100% success)
- `1` - Some checks failed (≥80% success rate)
- `2` - Many checks failed (<80% success rate)

#### Example Output
```
🚀 Microservices Health Check Tool
Environment: dev
Domain: dev.mydomain.com
=================================================

🏗️ Backend Services Health Check
==================================================
✅ Java Backend 1 (User Management): OK (200, 0.245s)
✅ Java Backend 2 (Product Catalog): OK (200, 0.189s)
✅ Node.js Backend 1 (Notification): OK (200, 0.156s)

📊 Health Check Summary
==================================================
Total Checks: 25
Passed: 25
Failed: 0
Success Rate: 100%

🎉 All checks passed! System is healthy.
```

---

### 2. Repository Migration Script (`migrate-to-separate-repos.sh`)

Automated script to split the monorepo into separate repositories for each backend service with centralized shared workflows.

#### Features
- **Automated Repository Creation**: Creates separate repositories for each backend
- **Shared Workflows Setup**: Creates centralized shared workflows repository
- **Complete Migration**: Copies all source code, Helm charts, and documentation
- **Workflow Updates**: Updates all workflow references to use external shared workflows
- **Documentation Generation**: Creates service-specific README files

#### Usage Examples

```bash
# Migrate to organization 'my-company'
./migrate-to-separate-repos.sh my-company

# Migrate with custom shared workflows repo name
./migrate-to-separate-repos.sh my-company my-shared-workflows

# Get help
./migrate-to-separate-repos.sh
```

#### Created Repositories
- `org/shared-workflows` - Centralized GitHub Actions workflows
- `org/java-backend1-user-management` - User Management Service
- `org/java-backend2-product-catalog` - Product Catalog Service
- `org/java-backend3-order-management` - Order Management Service
- `org/nodejs-backend1-notification` - Notification Service
- `org/nodejs-backend2-analytics` - Analytics Service
- `org/nodejs-backend3-file-management` - File Management Service

---

### 3. Azure Key Vault Setup Script (`azure-keyvault-setup.sh`)

Comprehensive script for managing Azure Key Vault and secrets.

#### Features
- **Setup**: Create new Key Vault with proper permissions
- **Secret Management**: Create, list, get, delete secrets
- **Backup/Restore**: Backup secrets to JSON and restore them
- **Environment Support**: Different secret sets for dev/staging/production
- **Access Testing**: Verify Key Vault permissions and connectivity

#### Usage Examples

```bash
# Create new Key Vault and secrets for development
./azure-keyvault-setup.sh setup -v myapp-kv-dev -g myapp-rg -e dev

# Create secrets in existing Key Vault
./azure-keyvault-setup.sh create-secrets -v myapp-kv-prod -e production

# List all secrets
./azure-keyvault-setup.sh list-secrets -v myapp-kv-dev

# Get specific secret value
./azure-keyvault-setup.sh get-secret -v myapp-kv-dev -n database-password

# Test Key Vault access and permissions
./azure-keyvault-setup.sh test-access -v myapp-kv-dev

# Backup all secrets
./azure-keyvault-setup.sh backup -v myapp-kv-prod -f production-backup.json

# Restore secrets from backup
./azure-keyvault-setup.sh restore -v myapp-kv-staging -f production-backup.json
```

#### Commands
- `setup` - Setup new Key Vault and create initial secrets
- `create-secrets` - Create application secrets in existing Key Vault
- `list-secrets` - List all secrets in Key Vault
- `get-secret` - Get a specific secret value
- `delete-secret` - Delete a specific secret
- `backup` - Backup all secrets to local files
- `restore` - Restore secrets from backup files
- `test-access` - Test access to Key Vault and secrets

#### Options
- `-v, --vault NAME` - Key Vault name (required)
- `-g, --resource-group NAME` - Resource group name (required for setup)
- `-l, --location REGION` - Azure region (default: eastus)
- `-s, --subscription ID` - Subscription ID
- `-e, --environment ENV` - Environment (dev/staging/production, default: dev)
- `-n, --secret-name NAME` - Secret name (for get/delete operations)
- `-f, --file PATH` - File path (for backup/restore operations)

### 2. Azure Identity Check Script (`azure-identity-check.sh`)

Comprehensive script for verifying Azure CLI authentication and permissions.

#### Features
- **Authentication Status**: Check Azure CLI login and token expiration
- **Identity Information**: Display user/service principal details
- **Resource Access**: Test access to subscriptions, resource groups, Key Vaults
- **Permission Verification**: Check role assignments and access policies
- **Network Connectivity**: Test connectivity to Azure endpoints
- **Health Check**: Comprehensive Azure CLI health verification

#### Usage Examples

```bash
# Basic identity check
./azure-identity-check.sh

# Verbose output with detailed information
./azure-identity-check.sh -v

# Check permissions and role assignments
./azure-identity-check.sh -p

# Check access to specific resources
./azure-identity-check.sh -g myapp-rg -k myapp-kv-dev

# Comprehensive check with all details
./azure-identity-check.sh --detailed -s subscription-id

# Check specific subscription
./azure-identity-check.sh -s 12345678-1234-1234-1234-123456789abc
```

#### Options
- `-v, --verbose` - Enable verbose output
- `-p, --check-permissions` - Check detailed permissions and role assignments
- `-g, --resource-group NAME` - Check access to specific resource group
- `-k, --keyvault NAME` - Check access to specific Key Vault
- `-s, --subscription ID` - Check specific subscription
- `--detailed` - Show detailed information for all checks

## 🔧 Prerequisites

### Required Tools
- **Azure CLI**: Version 2.30.0 or later
- **jq**: For JSON parsing (install with `apt-get install jq` or `brew install jq`)
- **curl**: For network connectivity tests
- **openssl**: For password generation

### Azure Authentication
Before using these scripts, ensure you're authenticated to Azure:

```bash
# Login to Azure CLI
az login

# Set default subscription (optional)
az account set --subscription "your-subscription-id"

# Verify login status
az account show
```

### Permissions Required

#### For Key Vault Operations:
- **Key Vault Contributor** or **Owner** role on the resource group
- **Key Vault Administrator** or specific access policies for secrets

#### For Identity Checks:
- **Reader** role on subscription (minimum)
- **User Access Administrator** role (for permission checks)

## 🚀 Quick Start

### 1. Setup Development Environment

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Create development Key Vault
./scripts/azure-keyvault-setup.sh setup \
  -v myapp-kv-dev \
  -g myapp-rg \
  -l eastus \
  -e dev

# Verify identity and access
./scripts/azure-identity-check.sh -v -g myapp-rg -k myapp-kv-dev
```

### 2. Setup Production Environment

```bash
# Create production Key Vault with stronger secrets
./scripts/azure-keyvault-setup.sh setup \
  -v myapp-kv-prod \
  -g myapp-prod-rg \
  -l eastus \
  -e production

# Test production access
./scripts/azure-keyvault-setup.sh test-access -v myapp-kv-prod
```

### 3. Backup and Migration

```bash
# Backup production secrets
./scripts/azure-keyvault-setup.sh backup \
  -v myapp-kv-prod \
  -f "prod-backup-$(date +%Y%m%d).json"

# Restore to staging for testing
./scripts/azure-keyvault-setup.sh restore \
  -v myapp-kv-staging \
  -f "prod-backup-$(date +%Y%m%d).json"
```

## 📊 Environment-Specific Secrets

The Key Vault setup script creates different secret sets based on environment:

### Development Environment (`-e dev`)
- Basic database and Redis connections
- Simple API keys and tokens
- Development SMTP settings

### Staging Environment (`-e staging`)
- Enhanced security with longer passwords
- Monitoring tokens
- Staging-specific API endpoints

### Production Environment (`-e production`)
- Maximum security with 32-48 character passwords
- Backup encryption keys
- Production monitoring and alerting tokens
- Internal DNS endpoints

## 🔒 Security Best Practices

1. **Access Control**:
   - Use Azure RBAC for Key Vault access
   - Implement least privilege principle
   - Regular access reviews

2. **Secret Management**:
   - Rotate secrets regularly
   - Use different secrets per environment
   - Monitor secret access logs

3. **Backup and Recovery**:
   - Regular automated backups
   - Encrypted backup storage
   - Tested recovery procedures

4. **Monitoring**:
   - Enable Key Vault logging
   - Set up alerts for unusual access
   - Monitor token expiration

## 🛠️ Troubleshooting

### Common Issues

#### "Not logged in to Azure CLI"
```bash
# Solution: Login to Azure
az login
# For service principal
az login --service-principal -u <app-id> -p <password> --tenant <tenant>
```

#### "Key Vault not found or access denied"
```bash
# Check permissions
./scripts/azure-identity-check.sh -p -k your-keyvault-name

# Verify Key Vault exists
az keyvault list --query "[?name=='your-keyvault-name']"
```

#### "Cannot create secrets"
```bash
# Check access policies
az keyvault show --name your-keyvault-name --query properties.accessPolicies

# Set access policy
az keyvault set-policy --name your-keyvault-name --upn your-email@domain.com --secret-permissions get list set delete
```

#### "Token expired"
```bash
# Refresh token
az account get-access-token --query accessToken -o tsv

# Re-login if needed
az login
```

### Debug Mode

Run scripts with bash debug mode for detailed troubleshooting:

```bash
# Enable debug output
bash -x ./scripts/azure-keyvault-setup.sh test-access -v your-keyvault-name

# Check specific functions
bash -x ./scripts/azure-identity-check.sh --detailed
```

## 📚 Integration with CI/CD

These scripts are designed to work with the CI/CD workflows in this repository:

### GitHub Actions Integration

```yaml
- name: Setup Azure Key Vault
  run: |
    ./scripts/azure-keyvault-setup.sh setup \
      -v ${{ vars.KEYVAULT_NAME }} \
      -g ${{ vars.RESOURCE_GROUP }} \
      -e ${{ vars.ENVIRONMENT }}

- name: Verify Azure Identity
  run: |
    ./scripts/azure-identity-check.sh \
      -g ${{ vars.RESOURCE_GROUP }} \
      -k ${{ vars.KEYVAULT_NAME }}
```

### Helm Chart Integration

The secrets created by these scripts are automatically used by the Helm charts when Azure Key Vault integration is enabled.

## 📄 Output Examples

### Key Vault Setup Output
```
🔍 Setting up Azure Key Vault: myapp-kv-dev
✅ Azure CLI authenticated as: user@domain.com
✅ Key Vault created: myapp-kv-dev
✅ Access policy configured
ℹ️  Creating application secrets for environment: dev
✅ Created: spring-datasource-password
✅ Created: jwt-secret
✅ All secrets created successfully
```

### Identity Check Output
```
🔍 Azure Identity and Authentication Check
✅ Azure CLI is installed
✅ Logged in to Azure CLI
User: user@domain.com
Type: user
Tenant: 12345678-1234-1234-1234-123456789abc
Subscription: My Subscription
✅ Can list resource groups
✅ Can access Key Vault: myapp-kv-dev
✅ All access tests completed successfully!
```

## 🤝 Contributing

1. Test scripts thoroughly before committing
2. Update documentation for new features
3. Follow existing code style and patterns
4. Add appropriate error handling
5. Include usage examples for new commands