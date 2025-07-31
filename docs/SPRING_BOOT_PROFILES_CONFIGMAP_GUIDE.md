# Spring Boot Profiles & ConfigMap Integration Guide

## 📋 **Complete Environment Overview**

This guide explains how Spring Boot profiles work with Kubernetes ConfigMaps across all environments for the Java Backend 1 - User Management Service.

### **🎯 Environment Progression Flow**

```
Local → SQE (Staging/QA) → PPR (Pre-Production) → Production
  ↓         ↓                  ↓                    ↓
development  testing      final validation    live system
```

## 📊 **Profile Configuration Comparison**

| Environment | Profile | Purpose | Security Level | Logging | Schema Management |
|-------------|---------|---------|----------------|---------|-------------------|
| **Local** | `local` | Development | Low | Verbose (DEBUG) | `create-drop` |
| **SQE** | `sqe` | Testing/QA | Medium | Balanced (INFO) | `validate` |
| **PPR** | `ppr` | Pre-Production | High | Minimal (WARN) | `none` |
| **Production** | `production` | Live System | Maximum | Minimal (ERROR) | `none` |

## 🏗️ **Spring Boot Profiles Structure**

### **1. Base Configuration (`application.yml`)**
```yaml
# Common settings for ALL environments
spring:
  application:
    name: java-backend1-user-management
  profiles:
    active: ${SPRING_PROFILES_ACTIVE:local}
  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:userdb}
    username: ${DB_USERNAME:user}
    password: ${DB_PASSWORD:password}
    hikari:
      maximum-pool-size: ${DB_POOL_SIZE:10}
      minimum-idle: ${DB_POOL_MIN_IDLE:5}
```

### **2. Local Development (`application-local.yml`)**
```yaml
# Developer-friendly settings
spring:
  jpa:
    hibernate:
      ddl-auto: create-drop  # ⚠️ Recreates schema
    show-sql: true           # Shows SQL queries
logging:
  level:
    com.example.userservice: DEBUG  # Verbose logging
management:
  endpoint:
    health:
      show-details: always   # Full health details
```

### **3. SQE Testing (`application-sqe.yml`)**
```yaml
# Testing environment - balanced settings
spring:
  jpa:
    hibernate:
      ddl-auto: validate     # ✅ Validates existing schema
    show-sql: false          # No SQL logging for performance
logging:
  level:
    com.example.userservice: INFO    # Balanced logging
management:
  endpoint:
    health:
      show-details: when-authorized  # Conditional details
```

### **4. PPR Pre-Production (`application-ppr.yml`)**
```yaml
# Production-like settings
spring:
  jpa:
    hibernate:
      ddl-auto: none         # 🔒 Never modify schema
    show-sql: false
logging:
  level:
    com.example.userservice: WARN    # Minimal logging
management:
  endpoint:
    health:
      show-details: never    # 🔒 No health details exposed
```

### **5. Production (`application-production.yml`)**
```yaml
# Maximum security and performance
spring:
  jpa:
    hibernate:
      ddl-auto: none         # 🔒 Never modify schema
    show-sql: false
logging:
  level:
    root: ERROR              # 🔒 Minimal logging
    com.example.userservice: WARN
management:
  endpoint:
    health:
      show-details: never    # 🔒 No health details exposed
```

## 🔧 **ConfigMap Integration**

### **How Environment Variables Override Spring Properties**

```yaml
# Spring Boot Profile (application-sqe.yml)
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}
    hikari:
      maximum-pool-size: ${DB_POOL_SIZE:15}

# ConfigMap (values-sqe.yaml → ConfigMap)
configMap:
  DB_HOST: "postgres-sqe.internal.company.com"
  DB_PORT: "5432"
  DB_NAME: "userdb_sqe"
  DB_POOL_SIZE: "15"

# Final Result
spring.datasource.url=jdbc:postgresql://postgres-sqe.internal.company.com:5432/userdb_sqe
spring.datasource.hikari.maximum-pool-size=15
```

## 📁 **Helm Values Structure**

### **SQE Environment (`values-sqe.yaml`)**
```yaml
app:
  environment: sqe
springboot:
  profiles:
    active: "sqe"
    
# Resources optimized for testing
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

# Database configuration
database:
  host: "postgres-sqe.internal.company.com"
  name: "userdb_sqe"
  username: "userapp_sqe"

# ConfigMap values
configMap:
  SPRING_PROFILES_ACTIVE: "sqe"
  DB_POOL_SIZE: "15"
  LOG_LEVEL_APP: "INFO"
  HEALTH_SHOW_DETAILS: "when-authorized"
  JWT_EXPIRATION: "7200000"  # 2 hours for testing
```

### **PPR Environment (`values-ppr.yaml`)**
```yaml
app:
  environment: ppr
springboot:
  profiles:
    active: "ppr"

# Production-like resources
resources:
  limits:
    cpu: 1500m
    memory: 2Gi
  requests:
    cpu: 750m
    memory: 1Gi

# Production-like database
database:
  host: "postgres-ppr.internal.company.com"
  name: "userdb_ppr"
  username: "userapp_ppr"

# ConfigMap values - production-like
configMap:
  SPRING_PROFILES_ACTIVE: "ppr"
  DB_POOL_SIZE: "18"
  LOG_LEVEL_APP: "WARN"
  HEALTH_SHOW_DETAILS: "never"
  JWT_EXPIRATION: "3600000"  # 1 hour like production

# Production-like security
securityContext:
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
```

## 🚀 **Deployment Commands**

### **Deploy to SQE**
```bash
# Deploy using SQE values
helm upgrade --install java-backend1-sqe ./apps/java-backend1/helm \
  --namespace sqe \
  --values ./apps/java-backend1/helm/values-sqe.yaml \
  --set image.tag=develop-latest

# Verify deployment
kubectl get pods -n sqe -l app.kubernetes.io/name=java-backend1
kubectl logs -n sqe deployment/java-backend1 --tail=50
```

### **Deploy to PPR**
```bash
# Deploy using PPR values
helm upgrade --install java-backend1-ppr ./apps/java-backend1/helm \
  --namespace ppr \
  --values ./apps/java-backend1/helm/values-ppr.yaml \
  --set image.tag=release-candidate-1.0.0

# Verify deployment
kubectl get pods -n ppr -l app.kubernetes.io/name=java-backend1
kubectl describe configmap java-backend1-ppr-config -n ppr
```

## 🔍 **Environment Comparison Table**

| Configuration | Local | SQE | PPR | Production |
|---------------|-------|-----|-----|------------|
| **Spring Profile** | `local` | `sqe` | `ppr` | `production` |
| **JPA DDL Auto** | `create-drop` | `validate` | `none` | `none` |
| **Show SQL** | ✅ `true` | ❌ `false` | ❌ `false` | ❌ `false` |
| **Log Level** | `DEBUG` | `INFO` | `WARN` | `ERROR/WARN` |
| **Health Details** | `always` | `when-authorized` | `never` | `never` |
| **DB Pool Size** | `5` | `15` | `18` | `20` |
| **JWT Expiration** | `1h` | `2h` | `1h` | `1h` |
| **CPU Limit** | `500m` | `1000m` | `1500m` | `2000m` |
| **Memory Limit** | `512Mi` | `1Gi` | `2Gi` | `4Gi` |
| **Replicas** | `1` | `2` | `3` | `5` |
| **Autoscaling** | ❌ | ❌ | ✅ | ✅ |
| **Network Policy** | ❌ | ❌ | ✅ | ✅ |
| **Read-only FS** | ❌ | ❌ | ✅ | ✅ |

## 📝 **Configuration Flow Examples**

### **Example 1: Database Connection**

#### **Spring Profile Definition:**
```yaml
# application-sqe.yml
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
```

#### **Helm Values:**
```yaml
# values-sqe.yaml
database:
  host: "postgres-sqe.cluster.local"
  port: "5432"
  name: "userdb_sqe"
  username: "userapp_sqe"
```

#### **Generated ConfigMap:**
```yaml
apiVersion: v1
kind: ConfigMap
data:
  DB_HOST: "postgres-sqe.cluster.local"
  DB_PORT: "5432"
  DB_NAME: "userdb_sqe"
  DB_USERNAME: "userapp_sqe"
  SPRING_PROFILES_ACTIVE: "sqe"
```

#### **Runtime Result:**
```
Final Database URL: jdbc:postgresql://postgres-sqe.cluster.local:5432/userdb_sqe
Spring Profile Active: sqe
JPA DDL Auto: validate (from application-sqe.yml)
```

### **Example 2: Security Configuration**

#### **Spring Profile:**
```yaml
# application-ppr.yml
app:
  security:
    jwt:
      secret: ${JWT_SECRET}
      expiration: ${JWT_EXPIRATION:3600000}
```

#### **Helm Values:**
```yaml
# values-ppr.yaml
security:
  jwt:
    expiration: "3600000"
secrets:
  JWT_SECRET: "base64-encoded-secret"
```

#### **Generated Resources:**
```yaml
# ConfigMap
data:
  JWT_EXPIRATION: "3600000"
  SPRING_PROFILES_ACTIVE: "ppr"

# Secret
data:
  JWT_SECRET: "base64-encoded-secret"
```

## 🛠️ **Best Practices**

### **✅ Do's**
1. **Use Spring Profiles for behavior changes** (logging, JPA settings, security)
2. **Use ConfigMaps for environment-specific values** (URLs, credentials, timeouts)
3. **Keep secrets in Kubernetes Secrets, not ConfigMaps**
4. **Use consistent naming across environments**
5. **Test profile behavior changes in SQE before PPR**
6. **Document all environment variables**

### **❌ Don'ts**
1. **Don't hardcode environment values in profiles**
2. **Don't put sensitive data in ConfigMaps**
3. **Don't use different profile behavior between PPR and Production**
4. **Don't skip SQE testing when changing profiles**
5. **Don't expose debug information in production profiles**

## 🔧 **Troubleshooting**

### **Check Active Profile**
```bash
# Check which profile is active
kubectl exec -n sqe deployment/java-backend1 -- \
  curl -s http://localhost:8080/actuator/env | jq '.propertySources[] | select(.name | contains("application-sqe"))'
```

### **Verify ConfigMap Values**
```bash
# Check ConfigMap content
kubectl get configmap java-backend1-sqe-config -n sqe -o yaml

# Check if values are injected as environment variables
kubectl exec -n sqe deployment/java-backend1 -- env | grep -E "DB_|SPRING_|JWT_"
```

### **Test Profile-Specific Behavior**
```bash
# Check JPA DDL Auto setting
kubectl logs -n sqe deployment/java-backend1 | grep -i "ddl-auto"

# Check logging level
kubectl logs -n sqe deployment/java-backend1 | grep -i "debug\|info\|warn\|error"

# Check health endpoint details
curl -s https://sqe.mydomain.com/java-backend1/actuator/health | jq '.'
```

## 📚 **Summary**

This setup provides:
- **🔧 Spring Boot Profiles**: Control application behavior per environment
- **🏗️ ConfigMaps**: Inject environment-specific configuration
- **🔒 Secrets**: Secure sensitive data management
- **📊 Progressive Validation**: Local → SQE → PPR → Production
- **🛡️ Security Gradation**: Increasing security from development to production
- **🎯 Environment Parity**: Consistent deployment patterns across environments

The combination ensures your application behaves correctly in each environment while maintaining security, performance, and operational requirements! 🚀