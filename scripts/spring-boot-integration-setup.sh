#!/bin/bash

# Spring Boot Production Integration Setup Script
# This script helps integrate Helm, Spring Boot profiles, and monitoring

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="${1:-your-spring-boot-app}"
ENVIRONMENT="${2:-dev}"
NAMESPACE="${3:-default}"

print_header() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}  🚀 Spring Boot Production Integration Setup${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}✨ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check if required tools are installed
    local missing_tools=()
    
    if ! command -v java &> /dev/null; then
        missing_tools+=("java (JDK 17+)")
    fi
    
    if ! command -v mvn &> /dev/null; then
        missing_tools+=("maven")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        exit 1
    fi
    
    echo "✅ All required tools are installed"
}

validate_java_version() {
    print_step "Validating Java version..."
    
    local java_version=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | sed '/^1\./s///' | cut -d'.' -f1)
    
    if [ "$java_version" -lt 17 ]; then
        print_error "Java 17+ is required. Current version: $java_version"
        exit 1
    fi
    
    echo "✅ Java version $java_version is supported"
}

create_directory_structure() {
    print_step "Creating directory structure..."
    
    # Create Spring Boot profile directories
    mkdir -p src/main/resources
    mkdir -p src/main/java/com/yourcompany/{config,health,metrics,aspects,annotations}
    
    # Create Helm chart directories
    mkdir -p helm/templates/tests
    
    # Create scripts directory
    mkdir -p scripts/deployment
    
    echo "✅ Directory structure created"
}

setup_maven_dependencies() {
    print_step "Setting up Maven dependencies..."
    
    cat > pom-dependencies.xml << 'EOF'
<!-- Add these dependencies to your pom.xml -->

<!-- Spring Boot Actuator for monitoring -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>

<!-- Micrometer for metrics -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>

<!-- Spring Boot Configuration Processor -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-configuration-processor</artifactId>
    <optional>true</optional>
</dependency>

<!-- Logback for structured logging -->
<dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
    <version>7.4</version>
</dependency>

<!-- Spring Boot Starter Redis (if using Redis) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>

<!-- Spring Boot Starter AOP (for metrics aspect) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-aop</artifactId>
</dependency>
EOF

    echo "✅ Maven dependencies template created (pom-dependencies.xml)"
    print_warning "Please add the dependencies from pom-dependencies.xml to your pom.xml"
}

create_spring_profiles() {
    print_step "Creating Spring Boot profile configurations..."
    
    # Base application.yml
    cat > src/main/resources/application.yml << 'EOF'
# Base configuration - shared across all environments
server:
  port: 8080
  servlet:
    context-path: /api

spring:
  application:
    name: ${APPLICATION_NAME:your-app-name}
  profiles:
    active: ${SPRING_PROFILES_ACTIVE:local}
  
  # Database configuration
  datasource:
    driver-class-name: org.postgresql.Driver
    hikari:
      minimum-idle: 5
      maximum-pool-size: 20
      idle-timeout: 300000
      connection-timeout: 20000

  # JPA configuration
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        format_sql: true

# Actuator configuration for monitoring
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
      base-path: /actuator
  endpoint:
    health:
      show-details: when-authorized
      probes:
        enabled: true
  metrics:
    export:
      prometheus:
        enabled: true
  info:
    env:
      enabled: true
    git:
      mode: full

# Logging configuration
logging:
  level:
    com.yourcompany: INFO
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} - %msg%n"
    file: "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n"
EOF

    # Development profile
    cat > src/main/resources/application-dev.yml << 'EOF'
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST:postgres-dev}:${DB_PORT:5432}/${DB_NAME:yourapp_dev}
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
  
  # Redis configuration for caching
  redis:
    host: ${REDIS_HOST:redis-dev}
    port: ${REDIS_PORT:6379}
    password: ${REDIS_PASSWORD:}
    timeout: 2000ms

# External service configurations
external:
  api:
    user-service:
      url: ${USER_SERVICE_URL:http://user-service-dev:8080}
      timeout: 5000
    notification-service:
      url: ${NOTIFICATION_SERVICE_URL:http://notification-service-dev:3000}
      timeout: 3000

logging:
  level:
    root: INFO
    com.yourcompany: DEBUG
EOF

    # Production profile
    cat > src/main/resources/application-production.yml << 'EOF'
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
    hikari:
      minimum-idle: 15
      maximum-pool-size: 50
      leak-detection-threshold: 60000

  redis:
    host: ${REDIS_HOST}
    port: ${REDIS_PORT:6379}
    password: ${REDIS_PASSWORD}
    timeout: 2000ms

external:
  api:
    user-service:
      url: ${USER_SERVICE_URL}
      timeout: 10000
    notification-service:
      url: ${NOTIFICATION_SERVICE_URL}
      timeout: 5000

# Production monitoring (limited endpoints for security)
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: never

logging:
  level:
    root: ERROR
    com.yourcompany: WARN
  file:
    name: /var/log/app/application.log
EOF

    echo "✅ Spring Boot profiles created"
}

create_helm_chart() {
    print_step "Creating Helm chart..."
    
    # Chart.yaml
    cat > helm/Chart.yaml << EOF
apiVersion: v2
name: $APP_NAME
description: Production-ready Spring Boot application with monitoring
type: application
version: 0.1.0
appVersion: "1.0.0"
keywords:
  - spring-boot
  - java
  - microservice
home: https://github.com/your-org/$APP_NAME
sources:
  - https://github.com/your-org/$APP_NAME
maintainers:
  - name: Your Team
    email: team@yourcompany.com
EOF

    # Base values.yaml
    cat > helm/values.yaml << 'EOF'
# Default values for Spring Boot application
replicaCount: 2

image:
  repository: your-registry/your-app
  pullPolicy: IfNotPresent
  tag: ""

serviceAccount:
  create: true
  annotations: {}
  name: ""

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/path: "/actuator/prometheus"
  prometheus.io/port: "8080"

service:
  type: ClusterIP
  port: 8080
  targetPort: 8080

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

springboot:
  profiles:
    active: "production"
  env:
    JAVA_OPTS: "-Xms512m -Xmx1g -XX:+UseG1GC"

database:
  host: "postgres"
  port: "5432"
  name: "yourapp"
  username: "app_user"

monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
    path: /actuator/prometheus

healthCheck:
  enabled: true
  livenessProbe:
    httpGet:
      path: /actuator/health/liveness
      port: http
    initialDelaySeconds: 60
    periodSeconds: 10
  readinessProbe:
    httpGet:
      path: /actuator/health/readiness
      port: http
    initialDelaySeconds: 30
    periodSeconds: 5
EOF

    # Environment-specific values
    cat > helm/values-$ENVIRONMENT.yaml << EOF
# $ENVIRONMENT environment configuration
springboot:
  profiles:
    active: "$ENVIRONMENT"

database:
  host: "postgres-$ENVIRONMENT"
  name: "yourapp_$ENVIRONMENT"

ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
  hosts:
    - host: $APP_NAME-$ENVIRONMENT.yourdomain.com
      paths:
        - path: /
          pathType: Prefix
EOF

    echo "✅ Helm chart created"
}

create_deployment_script() {
    print_step "Creating deployment script..."
    
    cat > scripts/deployment/deploy.sh << 'EOF'
#!/bin/bash

# Deployment script for Spring Boot application
set -e

APP_NAME="${1:-your-spring-boot-app}"
ENVIRONMENT="${2:-dev}"
NAMESPACE="${3:-default}"
IMAGE_TAG="${4:-latest}"

echo "🚀 Deploying $APP_NAME to $ENVIRONMENT environment..."

# Build and push Docker image
echo "📦 Building Docker image..."
mvn clean package -DskipTests
docker build -t $APP_NAME:$IMAGE_TAG .

# Push to registry (adjust for your registry)
echo "📤 Pushing to registry..."
# docker tag $APP_NAME:$IMAGE_TAG your-registry/$APP_NAME:$IMAGE_TAG
# docker push your-registry/$APP_NAME:$IMAGE_TAG

# Deploy with Helm
echo "🚢 Deploying with Helm..."
helm upgrade --install $APP_NAME ./helm \
    --values ./helm/values-$ENVIRONMENT.yaml \
    --set image.tag=$IMAGE_TAG \
    --namespace $NAMESPACE \
    --create-namespace \
    --wait \
    --timeout 300s

echo "✅ Deployment completed successfully!"

# Verify deployment
echo "🔍 Verifying deployment..."
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME
kubectl get services -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME

echo "📊 Health check:"
kubectl port-forward -n $NAMESPACE svc/$APP_NAME 8080:8080 &
PF_PID=$!
sleep 5
curl -f http://localhost:8080/actuator/health || echo "Health check failed"
kill $PF_PID

echo "🎉 Deployment verification completed!"
EOF

    chmod +x scripts/deployment/deploy.sh
    echo "✅ Deployment script created"
}

create_monitoring_setup() {
    print_step "Creating monitoring setup..."
    
    cat > scripts/deployment/setup-monitoring.sh << 'EOF'
#!/bin/bash

# Monitoring setup script
set -e

NAMESPACE="${1:-monitoring}"

echo "📊 Setting up monitoring stack..."

# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus Operator
echo "🔧 Installing Prometheus Operator..."
helm upgrade --install prometheus-operator prometheus-community/kube-prometheus-stack \
    --namespace $NAMESPACE \
    --create-namespace \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
    --set grafana.enabled=true \
    --set grafana.adminPassword=admin123 \
    --wait

echo "✅ Monitoring stack installed!"

# Get Grafana admin password
echo "🔑 Grafana admin password:"
kubectl get secret --namespace $NAMESPACE prometheus-operator-grafana \
    -o jsonpath="{.data.admin-password}" | base64 --decode

echo ""
echo "🌐 Access Grafana:"
echo "kubectl port-forward --namespace $NAMESPACE svc/prometheus-operator-grafana 3000:80"
echo "Then open http://localhost:3000 (admin/admin123)"
EOF

    chmod +x scripts/deployment/setup-monitoring.sh
    echo "✅ Monitoring setup script created"
}

create_java_configuration_classes() {
    print_step "Creating Java configuration classes..."
    
    # External Service Configuration
    cat > src/main/java/com/yourcompany/config/ExternalServiceConfig.java << 'EOF'
package com.yourcompany.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import lombok.Data;

@Data
@Configuration
@ConfigurationProperties(prefix = "external.api")
public class ExternalServiceConfig {
    
    private ServiceConfig userService = new ServiceConfig();
    private ServiceConfig notificationService = new ServiceConfig();
    
    @Data
    public static class ServiceConfig {
        private String url;
        private int timeout = 5000;
    }
}
EOF

    # Monitoring Configuration
    cat > src/main/java/com/yourcompany/config/MonitoringConfig.java << 'EOF'
package com.yourcompany.config;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Tags;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.actuate.autoconfigure.metrics.MeterRegistryCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MonitoringConfig {
    
    @Value("${spring.application.name}")
    private String applicationName;
    
    @Value("${spring.profiles.active}")
    private String environment;
    
    @Bean
    MeterRegistryCustomizer<MeterRegistry> metricsCommonTags() {
        return registry -> registry.config().commonTags(
            Tags.of(
                "application", applicationName,
                "environment", environment
            )
        );
    }
}
EOF

    # Health Check
    cat > src/main/java/com/yourcompany/health/ExternalServiceHealthIndicator.java << 'EOF'
package com.yourcompany.health;

import com.yourcompany.config.ExternalServiceConfig;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Component
@RequiredArgsConstructor
public class ExternalServiceHealthIndicator implements HealthIndicator {
    
    private final ExternalServiceConfig config;
    
    @Override
    public Health health() {
        try {
            // Implement your health check logic here
            return Health.up()
                .withDetail("user-service", "UP")
                .withDetail("notification-service", "UP")
                .build();
        } catch (Exception e) {
            log.error("Health check failed", e);
            return Health.down()
                .withDetail("error", e.getMessage())
                .build();
        }
    }
}
EOF

    # Metrics Component
    cat > src/main/java/com/yourcompany/metrics/ApplicationMetrics.java << 'EOF'
package com.yourcompany.metrics;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.stereotype.Component;
import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
public class ApplicationMetrics {
    
    private final MeterRegistry meterRegistry;
    
    private final Counter requestCounter = Counter.builder("app.requests.total")
            .description("Total number of requests")
            .register(meterRegistry);
    
    private final Timer requestTimer = Timer.builder("app.requests.duration")
            .description("Request processing time")
            .register(meterRegistry);
    
    public void incrementRequestCount() {
        requestCounter.increment();
    }
    
    public Timer.Sample startTimer() {
        return Timer.start(meterRegistry);
    }
    
    public void recordTime(Timer.Sample sample) {
        sample.stop(requestTimer);
    }
}
EOF

    echo "✅ Java configuration classes created"
}

create_logback_configuration() {
    print_step "Creating Logback configuration..."
    
    cat > src/main/resources/logback-spring.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <include resource="org/springframework/boot/logging/logback/defaults.xml"/>
    
    <!-- Console appender -->
    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
            <includeContext>true</includeContext>
            <includeMdc>true</includeMdc>
            <customFields>{"service":"${spring.application.name:-your-app}"}</customFields>
        </encoder>
    </appender>
    
    <!-- File appender for production -->
    <springProfile name="production">
        <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
            <file>/var/log/app/application.log</file>
            <encoder class="net.logstash.logback.encoder.LogstashEncoder">
                <includeContext>true</includeContext>
                <includeMdc>true</includeMdc>
                <customFields>{"service":"${spring.application.name:-your-app}","environment":"production"}</customFields>
            </encoder>
            <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
                <fileNamePattern>/var/log/app/application.%d{yyyy-MM-dd}.%i.log</fileNamePattern>
                <maxFileSize>100MB</maxFileSize>
                <maxHistory>30</maxHistory>
                <totalSizeCap>1GB</totalSizeCap>
            </rollingPolicy>
        </appender>
    </springProfile>
    
    <!-- Loggers -->
    <logger name="com.yourcompany" level="INFO"/>
    <logger name="org.springframework.web" level="WARN"/>
    <logger name="org.hibernate" level="WARN"/>
    
    <springProfile name="dev,local">
        <root level="DEBUG">
            <appender-ref ref="CONSOLE"/>
        </root>
    </springProfile>
    
    <springProfile name="sqe,production">
        <root level="INFO">
            <appender-ref ref="CONSOLE"/>
            <appender-ref ref="FILE"/>
        </root>
    </springProfile>
</configuration>
EOF

    echo "✅ Logback configuration created"
}

create_testing_scripts() {
    print_step "Creating testing scripts..."
    
    cat > scripts/deployment/test-deployment.sh << 'EOF'
#!/bin/bash

# Deployment testing script
set -e

APP_NAME="${1:-your-spring-boot-app}"
NAMESPACE="${2:-default}"

echo "🧪 Testing deployment for $APP_NAME in $NAMESPACE..."

# Wait for pods to be ready
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=$APP_NAME \
    --namespace=$NAMESPACE --timeout=300s

# Test health endpoints
echo "🏥 Testing health endpoints..."
kubectl port-forward -n $NAMESPACE svc/$APP_NAME 8080:8080 &
PF_PID=$!
sleep 5

# Basic health check
echo "Testing /actuator/health..."
curl -f http://localhost:8080/actuator/health

# Readiness check
echo "Testing /actuator/health/readiness..."
curl -f http://localhost:8080/actuator/health/readiness

# Liveness check
echo "Testing /actuator/health/liveness..."
curl -f http://localhost:8080/actuator/health/liveness

# Metrics endpoint
echo "Testing /actuator/prometheus..."
curl -f http://localhost:8080/actuator/prometheus | head -10

kill $PF_PID

echo "✅ All tests passed!"
EOF

    chmod +x scripts/deployment/test-deployment.sh
    echo "✅ Testing script created"
}

generate_integration_checklist() {
    print_step "Generating integration checklist..."
    
    cat > INTEGRATION_CHECKLIST.md << 'EOF'
# Spring Boot Production Integration Checklist

## ✅ Prerequisites
- [ ] Java 17+ installed
- [ ] Maven 3.6+ installed
- [ ] Docker installed and configured
- [ ] Kubernetes cluster access
- [ ] Helm 3.x installed
- [ ] kubectl configured

## ✅ Maven Dependencies
- [ ] Add spring-boot-starter-actuator
- [ ] Add micrometer-registry-prometheus
- [ ] Add spring-boot-configuration-processor
- [ ] Add logstash-logback-encoder
- [ ] Add spring-boot-starter-data-redis (if needed)
- [ ] Add spring-boot-starter-aop (for metrics)

## ✅ Spring Boot Configuration
- [ ] Create application.yml base configuration
- [ ] Create environment-specific profiles (dev, sqe, production)
- [ ] Configure actuator endpoints
- [ ] Configure database connection pools
- [ ] Set up external service configurations
- [ ] Configure logging patterns

## ✅ Java Code Integration
- [ ] Create ExternalServiceConfig class
- [ ] Create MonitoringConfig class
- [ ] Create custom health indicators
- [ ] Create metrics components
- [ ] Set up structured logging
- [ ] Add configuration validation

## ✅ Helm Chart Setup
- [ ] Create Chart.yaml
- [ ] Create base values.yaml
- [ ] Create environment-specific values files
- [ ] Create deployment template
- [ ] Create service template
- [ ] Create configmap template
- [ ] Create secret template
- [ ] Create ingress template (if needed)
- [ ] Create servicemonitor template

## ✅ Monitoring Integration
- [ ] Configure Prometheus metrics
- [ ] Set up custom business metrics
- [ ] Configure health check endpoints
- [ ] Set up structured logging
- [ ] Create Grafana dashboards (optional)

## ✅ Deployment Scripts
- [ ] Create deployment script
- [ ] Create monitoring setup script
- [ ] Create testing script
- [ ] Test deployment in dev environment
- [ ] Validate monitoring endpoints
- [ ] Test rollback procedures

## ✅ Security Considerations
- [ ] Configure non-root container user
- [ ] Set up resource limits
- [ ] Configure network policies (if needed)
- [ ] Set up secrets management
- [ ] Configure RBAC (if needed)

## ✅ Production Readiness
- [ ] Load testing completed
- [ ] Security scanning completed
- [ ] Backup procedures documented
- [ ] Monitoring alerts configured
- [ ] Runbook documentation created
- [ ] Team training completed
EOF

    echo "✅ Integration checklist created"
}

main() {
    print_header
    
    echo "🔧 Setting up Spring Boot production integration..."
    echo "   App Name: $APP_NAME"
    echo "   Environment: $ENVIRONMENT"
    echo "   Namespace: $NAMESPACE"
    echo ""
    
    check_prerequisites
    validate_java_version
    create_directory_structure
    setup_maven_dependencies
    create_spring_profiles
    create_helm_chart
    create_deployment_script
    create_monitoring_setup
    create_java_configuration_classes
    create_logback_configuration
    create_testing_scripts
    generate_integration_checklist
    
    echo ""
    echo -e "${GREEN}🎉 Spring Boot production integration setup completed!${NC}"
    echo ""
    echo "📋 Next steps:"
    echo "1. Review and update the generated configuration files"
    echo "2. Add the Maven dependencies from pom-dependencies.xml to your pom.xml"
    echo "3. Update package names in Java classes (com.yourcompany -> your.package)"
    echo "4. Configure your container registry in Helm values"
    echo "5. Review the INTEGRATION_CHECKLIST.md file"
    echo "6. Test deployment: ./scripts/deployment/deploy.sh $APP_NAME $ENVIRONMENT"
    echo ""
    echo "📚 Documentation: docs/SPRING_BOOT_PRODUCTION_INTEGRATION_GUIDE.md"
}

# Run main function
main "$@"