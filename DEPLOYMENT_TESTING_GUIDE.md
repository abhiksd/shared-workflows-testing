# Deployment Testing Guide

This guide provides comprehensive testing procedures and validation steps for both Java and Node.js applications after successful deployment to AKS cluster.

## 📋 Overview

This document covers:
- Application URLs and endpoints
- Health check verification
- API testing procedures
- Expected responses and outputs
- Monitoring validation
- Troubleshooting common issues

## 🏗️ Application Architecture

```
AKS Cluster
├── Java Application (Spring Boot)
│   ├── Service: java-app-service
│   ├── Port: 8080
│   └── Context Path: /api
├── Node.js Application (Express.js)
│   ├── Service: nodejs-app-service
│   ├── Port: 3000
│   └── Context Path: /api
└── Monitoring Stack
    ├── Prometheus
    ├── Grafana
    └── Loki
```

## 🔗 Application URLs

### Java Application (Spring Boot)

**Base URL Format:**
```
http://<EXTERNAL_IP>:<PORT>/api
https://<DOMAIN>/api  (if ingress configured)
```

**Example URLs:**
```bash
# Internal cluster access
http://java-app-service:8080/api

# External access (replace with actual external IP)
http://20.121.xxx.xxx:8080/api
http://your-domain.com/api
```

### Node.js Application (Express.js)

**Base URL Format:**
```
http://<EXTERNAL_IP>:<PORT>/api
https://<DOMAIN>/api  (if ingress configured)
```

**Example URLs:**
```bash
# Internal cluster access
http://nodejs-app-service:3000/api

# External access (replace with actual external IP)
http://20.121.xxx.xxx:3000/api
http://your-nodejs-domain.com/api
```

## 🏥 Health Check Endpoints

### Java Application Health Checks

#### 1. Basic Health Check
```bash
# URL
GET /actuator/health

# Example
curl http://20.121.xxx.xxx:8080/actuator/health

# Expected Response (200 OK)
{
  "status": "UP",
  "components": {
    "db": {
      "status": "UP",
      "details": {
        "database": "PostgreSQL",
        "validationQuery": "isValid()"
      }
    },
    "redis": {
      "status": "UP"
    },
    "diskSpace": {
      "status": "UP",
      "details": {
        "total": 10737418240,
        "free": 8589934592,
        "threshold": 10485760,
        "exists": true
      }
    }
  }
}
```

#### 2. Detailed Health Information
```bash
# URL
GET /actuator/health/detail

# Example
curl http://20.121.xxx.xxx:8080/actuator/health/detail

# Expected Response (200 OK)
{
  "status": "UP",
  "details": {
    "application": {
      "name": "Java App",
      "version": "1.0.0",
      "environment": "production"
    },
    "uptime": "2h 30m 15s",
    "timestamp": "2024-01-20T10:30:00Z"
  }
}
```

#### 3. Kubernetes Probes
```bash
# Liveness Probe
curl http://20.121.xxx.xxx:8080/actuator/health/liveness
# Expected: 200 OK with {"status":"UP"}

# Readiness Probe
curl http://20.121.xxx.xxx:8080/actuator/health/readiness
# Expected: 200 OK with {"status":"UP"}
```

#### 4. Prometheus Metrics
```bash
# URL
GET /actuator/prometheus

# Example
curl http://20.121.xxx.xxx:8080/actuator/prometheus

# Expected Response (200 OK) - Sample metrics
# HELP jvm_memory_used_bytes The amount of used memory
# TYPE jvm_memory_used_bytes gauge
jvm_memory_used_bytes{area="heap",id="PS Eden Space",} 2.1474836E7
# HELP http_server_requests_seconds
# TYPE http_server_requests_seconds summary
http_server_requests_seconds_count{method="GET",outcome="SUCCESS",status="200",uri="/actuator/health",} 1.0
```

### Node.js Application Health Checks

#### 1. Basic Health Check
```bash
# URL
GET /health

# Example
curl http://20.121.xxx.xxx:3000/health

# Expected Response (200 OK)
{
  "status": "healthy",
  "timestamp": "2024-01-20T10:30:00.000Z",
  "uptime": 9015.234,
  "environment": "production",
  "version": "1.0.0",
  "nodeVersion": "v18.19.0"
}
```

#### 2. Detailed Health Check
```bash
# URL
GET /health/detailed

# Example
curl http://20.121.xxx.xxx:3000/health/detailed

# Expected Response (200 OK)
{
  "status": "healthy",
  "timestamp": "2024-01-20T10:30:00.000Z",
  "uptime": 9015.234,
  "environment": "production",
  "version": "1.0.0",
  "nodeVersion": "v18.19.0",
  "pid": 1,
  "responseTime": "15ms",
  "checks": {
    "database": {
      "status": "healthy",
      "duration": "12ms"
    },
    "redis": {
      "status": "healthy",
      "duration": "3ms"
    },
    "externalApi": {
      "status": "healthy"
    }
  },
  "system": {
    "memory": {
      "rss": "45 MB",
      "heapUsed": "23 MB",
      "heapTotal": "35 MB",
      "external": "2 MB"
    },
    "cpu": {
      "user": 1250000,
      "system": 780000
    },
    "platform": "linux",
    "arch": "x64"
  }
}
```

#### 3. Kubernetes Probes
```bash
# Liveness Probe
curl http://20.121.xxx.xxx:3000/health/live
# Expected: 200 OK with {"status":"alive","timestamp":"2024-01-20T10:30:00.000Z"}

# Readiness Probe
curl http://20.121.xxx.xxx:3000/health/ready
# Expected: 200 OK with {"status":"ready","timestamp":"2024-01-20T10:30:00.000Z"}

# Startup Probe
curl http://20.121.xxx.xxx:3000/health/startup
# Expected: 200 OK with {"status":"started","timestamp":"2024-01-20T10:30:00.000Z"}
```

#### 4. Prometheus Metrics
```bash
# URL
GET /health/metrics

# Example
curl http://20.121.xxx.xxx:3000/health/metrics

# Expected Response (200 OK) - Sample metrics
# HELP nodejs_version_info Node.js version info
# TYPE nodejs_version_info gauge
nodejs_version_info{version="v18.19.0",major="18",minor="19",patch="0"} 1
# HELP http_request_duration_seconds Duration of HTTP requests in seconds
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.1",method="GET",route="/health",status_code="200"} 1
```

## 🔐 API Testing Procedures

### Java Application API Tests

#### 1. Hello Controller Test
```bash
# URL
GET /api/hello

# Example
curl http://20.121.xxx.xxx:8080/api/hello

# Expected Response (200 OK)
{
  "message": "Hello from Java App!",
  "timestamp": "2024-01-20T10:30:00.000Z",
  "version": "1.0.0"
}
```

#### 2. Application Information
```bash
# URL
GET /actuator/info

# Example
curl http://20.121.xxx.xxx:8080/actuator/info

# Expected Response (200 OK)
{
  "app": {
    "name": "Java App",
    "version": "1.0.0",
    "environment": "production"
  },
  "build": {
    "time": "2024-01-20T08:00:00.000Z"
  }
}
```

### Node.js Application API Tests

#### 1. Application Information
```bash
# URL
GET /health/info

# Example
curl http://20.121.xxx.xxx:3000/health/info

# Expected Response (200 OK)
{
  "name": "nodejs-backend-app",
  "version": "1.0.0",
  "environment": "production",
  "nodeVersion": "v18.19.0",
  "platform": "linux",
  "arch": "x64",
  "pid": 1,
  "uptime": 9015.234,
  "timestamp": "2024-01-20T10:30:00.000Z"
}
```

#### 2. Database Health Test
```bash
# URL
GET /health/db

# Example
curl http://20.121.xxx.xxx:3000/health/db

# Expected Response (200 OK)
{
  "status": "healthy",
  "duration": "12ms",
  "timestamp": "2024-01-20T10:30:00.000Z"
}
```

#### 3. Redis Health Test
```bash
# URL
GET /health/redis

# Example
curl http://20.121.xxx.xxx:3000/health/redis

# Expected Response (200 OK)
{
  "status": "healthy",
  "duration": "3ms",
  "timestamp": "2024-01-20T10:30:00.000Z"
}
```

### Authentication Testing (Node.js)

#### 1. User Registration
```bash
# URL
POST /api/auth/register

# Example
curl -X POST http://20.121.xxx.xxx:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!@#",
    "firstName": "Test",
    "lastName": "User"
  }'

# Expected Response (201 Created)
{
  "message": "User registered successfully",
  "user": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "email": "test@example.com",
    "first_name": "Test",
    "last_name": "User",
    "role": "user",
    "is_active": true,
    "created_at": "2024-01-20T10:30:00.000Z"
  },
  "tokens": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": "3600"
  }
}
```

#### 2. User Login
```bash
# URL
POST /api/auth/login

# Example
curl -X POST http://20.121.xxx.xxx:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!@#"
  }'

# Expected Response (200 OK)
{
  "message": "Login successful",
  "user": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "email": "test@example.com",
    "first_name": "Test",
    "last_name": "User",
    "role": "user",
    "last_login": "2024-01-20T10:30:00.000Z"
  },
  "tokens": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": "3600"
  }
}
```

#### 3. Protected Endpoint Test
```bash
# URL
GET /api/auth/profile

# Example (using token from login)
curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  http://20.121.xxx.xxx:3000/api/auth/profile

# Expected Response (200 OK)
{
  "message": "Profile retrieved successfully",
  "user": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "email": "test@example.com",
    "first_name": "Test",
    "last_name": "User",
    "role": "user",
    "is_active": true,
    "created_at": "2024-01-20T10:30:00.000Z",
    "last_login": "2024-01-20T10:30:00.000Z"
  }
}
```

## 📊 Monitoring Validation

### Prometheus Metrics Verification

#### 1. Check Service Discovery
```bash
# Access Prometheus UI
http://<PROMETHEUS_EXTERNAL_IP>:9090

# Verify targets are up
# Go to Status > Targets
# Ensure both java-app and nodejs-app show as "UP"
```

#### 2. Query Application Metrics
```bash
# Java App Metrics
http_server_requests_seconds_count{job="java-app"}
jvm_memory_used_bytes{job="java-app"}

# Node.js App Metrics
http_requests_total{job="nodejs-app"}
nodejs_heap_size_used_bytes{job="nodejs-app"}
```

### Grafana Dashboard Verification

#### 1. Access Grafana
```bash
# Grafana URL
http://<GRAFANA_EXTERNAL_IP>:3000

# Default credentials
Username: admin
Password: <check secret or default>
```

#### 2. Verify Dashboards
- Application Overview Dashboard
- JVM Metrics Dashboard (Java)
- Node.js Metrics Dashboard
- Infrastructure Overview

### Log Aggregation Verification

#### 1. Check Loki Logs
```bash
# Access Grafana Explore
http://<GRAFANA_EXTERNAL_IP>:3000/explore

# Sample LogQL queries
{app="java-app"} |= "ERROR"
{app="nodejs-app"} |= "health"
{namespace="default"} |= "started"
```

## 🔧 Service Discovery URLs

### Get External IPs
```bash
# Get all services with external IPs
kubectl get services -o wide

# Get specific service external IP
kubectl get service java-app-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
kubectl get service nodejs-app-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Port Forward (for testing)
```bash
# Java app port forward
kubectl port-forward service/java-app-service 8080:8080

# Node.js app port forward
kubectl port-forward service/nodejs-app-service 3000:3000

# Then access via localhost
curl http://localhost:8080/actuator/health
curl http://localhost:3000/health
```

## 🚨 Error Response Examples

### Common Error Responses

#### 1. Service Unavailable (503)
```json
{
  "error": "Service Temporarily Unavailable",
  "message": "Database connection failed",
  "timestamp": "2024-01-20T10:30:00.000Z",
  "requestId": "123e4567-e89b-12d3-a456-426614174000"
}
```

#### 2. Authentication Error (401)
```json
{
  "error": {
    "message": "Invalid token"
  },
  "requestId": "123e4567-e89b-12d3-a456-426614174000",
  "timestamp": "2024-01-20T10:30:00.000Z"
}
```

#### 3. Not Found (404)
```json
{
  "error": "Route not found",
  "message": "Cannot GET /api/nonexistent",
  "timestamp": "2024-01-20T10:30:00.000Z"
}
```

## 📝 Testing Checklist

### Pre-Deployment Verification
- [ ] All pods are running (`kubectl get pods`)
- [ ] Services have external IPs (`kubectl get services`)
- [ ] ConfigMaps and Secrets are applied
- [ ] Ingress rules are configured (if applicable)

### Application Health Verification
- [ ] Java app basic health check returns 200
- [ ] Java app detailed health check shows all components UP
- [ ] Node.js app basic health check returns 200
- [ ] Node.js app detailed health check shows all components healthy
- [ ] Database connections are working
- [ ] Redis connections are working (if enabled)

### API Functionality Verification
- [ ] Java app hello endpoint responds correctly
- [ ] Node.js auth endpoints work (register/login)
- [ ] Protected endpoints require authentication
- [ ] Error handling works correctly
- [ ] Rate limiting is functional

### Monitoring Verification
- [ ] Prometheus can scrape both applications
- [ ] Metrics are being collected
- [ ] Grafana dashboards display data
- [ ] Logs are being aggregated in Loki
- [ ] Alerting rules are active

### Performance Verification
- [ ] Response times are acceptable (<500ms for health checks)
- [ ] Memory usage is within expected ranges
- [ ] CPU usage is reasonable
- [ ] No memory leaks detected

## 🐛 Troubleshooting

### Common Issues and Solutions

#### 1. Pod Not Starting
```bash
# Check pod status
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Common fixes:
# - Check resource limits
# - Verify environment variables
# - Check image pull secrets
```

#### 2. Health Check Failing
```bash
# Check application logs
kubectl logs -l app=java-app
kubectl logs -l app=nodejs-app

# Common issues:
# - Database connection problems
# - Missing environment variables
# - Network connectivity issues
```

#### 3. Metrics Not Appearing
```bash
# Check ServiceMonitor
kubectl get servicemonitor

# Verify Prometheus targets
# Access Prometheus UI and check Status > Targets

# Common fixes:
# - Check service labels
# - Verify port configurations
# - Check network policies
```

### Debug Commands
```bash
# Get pod details
kubectl describe pod <pod-name>

# Execute into pod
kubectl exec -it <pod-name> -- /bin/bash

# Check service endpoints
kubectl get endpoints

# View recent events
kubectl get events --sort-by=.metadata.creationTimestamp
```

## 📋 Quick Test Script

Create a test script to verify all endpoints:

```bash
#!/bin/bash

# Configuration
JAVA_APP_URL="http://20.121.xxx.xxx:8080"
NODEJS_APP_URL="http://20.121.xxx.xxx:3000"

echo "=== Testing Java Application ==="
echo "Basic Health Check:"
curl -s "$JAVA_APP_URL/actuator/health" | jq .

echo -e "\nHello Endpoint:"
curl -s "$JAVA_APP_URL/api/hello" | jq .

echo -e "\nPrometheus Metrics:"
curl -s "$JAVA_APP_URL/actuator/prometheus" | head -5

echo -e "\n=== Testing Node.js Application ==="
echo "Basic Health Check:"
curl -s "$NODEJS_APP_URL/health" | jq .

echo -e "\nDetailed Health Check:"
curl -s "$NODEJS_APP_URL/health/detailed" | jq .

echo -e "\nApplication Info:"
curl -s "$NODEJS_APP_URL/health/info" | jq .

echo -e "\nPrometheus Metrics:"
curl -s "$NODEJS_APP_URL/health/metrics" | head -5

echo -e "\n=== All tests completed ==="
```

This comprehensive testing guide ensures thorough validation of both applications after deployment to your AKS cluster with the monitoring infrastructure.