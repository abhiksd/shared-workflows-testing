#!/bin/bash

# Azure Identity and Authentication Check Script
# This script checks Azure CLI login status, identity information, and permissions
# Usage: ./azure-identity-check.sh [options]

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
VERBOSE=false
CHECK_PERMISSIONS=false
RESOURCE_GROUP=""
KEYVAULT_NAME=""
SUBSCRIPTION_ID=""

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

print_header() {
    echo -e "${CYAN}🔍 $1${NC}"
}

print_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}   📝 $1${NC}"
    fi
}

# Function to display usage
usage() {
    cat << EOF
Azure Identity and Authentication Check Script

Usage: $0 [OPTIONS]

This script performs comprehensive checks of your Azure authentication status,
identity information, permissions, and access to Azure resources.

Options:
    -v, --verbose               Enable verbose output
    -p, --check-permissions     Check detailed permissions
    -g, --resource-group NAME   Check access to specific resource group
    -k, --keyvault NAME         Check access to specific Key Vault
    -s, --subscription ID       Check specific subscription
    --detailed                  Show detailed information for all checks
    -h, --help                  Show this help message

Examples:
    $0                                          # Basic identity check
    $0 -v                                       # Verbose output
    $0 -p                                       # Include permission checks
    $0 -g myapp-rg -k myapp-kv-dev             # Check specific resources
    $0 --detailed -s subscription-id            # Comprehensive check

EOF
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Azure CLI installation
check_azure_cli_installation() {
    print_header "Azure CLI Installation Check"
    
    if command_exists az; then
        local az_version=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "unknown")
        print_success "Azure CLI is installed"
        print_verbose "Version: $az_version"
        
        # Check for extensions
        print_verbose "Checking installed extensions..."
        local extensions=$(az extension list --query "[].name" -o tsv 2>/dev/null || echo "")
        if [[ -n "$extensions" ]]; then
            print_verbose "Extensions: $(echo $extensions | tr '\n' ', ' | sed 's/,$//')"
        else
            print_verbose "No extensions installed"
        fi
    else
        print_error "Azure CLI is not installed"
        print_info "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
}

# Function to check login status
check_login_status() {
    print_header "Azure Login Status"
    
    if az account show &> /dev/null; then
        print_success "Logged in to Azure CLI"
        
        # Get basic account info
        local user_name=$(az account show --query user.name -o tsv 2>/dev/null || echo "Unknown")
        local user_type=$(az account show --query user.type -o tsv 2>/dev/null || echo "Unknown")
        local tenant_id=$(az account show --query tenantId -o tsv 2>/dev/null || echo "Unknown")
        local subscription_name=$(az account show --query name -o tsv 2>/dev/null || echo "Unknown")
        local subscription_id=$(az account show --query id -o tsv 2>/dev/null || echo "Unknown")
        
        echo "User: $user_name"
        echo "Type: $user_type"
        echo "Tenant: $tenant_id"
        echo "Subscription: $subscription_name"
        echo "Subscription ID: $subscription_id"
        
        # Check if managed identity
        if [[ "$user_type" == "servicePrincipal" ]]; then
            print_info "Logged in as Service Principal"
        elif [[ "$user_type" == "managedIdentity" ]]; then
            print_info "Using Managed Identity"
        else
            print_info "Logged in as User Account"
        fi
        
    else
        print_error "Not logged in to Azure CLI"
        print_info "Run: az login"
        exit 1
    fi
}

# Function to check subscription access
check_subscription_access() {
    print_header "Subscription Access Check"
    
    # Set subscription if provided
    if [[ -n "$SUBSCRIPTION_ID" ]]; then
        print_info "Setting subscription to: $SUBSCRIPTION_ID"
        if az account set --subscription "$SUBSCRIPTION_ID" &> /dev/null; then
            print_success "Successfully set subscription"
        else
            print_error "Failed to set subscription"
            return 1
        fi
    fi
    
    # List accessible subscriptions
    print_info "Accessible subscriptions:"
    if az account list --query "[].{Name:name, ID:id, State:state, Default:isDefault}" -o table 2>/dev/null; then
        print_success "Subscription access verified"
    else
        print_error "Cannot list subscriptions"
        return 1
    fi
    
    # Check current subscription details
    print_verbose "Current subscription details:"
    if [[ "$VERBOSE" == true ]]; then
        az account show --query "{Name:name, ID:id, TenantID:tenantId, State:state}" -o table 2>/dev/null || true
    fi
}

# Function to check identity details
check_identity_details() {
    print_header "Identity Details"
    
    # Get signed-in user details
    print_info "Current user identity:"
    if az ad signed-in-user show --query "{DisplayName:displayName, UserPrincipalName:userPrincipalName, ObjectId:id, JobTitle:jobTitle}" -o table 2>/dev/null; then
        print_success "User identity retrieved"
    else
        print_warning "Cannot retrieve user identity (may be service principal or managed identity)"
        
        # Try to get service principal info
        local sp_info=$(az account show --query user -o json 2>/dev/null || echo "{}")
        if [[ "$sp_info" != "{}" ]]; then
            echo "Service Principal/Identity Info:"
            echo "$sp_info" | jq -r '. | "Name: \(.name)\nType: \(.type)"' 2>/dev/null || echo "$sp_info"
        fi
    fi
    
    # Check tenant information
    print_verbose "Tenant information:"
    if [[ "$VERBOSE" == true ]]; then
        local tenant_id=$(az account show --query tenantId -o tsv 2>/dev/null)
        if [[ -n "$tenant_id" ]]; then
            az rest --method GET --uri "https://graph.microsoft.com/v1.0/organization" --query "value[0].{DisplayName:displayName, ID:id, Domain:verifiedDomains[0].name}" -o table 2>/dev/null || print_verbose "Cannot retrieve tenant details"
        fi
    fi
}

# Function to check Azure resource access
check_resource_access() {
    print_header "Azure Resource Access"
    
    # Check resource groups
    print_info "Testing resource group access..."
    if az group list --query "[0:5].{Name:name, Location:location}" -o table 2>/dev/null; then
        print_success "Can list resource groups"
    else
        print_error "Cannot list resource groups"
    fi
    
    # Check specific resource group if provided
    if [[ -n "$RESOURCE_GROUP" ]]; then
        print_info "Checking specific resource group: $RESOURCE_GROUP"
        if az group show --name "$RESOURCE_GROUP" --query "{Name:name, Location:location, ProvisioningState:properties.provisioningState}" -o table 2>/dev/null; then
            print_success "Can access resource group: $RESOURCE_GROUP"
        else
            print_error "Cannot access resource group: $RESOURCE_GROUP"
        fi
    fi
    
    # Check Key Vault access if provided
    if [[ -n "$KEYVAULT_NAME" ]]; then
        print_info "Checking Key Vault access: $KEYVAULT_NAME"
        if az keyvault show --name "$KEYVAULT_NAME" --query "{Name:name, Location:location, Sku:properties.sku.name}" -o table 2>/dev/null; then
            print_success "Can access Key Vault: $KEYVAULT_NAME"
            
            # Test secret operations
            print_info "Testing Key Vault secret operations..."
            if az keyvault secret list --vault-name "$KEYVAULT_NAME" --maxresults 1 --output none 2>/dev/null; then
                print_success "Can list secrets in Key Vault"
            else
                print_warning "Cannot list secrets - may need additional permissions"
            fi
        else
            print_error "Cannot access Key Vault: $KEYVAULT_NAME"
        fi
    fi
}

# Function to check role assignments and permissions
check_permissions() {
    if [[ "$CHECK_PERMISSIONS" != true ]]; then
        return 0
    fi
    
    print_header "Permission and Role Assignment Check"
    
    # Get current user/service principal ID
    local current_user_id=""
    if current_user_id=$(az ad signed-in-user show --query id -o tsv 2>/dev/null); then
        print_info "Checking permissions for user: $current_user_id"
    else
        # Try service principal
        local sp_object_id=$(az account show --query user.assignedIdentityInfo -o tsv 2>/dev/null || echo "")
        if [[ -n "$sp_object_id" ]]; then
            current_user_id="$sp_object_id"
            print_info "Checking permissions for service principal: $current_user_id"
        else
            print_warning "Cannot determine current user/service principal ID"
            return 1
        fi
    fi
    
    # Check subscription-level role assignments
    print_info "Subscription-level role assignments:"
    if az role assignment list --assignee "$current_user_id" --query "[].{Role:roleDefinitionName, Scope:scope}" -o table 2>/dev/null; then
        print_success "Role assignments retrieved"
    else
        print_warning "Cannot retrieve role assignments"
    fi
    
    # Check specific resource group permissions if provided
    if [[ -n "$RESOURCE_GROUP" ]]; then
        print_info "Resource group permissions for: $RESOURCE_GROUP"
        local rg_scope="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP"
        az role assignment list --assignee "$current_user_id" --scope "$rg_scope" --query "[].{Role:roleDefinitionName, Scope:scope}" -o table 2>/dev/null || print_warning "Cannot retrieve resource group permissions"
    fi
    
    # Check Key Vault permissions if provided
    if [[ -n "$KEYVAULT_NAME" ]]; then
        print_info "Key Vault access policies for: $KEYVAULT_NAME"
        az keyvault show --name "$KEYVAULT_NAME" --query "properties.accessPolicies[?objectId=='$current_user_id'].{ObjectId:objectId, Permissions:permissions}" -o table 2>/dev/null || print_warning "Cannot retrieve Key Vault access policies"
    fi
}

# Function to test network connectivity
check_network_connectivity() {
    print_header "Network Connectivity Check"
    
    # Test connectivity to Azure endpoints
    local endpoints=(
        "management.azure.com"
        "login.microsoftonline.com"
        "graph.microsoft.com"
    )
    
    for endpoint in "${endpoints[@]}"; do
        print_info "Testing connectivity to: $endpoint"
        if curl -s --connect-timeout 5 --max-time 10 "https://$endpoint" > /dev/null 2>&1; then
            print_success "✓ $endpoint"
        else
            print_warning "✗ $endpoint (may be blocked or slow)"
        fi
    done
}

# Function to check token expiration
check_token_expiration() {
    print_header "Token Expiration Check"
    
    # Get access token info
    local token_info
    if token_info=$(az account get-access-token --query "{expiresOn:expiresOn, tokenType:tokenType}" -o json 2>/dev/null); then
        local expires_on=$(echo "$token_info" | jq -r .expiresOn)
        local token_type=$(echo "$token_info" | jq -r .tokenType)
        
        print_info "Token type: $token_type"
        print_info "Token expires: $expires_on"
        
        # Calculate time until expiration
        if command_exists date; then
            local expire_timestamp=$(date -d "$expires_on" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$expires_on" +%s 2>/dev/null || echo "0")
            local current_timestamp=$(date +%s)
            local time_diff=$((expire_timestamp - current_timestamp))
            
            if [[ $time_diff -gt 3600 ]]; then
                local hours=$((time_diff / 3600))
                print_success "Token valid for $hours hours"
            elif [[ $time_diff -gt 60 ]]; then
                local minutes=$((time_diff / 60))
                print_warning "Token expires in $minutes minutes"
            elif [[ $time_diff -gt 0 ]]; then
                print_warning "Token expires in $time_diff seconds"
            else
                print_error "Token has expired!"
            fi
        fi
    else
        print_error "Cannot retrieve token information"
    fi
}

# Function to perform comprehensive health check
health_check() {
    print_header "Azure CLI Health Check"
    
    # Check Azure CLI configuration
    print_info "Azure CLI configuration:"
    if [[ "$VERBOSE" == true ]]; then
        az config get --local --query "{Config:configuredDefaults, Output:output}" -o table 2>/dev/null || print_verbose "No local configuration found"
    fi
    
    # Check for common issues
    print_info "Checking for common issues..."
    
    # Check if in Cloud Shell
    if [[ -n "${AZURE_HTTP_USER_AGENT:-}" ]]; then
        print_info "Running in Azure Cloud Shell"
    fi
    
    # Check environment variables
    local azure_env_vars=(
        "AZURE_CLIENT_ID"
        "AZURE_CLIENT_SECRET"
        "AZURE_TENANT_ID"
        "AZURE_SUBSCRIPTION_ID"
    )
    
    print_verbose "Azure environment variables:"
    for var in "${azure_env_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            print_verbose "$var is set"
        else
            print_verbose "$var is not set"
        fi
    done
    
    print_success "Health check completed"
}

# Function to generate summary report
generate_summary() {
    print_header "Summary Report"
    
    echo "Azure Identity Check Summary"
    echo "=========================="
    echo "Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo
    
    # Basic info
    local user_name=$(az account show --query user.name -o tsv 2>/dev/null || echo "Unknown")
    local subscription_name=$(az account show --query name -o tsv 2>/dev/null || echo "Unknown")
    local tenant_id=$(az account show --query tenantId -o tsv 2>/dev/null || echo "Unknown")
    
    echo "Identity: $user_name"
    echo "Subscription: $subscription_name"
    echo "Tenant: $tenant_id"
    echo
    
    # Status indicators
    echo "Status Checks:"
    echo "  Azure CLI: ✅ Installed and working"
    echo "  Authentication: ✅ Logged in"
    echo "  Subscription Access: ✅ Available"
    
    if [[ -n "$RESOURCE_GROUP" ]]; then
        if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
            echo "  Resource Group ($RESOURCE_GROUP): ✅ Accessible"
        else
            echo "  Resource Group ($RESOURCE_GROUP): ❌ Not accessible"
        fi
    fi
    
    if [[ -n "$KEYVAULT_NAME" ]]; then
        if az keyvault show --name "$KEYVAULT_NAME" &> /dev/null; then
            echo "  Key Vault ($KEYVAULT_NAME): ✅ Accessible"
        else
            echo "  Key Vault ($KEYVAULT_NAME): ❌ Not accessible"
        fi
    fi
    
    echo
    print_success "Identity check completed successfully!"
}

# Main function to parse arguments and execute checks
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -p|--check-permissions)
                CHECK_PERMISSIONS=true
                shift
                ;;
            -g|--resource-group)
                RESOURCE_GROUP="$2"
                shift 2
                ;;
            -k|--keyvault)
                KEYVAULT_NAME="$2"
                shift 2
                ;;
            -s|--subscription)
                SUBSCRIPTION_ID="$2"
                shift 2
                ;;
            --detailed)
                VERBOSE=true
                CHECK_PERMISSIONS=true
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
    
    echo "🔍 Azure Identity and Authentication Check"
    echo "=========================================="
    echo
    
    # Perform checks
    check_azure_cli_installation
    echo
    
    check_login_status
    echo
    
    check_subscription_access
    echo
    
    check_identity_details
    echo
    
    check_resource_access
    echo
    
    check_permissions
    echo
    
    check_network_connectivity
    echo
    
    check_token_expiration
    echo
    
    health_check
    echo
    
    generate_summary
}

# Run main function with all arguments
main "$@"