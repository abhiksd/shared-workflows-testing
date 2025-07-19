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

---

**Last Updated**: $(date '+%Y-%m-%d')  
**Version**: 1.0.0  
**Maintained by**: DevOps Team