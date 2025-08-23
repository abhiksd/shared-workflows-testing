# Helm Deployment Cleanup Guide

This guide provides comprehensive instructions for cleaning up Helm deployments and their associated namespaces safely and efficiently.

## 🎯 Quick Start

For quick cleanup, use the automated script:

```bash
# Cleanup a specific release
./scripts/cleanup-helm-deployments.sh -r my-app -n production

# Cleanup all releases in a namespace and delete the namespace
./scripts/cleanup-helm-deployments.sh -n monitoring -a -d

# Dry run to see what would be deleted
./scripts/cleanup-helm-deployments.sh -r my-app -n production --dry-run
```

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Automated Cleanup Script](#automated-cleanup-script)
3. [Manual Cleanup Commands](#manual-cleanup-commands)
4. [Common Scenarios](#common-scenarios)
5. [Troubleshooting](#troubleshooting)
6. [Best Practices](#best-practices)
7. [Emergency Procedures](#emergency-procedures)

## Prerequisites

Before starting cleanup operations, ensure you have:

- `helm` CLI installed and configured
- `kubectl` CLI installed and configured
- Access to the target Kubernetes cluster
- Appropriate RBAC permissions for the target namespaces

### Verify Your Setup

```bash
# Check Helm version
helm version

# Check kubectl context
kubectl config current-context

# List current Helm releases
helm list --all-namespaces
```

## Automated Cleanup Script

The `cleanup-helm-deployments.sh` script provides comprehensive cleanup functionality with safety checks.

### Script Location

```bash
./scripts/cleanup-helm-deployments.sh
```

### Usage Examples

#### Single Release Cleanup

```bash
# Basic cleanup
./scripts/cleanup-helm-deployments.sh -r my-app -n production

# With custom timeout
./scripts/cleanup-helm-deployments.sh -r my-app -n production -t 600

# Keep release history
./scripts/cleanup-helm-deployments.sh -r my-app -n production --keep-history
```

#### Namespace-wide Cleanup

```bash
# Cleanup all releases in a namespace
./scripts/cleanup-helm-deployments.sh -n monitoring -a

# Cleanup all releases and delete the namespace
./scripts/cleanup-helm-deployments.sh -n monitoring -a -d

# Force cleanup without prompts
./scripts/cleanup-helm-deployments.sh -n monitoring -a -d -f
```

#### Cluster-wide Cleanup

```bash
# Cleanup all releases across all namespaces (use with extreme caution!)
./scripts/cleanup-helm-deployments.sh -A -f
```

#### Dry Run Operations

```bash
# See what would be deleted without actually deleting
./scripts/cleanup-helm-deployments.sh -r my-app -n production --dry-run
./scripts/cleanup-helm-deployments.sh -n monitoring -a --dry-run
```

## Manual Cleanup Commands

For situations where you prefer manual control or the automated script isn't available.

### 1. List Current Deployments

```bash
# List all Helm releases across all namespaces
helm list --all-namespaces

# List releases in a specific namespace
helm list -n <namespace>

# List releases with additional details
helm list --all-namespaces -o table
```

### 2. Uninstall Specific Release

```bash
# Basic uninstall
helm uninstall <release-name> -n <namespace>

# Uninstall with custom timeout
helm uninstall <release-name> -n <namespace> --timeout 600s

# Uninstall and keep history for potential rollback
helm uninstall <release-name> -n <namespace> --keep-history

# Force uninstall (use with caution)
helm uninstall <release-name> -n <namespace> --force
```

### 3. Verify Cleanup

```bash
# Check remaining resources in namespace
kubectl get all -n <namespace>

# Check for Helm-managed resources specifically
kubectl get all -l "app.kubernetes.io/managed-by=Helm" -n <namespace>

# Check for remaining secrets
kubectl get secrets -n <namespace> -l "owner=helm"
```

### 4. Clean Up Remaining Resources

```bash
# Delete specific resource types
kubectl delete deployments,services,configmaps -l "app.kubernetes.io/managed-by=Helm" -n <namespace>

# Delete PVCs if they weren't automatically cleaned up
kubectl delete pvc -l "app.kubernetes.io/managed-by=Helm" -n <namespace>

# Delete Helm secrets
kubectl delete secrets -l "owner=helm" -n <namespace>
```

### 5. Delete Namespace

```bash
# Check namespace contents before deletion
kubectl get all -n <namespace>

# Delete namespace (this will delete ALL resources in the namespace)
kubectl delete namespace <namespace>

# Force delete stuck namespace
kubectl delete namespace <namespace> --force --grace-period=0
```

## Common Scenarios

### Scenario 1: Clean Up Monitoring Stack

Based on your project's monitoring setup:

```bash
# Method 1: Using the automated script
./scripts/cleanup-helm-deployments.sh -n monitoring -a -d

# Method 2: Manual cleanup
helm uninstall kube-prometheus-stack -n monitoring
helm uninstall grafana -n monitoring
helm uninstall loki -n monitoring
helm uninstall aks-monitoring -n monitoring
kubectl delete namespace monitoring
```

### Scenario 2: Clean Up Application Deployment

```bash
# For a typical Spring Boot application
./scripts/cleanup-helm-deployments.sh -r java-backend1-ppr -n production

# Manual equivalent
helm uninstall java-backend1-ppr -n production
kubectl get all -l "app.kubernetes.io/name=java-backend1" -n production
kubectl delete all -l "app.kubernetes.io/name=java-backend1" -n production
```

### Scenario 3: Clean Up Development Environment

```bash
# Clean up all development releases
./scripts/cleanup-helm-deployments.sh -n development -a -d -f

# Manual cleanup of multiple releases
for release in $(helm list -n development --short); do
    helm uninstall "$release" -n development
done
kubectl delete namespace development
```

### Scenario 4: Emergency Full Cleanup

```bash
# DANGER: This will remove ALL Helm releases!
./scripts/cleanup-helm-deployments.sh -A -f

# Manual equivalent (use with extreme caution)
helm list --all-namespaces --short | while read -r release namespace; do
    helm uninstall "$release" -n "$namespace"
done
```

## Troubleshooting

### Stuck Releases

When releases won't uninstall normally:

```bash
# Check release status
helm status <release-name> -n <namespace>

# Check for stuck resources
kubectl get all -l "app.kubernetes.io/managed-by=Helm" -n <namespace>

# Force cleanup stuck resources
kubectl patch <resource-type>/<resource-name> -n <namespace> -p '{"metadata":{"finalizers":[]}}' --type=merge
kubectl delete <resource-type>/<resource-name> -n <namespace> --force --grace-period=0
```

### Stuck Namespaces

When namespaces won't delete:

```bash
# Check namespace status
kubectl get namespace <namespace> -o yaml

# Check for finalizers
kubectl get namespace <namespace> -o jsonpath='{.spec.finalizers}'

# Remove finalizers (dangerous - use carefully)
kubectl patch namespace <namespace> -p '{"spec":{"finalizers":[]}}' --type=merge

# Alternative: Use kubectl directly
kubectl delete namespace <namespace> --force --grace-period=0
```

### Persistent Volumes

Handle PVs that aren't automatically cleaned up:

```bash
# List PVs that might be left behind
kubectl get pv | grep <namespace>

# Check PV reclaim policy
kubectl get pv <pv-name> -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'

# Manually delete PV if needed
kubectl delete pv <pv-name>
```

### Helm Secrets Cleanup

Clean up Helm-related secrets:

```bash
# List Helm secrets
kubectl get secrets --all-namespaces -l "owner=helm"

# Delete specific Helm secret
kubectl delete secret sh.helm.release.v1.<release-name>.v<version> -n <namespace>

# Clean up all Helm secrets for a release
kubectl delete secrets -l "name=<release-name>" -n <namespace>
```

## Best Practices

### 1. Always Use Dry Run First

```bash
# Test what will be deleted
./scripts/cleanup-helm-deployments.sh -r my-app -n production --dry-run
helm uninstall my-app -n production --dry-run
```

### 2. Backup Before Cleanup

```bash
# Export release values
helm get values <release-name> -n <namespace> > backup-values.yaml

# Export all release information
helm get all <release-name> -n <namespace> > backup-release.yaml

# Backup persistent data if applicable
kubectl get pvc -n <namespace> -o yaml > backup-pvcs.yaml
```

### 3. Verify Prerequisites

```bash
# Check cluster connectivity
kubectl cluster-info

# Verify permissions
kubectl auth can-i delete pods -n <namespace>
kubectl auth can-i delete namespace <namespace>
```

### 4. Gradual Cleanup

For production environments, clean up gradually:

1. Stop traffic to the application
2. Scale down deployments
3. Remove services and ingress
4. Clean up persistent resources
5. Finally, uninstall Helm release

```bash
# Scale down deployments first
kubectl scale deployment <deployment-name> -n <namespace> --replicas=0

# Remove external access
kubectl delete ingress -l "app.kubernetes.io/managed-by=Helm" -n <namespace>
kubectl delete service -l "app.kubernetes.io/managed-by=Helm" -n <namespace>

# Then uninstall
helm uninstall <release-name> -n <namespace>
```

### 5. Monitor Resource Cleanup

```bash
# Watch resources being deleted
kubectl get all -n <namespace> -w

# Monitor namespace deletion
kubectl get namespace <namespace> -w
```

## Emergency Procedures

### Complete Environment Reset

When you need to completely reset an environment:

```bash
#!/bin/bash
# emergency-reset.sh

NAMESPACE="<your-namespace>"

echo "WARNING: This will completely reset namespace $NAMESPACE"
read -p "Are you absolutely sure? (type 'YES' to continue): " confirm

if [[ "$confirm" == "YES" ]]; then
    # Stop all traffic
    kubectl patch service -n "$NAMESPACE" --type='merge' -p='{"spec":{"type":"ClusterIP"}}' --all
    
    # Scale down all deployments
    kubectl scale deployment --all --replicas=0 -n "$NAMESPACE"
    
    # Wait for pods to terminate
    kubectl wait --for=delete pod --all -n "$NAMESPACE" --timeout=300s
    
    # Uninstall all Helm releases
    for release in $(helm list -n "$NAMESPACE" --short); do
        helm uninstall "$release" -n "$NAMESPACE" --timeout=600s
    done
    
    # Force cleanup remaining resources
    kubectl delete all --all -n "$NAMESPACE" --force --grace-period=0
    
    # Delete the namespace
    kubectl delete namespace "$NAMESPACE"
    
    echo "Environment reset complete"
else
    echo "Operation cancelled"
fi
```

### Force Cleanup Script

For stuck resources that won't delete normally:

```bash
#!/bin/bash
# force-cleanup.sh

NAMESPACE="$1"
RELEASE="$2"

if [[ -z "$NAMESPACE" ]]; then
    echo "Usage: $0 <namespace> [release-name]"
    exit 1
fi

echo "Force cleaning namespace: $NAMESPACE"

# Remove finalizers from all resources
for resource in $(kubectl get all -n "$NAMESPACE" -o name 2>/dev/null); do
    kubectl patch "$resource" -n "$NAMESPACE" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
done

# Force delete all resources
kubectl delete all --all -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true

# Clean up secrets
kubectl delete secrets --all -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true

# Clean up configmaps (except system ones)
kubectl delete configmaps -n "$NAMESPACE" --field-selector='metadata.name!=kube-root-ca.crt' --force --grace-period=0 2>/dev/null || true

# If namespace should be deleted
read -p "Delete namespace $NAMESPACE? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl patch namespace "$NAMESPACE" -p '{"spec":{"finalizers":[]}}' --type=merge 2>/dev/null || true
    kubectl delete namespace "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
fi

echo "Force cleanup completed"
```

## Security Considerations

### RBAC Requirements

Ensure you have appropriate permissions:

```yaml
# Minimum RBAC for cleanup operations
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: helm-cleanup
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets", "namespaces"]
  verbs: ["get", "list", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
  verbs: ["get", "list", "delete"]
- apiGroups: ["extensions", "networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "delete"]
```

### Audit Trail

Keep track of cleanup operations:

```bash
# Log cleanup operations
echo "$(date): Cleaned up release $RELEASE_NAME in namespace $NAMESPACE" >> /var/log/helm-cleanup.log

# Use kubectl with audit logging
kubectl delete deployment my-app -n production --record
```

## Conclusion

This guide covers comprehensive cleanup procedures for Helm deployments. Always start with dry runs, backup important data, and use the automated script when possible for consistency and safety.

For questions or issues, refer to the troubleshooting section or consult your team's DevOps documentation.