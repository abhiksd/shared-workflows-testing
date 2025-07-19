#!/bin/bash

# AKS Monitoring Deployment Script
# This script deploys the comprehensive monitoring stack to an AKS cluster

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

Deploy AKS monitoring stack including Prometheus, Grafana, Loki, and Azure Monitor integration.

OPTIONS:
    -e, --environment    Environment (dev, staging, production) [required]
    -c, --cluster        AKS cluster name [required]
    -g, --resource-group Resource group name [required]
    -s, --subscription   Azure subscription ID [required]
    -r, --region         Azure region [default: eastus]
    -f, --force          Force deployment even if no changes detected
    -v, --verify         Verify deployment after completion
    -h, --help           Display this help message

EXAMPLES:
    $0 -e dev -c my-aks-dev -g my-rg -s 12345678-1234-1234-1234-123456789abc
    $0 --environment production --cluster my-aks-prod --resource-group my-prod-rg --subscription 12345678-1234-1234-1234-123456789abc --verify

PREREQUISITES:
    - Azure CLI installed and authenticated
    - kubectl installed and configured
    - Helm 3.x installed
    - AKS cluster accessible
    - Proper Azure RBAC permissions

EOF
}

# Parse command line arguments
ENVIRONMENT=""
CLUSTER_NAME=""
RESOURCE_GROUP=""
SUBSCRIPTION_ID=""
REGION="eastus"
FORCE_DEPLOY=false
VERIFY_DEPLOYMENT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -c|--cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -s|--subscription)
            SUBSCRIPTION_ID="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -f|--force)
            FORCE_DEPLOY=true
            shift
            ;;
        -v|--verify)
            VERIFY_DEPLOYMENT=true
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

# Validate required parameters
if [[ -z "$ENVIRONMENT" || -z "$CLUSTER_NAME" || -z "$RESOURCE_GROUP" || -z "$SUBSCRIPTION_ID" ]]; then
    log_error "Missing required parameters"
    usage
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|production)$ ]]; then
    log_error "Environment must be one of: dev, staging, production"
    exit 1
fi

# Check if required tools are installed
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v az &> /dev/null; then
        missing_tools+=("azure-cli")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again"
        exit 1
    fi
    
    log_success "All prerequisites are installed"
}

# Authenticate with Azure and get AKS credentials
setup_azure_access() {
    log_info "Setting up Azure access..."
    
    # Check if already logged in
    if ! az account show &> /dev/null; then
        log_info "Not logged into Azure. Please run 'az login' first"
        exit 1
    fi
    
    # Set subscription
    az account set --subscription "$SUBSCRIPTION_ID"
    log_success "Set Azure subscription to: $SUBSCRIPTION_ID"
    
    # Get AKS credentials
    log_info "Getting AKS credentials..."
    az aks get-credentials \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --overwrite-existing
    
    log_success "Successfully connected to AKS cluster: $CLUSTER_NAME"
}

# Create monitoring namespace
create_monitoring_namespace() {
    log_info "Creating monitoring namespace..."
    
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace monitoring name=monitoring --overwrite
    
    log_success "Monitoring namespace created/updated"
}

# Add Helm repositories
setup_helm_repositories() {
    log_info "Setting up Helm repositories..."
    
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    log_success "Helm repositories updated"
}

# Deploy Prometheus Stack
deploy_prometheus_stack() {
    log_info "Deploying Prometheus Stack..."
    
    helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --values "$PROJECT_ROOT/helm/monitoring/values.yaml" \
        --values "$PROJECT_ROOT/helm/monitoring/values-$ENVIRONMENT.yaml" \
        --set global.environment="$ENVIRONMENT" \
        --set global.clusterName="$CLUSTER_NAME" \
        --set global.azureSubscriptionId="$SUBSCRIPTION_ID" \
        --set global.azureResourceGroup="$RESOURCE_GROUP" \
        --set global.region="$REGION" \
        --set kube-prometheus-stack.prometheus.enabled=true \
        --set kube-prometheus-stack.alertmanager.enabled=true \
        --set kube-prometheus-stack.grafana.enabled=false \
        --wait \
        --timeout=600s
    
    log_success "Prometheus Stack deployed successfully"
}

# Deploy Grafana
deploy_grafana() {
    log_info "Deploying Grafana..."
    
    helm upgrade --install grafana grafana/grafana \
        --namespace monitoring \
        --values "$PROJECT_ROOT/helm/monitoring/values.yaml" \
        --values "$PROJECT_ROOT/helm/monitoring/values-$ENVIRONMENT.yaml" \
        --set global.environment="$ENVIRONMENT" \
        --set global.clusterName="$CLUSTER_NAME" \
        --wait \
        --timeout=300s
    
    log_success "Grafana deployed successfully"
}

# Deploy Loki Stack
deploy_loki_stack() {
    log_info "Deploying Loki Stack..."
    
    helm upgrade --install loki grafana/loki-stack \
        --namespace monitoring \
        --values "$PROJECT_ROOT/helm/monitoring/values.yaml" \
        --values "$PROJECT_ROOT/helm/monitoring/values-$ENVIRONMENT.yaml" \
        --set global.environment="$ENVIRONMENT" \
        --set global.clusterName="$CLUSTER_NAME" \
        --wait \
        --timeout=300s
    
    log_success "Loki Stack deployed successfully"
}

# Deploy custom monitoring resources
deploy_custom_resources() {
    log_info "Deploying custom monitoring resources..."
    
    helm upgrade --install aks-monitoring "$PROJECT_ROOT/helm/monitoring" \
        --namespace monitoring \
        --values "$PROJECT_ROOT/helm/monitoring/values-$ENVIRONMENT.yaml" \
        --set global.environment="$ENVIRONMENT" \
        --set global.clusterName="$CLUSTER_NAME" \
        --set global.azureSubscriptionId="$SUBSCRIPTION_ID" \
        --set global.azureResourceGroup="$RESOURCE_GROUP" \
        --set global.region="$REGION" \
        --wait \
        --timeout=300s
    
    log_success "Custom monitoring resources deployed successfully"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying monitoring deployment..."
    
    log_info "Checking Prometheus pods..."
    kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
    
    log_info "Checking Grafana pods..."
    kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
    
    log_info "Checking Loki pods..."
    kubectl get pods -n monitoring -l app.kubernetes.io/name=loki
    
    log_info "Checking AlertManager pods..."
    kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager
    
    log_info "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=prometheus -n monitoring --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
    
    log_success "All monitoring components are running"
}

# Get access information
get_access_info() {
    log_info "Getting access information..."
    
    echo ""
    echo "=== Grafana Access Information ==="
    
    if [[ "$ENVIRONMENT" == "dev" ]]; then
        NODE_PORT=$(kubectl get svc grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null || echo "N/A")
        echo "Grafana URL: http://$NODE_IP:$NODE_PORT"
    else
        EXTERNAL_IP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
        echo "Grafana URL: http://$EXTERNAL_IP"
    fi
    
    echo "Default admin username: admin"
    ADMIN_PASSWORD=$(kubectl get secret grafana -n monitoring -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d || echo "N/A")
    echo "Admin password: $ADMIN_PASSWORD"
    
    echo ""
    echo "=== Prometheus Access Information ==="
    echo "Prometheus can be accessed via port-forward:"
    echo "kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
    echo "Then access: http://localhost:9090"
    
    echo ""
    echo "=== AlertManager Access Information ==="
    echo "AlertManager can be accessed via port-forward:"
    echo "kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093"
    echo "Then access: http://localhost:9093"
}

# Main deployment function
main() {
    log_info "Starting AKS monitoring deployment..."
    log_info "Environment: $ENVIRONMENT"
    log_info "Cluster: $CLUSTER_NAME"
    log_info "Resource Group: $RESOURCE_GROUP"
    log_info "Subscription: $SUBSCRIPTION_ID"
    log_info "Region: $REGION"
    echo ""
    
    check_prerequisites
    setup_azure_access
    create_monitoring_namespace
    setup_helm_repositories
    
    deploy_prometheus_stack
    deploy_grafana
    deploy_loki_stack
    deploy_custom_resources
    
    if [[ "$VERIFY_DEPLOYMENT" == true ]]; then
        verify_deployment
    fi
    
    get_access_info
    
    echo ""
    log_success "AKS monitoring deployment completed successfully!"
    log_info "Next steps:"
    log_info "1. Access Grafana dashboard to view metrics"
    log_info "2. Configure alert notification channels in AlertManager"
    log_info "3. Import additional dashboards as needed"
    log_info "4. Configure application monitoring endpoints"
    echo ""
}

# Run main function
main "$@"