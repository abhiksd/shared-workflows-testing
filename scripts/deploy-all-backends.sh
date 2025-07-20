#!/bin/bash

# Deploy All Backends Script
# Usage: ./scripts/deploy-all-backends.sh <environment> [--dry-run]
# Example: ./scripts/deploy-all-backends.sh dev
#          ./scripts/deploy-all-backends.sh staging --dry-run

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <environment> [--dry-run]"
    echo ""
    echo "Environments:"
    echo "  dev         - Development environment"
    echo "  staging     - Staging environment"
    echo "  production  - Production environment"
    echo ""
    echo "Options:"
    echo "  --dry-run   - Show what would be deployed without actually deploying"
    echo ""
    echo "Examples:"
    echo "  $0 dev"
    echo "  $0 staging --dry-run"
    echo "  $0 production"
}

# Check if environment is provided
if [ $# -lt 1 ]; then
    print_error "Environment not specified"
    show_usage
    exit 1
fi

ENVIRONMENT=$1
DRY_RUN=""

# Parse additional arguments
if [ "$2" = "--dry-run" ]; then
    DRY_RUN="--dry-run"
    print_warning "Running in dry-run mode - no actual deployments will be performed"
fi

# Validate environment
case $ENVIRONMENT in
    dev|staging|production)
        print_status "Deploying to $ENVIRONMENT environment"
        ;;
    *)
        print_error "Invalid environment: $ENVIRONMENT"
        show_usage
        exit 1
        ;;
esac

# Define backends
JAVA_BACKENDS=("java-backend1" "java-backend2" "java-backend3")
NODEJS_BACKENDS=("nodejs-backend1" "nodejs-backend2" "nodejs-backend3")

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed. Please install Helm first."
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Function to deploy a backend
deploy_backend() {
    local backend=$1
    local environment=$2
    local dry_run=$3
    
    print_status "Deploying $backend to $environment..."
    
    # Check if values file exists
    if [ ! -f "helm/$backend/values-$environment.yaml" ]; then
        print_error "Values file not found: helm/$backend/values-$environment.yaml"
        return 1
    fi
    
    # Prepare helm command
    local helm_cmd="helm upgrade --install $backend-$environment ./helm/$backend"
    helm_cmd="$helm_cmd --namespace $environment"
    helm_cmd="$helm_cmd --create-namespace"
    helm_cmd="$helm_cmd --values ./helm/$backend/values-$environment.yaml"
    helm_cmd="$helm_cmd --set global.environment=$environment"
    helm_cmd="$helm_cmd --wait --timeout=10m"
    
    if [ "$dry_run" = "--dry-run" ]; then
        helm_cmd="$helm_cmd --dry-run"
        print_status "DRY RUN: $helm_cmd"
    else
        print_status "Executing: $helm_cmd"
    fi
    
    # Execute helm command
    if eval $helm_cmd; then
        if [ "$dry_run" != "--dry-run" ]; then
            print_success "$backend deployed successfully to $environment"
        else
            print_success "$backend dry-run completed successfully"
        fi
        return 0
    else
        print_error "Failed to deploy $backend to $environment"
        return 1
    fi
}

# Function to verify deployment
verify_deployment() {
    local backend=$1
    local environment=$2
    
    print_status "Verifying $backend deployment in $environment..."
    
    # Check pods
    if kubectl get pods -n $environment -l app.kubernetes.io/name=$backend | grep -q Running; then
        print_success "$backend pods are running"
    else
        print_warning "$backend pods may not be ready yet"
    fi
    
    # Check ingress
    if kubectl get ingress -n $environment | grep -q $backend; then
        print_success "$backend ingress is configured"
    else
        print_warning "$backend ingress not found"
    fi
}

# Main deployment function
main() {
    print_status "Starting deployment of all backends to $ENVIRONMENT environment"
    echo ""
    
    # Track deployment results
    declare -A deployment_results
    total_backends=$((${#JAVA_BACKENDS[@]} + ${#NODEJS_BACKENDS[@]}))
    successful_deployments=0
    failed_deployments=0
    
    # Deploy Java backends
    print_status "Deploying Java backends..."
    for backend in "${JAVA_BACKENDS[@]}"; do
        if deploy_backend $backend $ENVIRONMENT $DRY_RUN; then
            deployment_results[$backend]="SUCCESS"
            ((successful_deployments++))
            if [ "$DRY_RUN" != "--dry-run" ]; then
                verify_deployment $backend $ENVIRONMENT
            fi
        else
            deployment_results[$backend]="FAILED"
            ((failed_deployments++))
        fi
        echo ""
    done
    
    # Deploy Node.js backends
    print_status "Deploying Node.js backends..."
    for backend in "${NODEJS_BACKENDS[@]}"; do
        if deploy_backend $backend $ENVIRONMENT $DRY_RUN; then
            deployment_results[$backend]="SUCCESS"
            ((successful_deployments++))
            if [ "$DRY_RUN" != "--dry-run" ]; then
                verify_deployment $backend $ENVIRONMENT
            fi
        else
            deployment_results[$backend]="FAILED"
            ((failed_deployments++))
        fi
        echo ""
    done
    
    # Print summary
    echo "=================================================="
    print_status "DEPLOYMENT SUMMARY"
    echo "=================================================="
    print_status "Environment: $ENVIRONMENT"
    print_status "Total backends: $total_backends"
    print_success "Successful deployments: $successful_deployments"
    if [ $failed_deployments -gt 0 ]; then
        print_error "Failed deployments: $failed_deployments"
    fi
    echo ""
    
    # Print individual results
    print_status "Individual Results:"
    for backend in "${!deployment_results[@]}"; do
        if [ "${deployment_results[$backend]}" = "SUCCESS" ]; then
            print_success "$backend: ${deployment_results[$backend]}"
        else
            print_error "$backend: ${deployment_results[$backend]}"
        fi
    done
    
    echo ""
    if [ $failed_deployments -eq 0 ]; then
        print_success "All backends deployed successfully!"
        if [ "$DRY_RUN" != "--dry-run" ]; then
            echo ""
            print_status "You can now test the deployments using:"
            echo "curl https://$ENVIRONMENT.mydomain.com/backend1/actuator/health"
            echo "curl https://$ENVIRONMENT.mydomain.com/backend2/actuator/health" 
            echo "curl https://$ENVIRONMENT.mydomain.com/backend3/actuator/health"
        fi
    else
        print_error "Some deployments failed. Please check the logs above."
        exit 1
    fi
}

# Run main function
main