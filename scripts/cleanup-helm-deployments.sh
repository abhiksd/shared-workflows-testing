#!/bin/bash

# Helm Deployment Cleanup Script
# This script provides comprehensive cleanup for Helm deployments including namespaces

set -euo pipefail

# Script variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Cleanup Helm deployments and optionally their namespaces.

OPTIONS:
    -r, --release        Helm release name to cleanup [required for single release]
    -n, --namespace      Namespace containing the release [default: default]
    -a, --all-releases   Cleanup all Helm releases in namespace
    -A, --all-namespaces Cleanup all Helm releases across all namespaces
    -d, --delete-namespace Delete the namespace after removing releases
    -f, --force          Force cleanup without confirmation prompts
    -t, --timeout        Timeout for uninstall operations in seconds [default: 300]
    --dry-run           Show what would be deleted without actually deleting
    --keep-history      Keep release history after uninstall
    -h, --help          Show this help message

EXAMPLES:
    # Cleanup a specific release
    $0 -r my-app -n production

    # Cleanup all releases in a namespace and delete the namespace
    $0 -n monitoring -a -d

    # Cleanup all releases across all namespaces (use with caution!)
    $0 -A -f

    # Dry run to see what would be deleted
    $0 -r my-app -n production --dry-run

    # Cleanup with custom timeout
    $0 -r my-app -n production -t 600

EOF
}

# Check if helm is available
check_helm() {
    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed or not in PATH"
        exit 1
    fi
    
    log_info "Using Helm version: $(helm version --short)"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    log_info "kubectl context: $(kubectl config current-context)"
}

# List Helm releases
list_releases() {
    local namespace="$1"
    local all_namespaces="$2"
    
    log_info "Listing Helm releases..."
    
    if [[ "$all_namespaces" == "true" ]]; then
        helm list --all-namespaces --output table
    else
        helm list --namespace "$namespace" --output table
    fi
}

# Confirm action with user
confirm_action() {
    local message="$1"
    local force="$2"
    
    if [[ "$force" == "true" ]]; then
        return 0
    fi
    
    echo -e "${YELLOW}$message${NC}"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled by user"
        exit 0
    fi
}

# Cleanup a specific Helm release
cleanup_release() {
    local release="$1"
    local namespace="$2"
    local timeout="$3"
    local dry_run="$4"
    local keep_history="$5"
    local force="$6"
    
    log_info "Cleaning up Helm release: $release in namespace: $namespace"
    
    # Check if release exists
    if ! helm list --namespace "$namespace" --short | grep -q "^$release$"; then
        log_warning "Release '$release' not found in namespace '$namespace'"
        return 1
    fi
    
    # Build uninstall command
    local cmd="helm uninstall $release --namespace $namespace --timeout ${timeout}s"
    
    if [[ "$keep_history" == "true" ]]; then
        cmd="$cmd --keep-history"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        cmd="$cmd --dry-run"
    fi
    
    # Confirm action
    if [[ "$dry_run" != "true" ]]; then
        confirm_action "This will uninstall release '$release' from namespace '$namespace'" "$force"
    fi
    
    # Execute uninstall
    log_info "Executing: $cmd"
    if eval "$cmd"; then
        log_success "Successfully uninstalled release: $release"
    else
        log_error "Failed to uninstall release: $release"
        return 1
    fi
    
    # Verify cleanup
    if [[ "$dry_run" != "true" ]]; then
        log_info "Verifying cleanup..."
        sleep 5
        
        # Check for remaining resources
        remaining_resources=$(kubectl get all -l "app.kubernetes.io/managed-by=Helm" -n "$namespace" --no-headers 2>/dev/null | wc -l)
        if [[ "$remaining_resources" -gt 0 ]]; then
            log_warning "Some resources may still be terminating. Run 'kubectl get all -n $namespace' to check."
        else
            log_success "All release resources have been cleaned up"
        fi
    fi
}

# Cleanup all releases in a namespace
cleanup_all_releases_in_namespace() {
    local namespace="$1"
    local timeout="$2"
    local dry_run="$3"
    local keep_history="$4"
    local force="$5"
    
    log_info "Getting all Helm releases in namespace: $namespace"
    
    # Get list of releases
    local releases
    releases=$(helm list --namespace "$namespace" --short 2>/dev/null || true)
    
    if [[ -z "$releases" ]]; then
        log_info "No Helm releases found in namespace: $namespace"
        return 0
    fi
    
    log_info "Found releases in namespace '$namespace':"
    echo "$releases"
    
    # Confirm action
    if [[ "$dry_run" != "true" ]]; then
        confirm_action "This will uninstall ALL releases in namespace '$namespace'" "$force"
    fi
    
    # Cleanup each release
    while IFS= read -r release; do
        if [[ -n "$release" ]]; then
            cleanup_release "$release" "$namespace" "$timeout" "$dry_run" "$keep_history" "true"
        fi
    done <<< "$releases"
}

# Cleanup all releases across all namespaces
cleanup_all_releases_all_namespaces() {
    local timeout="$1"
    local dry_run="$2"
    local keep_history="$3"
    local force="$4"
    
    log_warning "This will cleanup ALL Helm releases across ALL namespaces!"
    
    # Get all releases across all namespaces
    local releases_info
    releases_info=$(helm list --all-namespaces --output json 2>/dev/null || echo "[]")
    
    # Parse releases and namespaces
    local releases_count
    releases_count=$(echo "$releases_info" | jq '. | length' 2>/dev/null || echo "0")
    
    if [[ "$releases_count" -eq 0 ]]; then
        log_info "No Helm releases found across all namespaces"
        return 0
    fi
    
    log_info "Found $releases_count Helm releases across all namespaces"
    
    if [[ "$dry_run" != "true" ]]; then
        confirm_action "This will uninstall ALL $releases_count Helm releases across ALL namespaces" "$force"
    fi
    
    # Process each release
    for i in $(seq 0 $((releases_count - 1))); do
        local release
        local namespace
        release=$(echo "$releases_info" | jq -r ".[$i].name" 2>/dev/null || continue)
        namespace=$(echo "$releases_info" | jq -r ".[$i].namespace" 2>/dev/null || continue)
        
        if [[ -n "$release" && -n "$namespace" ]]; then
            cleanup_release "$release" "$namespace" "$timeout" "$dry_run" "$keep_history" "true"
        fi
    done
}

# Delete namespace after cleanup
delete_namespace() {
    local namespace="$1"
    local dry_run="$2"
    local force="$3"
    
    # Don't delete system namespaces
    local system_namespaces=("default" "kube-system" "kube-public" "kube-node-lease")
    for sys_ns in "${system_namespaces[@]}"; do
        if [[ "$namespace" == "$sys_ns" ]]; then
            log_warning "Skipping deletion of system namespace: $namespace"
            return 0
        fi
    done
    
    log_info "Preparing to delete namespace: $namespace"
    
    # Check if namespace exists
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        log_warning "Namespace '$namespace' does not exist"
        return 0
    fi
    
    # Check if namespace has any remaining resources
    local resources_count
    resources_count=$(kubectl get all -n "$namespace" --no-headers 2>/dev/null | wc -l)
    
    if [[ "$resources_count" -gt 0 ]]; then
        log_warning "Namespace '$namespace' still contains $resources_count resources"
        kubectl get all -n "$namespace"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY RUN] Would delete namespace: $namespace"
        return 0
    fi
    
    confirm_action "This will delete namespace '$namespace' and ALL its contents" "$force"
    
    log_info "Deleting namespace: $namespace"
    if kubectl delete namespace "$namespace" --timeout=300s; then
        log_success "Successfully deleted namespace: $namespace"
    else
        log_error "Failed to delete namespace: $namespace"
        log_info "You may need to manually clean up finalizers or stuck resources"
    fi
}

# Force cleanup stuck resources
force_cleanup_stuck_resources() {
    local namespace="$1"
    local release="$2"
    
    log_warning "Attempting force cleanup of stuck resources..."
    
    # Remove finalizers from stuck resources
    log_info "Removing finalizers from stuck resources..."
    
    # Get all resources with Helm labels
    local resources
    resources=$(kubectl get all -n "$namespace" -l "app.kubernetes.io/managed-by=Helm" -o name 2>/dev/null || true)
    
    if [[ -n "$resources" ]]; then
        echo "$resources" | while IFS= read -r resource; do
            log_info "Force deleting resource: $resource"
            kubectl patch "$resource" -n "$namespace" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
            kubectl delete "$resource" -n "$namespace" --force --grace-period=0 2>/dev/null || true
        done
    fi
    
    # Clean up any remaining Helm secrets
    log_info "Cleaning up Helm secrets..."
    kubectl delete secrets -n "$namespace" -l "owner=helm" 2>/dev/null || true
    kubectl delete secrets -n "$namespace" -l "name=$release" 2>/dev/null || true
}

# Main function
main() {
    local release=""
    local namespace="default"
    local all_releases="false"
    local all_namespaces="false"
    local delete_ns="false"
    local force="false"
    local timeout="300"
    local dry_run="false"
    local keep_history="false"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--release)
                release="$2"
                shift 2
                ;;
            -n|--namespace)
                namespace="$2"
                shift 2
                ;;
            -a|--all-releases)
                all_releases="true"
                shift
                ;;
            -A|--all-namespaces)
                all_namespaces="true"
                shift
                ;;
            -d|--delete-namespace)
                delete_ns="true"
                shift
                ;;
            -f|--force)
                force="true"
                shift
                ;;
            -t|--timeout)
                timeout="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --keep-history)
                keep_history="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate input
    if [[ "$all_namespaces" == "false" && "$all_releases" == "false" && -z "$release" ]]; then
        log_error "Must specify either a release name (-r), all releases in namespace (-a), or all releases in all namespaces (-A)"
        usage
        exit 1
    fi
    
    # Check prerequisites
    check_helm
    check_kubectl
    
    log_info "Starting Helm cleanup operation..."
    if [[ "$dry_run" == "true" ]]; then
        log_warning "DRY RUN MODE - No actual changes will be made"
    fi
    
    # Execute cleanup based on options
    if [[ "$all_namespaces" == "true" ]]; then
        cleanup_all_releases_all_namespaces "$timeout" "$dry_run" "$keep_history" "$force"
    elif [[ "$all_releases" == "true" ]]; then
        cleanup_all_releases_in_namespace "$namespace" "$timeout" "$dry_run" "$keep_history" "$force"
    else
        cleanup_release "$release" "$namespace" "$timeout" "$dry_run" "$keep_history" "$force"
    fi
    
    # Delete namespace if requested
    if [[ "$delete_ns" == "true" && "$dry_run" != "true" ]]; then
        delete_namespace "$namespace" "$dry_run" "$force"
    fi
    
    log_success "Helm cleanup operation completed!"
    
    # Show final status
    if [[ "$dry_run" != "true" ]]; then
        log_info "Final status:"
        if [[ "$all_namespaces" == "true" ]]; then
            helm list --all-namespaces
        else
            helm list --namespace "$namespace"
        fi
    fi
}

# Run main function with all arguments
main "$@"