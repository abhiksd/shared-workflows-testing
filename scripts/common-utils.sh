#!/bin/bash

# Common utilities for all scripts
# This file contains reusable functions to reduce code duplication

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Global settings
VERBOSE=${VERBOSE:-false}

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_header() { echo -e "${CYAN}🔍 $1${NC}"; }
log_verbose() { [[ "$VERBOSE" == true ]] && echo -e "${BLUE}   📝 $1${NC}"; }

# Utility functions
command_exists() { command -v "$1" >/dev/null 2>&1; }

check_required_vars() {
    local missing=()
    for var in "$@"; do
        [[ -z "${!var}" ]] && missing+=("$var")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required variables: ${missing[*]}"
        return 1
    fi
}

# HTTP checking function
check_http_endpoint() {
    local url=$1 description=$2 expected_status=${3:-200} timeout=${4:-30}
    local response status_code
    
    log_verbose "Checking: $url"
    response=$(curl -s -w "%{http_code}" -o /dev/null --connect-timeout "$timeout" --max-time "$timeout" "$url" 2>/dev/null)
    
    if [[ $? -eq 0 && "$response" -eq "$expected_status" ]]; then
        log_success "$description: OK ($response)"
        return 0
    else
        log_error "$description: FAILED ($response)"
        return 1
    fi
}

# Azure CLI helper functions
az_check_login() {
    if ! az account show &>/dev/null; then
        log_error "Not logged in to Azure CLI. Run: az login"
        return 1
    fi
    return 0
}

az_get_account_info() {
    az account show --query "{Name:name, ID:id, User:user.name, Type:user.type}" -o table 2>/dev/null
}

# Kubernetes helper functions
k8s_check_resource() {
    local type=$1 name=$2 namespace=${3:-default}
    kubectl get "$type" "$name" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null
}

# Environment validation
validate_environment() {
    local env=$1
    case "$env" in
        dev|staging|production) return 0 ;;
        *) log_error "Invalid environment: $env"; return 1 ;;
    esac
}

# Branch validation helpers
is_main_branch() { [[ "$GITHUB_REF" == "refs/heads/main" ]]; }
is_develop_branch() { [[ "$GITHUB_REF" == "refs/heads/develop" || "$GITHUB_REF" == "refs/heads/N630-6258_Helm_deploy" ]]; }
is_release_branch() { [[ "$GITHUB_REF" == refs/heads/release/* ]]; }
is_tag() { [[ "$GITHUB_REF" == refs/tags/* ]]; }

# Version helpers
get_short_sha() { echo "${GITHUB_SHA::7}"; }
get_date_stamp() { date +'%Y%m%d'; }

# File change detection
has_changes_in_path() {
    local path=$1 changed_files=$2
    echo "$changed_files" | grep -q "^$path/"
}

# Environment-specific cluster mapping
get_cluster_info() {
    local env=$1
    case "$env" in
        dev)
            echo "aks-platform-dev rg-platform-dev"
            ;;
        staging)
            echo "aks-platform-staging rg-platform-staging"
            ;;
        production)
            echo "aks-platform-prod rg-platform-prod"
            ;;
        *)
            log_error "Unknown environment: $env"
            return 1
            ;;
    esac
}