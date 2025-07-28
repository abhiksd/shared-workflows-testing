# Complete Migration Guide

This guide walks you through migrating any Spring Boot application to use the standardized Helm charts.

## 📋 Prerequisites

- Spring Boot 2.5+ or 3.x application
- Maven or Gradle build tool
- Docker for containerization
- Helm 3.x
- Kubernetes cluster access

## 🚀 Step-by-Step Migration

### Step 1: Copy Template Files

```bash
# Copy the Helm chart template
cp -r helm-migrations/templates/helm-chart-template apps/your-app-name/helm

# Copy Spring Boot config templates
cp helm-migrations/templates/spring-boot-configs/* apps/your-app-name/src/main/resources/
```

### Step 2: Customize Helm Chart

1. **Update Chart.yaml**
   - Change `name` to your application name
   - Update `description`
   - Update maintainer information

2. **Update values.yaml**
   - Change `global.applicationName`
   - Change `image.repository`
   - Update `ingress.hosts`
   - Adjust resource limits/requests

3. **Update _helpers.tpl**
   - Replace all `app-template` with your app name
   - Update label definitions

### Step 3: Configure Spring Boot

1. **Update application.yml**
   - Change package names in logging configuration
   - Update application name
   - Configure database settings

2. **Environment-specific configs**
   - Update database URLs for each environment
   - Configure CORS origins
   - Set appropriate logging levels

### Step 4: Update Application Code

1. **Add required dependencies** (see examples/sample-app/pom.xml)
2. **Add health check endpoints**
3. **Configure CORS if needed**
4. **Update package names**

### Step 5: Create Dockerfile

```dockerfile
FROM openjdk:17-jre-slim
COPY target/your-app-name.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

### Step 6: Test and Deploy

```bash
# Validate Helm chart
helm lint apps/your-app-name/helm

# Test template rendering
helm template test apps/your-app-name/helm

# Deploy to development
helm install your-app-dev apps/your-app-name/helm \
  --values apps/your-app-name/helm/values-dev.yaml
```

## 🔧 Common Customizations

### Database Configuration
- Update datasource URLs in application-{env}.yml files
- Add database-specific dependencies to pom.xml
- Configure connection pooling settings

### Security Configuration
- Configure CORS origins for each environment
- Set up authentication if needed
- Configure HTTPS settings

### Monitoring Integration
- Enable ServiceMonitor for Prometheus
- Configure custom metrics
- Set up alerting rules

## ✅ Migration Checklist

- [ ] Copied and customized Helm chart
- [ ] Updated all configuration files
- [ ] Added required dependencies
- [ ] Created Dockerfile
- [ ] Updated package names
- [ ] Configured database settings
- [ ] Set up monitoring
- [ ] Tested locally
- [ ] Deployed to development
- [ ] Verified health endpoints
- [ ] Created deployment workflow

## 🆘 Troubleshooting

See [troubleshooting.md](troubleshooting.md) for common issues and solutions.

## 📝 Detailed Steps

### Customizing Chart.yaml

```yaml
# Before
name: app-template
description: A Helm chart template for Spring Boot applications

# After
name: my-spring-app
description: My Spring Boot application Helm chart
```

### Customizing _helpers.tpl

```bash
# Replace all instances of "app-template" with your app name
sed -i 's/app-template/my-spring-app/g' helm/templates/_helpers.tpl
```

### Customizing Values Files

```yaml
# values.yaml
global:
  applicationName: my-spring-app  # Change this
image:
  repository: my-registry.azurecr.io/my-spring-app  # Change this
ingress:
  hosts:
    - host: my-app.local  # Change this
```

### Customizing Spring Boot Configs

```yaml
# application.yml
spring:
  application:
    name: my-spring-app  # Change this

logging:
  level:
    com.mycompany.myapp: INFO  # Change package name
```

### Required Dependencies

Add to your `pom.xml`:

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    <dependency>
        <groupId>io.micrometer</groupId>
        <artifactId>micrometer-registry-prometheus</artifactId>
    </dependency>
</dependencies>
```

### Environment Variables

Set these in your deployment:

```bash
SPRING_PROFILES_ACTIVE=dev
APPLICATION_NAME=my-spring-app
SERVER_PORT=8080
DB_HOST=your-database-host
DB_USERNAME=your-db-user
DB_PASSWORD=your-db-password
```

## 🔄 Testing Your Migration

### Local Testing

```bash
# Test Spring Boot app
mvn spring-boot:run -Dspring-boot.run.profiles=dev

# Test health endpoints
curl http://localhost:8080/actuator/health
curl http://localhost:8080/actuator/health/liveness
curl http://localhost:8080/actuator/health/readiness
```

### Helm Testing

```bash
# Lint chart
helm lint apps/your-app/helm

# Dry run
helm install test apps/your-app/helm --dry-run --debug

# Template test
helm template test apps/your-app/helm --values apps/your-app/helm/values-dev.yaml
```

### Deployment Testing

```bash
# Deploy to dev
helm install your-app-dev apps/your-app/helm \
  --values apps/your-app/helm/values-dev.yaml \
  --namespace dev-your-app \
  --create-namespace

# Check deployment
kubectl get pods -n dev-your-app
kubectl logs deployment/your-app-dev -n dev-your-app
```

## 📚 Additional Resources

- [Helm Best Practices](helm-best-practices.md)
- [Troubleshooting Guide](troubleshooting.md)
- [Spring Boot Configuration Reference](https://docs.spring.io/spring-boot/docs/current/reference/html/application-properties.html)