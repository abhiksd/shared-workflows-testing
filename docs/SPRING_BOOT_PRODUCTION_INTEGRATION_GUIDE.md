# Spring Boot Production Integration Guide

This comprehensive guide will help you integrate Helm charts, Spring Boot profiles, and monitoring into your existing Java Spring Boot application running in production.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Spring Boot Profile Integration](#spring-boot-profile-integration)
3. [Helm Chart Integration](#helm-chart-integration)
4. [Monitoring Integration](#monitoring-integration)
5. [Deployment Scripts](#deployment-scripts)
6. [Testing & Validation](#testing--validation)
7. [Troubleshooting](#troubleshooting)

## 🔧 Prerequisites

### Required Tools
- Java 17+ (preferably Java 21)
- Maven 3.6+
- Docker
- Kubernetes cluster access
- Helm 3.x
- kubectl configured

### Required Dependencies
Add these to your `pom.xml`:

```xml
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
```

## 🎯 Spring Boot Profile Integration

### Step 1: Create Profile-Specific Configuration Files

Create the following configuration files in `src/main/resources/`:

#### 1.1 Base Configuration (`application.yml`)
```yaml
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
    org.springframework.security: DEBUG
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} - %msg%n"
    file: "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n"
```

#### 1.2 Local Development (`application-local.yml`)
```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/yourapp_local
    username: ${DB_USERNAME:localuser}
    password: ${DB_PASSWORD:localpass}
  
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: true

logging:
  level:
    com.yourcompany: DEBUG
    org.springframework.web: DEBUG
```

#### 1.3 Development Environment (`application-dev.yml`)
```yaml
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
    lettuce:
      pool:
        max-active: 8
        max-wait: -1ms
        max-idle: 8
        min-idle: 0

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
```

#### 1.4 Staging Environment (`application-sqe.yml`)
```yaml
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
    hikari:
      minimum-idle: 10
      maximum-pool-size: 30

  redis:
    host: ${REDIS_HOST}
    port: ${REDIS_PORT:6379}
    password: ${REDIS_PASSWORD}
    timeout: 2000ms

external:
  api:
    user-service:
      url: ${USER_SERVICE_URL}
      timeout: 5000
    notification-service:
      url: ${NOTIFICATION_SERVICE_URL}
      timeout: 3000

# Enhanced monitoring for staging
management:
  endpoints:
    web:
      exposure:
        include: "*"
  endpoint:
    health:
      show-details: always

logging:
  level:
    root: WARN
    com.yourcompany: INFO
```

#### 1.5 Production Environment (`application-production.yml`)
```yaml
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
    lettuce:
      pool:
        max-active: 20
        max-wait: -1ms
        max-idle: 10
        min-idle: 5

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
```

### Step 2: Create Configuration Classes

#### 2.1 External Service Configuration
```java
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
```

#### 2.2 Database Configuration
```java
package com.yourcompany.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.boot.context.properties.ConfigurationProperties;

@Configuration
public class DatabaseConfig {
    
    @Bean
    @Profile("production")
    @ConfigurationProperties("spring.datasource.hikari")
    public HikariConfig hikariConfig() {
        HikariConfig config = new HikariConfig();
        config.setLeakDetectionThreshold(60000);
        config.setConnectionTestQuery("SELECT 1");
        return config;
    }
    
    @Bean
    @Profile("!production")
    public HikariConfig devHikariConfig() {
        HikariConfig config = new HikariConfig();
        config.setLeakDetectionThreshold(0); // Disable in dev
        return config;
    }
}
```

#### 2.3 Monitoring Configuration
```java
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
```

### Step 3: Health Check Implementation

#### 3.1 Custom Health Indicator
```java
package com.yourcompany.health;

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
            // Check external service connectivity
            boolean userServiceHealthy = checkService(config.getUserService().getUrl());
            boolean notificationServiceHealthy = checkService(config.getNotificationService().getUrl());
            
            if (userServiceHealthy && notificationServiceHealthy) {
                return Health.up()
                    .withDetail("user-service", "UP")
                    .withDetail("notification-service", "UP")
                    .build();
            } else {
                return Health.down()
                    .withDetail("user-service", userServiceHealthy ? "UP" : "DOWN")
                    .withDetail("notification-service", notificationServiceHealthy ? "UP" : "DOWN")
                    .build();
            }
        } catch (Exception e) {
            log.error("Health check failed", e);
            return Health.down()
                .withDetail("error", e.getMessage())
                .build();
        }
    }
    
    private boolean checkService(String url) {
        // Implement your service health check logic
        // This is a simplified example
        try {
            // Use RestTemplate or WebClient to check service health
            return true; // Replace with actual health check
        } catch (Exception e) {
            log.warn("Service health check failed for URL: {}", url, e);
            return false;
        }
    }
}
```

## 🚢 Helm Chart Integration

### Step 1: Create Helm Chart Structure

Create the following directory structure in your project:

```
helm/
├── Chart.yaml
├── values.yaml
├── values-dev.yaml
├── values-sqe.yaml
├── values-production.yaml
└── templates/
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── service.yaml
    ├── configmap.yaml
    ├── secret.yaml
    ├── ingress.yaml
    ├── servicemonitor.yaml
    └── tests/
        └── test-connection.yaml
```

#### 1.1 Chart.yaml
```yaml
apiVersion: v2
name: your-spring-boot-app
description: Production-ready Spring Boot application with monitoring
type: application
version: 0.1.0
appVersion: "1.0.0"
keywords:
  - spring-boot
  - java
  - microservice
home: https://github.com/your-org/your-app
sources:
  - https://github.com/your-org/your-app
maintainers:
  - name: Your Team
    email: team@yourcompany.com
```

#### 1.2 Base values.yaml
```yaml
# Default values for your Spring Boot application
replicaCount: 2

image:
  repository: your-registry/your-app
  pullPolicy: IfNotPresent
  tag: ""

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations: {}
  name: ""

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/path: "/actuator/prometheus"
  prometheus.io/port: "8080"

podSecurityContext:
  fsGroup: 1000
  runAsNonRoot: true
  runAsUser: 1000

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000

service:
  type: ClusterIP
  port: 8080
  targetPort: 8080

ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: your-app.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

nodeSelector: {}
tolerations: []
affinity: {}

# Spring Boot specific configuration
springboot:
  profiles:
    active: "production"
  
  # Environment variables
  env:
    JAVA_OPTS: "-Xms512m -Xmx1g -XX:+UseG1GC"
    SERVER_PORT: "8080"
    MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE: "health,info,metrics,prometheus"

# Database configuration
database:
  host: "postgres"
  port: "5432"
  name: "yourapp"
  username: "app_user"
  # Password should be stored in secret

# Redis configuration
redis:
  enabled: true
  host: "redis"
  port: "6379"

# External services
externalServices:
  userService:
    url: "http://user-service:8080"
  notificationService:
    url: "http://notification-service:3000"

# Monitoring configuration
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    namespace: monitoring
    interval: 30s
    path: /actuator/prometheus

# Health checks
healthCheck:
  enabled: true
  livenessProbe:
    httpGet:
      path: /actuator/health/liveness
      port: http
    initialDelaySeconds: 60
    periodSeconds: 10
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3
  readinessProbe:
    httpGet:
      path: /actuator/health/readiness
      port: http
    initialDelaySeconds: 30
    periodSeconds: 5
    timeoutSeconds: 3
    successThreshold: 1
    failureThreshold: 3

# Persistence (for logs, temp files, etc.)
persistence:
  enabled: true
  storageClass: ""
  accessMode: ReadWriteOnce
  size: 5Gi
  mountPath: /var/log/app
```

#### 1.3 Environment-specific Values

**values-dev.yaml:**
```yaml
replicaCount: 1

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 200m
    memory: 256Mi

springboot:
  profiles:
    active: "dev"
  env:
    JAVA_OPTS: "-Xms256m -Xmx512m"

database:
  host: "postgres-dev"
  name: "yourapp_dev"

ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-dev
  hosts:
    - host: your-app-dev.yourdomain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: your-app-dev-tls
      hosts:
        - your-app-dev.yourdomain.com
```

**values-production.yaml:**
```yaml
replicaCount: 3

resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 1000m
    memory: 1Gi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20

springboot:
  profiles:
    active: "production"
  env:
    JAVA_OPTS: "-Xms1g -Xmx2g -XX:+UseG1GC -XX:+HeapDumpOnOutOfMemoryError"

database:
  host: "postgres-prod"
  name: "yourapp_prod"

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - your-spring-boot-app
        topologyKey: kubernetes.io/hostname

ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rate-limit: "100"
  hosts:
    - host: your-app.yourdomain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: your-app-prod-tls
      hosts:
        - your-app.yourdomain.com
```

### Step 2: Create Helm Templates

#### 2.1 Deployment Template (templates/deployment.yaml)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "your-spring-boot-app.fullname" . }}
  labels:
    {{- include "your-spring-boot-app.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "your-spring-boot-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "your-spring-boot-app.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "your-spring-boot-app.serviceAccountName" . }}
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
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: {{ .Values.springboot.profiles.active | quote }}
            - name: DB_HOST
              value: {{ .Values.database.host | quote }}
            - name: DB_PORT
              value: {{ .Values.database.port | quote }}
            - name: DB_NAME
              value: {{ .Values.database.name | quote }}
            - name: DB_USERNAME
              valueFrom:
                secretKeyRef:
                  name: {{ include "your-spring-boot-app.fullname" . }}-secret
                  key: db-username
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ include "your-spring-boot-app.fullname" . }}-secret
                  key: db-password
            {{- if .Values.redis.enabled }}
            - name: REDIS_HOST
              value: {{ .Values.redis.host | quote }}
            - name: REDIS_PORT
              value: {{ .Values.redis.port | quote }}
            {{- end }}
            - name: USER_SERVICE_URL
              value: {{ .Values.externalServices.userService.url | quote }}
            - name: NOTIFICATION_SERVICE_URL
              value: {{ .Values.externalServices.notificationService.url | quote }}
            {{- range $key, $value := .Values.springboot.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
          envFrom:
            - configMapRef:
                name: {{ include "your-spring-boot-app.fullname" . }}-config
          {{- if .Values.healthCheck.enabled }}
          livenessProbe:
            {{- toYaml .Values.healthCheck.livenessProbe | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.healthCheck.readinessProbe | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            {{- if .Values.persistence.enabled }}
            - name: log-storage
              mountPath: {{ .Values.persistence.mountPath }}
            {{- end }}
      volumes:
        - name: tmp
          emptyDir: {}
        {{- if .Values.persistence.enabled }}
        - name: log-storage
          persistentVolumeClaim:
            claimName: {{ include "your-spring-boot-app.fullname" . }}-pvc
        {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

#### 2.2 ConfigMap Template (templates/configmap.yaml)
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "your-spring-boot-app.fullname" . }}-config
  labels:
    {{- include "your-spring-boot-app.labels" . | nindent 4 }}
data:
  # Application configuration
  APPLICATION_NAME: {{ include "your-spring-boot-app.name" . | quote }}
  ENVIRONMENT: {{ .Values.springboot.profiles.active | quote }}
  
  # Monitoring configuration
  {{- if .Values.monitoring.enabled }}
  MANAGEMENT_METRICS_EXPORT_PROMETHEUS_ENABLED: "true"
  MANAGEMENT_ENDPOINT_PROMETHEUS_ENABLED: "true"
  {{- end }}
  
  # Health check configuration
  {{- if .Values.healthCheck.enabled }}
  MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED: "true"
  MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS: "when-authorized"
  {{- end }}
  
  # Logging configuration
  LOGGING_LEVEL_ROOT: "INFO"
  LOGGING_PATTERN_CONSOLE: "%d{yyyy-MM-dd HH:mm:ss} - %msg%n"
```

#### 2.3 Secret Template (templates/secret.yaml)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "your-spring-boot-app.fullname" . }}-secret
  labels:
    {{- include "your-spring-boot-app.labels" . | nindent 4 }}
type: Opaque
data:
  db-username: {{ .Values.database.username | b64enc }}
  {{- if .Values.database.password }}
  db-password: {{ .Values.database.password | b64enc }}
  {{- else }}
  db-password: {{ randAlphaNum 16 | b64enc }}
  {{- end }}
  {{- if and .Values.redis.enabled .Values.redis.password }}
  redis-password: {{ .Values.redis.password | b64enc }}
  {{- end }}
```

#### 2.4 ServiceMonitor Template (templates/servicemonitor.yaml)
```yaml
{{- if and .Values.monitoring.enabled .Values.monitoring.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "your-spring-boot-app.fullname" . }}
  {{- if .Values.monitoring.serviceMonitor.namespace }}
  namespace: {{ .Values.monitoring.serviceMonitor.namespace }}
  {{- end }}
  labels:
    {{- include "your-spring-boot-app.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "your-spring-boot-app.selectorLabels" . | nindent 6 }}
  endpoints:
  - port: http
    path: {{ .Values.monitoring.serviceMonitor.path }}
    interval: {{ .Values.monitoring.serviceMonitor.interval }}
    scrapeTimeout: 10s
{{- end }}
```

## 📊 Monitoring Integration

### Step 1: Prometheus Metrics Configuration

#### 1.1 Custom Metrics Component
```java
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
    
    // Business metrics
    private final Counter orderCounter = Counter.builder("orders.created.total")
            .description("Total number of orders created")
            .register(meterRegistry);
    
    private final Timer orderProcessingTime = Timer.builder("orders.processing.time")
            .description("Time taken to process orders")
            .register(meterRegistry);
    
    public void incrementOrderCount() {
        orderCounter.increment();
    }
    
    public Timer.Sample startOrderTimer() {
        return Timer.start(meterRegistry);
    }
    
    public void recordOrderProcessingTime(Timer.Sample sample) {
        sample.stop(orderProcessingTime);
    }
}
```

#### 1.2 Metric Aspect for Automatic Instrumentation
```java
package com.yourcompany.aspects;

import com.yourcompany.metrics.ApplicationMetrics;
import io.micrometer.core.instrument.Timer;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.stereotype.Component;
import lombok.RequiredArgsConstructor;

@Aspect
@Component
@RequiredArgsConstructor
public class MetricsAspect {
    
    private final ApplicationMetrics metrics;
    
    @Around("@annotation(com.yourcompany.annotations.Timed)")
    public Object timeMethod(ProceedingJoinPoint joinPoint) throws Throwable {
        Timer.Sample sample = metrics.startOrderTimer();
        try {
            return joinPoint.proceed();
        } finally {
            metrics.recordOrderProcessingTime(sample);
        }
    }
}
```

### Step 2: Structured Logging Configuration

#### 2.1 Logback Configuration (logback-spring.xml)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <include resource="org/springframework/boot/logging/logback/defaults.xml"/>
    
    <!-- Console appender -->
    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
            <includeContext>true</includeContext>
            <includeMdc>true</includeMdc>
            <customFields>{"service":"your-app"}</customFields>
        </encoder>
    </appender>
    
    <!-- File appender for production -->
    <springProfile name="production">
        <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
            <file>/var/log/app/application.log</file>
            <encoder class="net.logstash.logback.encoder.LogstashEncoder">
                <includeContext>true</includeContext>
                <includeMdc>true</includeMdc>
                <customFields>{"service":"your-app","environment":"production"}</customFields>
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
```

## 🚀 Deployment Scripts

### Step 1: Main Deployment Script

Create `scripts/deployment/deploy.sh`:

```bash
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
docker tag $APP_NAME:$IMAGE_TAG your-registry/$APP_NAME:$IMAGE_TAG
docker push your-registry/$APP_NAME:$IMAGE_TAG

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
```

### Step 2: Monitoring Setup Script

Create `scripts/deployment/setup-monitoring.sh`:

```bash
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
```

### Step 3: Database Migration Script

Create `scripts/deployment/migrate-database.sh`:

```bash
#!/bin/bash

# Database migration script
set -e

APP_NAME="${1:-your-spring-boot-app}"
ENVIRONMENT="${2:-dev}"
NAMESPACE="${3:-default}"

echo "🗄️ Running database migrations for $ENVIRONMENT..."

# Run Flyway or Liquibase migrations through a Job
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: $APP_NAME-migration-$(date +%s)
  namespace: $NAMESPACE
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migration
        image: your-registry/$APP_NAME:latest
        command: ["java"]
        args: [
          "-jar", "/app.jar",
          "--spring.profiles.active=$ENVIRONMENT",
          "--spring.jpa.hibernate.ddl-auto=validate",
          "--spring.flyway.enabled=true"
        ]
        env:
        - name: DB_HOST
          value: "postgres-$ENVIRONMENT"
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: $APP_NAME-secret
              key: db-username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $APP_NAME-secret
              key: db-password
EOF

echo "✅ Database migration job submitted"
```

### Step 4: Rollback Script

Create `scripts/deployment/rollback.sh`:

```bash
#!/bin/bash

# Rollback script
set -e

APP_NAME="${1:-your-spring-boot-app}"
NAMESPACE="${2:-default}"
REVISION="${3:-1}"

echo "🔄 Rolling back $APP_NAME to revision $REVISION..."

# Rollback using Helm
helm rollback $APP_NAME $REVISION --namespace $NAMESPACE

echo "✅ Rollback completed!"

# Verify rollback
echo "🔍 Verifying rollback..."
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME
```

## 🧪 Testing & Validation

### Step 1: Automated Testing Script

Create `scripts/deployment/test-deployment.sh`:

```bash
#!/bin/bash

# Comprehensive deployment testing script
set -e

APP_NAME="${1:-your-spring-boot-app}"
NAMESPACE="${2:-default}"
BASE_URL="${3:-http://localhost:8080}"

echo "🧪 Running comprehensive tests for $APP_NAME..."

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo "Testing: $test_name"
    if eval "$test_command"; then
        echo "✅ $test_name - PASSED"
    else
        echo "❌ $test_name - FAILED"
        return 1
    fi
}

# Wait for pods to be ready
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=$APP_NAME \
    --namespace=$NAMESPACE --timeout=300s

# Set up port forwarding
kubectl port-forward -n $NAMESPACE svc/$APP_NAME 8080:8080 &
PF_PID=$!
sleep 10

# Health check tests
echo "🏥 Running health check tests..."
run_test "Basic Health Check" "curl -f $BASE_URL/actuator/health"
run_test "Readiness Probe" "curl -f $BASE_URL/actuator/health/readiness"
run_test "Liveness Probe" "curl -f $BASE_URL/actuator/health/liveness"

# Metrics tests
echo "📊 Running metrics tests..."
run_test "Prometheus Metrics" "curl -f $BASE_URL/actuator/prometheus | grep -q 'jvm_memory_used_bytes'"
run_test "Application Info" "curl -f $BASE_URL/actuator/info"

# Application-specific tests
echo "🔧 Running application tests..."
run_test "Application Root" "curl -f $BASE_URL/api"

# Performance tests
echo "⚡ Running performance tests..."
run_test "Response Time Test" "timeout 10s bash -c 'start=\$(date +%s%N); curl -f $BASE_URL/actuator/health >/dev/null; end=\$(date +%s%N); duration=\$(((\$end - \$start) / 1000000)); [ \$duration -lt 1000 ]'"

# Clean up
kill $PF_PID

echo "🎉 All tests completed!"
```

### Step 2: Load Testing Script

Create `scripts/testing/load-test.sh`:

```bash
#!/bin/bash

# Load testing script using Apache Bench
set -e

APP_NAME="${1:-your-spring-boot-app}"
NAMESPACE="${2:-default}"
CONCURRENT_USERS="${3:-10}"
TOTAL_REQUESTS="${4:-1000}"

echo "🔥 Running load test for $APP_NAME..."
echo "Concurrent users: $CONCURRENT_USERS"
echo "Total requests: $TOTAL_REQUESTS"

# Set up port forwarding
kubectl port-forward -n $NAMESPACE svc/$APP_NAME 8080:8080 &
PF_PID=$!
sleep 5

# Run load test
ab -n $TOTAL_REQUESTS -c $CONCURRENT_USERS http://localhost:8080/actuator/health

# Clean up
kill $PF_PID

echo "✅ Load test completed!"
```

### Step 3: Security Testing

Create `scripts/testing/security-test.sh`:

```bash
#!/bin/bash

# Basic security testing script
set -e

APP_NAME="${1:-your-spring-boot-app}"
NAMESPACE="${2:-default}"

echo "🔒 Running security tests for $APP_NAME..."

# Check pod security context
echo "Checking pod security context..."
kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME \
    -o jsonpath='{.items[0].spec.securityContext}' | jq '.'

# Check container security context
echo "Checking container security context..."
kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME \
    -o jsonpath='{.items[0].spec.containers[0].securityContext}' | jq '.'

# Check for privileged containers
echo "Checking for privileged containers..."
PRIVILEGED=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME \
    -o jsonpath='{.items[0].spec.containers[0].securityContext.privileged}')

if [ "$PRIVILEGED" = "true" ]; then
    echo "❌ Container is running as privileged!"
    exit 1
else
    echo "✅ Container is not privileged"
fi

# Check resource limits
echo "Checking resource limits..."
kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME \
    -o jsonpath='{.items[0].spec.containers[0].resources}' | jq '.'

echo "✅ Security tests completed!"
```

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. Application Won't Start

**Problem**: Pods are in CrashLoopBackOff state

**Solutions**:
```bash
# Check pod logs
kubectl logs -n $NAMESPACE deployment/$APP_NAME

# Check events
kubectl describe pod -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME

# Common fixes:
# - Check database connectivity
# - Verify environment variables
# - Check resource limits
# - Validate configuration files
```

#### 2. Health Check Failures

**Problem**: Readiness/Liveness probes failing

**Solutions**:
```bash
# Test health endpoint manually
kubectl exec -n $NAMESPACE deployment/$APP_NAME -- curl localhost:8080/actuator/health

# Check probe configuration
kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME -o yaml | grep -A 10 "livenessProbe\|readinessProbe"

# Increase probe timeouts if needed
```

#### 3. Database Connection Issues

**Problem**: Cannot connect to database

**Solutions**:
```bash
# Check database service
kubectl get svc -n $NAMESPACE | grep postgres

# Test database connectivity
kubectl run --rm -it --restart=Never postgres-client --image=postgres:13 -- psql -h postgres-$ENVIRONMENT -U $DB_USERNAME -d $DB_NAME

# Check secrets
kubectl get secret $APP_NAME-secret -n $NAMESPACE -o yaml
```

#### 4. Memory Issues

**Problem**: OutOfMemoryError or high memory usage

**Solutions**:
```bash
# Check current memory usage
kubectl top pod -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME

# Increase memory limits in values.yaml
resources:
  limits:
    memory: 2Gi
  requests:
    memory: 1Gi

# Tune JVM settings
JAVA_OPTS: "-Xms1g -Xmx1800m -XX:+UseG1GC"
```

#### 5. Monitoring Not Working

**Problem**: Metrics not appearing in Prometheus

**Solutions**:
```bash
# Check ServiceMonitor
kubectl get servicemonitor -n monitoring

# Verify metrics endpoint
kubectl port-forward -n $NAMESPACE svc/$APP_NAME 8080:8080
curl http://localhost:8080/actuator/prometheus

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-operator-prometheus 9090:9090
# Open http://localhost:9090/targets
```

### Debugging Commands

```bash
# General debugging
kubectl get all -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME
kubectl describe deployment $APP_NAME -n $NAMESPACE
kubectl logs -f deployment/$APP_NAME -n $NAMESPACE

# Network debugging
kubectl exec -n $NAMESPACE deployment/$APP_NAME -- nslookup postgres-$ENVIRONMENT
kubectl exec -n $NAMESPACE deployment/$APP_NAME -- ping postgres-$ENVIRONMENT

# Configuration debugging
kubectl get configmap $APP_NAME-config -n $NAMESPACE -o yaml
kubectl get secret $APP_NAME-secret -n $NAMESPACE -o yaml

# Performance debugging
kubectl top pod -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME
kubectl exec -n $NAMESPACE deployment/$APP_NAME -- cat /proc/meminfo
```

## 📚 Quick Reference

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SPRING_PROFILES_ACTIVE` | Active Spring profile | `production` |
| `DB_HOST` | Database host | `postgres-prod` |
| `DB_USERNAME` | Database username | `app_user` |
| `DB_PASSWORD` | Database password | `secret_password` |
| `JAVA_OPTS` | JVM options | `-Xms1g -Xmx2g` |

### Useful Commands

```bash
# Deploy application
./scripts/deployment/deploy.sh my-app production

# Setup monitoring
./scripts/deployment/setup-monitoring.sh

# Test deployment
./scripts/deployment/test-deployment.sh my-app default

# Rollback
./scripts/deployment/rollback.sh my-app default 1

# View logs
kubectl logs -f deployment/my-app -n default

# Port forward
kubectl port-forward svc/my-app 8080:8080 -n default

# Scale application
kubectl scale deployment my-app --replicas=5 -n default
```

### Health Check URLs

| Endpoint | Purpose |
|----------|---------|
| `/actuator/health` | Overall health |
| `/actuator/health/readiness` | Readiness probe |
| `/actuator/health/liveness` | Liveness probe |
| `/actuator/info` | Application info |
| `/actuator/metrics` | Metrics list |
| `/actuator/prometheus` | Prometheus metrics |

## 🎉 Conclusion

This comprehensive guide provides everything you need to integrate Helm charts, Spring Boot profiles, and monitoring into your existing production Spring Boot application. The provided scripts and configurations follow best practices for production deployments.

Remember to:
1. Customize the configurations for your specific environment
2. Test thoroughly in a development environment first
3. Monitor application performance after deployment
4. Keep your dependencies and configurations up to date
5. Follow security best practices

For additional support, refer to the troubleshooting section or consult the official documentation for Spring Boot, Helm, and Prometheus.