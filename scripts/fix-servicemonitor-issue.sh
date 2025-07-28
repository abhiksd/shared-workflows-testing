#!/bin/bash

# Script to fix ServiceMonitor CRD issue by deploying monitoring stack first
set -e

echo "🔧 Fixing ServiceMonitor CRD Issue for SQE Environment"
echo "=================================================="

# Configuration
ENVIRONMENT="sqe"
AKS_CLUSTER_NAME="aks-cluster-sqe"
AKS_RESOURCE_GROUP="rg-aks-sqe"
AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-your-subscription-id}"

echo "Environment: $ENVIRONMENT"
echo "AKS Cluster: $AKS_CLUSTER_NAME"
echo "Resource Group: $AKS_RESOURCE_GROUP"
echo ""

# Step 1: Verify cluster connection
echo "📋 Step 1: Verifying AKS cluster connection..."
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Not connected to Kubernetes cluster. Getting credentials..."
    az aks get-credentials \
        --resource-group "$AKS_RESOURCE_GROUP" \
        --name "$AKS_CLUSTER_NAME" \
        --overwrite-existing
    echo "✅ Connected to AKS cluster"
else
    echo "✅ Already connected to Kubernetes cluster"
fi
echo ""

# Step 2: Check if monitoring namespace exists
echo "📋 Step 2: Checking monitoring namespace..."
if ! kubectl get namespace monitoring >/dev/null 2>&1; then
    echo "Creating monitoring namespace..."
    kubectl create namespace monitoring
    kubectl label namespace monitoring name=monitoring
    echo "✅ Monitoring namespace created"
else
    echo "✅ Monitoring namespace already exists"
fi
echo ""

# Step 3: Check if ServiceMonitor CRD exists
echo "📋 Step 3: Checking ServiceMonitor CRD..."
if ! kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
    echo "❌ ServiceMonitor CRD not found. Need to install Prometheus Operator."
    INSTALL_MONITORING=true
else
    echo "✅ ServiceMonitor CRD already exists"
    INSTALL_MONITORING=false
fi
echo ""

# Step 4: Install monitoring stack if needed
if [ "$INSTALL_MONITORING" = true ]; then
    echo "📋 Step 4: Installing kube-prometheus-stack..."
    
    # Add Helm repositories
    echo "Adding Helm repositories..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
    helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
    helm repo update >/dev/null 2>&1
    echo "✅ Helm repositories updated"
    
    # Deploy kube-prometheus-stack
    echo "Deploying kube-prometheus-stack..."
    helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --values helm/monitoring/values.yaml \
        --values helm/monitoring/values-sqe.yaml \
        --set global.environment=sqe \
        --set global.clusterName="$AKS_CLUSTER_NAME" \
        --set global.azureSubscriptionId="$AZURE_SUBSCRIPTION_ID" \
        --set global.azureResourceGroup="$AKS_RESOURCE_GROUP" \
        --wait \
        --timeout=600s
    
    echo "✅ kube-prometheus-stack deployed successfully"
else
    echo "📋 Step 4: Skipping monitoring installation (already exists)"
fi
echo ""

# Step 5: Verify ServiceMonitor CRD
echo "📋 Step 5: Final verification..."
if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
    echo "✅ ServiceMonitor CRD is now available"
    echo "✅ Applications can now be deployed with ServiceMonitor resources"
else
    echo "❌ ServiceMonitor CRD still not available. Check the monitoring stack deployment."
    exit 1
fi
echo ""

# Step 6: Show next steps
echo "🎯 Next Steps:"
echo "1. ✅ ServiceMonitor CRD is now installed"
echo "2. 🚀 You can now deploy your applications without ServiceMonitor errors"
echo "3. 📊 Applications will automatically be discovered by Prometheus for monitoring"
echo ""

echo "🔗 Useful Commands:"
echo "# Check monitoring stack status:"
echo "kubectl get pods -n monitoring"
echo ""
echo "# View ServiceMonitor resources:"
echo "kubectl get servicemonitors -A"
echo ""
echo "# Access Prometheus (port-forward):"
echo "kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo ""

echo "✅ ServiceMonitor issue resolution complete!"