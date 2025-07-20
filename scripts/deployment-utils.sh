#!/bin/bash

# Deployment validation utilities
# This file contains deployment-specific helper functions

source "$(dirname "${BASH_SOURCE[0]}")/common-utils.sh"

# Environment-specific deployment rules
can_deploy_to_environment() {
    local env=$1 ref=$2 event_name=$3
    
    case "$env" in
        dev)
            is_develop_branch || [[ "$event_name" == "workflow_dispatch" ]]
            ;;
        staging)
            is_main_branch || [[ "$event_name" == "workflow_dispatch" ]]
            ;;
        production)
            is_release_branch || is_tag || [[ "$event_name" == "workflow_dispatch" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# Auto-detect environment from branch
auto_detect_environment() {
    if is_develop_branch; then
        echo "dev"
    elif is_main_branch; then
        echo "staging"
    elif is_release_branch || is_tag; then
        echo "production"
    else
        echo "unknown"
    fi
}

# Validate deployment inputs and set outputs
validate_and_set_deployment() {
    local env_input=$1
    local target_env actual_env should_deploy cluster_info
    
    # Auto-detect or use provided environment
    if [[ "$env_input" == "auto" ]]; then
        target_env=$(auto_detect_environment)
        log_info "Auto-detected environment: $target_env"
    else
        target_env="$env_input"
        log_info "Using specified environment: $target_env"
    fi
    
    # Validate environment
    if ! validate_environment "$target_env"; then
        echo "should_deploy=false" >> "$GITHUB_OUTPUT"
        echo "target_environment=unknown" >> "$GITHUB_OUTPUT"
        return 1
    fi
    
    # Check deployment rules
    if can_deploy_to_environment "$target_env" "$GITHUB_REF" "$GITHUB_EVENT_NAME"; then
        should_deploy="true"
        log_success "$target_env deployment approved"
    else
        should_deploy="false"
        log_error "$target_env deployment blocked by branch rules"
    fi
    
    # Get cluster information
    cluster_info=$(get_cluster_info "$target_env")
    read -r cluster_name resource_group <<< "$cluster_info"
    
    # Set GitHub outputs
    {
        echo "should_deploy=$should_deploy"
        echo "target_environment=$target_env"
        echo "aks_cluster_name=$cluster_name"
        echo "aks_resource_group=$resource_group"
    } >> "$GITHUB_OUTPUT"
    
    log_info "Deployment decision: should_deploy=$should_deploy"
    return 0
}

# Determine deployment strategy
get_deployment_strategy() {
    local env=$1
    case "$env" in
        production) echo "rolling" ;;
        staging) echo "blue-green" ;;
        dev) echo "recreate" ;;
        *) echo "rolling" ;;
    esac
}

# Check if changes require deployment
should_deploy_based_on_changes() {
    local build_context=$1 force_deploy=$2 changed_files=$3
    
    # Force deploy if requested
    [[ "$force_deploy" == "true" ]] && return 0
    
    # Always deploy for tags and releases
    (is_tag || is_release_branch) && return 0
    
    # Check for relevant file changes
    has_changes_in_path "$build_context" "$changed_files" && return 0
    echo "$changed_files" | grep -q "Dockerfile\|helm/\|\.github/" && return 0
    
    return 1
}

# Rollback validation
validate_rollback_request() {
    local env=$1 strategy=$2 target_version=$3 target_revision=$4
    
    validate_environment "$env" || return 1
    
    case "$strategy" in
        previous-version)
            echo "previous"
            ;;
        specific-version)
            [[ -n "$target_version" ]] || { log_error "Target version required"; return 1; }
            echo "$target_version"
            ;;
        specific-revision)
            [[ -n "$target_revision" ]] || { log_error "Target revision required"; return 1; }
            echo "$target_revision"
            ;;
        *)
            log_error "Invalid rollback strategy: $strategy"
            return 1
            ;;
    esac
}