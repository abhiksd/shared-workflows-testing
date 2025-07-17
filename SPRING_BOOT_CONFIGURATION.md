# 🚀 Spring Boot Configuration & Profiling Guide

## ✅ **COMPREHENSIVE SPRING BOOT INTEGRATION**

This guide documents the complete Spring Boot configuration, profiling, and secrets injection setup implemented in the Helm charts.

## 🎯 **SPRING BOOT PROFILING ENABLED**

### **Environment-Based Profiles**

The system automatically activates Spring Boot profiles based on the deployment environment:

| Environment | Active Profiles | Configuration Focus |
|-------------|----------------|-------------------|
| **dev** | `dev,actuator,dev-tools` | Full debugging, hot reload, verbose logging |
| **staging** | `staging,actuator` | Production-like with extended monitoring |
| **production** | `production,actuator` | Optimized performance, minimal exposure |

### **Profile Configuration Sources**

1. **Environment Variable**: `SPRING_PROFILES_ACTIVE={{ environment }}`
2. **ConfigMap Property**: `spring.profiles.active={{ environment }}`
3. **Additional Profiles**: `SPRING_PROFILES_INCLUDE=actuator[,dev-tools]`
4. **Application Properties**: `/etc/config/application-{{ environment }}.yml`

## 🔧 **CONFIGURATION INJECTION METHODS**

### **1. Environment Variables** ✅
Direct injection of Spring Boot properties via environment variables:

```yaml
env:
  - name: SPRING_PROFILES_ACTIVE
    value: "{{ .Values.global.environment }}"
  - name: SPRING_APPLICATION_NAME
    value: "{{ .Values.global.applicationName }}"
  - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
    valueFrom:
      configMapKeyRef:
        name: {{ include "java-app.fullname" . }}-config
        key: management.endpoints.web.exposure.include
```

### **2. ConfigMap Mount** ✅
Spring Boot properties file mounted at `/etc/config/`:

```yaml
volumeMounts:
  - name: config-volume
    mountPath: /etc/config
    readOnly: true

env:
  - name: SPRING_CONFIG_ADDITIONAL_LOCATION
    value: "file:/etc/config/"
```

### **3. Azure Key Vault Secrets** ✅
Secure secrets injection via Azure Key Vault CSI driver:

```yaml
volumeMounts:
  - name: secrets-store
    mountPath: /mnt/secrets-store
    readOnly: true

env:
  - name: AZURE_KEYVAULT_SECRETS_PATH
    value: "/mnt/secrets-store"
  - name: SPRING_CLOUD_AZURE_KEYVAULT_SECRET_ENABLED
    value: "true"
```

## 📊 **ENVIRONMENT-SPECIFIC CONFIGURATIONS**

### **Development Environment** 🔧

**Focus**: Full debugging and development productivity

```yaml
# Actuator Configuration
MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE: "*"
MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS: "always"

# Logging Configuration
LOG_LEVEL: "DEBUG"
SPRING_JPA_SHOW_SQL: "true"

# JVM Configuration
JAVA_OPTS: "-Xms256m -Xmx512m -XX:+UseG1GC -Dspring.devtools.restart.enabled=true"

# Development Tools
SPRING_DEVTOOLS_RESTART_ENABLED: "true"
SPRING_PROFILES_INCLUDE: "actuator,dev-tools"
```

**Exposed Actuator Endpoints**: ALL (`*`)
- `/actuator/health` - Health status (detailed)
- `/actuator/info` - Application information
- `/actuator/metrics` - Application metrics
- `/actuator/env` - Environment properties
- `/actuator/configprops` - Configuration properties
- `/actuator/beans` - Spring beans
- `/actuator/mappings` - Request mappings
- `/actuator/httptrace` - HTTP trace information

### **Staging Environment** 🧪

**Focus**: Production-like testing with extended monitoring

```yaml
# Actuator Configuration
MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE: "health,info,metrics,prometheus,env,configprops"
MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS: "when-authorized"

# Logging Configuration
LOG_LEVEL: "INFO"

# JVM Configuration
JAVA_OPTS: "-Xms512m -Xmx1g -XX:+UseG1GC -XX:+UseStringDeduplication -XX:MaxGCPauseMillis=200"
```

**Exposed Actuator Endpoints**: Extended monitoring
- `/actuator/health` - Health status (authorized users only)
- `/actuator/info` - Application information
- `/actuator/metrics` - Application metrics
- `/actuator/prometheus` - Prometheus metrics
- `/actuator/env` - Environment properties (for testing)
- `/actuator/configprops` - Configuration properties (for testing)

### **Production Environment** 🏭

**Focus**: Security, performance, and minimal exposure

```yaml
# Actuator Configuration
MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE: "health,info,metrics,prometheus"
MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS: "never"

# Logging Configuration
LOG_LEVEL: "WARN"

# JVM Configuration
JAVA_OPTS: "-Xms1g -Xmx2g -XX:+UseG1GC -XX:+UseStringDeduplication -XX:MaxGCPauseMillis=200 -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp"

# Production Optimizations
JVM_METRICS_ENABLED: "true"
```

**Exposed Actuator Endpoints**: Security-focused minimal set
- `/actuator/health` - Health status (no details)
- `/actuator/info` - Application information
- `/actuator/metrics` - Application metrics
- `/actuator/prometheus` - Prometheus metrics for monitoring

## 🔐 **SECRETS MANAGEMENT INTEGRATION**

### **Azure Key Vault Configuration**

The application automatically configures Azure Key Vault integration when enabled:

```yaml
spring:
  cloud:
    azure:
      keyvault:
        secret:
          enabled: true
          property-sources:
            - endpoint: https://{{ keyvault-name }}.vault.azure.net/
              name: {{ keyvault-name }}
```

### **Secret Access in Spring Boot**

Secrets are automatically available as Spring properties:

```java
@Value("${db-password}")
private String dbPassword;

@Value("${api-key}")
private String apiKey;

@Value("${jwt-secret}")
private String jwtSecret;
```

### **Environment Variables for Secret Paths**

```yaml
AZURE_KEYVAULT_SECRETS_PATH: "/mnt/secrets-store"
SPRING_CLOUD_AZURE_KEYVAULT_SECRET_ENABLED: "true"
```

## 📝 **CONFIGURATION FILES STRUCTURE**

### **Classpath Configuration** (Built into JAR)
```
src/main/resources/
├── application.yml              # Default configuration
├── application-dev.yml          # Development overrides
├── application-staging.yml      # Staging overrides
└── application-production.yml   # Production overrides
```

### **External Configuration** (Kubernetes ConfigMap)
```
/etc/config/
├── application-{{ environment }}.yml  # Environment-specific config
└── [additional config files]
```

### **Configuration Loading Order** (Spring Boot)
1. Classpath: `application.yml`
2. Classpath: `application-{{ environment }}.yml`
3. External: `/etc/config/application-{{ environment }}.yml`
4. Environment Variables
5. Azure Key Vault Properties

## 🚀 **JVM OPTIMIZATION BY ENVIRONMENT**

### **Development JVM Settings**
```bash
-Xms256m -Xmx512m 
-XX:+UseG1GC 
-Dspring.devtools.restart.enabled=true
```
**Focus**: Fast startup, development tools support

### **Staging JVM Settings**
```bash
-Xms512m -Xmx1g 
-XX:+UseG1GC 
-XX:+UseStringDeduplication 
-XX:MaxGCPauseMillis=200
```
**Focus**: Production-like performance testing

### **Production JVM Settings**
```bash
-Xms1g -Xmx2g 
-XX:+UseG1GC 
-XX:+UseStringDeduplication 
-XX:MaxGCPauseMillis=200 
-XX:+HeapDumpOnOutOfMemoryError 
-XX:HeapDumpPath=/tmp
```
**Focus**: Optimal performance, diagnostics, memory efficiency

## 🔍 **MONITORING & OBSERVABILITY**

### **Health Check Endpoints**

All environments expose health checks with different detail levels:

```yaml
# Development
/actuator/health - Full details always shown

# Staging  
/actuator/health - Details shown when authorized

# Production
/actuator/health - No details shown (security)
```

### **Kubernetes Probes Integration**

```yaml
management:
  endpoint:
    health:
      probes:
        enabled: true
  health:
    readiness-state:
      enabled: true
    liveness-state:
      enabled: true
```

**Probe Endpoints**:
- `/actuator/health/liveness` - Kubernetes liveness probe
- `/actuator/health/readiness` - Kubernetes readiness probe

### **Metrics Collection**

**Development**: All metrics exposed
**Staging**: Extended metrics for testing
**Production**: Essential metrics only

```
/actuator/metrics     - Micrometer metrics
/actuator/prometheus  - Prometheus format metrics
```

## ✅ **VERIFICATION CHECKLIST**

### **Configuration Injection** ✅
- [x] Environment variables properly set
- [x] ConfigMap mounted and accessible
- [x] Azure Key Vault secrets mounted
- [x] Spring Boot profiles activated correctly

### **Environment-Specific Settings** ✅
- [x] Development: Full debugging enabled
- [x] Staging: Production-like with monitoring
- [x] Production: Optimized and secure

### **Secrets Management** ✅
- [x] Azure Key Vault integration configured
- [x] Workload Identity authentication
- [x] Secrets mounted to filesystem
- [x] Spring Boot Azure Key Vault properties

### **Monitoring & Health Checks** ✅
- [x] Actuator endpoints configured per environment
- [x] Kubernetes liveness/readiness probes
- [x] Prometheus metrics exposed
- [x] Logging levels appropriate for environment

## 🎯 **USAGE IN SPRING BOOT APPLICATION**

### **Accessing Configuration**

```java
@ConfigurationProperties(prefix = "app")
@Component
public class AppConfig {
    private String environment;
    private String applicationName;
    // getters and setters
}
```

### **Accessing Secrets**

```java
@Value("${db-password}")
private String dbPassword;

// Or using @ConfigurationProperties
@ConfigurationProperties(prefix = "db")
public class DatabaseConfig {
    private String password; // Maps to 'db-password' from Key Vault
}
```

### **Using Profiles**

```java
@Profile("dev")
@Component
public class DevOnlyComponent {
    // Only active in development
}

@Profile("!production")
@Component
public class NonProductionComponent {
    // Active in dev and staging only
}
```

## 🚀 **READY FOR DEPLOYMENT**

The Spring Boot application will automatically:

1. **Activate correct profiles** based on environment
2. **Load configuration** from multiple sources in correct order
3. **Access secrets** from Azure Key Vault seamlessly
4. **Expose appropriate endpoints** for monitoring
5. **Apply JVM optimizations** suitable for the environment
6. **Provide health checks** for Kubernetes

**No additional configuration required** - everything is handled by the Helm chart during deployment!