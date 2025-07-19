# Helm Chart Comprehensive Guide

This guide provides detailed instructions for working with the Helm charts used in the production-grade AKS deployment platform.

## 📋 Table of Contents

- [Chart Overview](#-chart-overview)
- [Chart Structure](#-chart-structure)
- [Values Configuration](#-values-configuration)
- [Template Customization](#-template-customization)
- [Environment-Specific Deployments](#-environment-specific-deployments)
- [Advanced Features](#-advanced-features)
- [Troubleshooting](#-troubleshooting)
- [Best Practices](#-best-practices)

## 📊 Chart Overview

### Available Charts

| Chart | Purpose | Application Type | Key Features |
|-------|---------|------------------|--------------|
| `java-app` | Java Spring Boot applications | Java/Maven | Actuator integration, JVM optimization |
| `nodejs-app` | Node.js applications | Node.js/npm | PM2 support, health endpoints |
| `shared-app` | Generic applications | Any | Flexible, configurable templates |

### Chart Dependencies
```yaml
# All charts include:
- Kubernetes 1.20+
- Helm 3.8+
- Azure Key Vault CSI Driver (optional)
- Prometheus monitoring (optional)
- Ingress controller (optional)
```

## 🏗️ Chart Structure

### Standard Chart Layout
```
helm/java-app/
├── Chart.yaml                 # Chart metadata
├── values.yaml               # Default values
├── values-dev.yaml           # Development overrides
├── values-staging.yaml       # Staging overrides
├── values-production.yaml    # Production overrides
└── templates/
    ├── _helpers.tpl          # Template helpers
    ├── configmap.yaml        # Configuration data
    ├── deployment.yaml       # Main application deployment
    ├── ingress.yaml          # Ingress configuration
    ├── poddisruptionbudget.yaml  # PDB for availability
    ├── secretproviderclass.yaml  # Azure Key Vault integration
    ├── service.yaml          # Service definition
    └── serviceaccount.yaml   # Service account
```

### Chart Metadata (Chart.yaml)
```yaml
apiVersion: v2
name: java-app
description: A Helm chart for Java Spring Boot Application
type: application
version: 0.1.0
appVersion: "1.0.0"

keywords:
  - java
  - spring-boot
  - microservice

maintainers:
  - name: DevOps Team
    email: devops@company.com

dependencies: []

annotations:
  category: Application
  licenses: Apache-2.0
```

## ⚙️ Values Configuration

### Global Configuration
```yaml
# Global values (applies to all charts)
global:
  environment: dev|staging|production
  applicationName: java-app
  applicationType: java-springboot
  registry: myregistry.azurecr.io
  imageTag: latest
  namespace: default
```

### Application Configuration
```yaml
# Application-specific configuration
replicaCount: 1

image:
  repository: myregistry.azurecr.io/java-app
  pullPolicy: IfNotPresent
  tag: "latest"

nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations: {}
  name: ""
```

### Resource Management
```yaml
resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi

# Horizontal Pod Autoscaling
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80

# Pod Disruption Budget
podDisruptionBudget:
  enabled: false
  minAvailable: 1
  # OR maxUnavailable: 1
```

### Service Configuration
```yaml
service:
  type: ClusterIP
  port: 8080
  targetPort: 8080
  annotations: {}

ingress:
  enabled: false
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "1024m"
  hosts:
    - host: java-app.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: java-app-tls
      hosts:
        - java-app.example.com
```

### Environment Variables
```yaml
env:
  - name: ENVIRONMENT
    value: "production"
  - name: APPLICATION_NAME
    value: "java-app"
  - name: SERVER_PORT
    value: "8080"
  - name: SPRING_PROFILES_ACTIVE
    value: "production"

# ConfigMap data
configMap:
  enabled: true
  data:
    LOG_LEVEL: "INFO"
    JAVA_OPTS: "-Xms1g -Xmx2g -XX:+UseG1GC"
    DATABASE_POOL_SIZE: "20"
```

### Health Checks
```yaml
livenessProbe:
  enabled: true
  httpGet:
    path: /actuator/health
    port: 8080
  initialDelaySeconds: 60
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  enabled: true
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

### Security Configuration
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  readOnlyRootFilesystem: true

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000

networkPolicy:
  enabled: false
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: ingress-nginx
      ports:
      - protocol: TCP
        port: 8080
```

## 🎨 Template Customization

### Helper Functions (_helpers.tpl)
```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "java-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "java-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "java-app.labels" -}}
helm.sh/chart: {{ include "java-app.chart" . }}
{{ include "java-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/environment: {{ .Values.global.environment }}
{{- end }}
```

### Deployment Template
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "java-app.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "java-app.labels" . | nindent 4 }}
  annotations:
    deployment.kubernetes.io/revision: "{{ .Release.Revision }}"
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "java-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "java-app.selectorLabels" . | nindent 8 }}
    spec:
      serviceAccountName: {{ include "java-app.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          {{- if .Values.livenessProbe.enabled }}
          livenessProbe:
            {{- toYaml .Values.livenessProbe.httpGet | nindent 12 }}
            initialDelaySeconds: {{ .Values.livenessProbe.initialDelaySeconds }}
            periodSeconds: {{ .Values.livenessProbe.periodSeconds }}
            timeoutSeconds: {{ .Values.livenessProbe.timeoutSeconds }}
            failureThreshold: {{ .Values.livenessProbe.failureThreshold }}
          {{- end }}
          {{- if .Values.readinessProbe.enabled }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe.httpGet | nindent 12 }}
            initialDelaySeconds: {{ .Values.readinessProbe.initialDelaySeconds }}
            periodSeconds: {{ .Values.readinessProbe.periodSeconds }}
            timeoutSeconds: {{ .Values.readinessProbe.timeoutSeconds }}
            failureThreshold: {{ .Values.readinessProbe.failureThreshold }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

### Azure Key Vault Integration
```yaml
# secretproviderclass.yaml
{{- if .Values.azureKeyVault.enabled }}
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: {{ include "java-app.fullname" . }}-secrets
  namespace: {{ .Release.Namespace }}
spec:
  provider: azure
  parameters:
    useVMManagedIdentity: "false"
    usePodIdentity: "false"
    userAssignedIdentityID: {{ .Values.azureKeyVault.userAssignedIdentityID }}
    keyvaultName: {{ .Values.azureKeyVault.keyvaultName }}
    cloudName: ""
    objects: |
      array:
        {{- range .Values.azureKeyVault.secrets }}
        - |
          objectName: {{ .objectName }}
          objectAlias: {{ .objectAlias }}
          objectType: secret
        {{- end }}
    tenantId: {{ .Values.azureKeyVault.tenantId }}
  {{- if .Values.azureKeyVault.secretObjects }}
  secretObjects:
    {{- range .Values.azureKeyVault.secretObjects }}
    - secretName: {{ .secretName }}
      type: {{ .type }}
      data:
        {{- range .data }}
        - objectName: {{ .objectName }}
          key: {{ .key }}
        {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
```

## 🌍 Environment-Specific Deployments

### Development Environment (values-dev.yaml)
```yaml
# Optimized for development workflow
global:
  environment: dev

replicaCount: 1

image:
  pullPolicy: Always  # Always pull latest

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 1Gi

env:
  - name: SPRING_PROFILES_ACTIVE
    value: "dev"
  - name: LOG_LEVEL
    value: "DEBUG"
  - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
    value: "*"  # Expose all actuator endpoints

configMap:
  data:
    JAVA_OPTS: "-Xms256m -Xmx1g -XX:+UseG1GC -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"

autoscaling:
  enabled: false

monitoring:
  enabled: false

security:
  networkPolicy:
    enabled: false
```

### Staging Environment (values-staging.yaml)
```yaml
# Production-like environment for testing
global:
  environment: staging

replicaCount: 2

image:
  pullPolicy: IfNotPresent

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 1000m
    memory: 2Gi

env:
  - name: SPRING_PROFILES_ACTIVE
    value: "staging"
  - name: LOG_LEVEL
    value: "INFO"

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70

monitoring:
  enabled: true
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/actuator/prometheus"

security:
  networkPolicy:
    enabled: true

azureKeyVault:
  enabled: true
```

### Production Environment (values-production.yaml)
```yaml
# Production-ready configuration
global:
  environment: production

replicaCount: 3

image:
  pullPolicy: IfNotPresent

resources:
  requests:
    cpu: 1000m
    memory: 2Gi
  limits:
    cpu: 2000m
    memory: 4Gi

env:
  - name: SPRING_PROFILES_ACTIVE
    value: "production"
  - name: LOG_LEVEL
    value: "WARN"

configMap:
  data:
    JAVA_OPTS: "-Xms2g -Xmx3g -XX:+UseG1GC -XX:+UseStringDeduplication"

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 60
  targetMemoryUtilizationPercentage: 70

podDisruptionBudget:
  enabled: true
  minAvailable: 2

monitoring:
  enabled: true

security:
  networkPolicy:
    enabled: true
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000

azureKeyVault:
  enabled: true
  keyvaultName: "prod-keyvault"
  secrets:
    - objectName: "database-password"
      objectAlias: "db-password"
    - objectName: "jwt-secret"
      objectAlias: "jwt-secret"
```

## 🚀 Advanced Features

### Custom Resource Definitions (CRDs)
```yaml
# Enable custom resources if needed
customResources:
  enabled: false
  definitions:
    - apiVersion: apiextensions.k8s.io/v1
      kind: CustomResourceDefinition
      metadata:
        name: applications.custom.io
      spec:
        group: custom.io
        versions:
        - name: v1
          served: true
          storage: true
```

### Multi-Container Pods
```yaml
# Sidecar containers configuration
sidecars:
  enabled: false
  containers:
    - name: log-aggregator
      image: fluent/fluent-bit:latest
      volumeMounts:
        - name: varlog
          mountPath: /var/log
    - name: metrics-exporter
      image: prom/node-exporter:latest
      ports:
        - containerPort: 9100
```

### Init Containers
```yaml
# Database migration or setup
initContainers:
  enabled: false
  containers:
    - name: db-migration
      image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
      command: ['sh', '-c', 'java -jar app.jar --spring.profiles.active=migration']
      env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: database-url
```

### Volume Management
```yaml
# Persistent volumes
persistence:
  enabled: false
  storageClass: "default"
  accessMode: ReadWriteOnce
  size: 10Gi
  mountPath: /data

# ConfigMap volumes
volumes:
  - name: config-volume
    configMap:
      name: {{ include "java-app.fullname" . }}-config
  - name: secret-volume
    secret:
      secretName: {{ include "java-app.fullname" . }}-secrets

volumeMounts:
  - name: config-volume
    mountPath: /app/config
  - name: secret-volume
    mountPath: /app/secrets
    readOnly: true
```

### Service Mesh Integration (Istio)
```yaml
# Istio service mesh configuration
istio:
  enabled: false
  gateway:
    enabled: false
    hosts:
      - java-app.example.com
  virtualService:
    enabled: false
    routes:
      - match:
        - uri:
            prefix: "/"
        route:
        - destination:
            host: java-app
            port:
              number: 8080
  destinationRule:
    enabled: false
    trafficPolicy:
      tls:
        mode: ISTIO_MUTUAL
```

## 🔧 Troubleshooting

### Common Chart Issues

#### 1. Template Rendering Errors
```bash
# Debug template rendering
helm template my-app helm/java-app/ -f helm/java-app/values-dev.yaml

# Check for syntax errors
helm lint helm/java-app/

# Debug with increased verbosity
helm install my-app helm/java-app/ --debug --dry-run
```

#### 2. Values Override Problems
```bash
# Check merged values
helm get values my-app -n development

# Verify value precedence
helm template my-app helm/java-app/ \
  -f helm/java-app/values.yaml \
  -f helm/java-app/values-dev.yaml \
  --set image.tag=v1.2.3
```

#### 3. Resource Creation Failures
```bash
# Check resource status
kubectl get all -l app.kubernetes.io/name=java-app -n development

# Describe failed resources
kubectl describe deployment java-app -n development

# Check events
kubectl get events --sort-by='.metadata.creationTimestamp' -n development
```

#### 4. ConfigMap and Secret Issues
```bash
# Verify ConfigMap data
kubectl get configmap java-app-config -o yaml -n development

# Check Secret Provider Class
kubectl describe secretproviderclass java-app-secrets -n development

# Verify volume mounts
kubectl describe pod -l app=java-app -n development
```

### Debugging Commands
```bash
# Chart validation
helm lint helm/java-app/

# Template debugging
helm template java-app helm/java-app/ --debug

# Installation debugging
helm install java-app helm/java-app/ --debug --dry-run

# Release management
helm list -n development
helm history java-app -n development
helm rollback java-app 1 -n development

# Resource inspection
kubectl get all,configmap,secret -l app.kubernetes.io/name=java-app
```

## 📚 Best Practices

### Chart Development
1. **Use semantic versioning for charts**
2. **Always test templates with lint and dry-run**
3. **Document all values in values.yaml comments**
4. **Use consistent naming conventions**
5. **Include resource limits and requests**

### Template Organization
```yaml
# Organize templates logically:
templates/
├── _helpers.tpl          # Shared template functions
├── configmap.yaml        # Application configuration
├── deployment.yaml       # Main workload
├── service.yaml          # Service definition
├── ingress.yaml          # External access
├── serviceaccount.yaml   # RBAC and identity
├── secretproviderclass.yaml  # Secret management
└── tests/               # Chart tests
    └── test-connection.yaml
```

### Values File Structure
```yaml
# Structure values hierarchically:
global:
  # Global settings

image:
  # Image configuration

service:
  # Service configuration

ingress:
  # Ingress configuration

resources:
  # Resource management

autoscaling:
  # Scaling configuration

monitoring:
  # Observability settings

security:
  # Security policies
```

### Environment Management
1. **Use separate values files per environment**
2. **Keep sensitive data in Key Vault**
3. **Use environment-specific resource sizing**
4. **Configure appropriate health checks**
5. **Enable monitoring in staging and production**

### Security Best Practices
```yaml
# Always include security contexts
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  readOnlyRootFilesystem: true

# Use service accounts
serviceAccount:
  create: true
  annotations:
    azure.workload.identity/client-id: "your-client-id"

# Enable network policies
networkPolicy:
  enabled: true
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: allowed-namespace
```

### Performance Optimization
```yaml
# Right-size resources
resources:
  requests:
    cpu: 100m      # Actual minimum usage
    memory: 256Mi  # Actual minimum usage
  limits:
    cpu: 1000m     # Reasonable maximum
    memory: 2Gi    # Prevent OOM kills

# Configure appropriate scaling
autoscaling:
  enabled: true
  minReplicas: 2  # High availability
  maxReplicas: 10 # Cost control
  targetCPUUtilizationPercentage: 70  # Efficient utilization
```

## 📖 Chart Testing

### Unit Testing
```bash
# Test chart templates
helm unittest helm/java-app/

# Test specific scenarios
helm template test-release helm/java-app/ \
  -f helm/java-app/values-production.yaml \
  --set replicaCount=5
```

### Integration Testing
```bash
# Deploy to test environment
helm install test-java-app helm/java-app/ \
  -f helm/java-app/values-dev.yaml \
  -n test-environment \
  --create-namespace

# Run connectivity tests
helm test test-java-app -n test-environment

# Cleanup test deployment
helm uninstall test-java-app -n test-environment
```

## 🗑️ Cleanup and Resource Removal

### Helm-based Cleanup

#### 1. Standard Helm Uninstall
```bash
# Uninstall a specific release
helm uninstall java-app -n default

# Uninstall with confirmation
helm uninstall java-app -n default --dry-run
helm uninstall java-app -n default

# Uninstall and keep history (for potential rollback)
helm uninstall java-app -n default --keep-history

# Force uninstall (even if some resources fail to delete)
helm uninstall java-app -n default --force

# Uninstall with timeout
helm uninstall java-app -n default --timeout=300s
```

#### 2. Multiple Environment Cleanup
```bash
# Function to cleanup all environments
cleanup_all_environments() {
  local app_name="java-app"
  local environments=("default" "dev" "staging" "production")
  
  for env in "${environments[@]}"; do
    echo "🧹 Cleaning up $app_name in $env environment..."
    
    # Check if release exists
    if helm list -n "$env" | grep -q "$app_name"; then
      echo "Found release $app_name in namespace $env"
      helm uninstall "$app_name" -n "$env"
      echo "✅ Uninstalled $app_name from $env"
    else
      echo "ℹ️  No release $app_name found in namespace $env"
    fi
    
    echo ""
  done
}

# Execute cleanup
cleanup_all_environments
```

#### 3. Cleanup with Resource Verification
```bash
# Enhanced cleanup with verification
cleanup_with_verification() {
  local app_name="java-app"
  local namespace="default"
  
  echo "🔍 Pre-cleanup resource inventory for $app_name in $namespace..."
  
  # List all resources before cleanup
  echo "Helm releases:"
  helm list -n "$namespace" | grep "$app_name" || echo "No Helm releases found"
  
  echo "Kubernetes resources:"
  kubectl get all -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "No labeled resources found"
  
  # Perform cleanup
  echo "🧹 Starting cleanup..."
  helm uninstall "$app_name" -n "$namespace"
  
  # Wait for cleanup completion
  echo "⏳ Waiting for resources to be cleaned up..."
  sleep 30
  
  # Verify cleanup
  echo "🔍 Post-cleanup verification..."
  echo "Remaining Helm releases:"
  helm list -n "$namespace" | grep "$app_name" || echo "✅ No Helm releases remaining"
  
  echo "Remaining Kubernetes resources:"
  kubectl get all -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "✅ No labeled resources remaining"
}

# Execute cleanup with verification
cleanup_with_verification
```

### kubectl-based Manual Cleanup

#### 1. Complete Resource Cleanup by Labels
```bash
# Cleanup all resources by application label
kubectl delete all -l app.kubernetes.io/name=java-app -n default

# Cleanup specific resource types by label
kubectl delete deployment,service,configmap,secret -l app.kubernetes.io/name=java-app -n default

# Cleanup with multiple label selectors
kubectl delete all -l app.kubernetes.io/name=java-app,app.kubernetes.io/instance=java-app -n default

# Force delete stuck resources
kubectl delete all -l app.kubernetes.io/name=java-app -n default --force --grace-period=0
```

#### 2. Step-by-Step Resource Cleanup
```bash
# Comprehensive step-by-step cleanup
cleanup_by_resource_type() {
  local app_name="java-app"
  local namespace="default"
  
  echo "🧹 Starting comprehensive cleanup for $app_name in $namespace..."
  
  # 1. Scale down deployments first
  echo "📉 Scaling down deployments..."
  kubectl scale deployment -l app.kubernetes.io/name="$app_name" --replicas=0 -n "$namespace" 2>/dev/null || echo "No deployments to scale"
  
  # 2. Wait for pods to terminate gracefully
  echo "⏳ Waiting for pods to terminate..."
  kubectl wait --for=delete pod -l app.kubernetes.io/name="$app_name" -n "$namespace" --timeout=60s 2>/dev/null || echo "No pods to wait for"
  
  # 3. Delete in order to avoid dependency issues
  echo "🗑️  Deleting ingresses..."
  kubectl delete ingress -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "No ingresses found"
  
  echo "🗑️  Deleting services..."
  kubectl delete service -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "No services found"
  
  echo "🗑️  Deleting deployments..."
  kubectl delete deployment -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "No deployments found"
  
  echo "🗑️  Deleting replicasets..."
  kubectl delete replicaset -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "No replicasets found"
  
  echo "🗑️  Deleting pods (if any stuck)..."
  kubectl delete pod -l app.kubernetes.io/name="$app_name" -n "$namespace" --force --grace-period=0 2>/dev/null || echo "No pods found"
  
  echo "🗑️  Deleting configmaps..."
  kubectl delete configmap -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "No configmaps found"
  
  echo "🗑️  Deleting secrets..."
  kubectl delete secret -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "No secrets found"
  
  echo "🗑️  Deleting service accounts..."
  kubectl delete serviceaccount -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "No service accounts found"
  
  echo "🗑️  Deleting PVCs..."
  kubectl delete pvc -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "No PVCs found"
  
  echo "🗑️  Deleting network policies..."
  kubectl delete networkpolicy -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "No network policies found"
  
  echo "🗑️  Deleting pod disruption budgets..."
  kubectl delete poddisruptionbudget -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "No PDBs found"
  
  echo "🗑️  Deleting secret provider classes..."
  kubectl delete secretproviderclass -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "No secret provider classes found"
  
  echo "🗑️  Deleting horizontal pod autoscalers..."
  kubectl delete hpa -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "No HPAs found"
  
  echo "✅ Cleanup completed for $app_name in $namespace"
}

# Execute step-by-step cleanup
cleanup_by_resource_type
```

#### 3. Specific Resource Type Cleanup
```bash
# Cleanup specific Kubernetes resources

# Deployments and ReplicaSets
kubectl delete deployment java-app -n default
kubectl delete replicaset -l app.kubernetes.io/name=java-app -n default

# Services and Ingresses
kubectl delete service java-app -n default
kubectl delete ingress java-app -n default

# ConfigMaps and Secrets
kubectl delete configmap java-app-config -n default
kubectl delete secret java-app-secrets -n default

# Persistent Volume Claims
kubectl delete pvc -l app.kubernetes.io/name=java-app -n default

# Azure Key Vault Secret Provider Class
kubectl delete secretproviderclass java-app-secrets -n default

# Pod Disruption Budget
kubectl delete poddisruptionbudget java-app-pdb -n default

# Network Policies
kubectl delete networkpolicy java-app-netpol -n default

# Horizontal Pod Autoscaler
kubectl delete hpa java-app-hpa -n default

# Service Account
kubectl delete serviceaccount java-app -n default
```

### Advanced Cleanup Scenarios

#### 1. Emergency Cleanup (Force Delete Everything)
```bash
# Emergency cleanup when normal deletion hangs
emergency_cleanup() {
  local app_name="java-app"
  local namespace="default"
  
  echo "🚨 EMERGENCY CLEANUP for $app_name in $namespace..."
  echo "⚠️  This will force delete all resources immediately!"
  
  read -p "Are you sure you want to proceed? (yes/no): " confirm
  if [[ $confirm != "yes" ]]; then
    echo "❌ Emergency cleanup cancelled"
    return 1
  fi
  
  # Force delete all resources with zero grace period
  kubectl delete all -l app.kubernetes.io/name="$app_name" -n "$namespace" --force --grace-period=0
  kubectl delete configmap -l app.kubernetes.io/name="$app_name" -n "$namespace" --force --grace-period=0
  kubectl delete secret -l app.kubernetes.io/name="$app_name" -n "$namespace" --force --grace-period=0
  kubectl delete pvc -l app.kubernetes.io/name="$app_name" -n "$namespace" --force --grace-period=0
  kubectl delete secretproviderclass -l app.kubernetes.io/name="$app_name" -n "$namespace" --force --grace-period=0
  kubectl delete networkpolicy -l app.kubernetes.io/name="$app_name" -n "$namespace" --force --grace-period=0
  kubectl delete poddisruptionbudget -l app.kubernetes.io/name="$app_name" -n "$namespace" --force --grace-period=0
  kubectl delete hpa -l app.kubernetes.io/name="$app_name" -n "$namespace" --force --grace-period=0
  
  echo "✅ Emergency cleanup completed"
}

# Use with extreme caution
# emergency_cleanup
```

#### 2. Selective Cleanup (Keep Some Resources)
```bash
# Cleanup everything except secrets and configmaps
selective_cleanup() {
  local app_name="java-app"
  local namespace="default"
  
  echo "🎯 Selective cleanup for $app_name in $namespace (keeping secrets and configmaps)..."
  
  # Delete workload resources
  kubectl delete deployment -l app.kubernetes.io/name="$app_name" -n "$namespace"
  kubectl delete service -l app.kubernetes.io/name="$app_name" -n "$namespace"
  kubectl delete ingress -l app.kubernetes.io/name="$app_name" -n "$namespace"
  kubectl delete hpa -l app.kubernetes.io/name="$app_name" -n "$namespace"
  kubectl delete poddisruptionbudget -l app.kubernetes.io/name="$app_name" -n "$namespace"
  
  # Keep: configmaps, secrets, PVCs, service accounts
  echo "✅ Selective cleanup completed (secrets and configmaps preserved)"
}

# Execute selective cleanup
selective_cleanup
```

#### 3. Namespace-wide Cleanup
```bash
# Cleanup entire namespace (DANGEROUS)
cleanup_entire_namespace() {
  local namespace="$1"
  
  if [[ -z "$namespace" ]]; then
    echo "❌ Error: Namespace parameter required"
    echo "Usage: cleanup_entire_namespace <namespace>"
    return 1
  fi
  
  if [[ "$namespace" == "default" || "$namespace" == "kube-system" || "$namespace" == "kube-public" ]]; then
    echo "❌ Error: Cannot cleanup system namespace: $namespace"
    return 1
  fi
  
  echo "🚨 WARNING: This will delete ALL resources in namespace: $namespace"
  read -p "Type the namespace name to confirm: " confirm
  
  if [[ "$confirm" != "$namespace" ]]; then
    echo "❌ Namespace confirmation failed. Cleanup cancelled."
    return 1
  fi
  
  echo "🧹 Cleaning up entire namespace: $namespace..."
  
  # Delete all resources in namespace
  kubectl delete all --all -n "$namespace"
  kubectl delete configmap --all -n "$namespace"
  kubectl delete secret --all -n "$namespace"
  kubectl delete pvc --all -n "$namespace"
  kubectl delete secretproviderclass --all -n "$namespace" 2>/dev/null || true
  kubectl delete networkpolicy --all -n "$namespace" 2>/dev/null || true
  
  # Optionally delete the namespace itself
  read -p "Delete the namespace itself? (yes/no): " delete_ns
  if [[ "$delete_ns" == "yes" ]]; then
    kubectl delete namespace "$namespace"
    echo "✅ Namespace $namespace deleted"
  else
    echo "✅ Namespace $namespace cleaned but preserved"
  fi
}

# Usage example (uncomment to use):
# cleanup_entire_namespace "test-environment"
```

### Cleanup Verification and Monitoring

#### 1. Comprehensive Verification Script
```bash
# Verify cleanup completion
verify_cleanup() {
  local app_name="java-app"
  local namespace="default"
  
  echo "🔍 Verifying cleanup for $app_name in $namespace..."
  
  # Check Helm releases
  echo "📊 Helm Releases:"
  helm list -n "$namespace" | grep "$app_name" && echo "❌ Helm release still exists!" || echo "✅ No Helm releases found"
  
  # Check all Kubernetes resources
  echo "📊 Kubernetes Resources:"
  local resources=$(kubectl get all -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null)
  if [[ -n "$resources" ]]; then
    echo "❌ Resources still exist:"
    echo "$resources"
  else
    echo "✅ No labeled resources found"
  fi
  
  # Check ConfigMaps
  echo "📊 ConfigMaps:"
  kubectl get configmap -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null && echo "❌ ConfigMaps still exist!" || echo "✅ No ConfigMaps found"
  
  # Check Secrets
  echo "📊 Secrets:"
  kubectl get secret -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null && echo "❌ Secrets still exist!" || echo "✅ No Secrets found"
  
  # Check PVCs
  echo "📊 Persistent Volume Claims:"
  kubectl get pvc -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null && echo "❌ PVCs still exist!" || echo "✅ No PVCs found"
  
  # Check Secret Provider Classes
  echo "📊 Secret Provider Classes:"
  kubectl get secretproviderclass -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null && echo "❌ SecretProviderClasses still exist!" || echo "✅ No SecretProviderClasses found"
  
  echo "🏁 Verification completed"
}

# Execute verification
verify_cleanup
```

#### 2. Monitoring Cleanup Progress
```bash
# Monitor cleanup progress in real-time
monitor_cleanup() {
  local app_name="java-app"
  local namespace="default"
  
  echo "👀 Monitoring cleanup progress for $app_name in $namespace..."
  echo "Press Ctrl+C to stop monitoring"
  
  while true; do
    clear
    echo "=== Cleanup Monitor - $(date) ==="
    echo ""
    
    echo "🎯 Helm Releases:"
    helm list -n "$namespace" | grep "$app_name" || echo "✅ No Helm releases"
    echo ""
    
    echo "🎯 Pods:"
    kubectl get pods -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "✅ No pods"
    echo ""
    
    echo "🎯 Deployments:"
    kubectl get deployments -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "✅ No deployments"
    echo ""
    
    echo "🎯 Services:"
    kubectl get services -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "✅ No services"
    echo ""
    
    echo "🎯 Other Resources:"
    kubectl get configmap,secret,pvc -l app.kubernetes.io/name="$app_name" -n "$namespace" 2>/dev/null || echo "✅ No other resources"
    
    sleep 5
  done
}

# Start monitoring (run in separate terminal)
# monitor_cleanup
```

### Cleanup Automation Scripts

#### 1. Complete Cleanup Automation
```bash
#!/bin/bash
# cleanup-helm-deployment.sh - Complete cleanup automation script

set -e

# Configuration
APP_NAME="${1:-java-app}"
NAMESPACE="${2:-default}"
FORCE="${3:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
  echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Main cleanup function
main() {
  log "Starting cleanup for application: $APP_NAME in namespace: $NAMESPACE"
  
  # Confirm with user unless force is specified
  if [[ "$FORCE" != "true" ]]; then
    warn "This will delete all resources for $APP_NAME in namespace $NAMESPACE"
    read -p "Continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
      error "Cleanup cancelled by user"
      exit 1
    fi
  fi
  
  # Step 1: Helm cleanup
  log "Step 1: Checking for Helm releases..."
  if helm list -n "$NAMESPACE" | grep -q "$APP_NAME"; then
    log "Uninstalling Helm release: $APP_NAME"
    helm uninstall "$APP_NAME" -n "$NAMESPACE"
    success "Helm release uninstalled"
  else
    log "No Helm release found for $APP_NAME"
  fi
  
  # Step 2: Wait for Helm cleanup
  log "Step 2: Waiting for Helm cleanup to complete..."
  sleep 30
  
  # Step 3: Manual cleanup of remaining resources
  log "Step 3: Cleaning up remaining resources..."
  
  kubectl delete all -l app.kubernetes.io/name="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || true
  kubectl delete configmap -l app.kubernetes.io/name="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || true
  kubectl delete secret -l app.kubernetes.io/name="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || true
  kubectl delete pvc -l app.kubernetes.io/name="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || true
  kubectl delete secretproviderclass -l app.kubernetes.io/name="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || true
  kubectl delete networkpolicy -l app.kubernetes.io/name="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || true
  kubectl delete poddisruptionbudget -l app.kubernetes.io/name="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || true
  kubectl delete hpa -l app.kubernetes.io/name="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || true
  
  success "Manual cleanup completed"
  
  # Step 4: Verification
  log "Step 4: Verifying cleanup..."
  sleep 10
  
  local remaining_resources=$(kubectl get all -l app.kubernetes.io/name="$APP_NAME" -n "$NAMESPACE" 2>/dev/null)
  if [[ -z "$remaining_resources" ]]; then
    success "✅ All resources cleaned up successfully!"
  else
    warn "❌ Some resources may still exist:"
    echo "$remaining_resources"
  fi
  
  log "Cleanup completed for $APP_NAME in $NAMESPACE"
}

# Usage information
usage() {
  echo "Usage: $0 [APP_NAME] [NAMESPACE] [FORCE]"
  echo "  APP_NAME:  Application name (default: java-app)"
  echo "  NAMESPACE: Kubernetes namespace (default: default)"
  echo "  FORCE:     Skip confirmation (default: false)"
  echo ""
  echo "Examples:"
  echo "  $0                                    # Clean java-app from default namespace"
  echo "  $0 my-app production                  # Clean my-app from production namespace"
  echo "  $0 java-app default true             # Force clean without confirmation"
}

# Check if help is requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

# Execute main function
main
```

#### 2. Multi-Environment Cleanup Script
```bash
#!/bin/bash
# cleanup-all-environments.sh - Cleanup across multiple environments

APP_NAME="java-app"
ENVIRONMENTS=("dev" "staging" "production")

for env in "${ENVIRONMENTS[@]}"; do
  echo "🧹 Cleaning up $APP_NAME in $env environment..."
  
  # Check if namespace exists
  if kubectl get namespace "$env" >/dev/null 2>&1; then
    # Helm cleanup
    if helm list -n "$env" | grep -q "$APP_NAME"; then
      helm uninstall "$APP_NAME" -n "$env"
    fi
    
    # Manual cleanup
    kubectl delete all -l app.kubernetes.io/name="$APP_NAME" -n "$env" 2>/dev/null || true
    kubectl delete configmap,secret,pvc -l app.kubernetes.io/name="$APP_NAME" -n "$env" 2>/dev/null || true
    
    echo "✅ Cleanup completed for $env"
  else
    echo "ℹ️  Namespace $env does not exist, skipping..."
  fi
  
  echo ""
done

echo "🎉 Multi-environment cleanup completed!"
```

### Usage Examples and Best Practices

#### Quick Reference Commands
```bash
# Quick cleanup commands for daily use

# 1. Standard cleanup (recommended)
helm uninstall java-app -n default

# 2. Cleanup with verification
helm uninstall java-app -n default && kubectl get all -l app.kubernetes.io/name=java-app -n default

# 3. Force cleanup stuck resources
kubectl delete all -l app.kubernetes.io/name=java-app -n default --force --grace-period=0

# 4. Complete manual cleanup
kubectl delete all,configmap,secret,pvc,secretproviderclass,networkpolicy,poddisruptionbudget,hpa -l app.kubernetes.io/name=java-app -n default

# 5. Emergency cleanup (last resort)
kubectl patch deployment java-app -p '{"metadata":{"finalizers":[]}}' --type=merge -n default
kubectl delete deployment java-app --force --grace-period=0 -n default
```

#### Cleanup Best Practices
1. **Always use Helm uninstall first** - let Helm manage the cleanup process
2. **Verify cleanup completion** - check for remaining resources after Helm uninstall
3. **Use labels for manual cleanup** - leverage Kubernetes labels for bulk operations
4. **Scale down before deletion** - gracefully scale deployments to 0 before deletion
5. **Check dependencies** - ensure no other applications depend on shared resources
6. **Backup if needed** - export configurations before cleanup if rollback might be needed
7. **Clean environments separately** - avoid accidentally affecting wrong environment

---

**Last Updated**: $(date '+%Y-%m-%d')  
**Version**: 1.0.0  
**Maintained by**: DevOps Team