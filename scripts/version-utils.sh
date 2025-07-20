#!/bin/bash

# Version calculation utilities
# This file contains version generation and tagging logic

source "$(dirname "${BASH_SOURCE[0]}")/common-utils.sh"

# Generate version based on strategy
generate_version() {
    local env=$1 app_name=$2
    local version image_tag helm_version
    
    if is_tag; then
        # Use tag as version
        local tag_version="${GITHUB_REF#refs/tags/}"
        version="$tag_version"
        image_tag="$tag_version"
        helm_version="$tag_version"
        
    elif is_release_branch; then
        # Generate semantic version for release
        version=$(get_release_version)
        image_tag="$version"
        helm_version="$version"
        
    elif [[ "$env" == "production" ]]; then
        # Production version with date
        local date_stamp=$(get_date_stamp)
        local short_sha=$(get_short_sha)
        version="v1.0.0-${date_stamp}-${short_sha}"
        image_tag="$version"
        helm_version="$version"
        
    else
        # Development version
        local short_sha=$(get_short_sha)
        version="${env}-${short_sha}"
        image_tag="${env}-${short_sha}"
        helm_version="0.1.0-${env}-${short_sha}"
    fi
    
    echo "$version $image_tag $helm_version"
}

# Get release version from branch or calculate next
get_release_version() {
    local release_branch="${GITHUB_REF#refs/heads/release/}"
    
    if [[ "$release_branch" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        echo "v$release_branch"
    else
        # Auto-increment from latest tag
        local latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
        increment_version "$latest_tag"
    fi
}

# Increment version number
increment_version() {
    local version=$1
    local major minor patch
    
    if [[ "$version" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        major=${BASH_REMATCH[1]}
        minor=${BASH_REMATCH[2]}
        patch=${BASH_REMATCH[3]}
        patch=$((patch + 1))
        echo "v${major}.${minor}.${patch}"
    else
        echo "v0.0.1"
    fi
}

# Set version outputs for GitHub Actions
set_version_outputs() {
    local env=$1 app_name=$2
    local version_info
    
    version_info=$(generate_version "$env" "$app_name")
    read -r version image_tag helm_version <<< "$version_info"
    
    {
        echo "version=$version"
        echo "image_tag=$image_tag"
        echo "helm_version=$helm_version"
    } >> "$GITHUB_OUTPUT"
    
    log_info "Generated versions: version=$version, image_tag=$image_tag, helm_version=$helm_version"
}