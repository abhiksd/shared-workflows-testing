# Troubleshooting Guide

Common issues and solutions when migrating Spring Boot applications to use standardized Helm charts.

## 🚨 Common Issues

### 1. ServiceMonitor CRD Not Found

**Error:**
```
no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"
```

**Solution:**
```bash
# Option 1: Disable ServiceMonitor temporarily
helm install my-app ./helm --set monitoring.serviceMonitor.enabled=false

# Option 2: Install Prometheus Operator first
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

### 2. Spring Profiles Active Error

**Error:**
```
Property 'spring.profiles.active' imported from location 'file [/etc/config/application-sqe.yml]' is invalid in a profile specific resource
```

**Solution:**
Remove `spring.profiles.active` from profile-specific YAML files:
```yaml
# ❌ Wrong - in application-sqe.yml
spring:
  profiles:
    active: sqe  # Remove this line

# ✅ Correct - only in main application.yml
spring:
  profiles:
    active: ${SPRING_PROFILES_ACTIVE:dev}
```

### 3. Image Pull Errors

**Error:**
```
Failed to pull image "my-app:0.0.0": rpc error: code = NotFound
```

**Solutions:**
```bash
# Check image tag in values
helm template my-app ./helm | grep image:

# Set correct image tag
helm install my-app ./helm --set image.tag=dev-latest

# Check if image exists in registry
docker images | grep my-app
```

### 4. Health Check Failures

**Error:**
```
Readiness probe failed: Get "http://10.0.0.1:8080/actuator/health/readiness": dial tcp 10.0.0.1:8080: connect: connection refused
```

**Solutions:**
```bash
# Check if actuator dependency is added
grep -r "spring-boot-starter-actuator" pom.xml

# Verify health endpoints are enabled
curl http://localhost:8080/actuator/health

# Check application logs
kubectl logs deployment/my-app
```

### 5. Database Connection Issues

**Error:**
```
java.sql.SQLException: Connection refused
```

**Solutions:**
```yaml
# Update database configuration in application-{env}.yml
spring:
  datasource:
    url: jdbc:postgresql://correct-host:5432/dbname
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
```

### 6. Permission Denied Errors

**Error:**
```
java.io.FileNotFoundException: /app/logs/application.log (Permission denied)
```

**Solutions:**
```yaml
# Update deployment security context
securityContext:
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000

# Or use /tmp for logs
logging:
  file:
    name: /tmp/application.log
```

### 7. Ingress Not Working

**Error:**
```
404 Not Found when accessing application URL
```

**Solutions:**
```bash
# Check ingress configuration
kubectl get ingress
kubectl describe ingress my-app

# Verify service is running
kubectl get svc
kubectl get endpoints

# Check ingress controller
kubectl get pods -n ingress-nginx
```

### 8. ConfigMap Issues

**Error:**
```
Error: couldn't find key application-dev.yml in ConfigMap
```

**Solutions:**
```yaml
# Ensure configMap is enabled
configMap:
  enabled: true

# Check if configMap is created
kubectl get configmap
kubectl describe configmap my-app-config
```

## 🔍 Debugging Commands

### General Debugging
```bash
# Check pod status
kubectl get pods
kubectl describe pod my-app-xxx

# Check logs
kubectl logs deployment/my-app
kubectl logs deployment/my-app --previous

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Helm Debugging
```bash
# Lint chart
helm lint ./helm

# Dry run deployment
helm install my-app ./helm --dry-run --debug

# Template rendering
helm template my-app ./helm --values ./helm/values-dev.yaml

# Check release status
helm status my-app
helm get values my-app
```

### Spring Boot Debugging
```bash
# Check actuator endpoints
curl http://localhost:8080/actuator/health
curl http://localhost:8080/actuator/info
curl http://localhost:8080/actuator/env

# Check application properties
curl http://localhost:8080/actuator/configprops
curl http://localhost:8080/actuator/beans
```

## 🛠️ Configuration Validation

### Validate Spring Boot Configuration
```bash
# Test different profiles locally
mvn spring-boot:run -Dspring-boot.run.profiles=dev
mvn spring-boot:run -Dspring-boot.run.profiles=sqe

# Check for YAML syntax errors
python3 -c "
import yaml
with open('src/main/resources/application.yml') as f:
    yaml.safe_load(f)
print('YAML is valid')
"
```

### Validate Helm Chart
```bash
# Comprehensive validation
helm lint ./helm
helm template test ./helm --values ./helm/values-dev.yaml --debug
helm install test ./helm --dry-run --debug
```

### Validate Docker Image
```bash
# Test image locally
docker build -t my-app:test .
docker run -p 8080:8080 my-app:test

# Check image in registry
docker pull my-registry.azurecr.io/my-app:latest
```

## 📋 Environment-Specific Issues

### Development Environment
- **Issue**: Slow startup times
- **Solution**: Increase health check delays in values-dev.yaml

### SQE Environment
- **Issue**: Resource limits too low
- **Solution**: Adjust CPU/memory in values-sqe.yaml

### Production Environment
- **Issue**: Security context restrictions
- **Solution**: Ensure proper security settings in values-production.yaml

## 🔧 Performance Issues

### High Memory Usage
```yaml
# Adjust JVM settings
env:
  - name: JAVA_OPTS
    value: "-Xms512m -Xmx1024m -XX:+UseG1GC"
```

### Slow Database Queries
```yaml
# Optimize connection pool
spring:
  datasource:
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      connection-timeout: 30000
```

### Pod Startup Issues
```yaml
# Increase probe delays
livenessProbe:
  initialDelaySeconds: 60
readinessProbe:
  initialDelaySeconds: 30
```

## 📞 Getting Help

### Check Documentation
- [Migration Guide](migration-guide.md)
- [Helm Best Practices](helm-best-practices.md)

### Common Patterns
- Compare with existing working applications
- Check java-backend1 as reference implementation
- Review shared deployment workflows

### Debug Checklist
- [ ] Helm chart lints successfully
- [ ] Image exists and is accessible
- [ ] Database configuration is correct
- [ ] Health endpoints respond
- [ ] Environment variables are set
- [ ] Security context allows required operations
- [ ] Resources limits are adequate
- [ ] Ingress configuration is correct