#!/bin/bash

# Azure Key Vault Secrets Management Script
# This script helps create, manage, and verify Azure Key Vault secrets
# Usage: ./azure-keyvault-setup.sh [command] [options]

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
KEYVAULT_NAME=""
RESOURCE_GROUP=""
LOCATION="eastus"
SUBSCRIPTION_ID=""
ENVIRONMENT="dev"

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to display usage
usage() {
    cat << EOF
Azure Key Vault Secrets Management Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    setup           Setup new Key Vault and create initial secrets
    create-secrets  Create application secrets in existing Key Vault
    list-secrets    List all secrets in Key Vault
    get-secret      Get a specific secret value
    delete-secret   Delete a specific secret
    backup          Backup all secrets to local files
    restore         Restore secrets from backup files
    test-access     Test access to Key Vault and secrets
    help            Show this help message

Options:
    -v, --vault NAME        Key Vault name (required)
    -g, --resource-group    Resource group name (required for setup)
    -l, --location          Azure region (default: eastus)
    -s, --subscription      Subscription ID
    -e, --environment       Environment (dev/staging/production, default: dev)
    -n, --secret-name       Secret name (for get/delete operations)
    -f, --file              File path (for backup/restore operations)
    --dry-run               Show what would be done without executing

Examples:
    $0 setup -v myapp-kv-dev -g myapp-rg -l eastus -e dev
    $0 create-secrets -v myapp-kv-dev -e dev
    $0 list-secrets -v myapp-kv-dev
    $0 get-secret -v myapp-kv-dev -n database-password
    $0 test-access -v myapp-kv-dev

EOF
}

# Function to validate Azure CLI installation and login
check_azure_cli() {
    print_info "Checking Azure CLI installation and authentication..."
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        print_info "Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # Check if logged in
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure CLI. Please run: az login"
        exit 1
    fi
    
    local current_user=$(az account show --query user.name -o tsv 2>/dev/null || echo "Unknown")
    local current_subscription=$(az account show --query name -o tsv 2>/dev/null || echo "Unknown")
    
    print_success "Azure CLI authenticated as: $current_user"
    print_info "Current subscription: $current_subscription"
    
    # Set subscription if provided
    if [[ -n "$SUBSCRIPTION_ID" ]]; then
        print_info "Setting subscription to: $SUBSCRIPTION_ID"
        az account set --subscription "$SUBSCRIPTION_ID"
    fi
}

# Function to check if Key Vault exists
check_keyvault_exists() {
    local vault_name="$1"
    if az keyvault show --name "$vault_name" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to setup Key Vault
setup_keyvault() {
    print_info "Setting up Azure Key Vault: $KEYVAULT_NAME"
    
    if [[ -z "$RESOURCE_GROUP" ]]; then
        print_error "Resource group is required for setup"
        exit 1
    fi
    
    # Check if resource group exists
    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        print_warning "Resource group '$RESOURCE_GROUP' does not exist. Creating it..."
        az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
        print_success "Resource group created: $RESOURCE_GROUP"
    fi
    
    # Check if Key Vault already exists
    if check_keyvault_exists "$KEYVAULT_NAME"; then
        print_warning "Key Vault '$KEYVAULT_NAME' already exists"
    else
        print_info "Creating Key Vault: $KEYVAULT_NAME"
        az keyvault create \
            --name "$KEYVAULT_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --enabled-for-deployment true \
            --enabled-for-template-deployment true \
            --enabled-for-disk-encryption true \
            --enable-rbac-authorization false \
            --sku standard
        
        print_success "Key Vault created: $KEYVAULT_NAME"
    fi
    
    # Set access policy for current user
    local current_user_id=$(az ad signed-in-user show --query id -o tsv)
    print_info "Setting access policy for current user..."
    
    az keyvault set-policy \
        --name "$KEYVAULT_NAME" \
        --object-id "$current_user_id" \
        --secret-permissions get list set delete backup restore recover purge
    
    print_success "Access policy configured"
    
    # Create initial secrets
    create_application_secrets
}

# Function to generate secure random password
generate_password() {
    local length=${1:-16}
    openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | cut -c1-${length}
}

# Function to create application secrets
create_application_secrets() {
    print_info "Creating application secrets for environment: $ENVIRONMENT"
    
    if ! check_keyvault_exists "$KEYVAULT_NAME"; then
        print_error "Key Vault '$KEYVAULT_NAME' does not exist"
        exit 1
    fi
    
    # Define secrets based on environment
    declare -A secrets
    
    case "$ENVIRONMENT" in
        "dev")
            secrets=(
                ["spring-datasource-url"]="jdbc:postgresql://dev-db:5432/myapp_dev"
                ["spring-datasource-username"]="myapp_dev_user"
                ["spring-datasource-password"]="$(generate_password 16)"
                ["spring-redis-url"]="redis://dev-redis:6379"
                ["spring-redis-password"]="$(generate_password 12)"
                ["jwt-secret"]="$(generate_password 32)"
                ["encryption-key"]="$(generate_password 32)"
                ["api-key-external"]="dev-api-key-$(generate_password 16)"
                ["oauth-client-secret"]="$(generate_password 24)"
                ["nodejs-database-url"]="postgresql://nodejs_dev_user:$(generate_password 16)@dev-db:5432/nodejs_dev"
                ["nodejs-session-secret"]="$(generate_password 32)"
                ["nodejs-api-key"]="$(generate_password 24)"
                ["smtp-password"]="$(generate_password 16)"
            )
            ;;
        "staging")
            secrets=(
                ["spring-datasource-url"]="jdbc:postgresql://staging-db:5432/myapp_staging"
                ["spring-datasource-username"]="myapp_staging_user"
                ["spring-datasource-password"]="$(generate_password 20)"
                ["spring-redis-url"]="redis://staging-redis:6379"
                ["spring-redis-password"]="$(generate_password 16)"
                ["jwt-secret"]="$(generate_password 32)"
                ["encryption-key"]="$(generate_password 32)"
                ["api-key-external"]="staging-api-key-$(generate_password 20)"
                ["oauth-client-secret"]="$(generate_password 28)"
                ["nodejs-database-url"]="postgresql://nodejs_staging_user:$(generate_password 20)@staging-db:5432/nodejs_staging"
                ["nodejs-session-secret"]="$(generate_password 32)"
                ["nodejs-api-key"]="$(generate_password 28)"
                ["smtp-password"]="$(generate_password 20)"
                ["monitoring-token"]="$(generate_password 24)"
            )
            ;;
        "production")
            secrets=(
                ["spring-datasource-url"]="jdbc:postgresql://prod-db.internal:5432/myapp_prod"
                ["spring-datasource-username"]="myapp_prod_user"
                ["spring-datasource-password"]="$(generate_password 32)"
                ["spring-redis-url"]="redis://prod-redis.internal:6379"
                ["spring-redis-password"]="$(generate_password 24)"
                ["jwt-secret"]="$(generate_password 48)"
                ["encryption-key"]="$(generate_password 48)"
                ["api-key-external"]="prod-api-key-$(generate_password 32)"
                ["oauth-client-secret"]="$(generate_password 40)"
                ["nodejs-database-url"]="postgresql://nodejs_prod_user:$(generate_password 32)@prod-db.internal:5432/nodejs_prod"
                ["nodejs-session-secret"]="$(generate_password 48)"
                ["nodejs-api-key"]="$(generate_password 40)"
                ["smtp-password"]="$(generate_password 32)"
                ["monitoring-token"]="$(generate_password 32)"
                ["backup-encryption-key"]="$(generate_password 48)"
            )
            ;;
    esac
    
    # Create secrets in Key Vault
    for secret_name in "${!secrets[@]}"; do
        local secret_value="${secrets[$secret_name]}"
        print_info "Creating secret: $secret_name"
        
        az keyvault secret set \
            --vault-name "$KEYVAULT_NAME" \
            --name "$secret_name" \
            --value "$secret_value" \
            --output none
        
        print_success "Created: $secret_name"
    done
    
    print_success "All secrets created successfully"
    
    # Display summary
    print_info "Secrets created for $ENVIRONMENT environment:"
    list_secrets_summary
}

# Function to list secrets
list_secrets() {
    print_info "Listing secrets in Key Vault: $KEYVAULT_NAME"
    
    if ! check_keyvault_exists "$KEYVAULT_NAME"; then
        print_error "Key Vault '$KEYVAULT_NAME' does not exist"
        exit 1
    fi
    
    az keyvault secret list --vault-name "$KEYVAULT_NAME" --query "[].{Name:name, Created:attributes.created, Updated:attributes.updated}" --output table
}

# Function to list secrets summary
list_secrets_summary() {
    if ! check_keyvault_exists "$KEYVAULT_NAME"; then
        print_error "Key Vault '$KEYVAULT_NAME' does not exist"
        return 1
    fi
    
    local secrets=$(az keyvault secret list --vault-name "$KEYVAULT_NAME" --query "[].name" --output tsv)
    local count=$(echo "$secrets" | wc -l)
    
    echo "$secrets" | sort
    print_info "Total secrets: $count"
}

# Function to get a specific secret
get_secret() {
    local secret_name="$1"
    
    if [[ -z "$secret_name" ]]; then
        print_error "Secret name is required"
        exit 1
    fi
    
    print_info "Retrieving secret: $secret_name"
    
    if ! check_keyvault_exists "$KEYVAULT_NAME"; then
        print_error "Key Vault '$KEYVAULT_NAME' does not exist"
        exit 1
    fi
    
    local secret_value
    if secret_value=$(az keyvault secret show --vault-name "$KEYVAULT_NAME" --name "$secret_name" --query value --output tsv 2>/dev/null); then
        echo "Secret value: $secret_value"
    else
        print_error "Secret '$secret_name' not found or access denied"
        exit 1
    fi
}

# Function to delete a secret
delete_secret() {
    local secret_name="$1"
    
    if [[ -z "$secret_name" ]]; then
        print_error "Secret name is required"
        exit 1
    fi
    
    print_warning "Deleting secret: $secret_name"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        az keyvault secret delete --vault-name "$KEYVAULT_NAME" --name "$secret_name"
        print_success "Secret deleted: $secret_name"
    else
        print_info "Operation cancelled"
    fi
}

# Function to backup secrets
backup_secrets() {
    local backup_file="${1:-secrets-backup-$(date +%Y%m%d-%H%M%S).json}"
    
    print_info "Backing up secrets to: $backup_file"
    
    if ! check_keyvault_exists "$KEYVAULT_NAME"; then
        print_error "Key Vault '$KEYVAULT_NAME' does not exist"
        exit 1
    fi
    
    # Get all secrets
    local secrets=$(az keyvault secret list --vault-name "$KEYVAULT_NAME" --query "[].name" --output tsv)
    
    echo "{" > "$backup_file"
    echo "  \"keyvault\": \"$KEYVAULT_NAME\"," >> "$backup_file"
    echo "  \"backup_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$backup_file"
    echo "  \"secrets\": {" >> "$backup_file"
    
    local first=true
    while IFS= read -r secret_name; do
        if [[ -n "$secret_name" ]]; then
            local secret_value=$(az keyvault secret show --vault-name "$KEYVAULT_NAME" --name "$secret_name" --query value --output tsv)
            
            if [[ "$first" == true ]]; then
                first=false
            else
                echo "," >> "$backup_file"
            fi
            
            echo -n "    \"$secret_name\": \"$secret_value\"" >> "$backup_file"
            print_info "Backed up: $secret_name"
        fi
    done <<< "$secrets"
    
    echo "" >> "$backup_file"
    echo "  }" >> "$backup_file"
    echo "}" >> "$backup_file"
    
    print_success "Backup completed: $backup_file"
}

# Function to restore secrets from backup
restore_secrets() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]] || [[ ! -f "$backup_file" ]]; then
        print_error "Backup file is required and must exist"
        exit 1
    fi
    
    print_warning "Restoring secrets from: $backup_file"
    print_warning "This will overwrite existing secrets!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled"
        exit 0
    fi
    
    if ! check_keyvault_exists "$KEYVAULT_NAME"; then
        print_error "Key Vault '$KEYVAULT_NAME' does not exist"
        exit 1
    fi
    
    # Parse JSON and restore secrets
    local secrets=$(jq -r '.secrets | keys[]' "$backup_file")
    
    while IFS= read -r secret_name; do
        if [[ -n "$secret_name" ]]; then
            local secret_value=$(jq -r ".secrets[\"$secret_name\"]" "$backup_file")
            
            print_info "Restoring: $secret_name"
            az keyvault secret set \
                --vault-name "$KEYVAULT_NAME" \
                --name "$secret_name" \
                --value "$secret_value" \
                --output none
            
            print_success "Restored: $secret_name"
        fi
    done <<< "$secrets"
    
    print_success "Restore completed"
}

# Function to test Key Vault access
test_access() {
    print_info "Testing access to Key Vault: $KEYVAULT_NAME"
    
    # Test 1: Check if Key Vault exists and is accessible
    if check_keyvault_exists "$KEYVAULT_NAME"; then
        print_success "Key Vault exists and is accessible"
    else
        print_error "Key Vault does not exist or is not accessible"
        exit 1
    fi
    
    # Test 2: List secrets (test read permission)
    print_info "Testing secret list permission..."
    if az keyvault secret list --vault-name "$KEYVAULT_NAME" --output none 2>/dev/null; then
        print_success "Can list secrets"
    else
        print_error "Cannot list secrets - check permissions"
        exit 1
    fi
    
    # Test 3: Create a test secret
    print_info "Testing secret creation permission..."
    local test_secret_name="test-secret-$(date +%s)"
    local test_secret_value="test-value-$(date +%s)"
    
    if az keyvault secret set \
        --vault-name "$KEYVAULT_NAME" \
        --name "$test_secret_name" \
        --value "$test_secret_value" \
        --output none 2>/dev/null; then
        print_success "Can create secrets"
        
        # Test 4: Read the test secret
        print_info "Testing secret retrieval..."
        if retrieved_value=$(az keyvault secret show --vault-name "$KEYVAULT_NAME" --name "$test_secret_name" --query value --output tsv 2>/dev/null); then
            if [[ "$retrieved_value" == "$test_secret_value" ]]; then
                print_success "Can retrieve secrets correctly"
            else
                print_error "Secret value mismatch"
            fi
        else
            print_error "Cannot retrieve secrets"
        fi
        
        # Clean up test secret
        print_info "Cleaning up test secret..."
        az keyvault secret delete --vault-name "$KEYVAULT_NAME" --name "$test_secret_name" --output none 2>/dev/null
        print_success "Test secret cleaned up"
    else
        print_error "Cannot create secrets - check permissions"
        exit 1
    fi
    
    # Test 5: Check current user permissions
    print_info "Checking current user permissions..."
    local current_user_id=$(az ad signed-in-user show --query id -o tsv)
    local policies=$(az keyvault show --name "$KEYVAULT_NAME" --query "properties.accessPolicies[?objectId=='$current_user_id'].permissions.secrets" --output tsv)
    
    if [[ -n "$policies" ]]; then
        print_success "Access policies found: $policies"
    else
        print_warning "No specific access policies found - may be using RBAC"
    fi
    
    print_success "All access tests completed successfully!"
}

# Main function to parse arguments and execute commands
main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi
    
    local command="$1"
    shift
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--vault)
                KEYVAULT_NAME="$2"
                shift 2
                ;;
            -g|--resource-group)
                RESOURCE_GROUP="$2"
                shift 2
                ;;
            -l|--location)
                LOCATION="$2"
                shift 2
                ;;
            -s|--subscription)
                SUBSCRIPTION_ID="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -n|--secret-name)
                SECRET_NAME="$2"
                shift 2
                ;;
            -f|--file)
                FILE_PATH="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$KEYVAULT_NAME" ]] && [[ "$command" != "help" ]]; then
        print_error "Key Vault name is required"
        usage
        exit 1
    fi
    
    # Check Azure CLI before executing commands
    if [[ "$command" != "help" ]]; then
        check_azure_cli
    fi
    
    # Execute command
    case "$command" in
        setup)
            setup_keyvault
            ;;
        create-secrets)
            create_application_secrets
            ;;
        list-secrets)
            list_secrets
            ;;
        get-secret)
            get_secret "$SECRET_NAME"
            ;;
        delete-secret)
            delete_secret "$SECRET_NAME"
            ;;
        backup)
            backup_secrets "$FILE_PATH"
            ;;
        restore)
            restore_secrets "$FILE_PATH"
            ;;
        test-access)
            test_access
            ;;
        help)
            usage
            ;;
        *)
            print_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"