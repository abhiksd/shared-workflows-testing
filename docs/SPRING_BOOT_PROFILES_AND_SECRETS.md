# Spring Boot Profiles & Azure Key Vault Integration Guide

This guide provides comprehensive documentation on how Spring Boot environment profiles are mapped with Helm deployment templates using Azure Key Vault integration for secure secret management.

## 📋 Table of Contents

- [Architecture Overview](#-architecture-overview)
- [Spring Boot Profile Configuration](#-spring-boot-profile-configuration)
- [Helm Template Integration](#-helm-template-integration)
- [Azure Key Vault Setup](#-azure-key-vault-setup)
- [Environment-Specific Mappings](#-environment-specific-mappings)
- [Deployment Flow](#-deployment-flow)
- [Complete Examples](#-complete-examples)
- [Best Practices](#-best-practices)
- [Troubleshooting](#-troubleshooting)

## 🏗️ Architecture Overview

### Integration Flow Diagram
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Spring Boot   │    │   Helm Chart     │    │  Azure Key      │
│   Application   │◄───│   Templates      │◄───│  Vault          │
│   (Profiles)    │    │                  │    │  (Secrets)      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Environment    │    │  ConfigMap &     │    │  Secret         │
│  Variables      │    │  Secret Objects  │    │  Provider       │
│  & Config       │    │                  │    │  Class          │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 ▼
                    ┌──────────────────┐
                    │   Kubernetes     │
                    │   Pod with       │
                    │   Mounted        │
                    │   Secrets        │
                    └──────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Configuration Source |
|-----------|----------------|---------------------|
| **Spring Boot** | Profile-based configuration loading | `application-{profile}.yml` |
| **Helm Templates** | Environment-specific value injection | `values-{env}.yaml` |
| **Azure Key Vault** | Secure secret storage | Key Vault secrets |
| **Secret Provider Class** | Secret mounting to pods | Kubernetes CSI driver |
| **ConfigMaps** | Non-sensitive configuration | Helm templates |

## 🔧 Spring Boot Profile Configuration

### 1. Application Structure
```
src/main/resources/
├── application.yml                 # Base configuration
├── application-dev.yml            # Development profile
├── application-staging.yml        # Staging profile
├── application-production.yml     # Production profile
└── application-local.yml          # Local development
```

### 2. Base Configuration (`application.yml`)
```yaml
# Base Spring Boot configuration
spring:
  application:
    name: java-app
  
  # Profile-specific configurations will override these
  datasource:
    driver-class-name: org.postgresql.Driver
    hikari:
      minimum-idle: 2
      maximum-pool-size: 10
  
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false

# Management endpoints (Actuator)
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: when-authorized
  server:
    port: 8081

# Server configuration
server:
  port: 8080
  servlet:
    context-path: /

# Logging configuration
logging:
  level:
    com.example.javaapp: INFO
    org.springframework.security: WARN
  pattern:
    console: "%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"
```

### 3. Environment-Specific Profiles

#### Development Profile (`application-dev.yml`)
```yaml
spring:
  profiles:
    active: dev
  
  # Development database (can use H2 or containerized DB)
  datasource:
    url: jdbc:postgresql://dev-db.example.com:5432/javaapp_dev
    username: ${DB_USERNAME:dev_user}
    # Password comes from Key Vault or environment variable
    password: ${DB_PASSWORD:dev_password}
    hikari:
      minimum-idle: 1
      maximum-pool-size: 5
  
  jpa:
    hibernate:
      ddl-auto: create-drop  # Recreate schema for dev
    show-sql: true
    properties:
      hibernate:
        format_sql: true

# Development-specific settings
management:
  endpoints:
    web:
      exposure:
        include: "*"  # Expose all endpoints for debugging
  endpoint:
    health:
      show-details: always

# Enhanced logging for development
logging:
  level:
    com.example.javaapp: DEBUG
    org.springframework.web: DEBUG
    org.hibernate.SQL: DEBUG
    org.hibernate.type.descriptor.sql.BasicBinder: TRACE

# Development feature flags
app:
  features:
    debug-mode: true
    mock-external-services: true
  external-services:
    api-url: "https://dev-api.example.com"
    timeout: 30000
```

#### Staging Profile (`application-staging.yml`)
```yaml
spring:
  profiles:
    active: staging
  
  # Staging database (production-like)
  datasource:
    url: jdbc:postgresql://staging-db.example.com:5432/javaapp_staging
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}  # From Key Vault
    hikari:
      minimum-idle: 3
      maximum-pool-size: 15
      connection-timeout: 20000
      idle-timeout: 300000
      max-lifetime: 1200000
  
  jpa:
    hibernate:
      ddl-auto: validate  # Don't modify schema
    show-sql: false

# Production-like management settings
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: when-authorized
  metrics:
    export:
      prometheus:
        enabled: true

# Moderate logging for staging
logging:
  level:
    com.example.javaapp: INFO
    org.springframework.security: WARN
    root: WARN

# Staging-specific settings
app:
  features:
    debug-mode: false
    mock-external-services: false
  external-services:
    api-url: ${EXTERNAL_API_URL}  # From Key Vault
    api-key: ${EXTERNAL_API_KEY}  # From Key Vault
    timeout: 15000
  security:
    jwt:
      secret: ${JWT_SECRET}  # From Key Vault
      expiration: 86400
```

#### Production Profile (`application-production.yml`)
```yaml
spring:
  profiles:
    active: production
  
  # Production database with connection pooling
  datasource:
    url: ${DB_CONNECTION_STRING}  # From Key Vault
    username: ${DB_USERNAME}      # From Key Vault
    password: ${DB_PASSWORD}      # From Key Vault
    hikari:
      minimum-idle: 5
      maximum-pool-size: 30
      connection-timeout: 20000
      idle-timeout: 600000
      max-lifetime: 1800000
      leak-detection-threshold: 60000
  
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false
    properties:
      hibernate:
        jdbc:
          batch_size: 20
        order_inserts: true
        order_updates: true

# Production management settings
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: never  # Hide details for security
  metrics:
    export:
      prometheus:
        enabled: true
  server:
    port: 8081
    ssl:
      enabled: false  # SSL terminated at ingress

# Minimal logging for production
logging:
  level:
    com.example.javaapp: WARN
    org.springframework.security: ERROR
    root: ERROR
  file:
    name: /var/log/app/application.log
  pattern:
    file: "%d{ISO8601} [%thread] %-5level %logger{36} - %msg%n"

# Production-specific settings
app:
  features:
    debug-mode: false
    mock-external-services: false
  external-services:
    api-url: ${EXTERNAL_API_URL}     # From Key Vault
    api-key: ${EXTERNAL_API_KEY}     # From Key Vault
    timeout: 10000
  security:
    jwt:
      secret: ${JWT_SECRET}          # From Key Vault
      expiration: 3600
  monitoring:
    enabled: true
    metrics-endpoint: ${METRICS_ENDPOINT}  # From Key Vault
```

## 🎯 Helm Template Integration

### 1. Values Structure for Profiles

#### Base Values (`values.yaml`)
```yaml
# Global configuration
global:
  environment: dev
  applicationName: java-app
  applicationType: java-springboot

# Image configuration
image:
  repository: myregistry.azurecr.io/java-app
  pullPolicy: IfNotPresent
  tag: "latest"

# Environment variables (base)
env:
  - name: SPRING_PROFILES_ACTIVE
    value: "dev"
  - name: SERVER_PORT
    value: "8080"
  - name: MANAGEMENT_SERVER_PORT
    value: "8081"

# ConfigMap for non-sensitive configuration
configMap:
  enabled: true
  data:
    # JVM settings
    JAVA_OPTS: "-Xms512m -Xmx1g -XX:+UseG1GC"
    
    # Application settings
    LOG_LEVEL: "INFO"
    
    # Feature flags (non-sensitive)
    FEATURE_DEBUG_MODE: "false"
    FEATURE_MOCK_SERVICES: "false"

# Azure Key Vault integration
azureKeyVault:
  enabled: false
  keyvaultName: ""
  tenantId: ""
  userAssignedIdentityID: ""
  secrets: []
  secretObjects: []
```

#### Development Values (`values-dev.yaml`)
```yaml
# Development environment configuration
global:
  environment: dev

# Environment variables for development
env:
  - name: SPRING_PROFILES_ACTIVE
    value: "dev"
  - name: SERVER_PORT
    value: "8080"
  - name: MANAGEMENT_SERVER_PORT
    value: "8081"
  # Non-sensitive dev-specific configs
  - name: DB_USERNAME
    value: "dev_user"
  - name: EXTERNAL_API_URL
    value: "https://dev-api.example.com"

# ConfigMap for development
configMap:
  enabled: true
  data:
    JAVA_OPTS: "-Xms256m -Xmx1g -XX:+UseG1GC -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
    LOG_LEVEL: "DEBUG"
    FEATURE_DEBUG_MODE: "true"
    FEATURE_MOCK_SERVICES: "true"
    
    # Development database settings
    DB_HOST: "dev-db.example.com"
    DB_PORT: "5432"
    DB_NAME: "javaapp_dev"

# Basic Key Vault for development (optional)
azureKeyVault:
  enabled: true
  keyvaultName: "kv-platform-dev"
  tenantId: "your-tenant-id"
  userAssignedIdentityID: "your-dev-identity-id"
  secrets:
    - objectName: "db-password-dev"
      objectAlias: "db-password"
  secretObjects:
    - secretName: "app-secrets"
      type: "Opaque"
      data:
        - objectName: "db-password-dev"
          key: "DB_PASSWORD"
```

#### Staging Values (`values-staging.yaml`)
```yaml
# Staging environment configuration
global:
  environment: staging

# Environment variables for staging
env:
  - name: SPRING_PROFILES_ACTIVE
    value: "staging"
  - name: SERVER_PORT
    value: "8080"
  - name: MANAGEMENT_SERVER_PORT
    value: "8081"

# ConfigMap for staging
configMap:
  enabled: true
  data:
    JAVA_OPTS: "-Xms1g -Xmx2g -XX:+UseG1GC -XX:+UseStringDeduplication"
    LOG_LEVEL: "INFO"
    FEATURE_DEBUG_MODE: "false"
    FEATURE_MOCK_SERVICES: "false"
    
    # Staging database settings
    DB_HOST: "staging-db.example.com"
    DB_PORT: "5432"
    DB_NAME: "javaapp_staging"

# Comprehensive Key Vault for staging
azureKeyVault:
  enabled: true
  keyvaultName: "kv-platform-staging"
  tenantId: "your-tenant-id"
  userAssignedIdentityID: "your-staging-identity-id"
  secrets:
    - objectName: "db-connection-string-staging"
      objectAlias: "db-connection-string"
    - objectName: "db-username-staging"
      objectAlias: "db-username"
    - objectName: "db-password-staging"
      objectAlias: "db-password"
    - objectName: "external-api-key-staging"
      objectAlias: "external-api-key"
    - objectName: "external-api-url-staging"
      objectAlias: "external-api-url"
    - objectName: "jwt-secret-staging"
      objectAlias: "jwt-secret"
  secretObjects:
    - secretName: "app-secrets"
      type: "Opaque"
      data:
        - objectName: "db-username-staging"
          key: "DB_USERNAME"
        - objectName: "db-password-staging"
          key: "DB_PASSWORD"
        - objectName: "external-api-key-staging"
          key: "EXTERNAL_API_KEY"
        - objectName: "external-api-url-staging"
          key: "EXTERNAL_API_URL"
        - objectName: "jwt-secret-staging"
          key: "JWT_SECRET"
```

#### Production Values (`values-production.yaml`)
```yaml
# Production environment configuration
global:
  environment: production

# Environment variables for production
env:
  - name: SPRING_PROFILES_ACTIVE
    value: "production"
  - name: SERVER_PORT
    value: "8080"
  - name: MANAGEMENT_SERVER_PORT
    value: "8081"

# ConfigMap for production
configMap:
  enabled: true
  data:
    JAVA_OPTS: "-Xms2g -Xmx4g -XX:+UseG1GC -XX:+UseStringDeduplication -XX:MaxGCPauseMillis=200"
    LOG_LEVEL: "WARN"
    FEATURE_DEBUG_MODE: "false"
    FEATURE_MOCK_SERVICES: "false"
    
    # Production database settings (non-sensitive)
    DB_HOST: "prod-db.example.com"
    DB_PORT: "5432"
    DB_NAME: "javaapp_production"

# Full Key Vault integration for production
azureKeyVault:
  enabled: true
  keyvaultName: "kv-platform-prod"
  tenantId: "your-tenant-id"
  userAssignedIdentityID: "your-prod-identity-id"
  secrets:
    - objectName: "db-connection-string-prod"
      objectAlias: "db-connection-string"
    - objectName: "db-username-prod"
      objectAlias: "db-username"
    - objectName: "db-password-prod"
      objectAlias: "db-password"
    - objectName: "external-api-key-prod"
      objectAlias: "external-api-key"
    - objectName: "external-api-url-prod"
      objectAlias: "external-api-url"
    - objectName: "jwt-secret-prod"
      objectAlias: "jwt-secret"
    - objectName: "metrics-endpoint-prod"
      objectAlias: "metrics-endpoint"
    - objectName: "encryption-key-prod"
      objectAlias: "encryption-key"
  secretObjects:
    - secretName: "app-secrets"
      type: "Opaque"
      data:
        - objectName: "db-connection-string-prod"
          key: "DB_CONNECTION_STRING"
        - objectName: "db-username-prod"
          key: "DB_USERNAME"
        - objectName: "db-password-prod"
          key: "DB_PASSWORD"
        - objectName: "external-api-key-prod"
          key: "EXTERNAL_API_KEY"
        - objectName: "external-api-url-prod"
          key: "EXTERNAL_API_URL"
        - objectName: "jwt-secret-prod"
          key: "JWT_SECRET"
        - objectName: "metrics-endpoint-prod"
          key: "METRICS_ENDPOINT"
        - objectName: "encryption-key-prod"
          key: "ENCRYPTION_KEY"
```

### 2. Deployment Template Integration

#### Deployment Template (`templates/deployment.yaml`)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "java-app.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "java-app.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "java-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        # Force pod restart when ConfigMap or secrets change
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- if .Values.azureKeyVault.enabled }}
        checksum/secrets: {{ .Values.azureKeyVault | toYaml | sha256sum }}
        {{- end }}
      labels:
        {{- include "java-app.selectorLabels" . | nindent 8 }}
        {{- if .Values.azureKeyVault.enabled }}
        azure.workload.identity/use: "true"
        {{- end }}
    spec:
      serviceAccountName: {{ include "java-app.serviceAccountName" . }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
              protocol: TCP
            - name: management
              containerPort: 8081
              protocol: TCP
          
          # Environment variables from values and ConfigMap
          env:
            {{- range .Values.env }}
            - name: {{ .name }}
              value: {{ .value | quote }}
            {{- end }}
            
            # Environment variables from ConfigMap
            {{- if .Values.configMap.enabled }}
            {{- range $key, $value := .Values.configMap.data }}
            - name: {{ $key }}
              valueFrom:
                configMapKeyRef:
                  name: {{ include "java-app.fullname" $ }}-config
                  key: {{ $key }}
            {{- end }}
            {{- end }}
            
            # Environment variables from secrets (Key Vault)
            {{- if .Values.azureKeyVault.enabled }}
            {{- range .Values.azureKeyVault.secretObjects }}
            {{- range .data }}
            - name: {{ .key }}
              valueFrom:
                secretKeyRef:
                  name: {{ $.secretName }}
                  key: {{ .key }}
            {{- end }}
            {{- end }}
            {{- end }}
          
          # Volume mounts for Key Vault secrets
          volumeMounts:
            {{- if .Values.azureKeyVault.enabled }}
            - name: secrets-store
              mountPath: "/mnt/secrets-store"
              readOnly: true
            {{- end }}
            # Additional volume mounts for logs, temp files, etc.
            - name: tmp-volume
              mountPath: /tmp
            - name: logs-volume
              mountPath: /var/log/app
          
          # Health checks using Spring Boot Actuator
          livenessProbe:
            httpGet:
              path: /actuator/health
              port: 8081
            initialDelaySeconds: 60
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8081
            initialDelaySeconds: 30
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
          
          # Resource limits
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
      
      # Volumes
      volumes:
        {{- if .Values.azureKeyVault.enabled }}
        - name: secrets-store
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: {{ include "java-app.fullname" . }}-secrets
        {{- end }}
        - name: tmp-volume
          emptyDir: {}
        - name: logs-volume
          emptyDir: {}
```

#### ConfigMap Template (`templates/configmap.yaml`)
```yaml
{{- if .Values.configMap.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "java-app.fullname" . }}-config
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "java-app.labels" . | nindent 4 }}
data:
  # Application configuration from values
  {{- range $key, $value := .Values.configMap.data }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
  
  # Environment-specific Spring Boot configuration
  SPRING_PROFILES_ACTIVE: {{ .Values.global.environment | quote }}
  
  # Application metadata
  APPLICATION_NAME: {{ .Values.global.applicationName | quote }}
  APPLICATION_TYPE: {{ .Values.global.applicationType | quote }}
  DEPLOYMENT_ENVIRONMENT: {{ .Values.global.environment | quote }}
  
  # Kubernetes metadata
  K8S_NAMESPACE: {{ .Release.Namespace | quote }}
  K8S_POD_NAME: {{ include "java-app.fullname" . }}
  HELM_RELEASE_NAME: {{ .Release.Name | quote }}
  HELM_CHART_VERSION: {{ .Chart.Version | quote }}
{{- end }}
```

#### Secret Provider Class Template (`templates/secretproviderclass.yaml`)
```yaml
{{- if .Values.azureKeyVault.enabled }}
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: {{ include "java-app.fullname" . }}-secrets
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "java-app.labels" . | nindent 4 }}
spec:
  provider: azure
  parameters:
    useVMManagedIdentity: "false"
    usePodIdentity: "false"
    userAssignedIdentityID: {{ .Values.azureKeyVault.userAssignedIdentityID | quote }}
    keyvaultName: {{ .Values.azureKeyVault.keyvaultName | quote }}
    tenantId: {{ .Values.azureKeyVault.tenantId | quote }}
    objects: |
      array:
        {{- range .Values.azureKeyVault.secrets }}
        - |
          objectName: {{ .objectName }}
          objectAlias: {{ .objectAlias }}
          objectType: secret
        {{- end }}
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

## 🔐 Azure Key Vault Setup

### 1. Key Vault Structure by Environment

#### Development Secrets
```bash
# Create development secrets
az keyvault secret set --vault-name "kv-platform-dev" --name "db-password-dev" --value "dev_secure_password"
az keyvault secret set --vault-name "kv-platform-dev" --name "jwt-secret-dev" --value "dev_jwt_secret_key"
```

#### Staging Secrets
```bash
# Create staging secrets
az keyvault secret set --vault-name "kv-platform-staging" --name "db-connection-string-staging" --value "postgresql://staging-db.example.com:5432/javaapp_staging"
az keyvault secret set --vault-name "kv-platform-staging" --name "db-username-staging" --value "staging_db_user"
az keyvault secret set --vault-name "kv-platform-staging" --name "db-password-staging" --value "staging_secure_password"
az keyvault secret set --vault-name "kv-platform-staging" --name "external-api-key-staging" --value "staging_api_key_12345"
az keyvault secret set --vault-name "kv-platform-staging" --name "external-api-url-staging" --value "https://staging-api.example.com"
az keyvault secret set --vault-name "kv-platform-staging" --name "jwt-secret-staging" --value "staging_jwt_secret_key_very_secure"
```

#### Production Secrets
```bash
# Create production secrets
az keyvault secret set --vault-name "kv-platform-prod" --name "db-connection-string-prod" --value "postgresql://prod-db.example.com:5432/javaapp_production"
az keyvault secret set --vault-name "kv-platform-prod" --name "db-username-prod" --value "prod_db_user"
az keyvault secret set --vault-name "kv-platform-prod" --name "db-password-prod" --value "$(openssl rand -base64 32)"
az keyvault secret set --vault-name "kv-platform-prod" --name "external-api-key-prod" --value "prod_api_key_$(openssl rand -hex 16)"
az keyvault secret set --vault-name "kv-platform-prod" --name "external-api-url-prod" --value "https://api.example.com"
az keyvault secret set --vault-name "kv-platform-prod" --name "jwt-secret-prod" --value "$(openssl rand -base64 64)"
az keyvault secret set --vault-name "kv-platform-prod" --name "metrics-endpoint-prod" --value "https://metrics.example.com"
az keyvault secret set --vault-name "kv-platform-prod" --name "encryption-key-prod" --value "$(openssl rand -base64 32)"
```

### 2. Key Vault Access Policy
```bash
# Grant access to managed identity
az keyvault set-policy \
  --name "kv-platform-prod" \
  --object-id "$MANAGED_IDENTITY_OBJECT_ID" \
  --secret-permissions get list
```

## 🔄 Environment-Specific Mappings

### Complete Mapping Table

| Spring Profile | Helm Values File | Key Vault | Environment Variables | Purpose |
|----------------|------------------|-----------|----------------------|---------|
| `dev` | `values-dev.yaml` | `kv-platform-dev` | `SPRING_PROFILES_ACTIVE=dev` | Development/Testing |
| `staging` | `values-staging.yaml` | `kv-platform-staging` | `SPRING_PROFILES_ACTIVE=staging` | Pre-production validation |
| `production` | `values-production.yaml` | `kv-platform-prod` | `SPRING_PROFILES_ACTIVE=production` | Live production |

### Profile-Specific Features

#### Development Profile Features
```yaml
# Development-specific Spring Boot configuration
spring:
  h2:
    console:
      enabled: true  # Enable H2 console for development
  devtools:
    restart:
      enabled: true  # Enable hot reload
  jpa:
    show-sql: true   # Show SQL queries

logging:
  level:
    org.springframework.web: DEBUG
    com.example.javaapp: DEBUG
```

#### Staging Profile Features
```yaml
# Staging-specific Spring Boot configuration
spring:
  jpa:
    properties:
      hibernate:
        generate_statistics: true  # Enable statistics for monitoring

management:
  metrics:
    export:
      prometheus:
        enabled: true  # Enable Prometheus metrics
```

#### Production Profile Features
```yaml
# Production-specific Spring Boot configuration
spring:
  jpa:
    properties:
      hibernate:
        jdbc:
          batch_size: 20  # Optimize batch processing
        cache:
          use_second_level_cache: true

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus  # Limited endpoints
```

## 🚀 Deployment Flow

### Complete Deployment Process Diagram
```
┌─────────────────┐
│ 1. Git Push to  │
│ Environment     │
│ Branch          │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ 2. GitHub       │
│ Actions         │
│ Triggered       │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ 3. Determine    │
│ Environment     │
│ (dev/staging/   │
│ production)     │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ 4. Select       │
│ Helm Values     │
│ File            │
│ (values-env.yml)│
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ 5. Azure Login  │
│ & AKS Access    │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ 6. Helm Deploy  │
│ with Values     │
│ Override        │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ 7. Kubernetes   │
│ Creates:        │
│ - ConfigMap     │
│ - Secret        │
│ - Deployment    │
│ - Service       │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ 8. Azure Key    │
│ Vault CSI       │
│ Mounts Secrets  │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ 9. Spring Boot  │
│ Starts with     │
│ Profile-specific│
│ Configuration   │
└─────────────────┘
```

### Step-by-Step Process

#### 1. GitHub Actions Workflow
```yaml
# In .github/workflows/shared-deploy.yml
- name: Deploy to AKS
  uses: ./.github/actions/helm-deploy
  with:
    environment: ${{ needs.validate-environment.outputs.target_environment }}
    application_name: ${{ inputs.application_name }}
    helm_chart_path: ${{ inputs.helm_chart_path }}
    # ... other parameters
```

#### 2. Helm Deployment Command
```bash
# Generated Helm command based on environment
helm upgrade --install java-app ./helm/java-app \
  --namespace default \
  --values ./helm/java-app/values.yaml \
  --values ./helm/java-app/values-production.yaml \
  --set image.tag=${IMAGE_TAG} \
  --set global.environment=production \
  --wait --timeout=10m
```

#### 3. Kubernetes Resource Creation
```yaml
# Resources created by Helm
apiVersion: v1
kind: ConfigMap
metadata:
  name: java-app-config
data:
  SPRING_PROFILES_ACTIVE: "production"
  JAVA_OPTS: "-Xms2g -Xmx4g -XX:+UseG1GC"
  LOG_LEVEL: "WARN"
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: java-app-secrets
spec:
  provider: azure
  parameters:
    keyvaultName: "kv-platform-prod"
    # ... Key Vault configuration
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: java-app
spec:
  template:
    spec:
      containers:
        - name: java-app
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: "production"
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: DB_PASSWORD
          volumeMounts:
            - name: secrets-store
              mountPath: "/mnt/secrets-store"
```

#### 4. Pod Runtime Environment
```bash
# Environment variables available in the pod
SPRING_PROFILES_ACTIVE=production
SERVER_PORT=8080
JAVA_OPTS=-Xms2g -Xmx4g -XX:+UseG1GC
LOG_LEVEL=WARN

# Secrets mounted from Key Vault
DB_USERNAME=prod_db_user
DB_PASSWORD=secure_production_password
JWT_SECRET=production_jwt_secret_key
EXTERNAL_API_KEY=prod_api_key_xyz

# Files mounted from Key Vault
/mnt/secrets-store/db-password
/mnt/secrets-store/jwt-secret
/mnt/secrets-store/external-api-key
```

## 📖 Complete Examples

### Example 1: Development Deployment

#### Trigger
```bash
git checkout N630-6258_Helm_deploy
git push origin N630-6258_Helm_deploy
```

#### Resulting Configuration
```yaml
# Pod environment variables
SPRING_PROFILES_ACTIVE: dev
LOG_LEVEL: DEBUG
FEATURE_DEBUG_MODE: true
FEATURE_MOCK_SERVICES: true
DB_HOST: dev-db.example.com
DB_USERNAME: dev_user
DB_PASSWORD: dev_secure_password  # From Key Vault
```

#### Spring Boot Application Properties
```yaml
# application-dev.yml is loaded
spring:
  profiles:
    active: dev
  datasource:
    url: jdbc:postgresql://dev-db.example.com:5432/javaapp_dev
    username: dev_user
    password: dev_secure_password
  jpa:
    show-sql: true
logging:
  level:
    com.example.javaapp: DEBUG
```

### Example 2: Production Deployment

#### Trigger
```bash
git checkout main
git checkout -b release/v1.2.3
git push origin release/v1.2.3
```

#### Resulting Configuration
```yaml
# Pod environment variables
SPRING_PROFILES_ACTIVE: production
LOG_LEVEL: WARN
FEATURE_DEBUG_MODE: false
FEATURE_MOCK_SERVICES: false
DB_CONNECTION_STRING: postgresql://prod-db.example.com:5432/javaapp_production  # From Key Vault
DB_USERNAME: prod_db_user  # From Key Vault
DB_PASSWORD: secure_production_password  # From Key Vault
JWT_SECRET: production_jwt_secret_key  # From Key Vault
EXTERNAL_API_KEY: prod_api_key_xyz  # From Key Vault
```

#### Spring Boot Application Properties
```yaml
# application-production.yml is loaded
spring:
  profiles:
    active: production
  datasource:
    url: postgresql://prod-db.example.com:5432/javaapp_production
    username: prod_db_user
    password: secure_production_password
logging:
  level:
    com.example.javaapp: WARN
    root: ERROR
```

## 🎯 Best Practices

### 1. Profile Management
```yaml
# Use consistent naming
spring.profiles.active: ${SPRING_PROFILES_ACTIVE:dev}

# Profile-specific property files
application.yml          # Base configuration
application-dev.yml      # Development overrides
application-staging.yml  # Staging overrides
application-production.yml # Production overrides

# Include profiles for modular configuration
spring.profiles.include: actuator,monitoring
```

### 2. Secret Management
```yaml
# Categorize secrets by sensitivity
# Level 1: Non-sensitive configuration (ConfigMap)
- Database host, port, name
- Feature flags
- Log levels
- External service URLs (non-sensitive)

# Level 2: Sensitive configuration (Key Vault)
- Database credentials
- API keys
- JWT secrets
- Encryption keys
- Third-party service credentials
```

### 3. Environment Variable Strategy
```yaml
# Use consistent naming convention
DB_HOST              # Database host
DB_PORT              # Database port
DB_NAME              # Database name
DB_USERNAME          # Database username (from Key Vault)
DB_PASSWORD          # Database password (from Key Vault)
DB_CONNECTION_STRING # Full connection string (from Key Vault)

# Application-specific variables
APP_FEATURE_DEBUG_MODE     # Feature flags
APP_EXTERNAL_API_URL       # External service URLs
APP_EXTERNAL_API_KEY       # External service credentials (from Key Vault)
```

### 4. Key Vault Organization
```bash
# Naming convention: {secret-type}-{environment}
db-password-dev
db-password-staging  
db-password-prod

jwt-secret-dev
jwt-secret-staging
jwt-secret-prod

external-api-key-dev
external-api-key-staging
external-api-key-prod
```

### 5. Configuration Validation
```java
// Add configuration validation in Spring Boot
@Component
@ConfigurationProperties(prefix = "app")
@Validated
public class AppProperties {
    
    @NotBlank
    private String externalApiUrl;
    
    @NotBlank
    private String externalApiKey;
    
    @Valid
    private Database database = new Database();
    
    @Valid
    private Security security = new Security();
    
    // Getters and setters
    
    public static class Database {
        @NotBlank
        private String host;
        
        @Min(1)
        @Max(65535)
        private int port;
        
        @NotBlank
        private String name;
        
        // Getters and setters
    }
    
    public static class Security {
        @NotBlank
        private String jwtSecret;
        
        @Min(60)
        private int jwtExpiration;
        
        // Getters and setters
    }
}
```

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. Profile Not Loading
```bash
# Check environment variable
kubectl exec -it <pod-name> -- env | grep SPRING_PROFILES_ACTIVE

# Check application logs
kubectl logs <pod-name> | grep "The following profiles are active"

# Verify ConfigMap
kubectl get configmap java-app-config -o yaml
```

#### 2. Secrets Not Available
```bash
# Check Secret Provider Class
kubectl describe secretproviderclass java-app-secrets

# Check mounted secrets
kubectl exec -it <pod-name> -- ls -la /mnt/secrets-store/

# Check Kubernetes secrets
kubectl get secret app-secrets -o yaml

# Check Key Vault access
az keyvault secret list --vault-name kv-platform-prod
```

#### 3. Database Connection Issues
```bash
# Test connection from pod
kubectl exec -it <pod-name> -- nc -zv $DB_HOST $DB_PORT

# Check environment variables
kubectl exec -it <pod-name> -- env | grep DB_

# Verify secret values (be careful in production)
kubectl exec -it <pod-name> -- cat /mnt/secrets-store/db-password
```

#### 4. Configuration Override Issues
```bash
# Check active configuration
kubectl exec -it <pod-name> -- curl http://localhost:8081/actuator/env

# Check configuration properties
kubectl exec -it <pod-name> -- curl http://localhost:8081/actuator/configprops

# Verify profile-specific properties
kubectl logs <pod-name> | grep "application-.*\.yml"
```

### Debugging Commands
```bash
# Check all environment variables in pod
kubectl exec -it <pod-name> -- env | sort

# Check mounted volumes
kubectl exec -it <pod-name> -- mount | grep secrets

# Check application configuration
kubectl exec -it <pod-name> -- curl http://localhost:8081/actuator/env

# Check health status
kubectl exec -it <pod-name> -- curl http://localhost:8081/actuator/health

# Check application info
kubectl exec -it <pod-name> -- curl http://localhost:8081/actuator/info
```

### Monitoring and Validation
```bash
# Monitor deployment rollout
kubectl rollout status deployment/java-app

# Check pod status
kubectl get pods -l app=java-app

# Watch pod events
kubectl get events --field-selector involvedObject.name=<pod-name>

# Check resource usage
kubectl top pod <pod-name>
```

---

**Last Updated**: $(date '+%Y-%m-%d')  
**Version**: 1.0.0  
**Maintained by**: DevOps Team