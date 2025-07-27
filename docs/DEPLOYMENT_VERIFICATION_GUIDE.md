# Deployment Verification Guide

This comprehensive guide provides step-by-step instructions for verifying that all components and services are working correctly after deployment.

## 🎯 **Overview**

This guide covers verification for:
- **Java Spring Boot Backend Services** (3 services)
- **Node.js Express Backend Services** (3 services)
- **Monitoring Stack** (Prometheus, Grafana, Loki, AlertManager)
- **Infrastructure Components** (Ingress, Load Balancer, DNS)
- **Security Components** (HTTPS, Authentication)

## 📋 **Quick Health Check Summary**

### **✅ Quick Verification Commands**
```bash
# All Java services health check
curl -f https://dev.mydomain.com/backend1/actuator/health
curl -f https://dev.mydomain.com/backend2/actuator/health  
curl -f https://dev.mydomain.com/backend3/actuator/health

# All Node.js services health check
curl -f https://dev.mydomain.com/backend1/health
curl -f https://dev.mydomain.com/backend2/health
curl -f https://dev.mydomain.com/backend3/health

# Monitoring stack health
curl -f https://dev.mydomain.com/prometheus/-/healthy
curl -f https://dev.mydomain.com/grafana/api/health
```

## 🏗️ **Backend Services Verification**

### **Java Spring Boot Services**

#### **1. Java Backend 1 - User Management Service**
```bash
# Environment URLs
DEV_URL="https://dev.mydomain.com/backend1"
STAGING_URL="https://staging.mydomain.com/backend1"
PROD_URL="https://production.mydomain.com/backend1"

# Health Checks
echo "=== Java Backend 1 Health Checks ==="
curl -s $DEV_URL/actuator/health | jq '.'
curl -s $DEV_URL/actuator/health/readiness | jq '.'
curl -s $DEV_URL/actuator/health/liveness | jq '.'

# Metrics Endpoint
curl -s $DEV_URL/actuator/prometheus | head -20

# API Endpoints
curl -s $DEV_URL/api/status | jq '.'
curl -s -H "Accept: application/json" $DEV_URL/api/users | jq '.'

# Expected Response Examples:
# Health: {"status":"UP","components":{"db":{"status":"UP"}}}
# Status: {"service":"java-backend1","version":"1.0.0","environment":"dev"}
```

#### **2. Java Backend 2 - Product Catalog Service**
```bash
# Environment URLs
DEV_URL="https://dev.mydomain.com/backend2"
STAGING_URL="https://staging.mydomain.com/backend2"
PROD_URL="https://production.mydomain.com/backend2"

# Health Checks
echo "=== Java Backend 2 Health Checks ==="
curl -s $DEV_URL/actuator/health | jq '.'
curl -s $DEV_URL/actuator/info | jq '.'

# API Endpoints
curl -s $DEV_URL/api/status | jq '.'
curl -s -H "Accept: application/json" $DEV_URL/api/products | jq '.'

# Performance Check
time curl -s $DEV_URL/actuator/health > /dev/null
```

#### **3. Java Backend 3 - Order Management Service**
```bash
# Environment URLs
DEV_URL="https://dev.mydomain.com/backend3"
STAGING_URL="https://staging.mydomain.com/backend3"
PROD_URL="https://production.mydomain.com/backend3"

# Health Checks
echo "=== Java Backend 3 Health Checks ==="
curl -s $DEV_URL/actuator/health | jq '.'

# API Endpoints
curl -s $DEV_URL/api/status | jq '.'
curl -s -H "Accept: application/json" $DEV_URL/api/orders | jq '.'

# Database Connectivity Check
curl -s $DEV_URL/actuator/health | jq '.components.db.status'
```

### **Node.js Express Services**

#### **1. Node.js Backend 1 - Notification Service**
```bash
# Environment URLs
DEV_URL="https://dev.mydomain.com/backend1"
STAGING_URL="https://staging.mydomain.com/backend1"  
PROD_URL="https://production.mydomain.com/backend1"

# Health Checks
echo "=== Node.js Backend 1 Health Checks ==="
curl -s $DEV_URL/health | jq '.'
curl -s $DEV_URL/health/ready | jq '.'

# Metrics Endpoint
curl -s $DEV_URL/metrics | head -20

# API Endpoints
curl -s $DEV_URL/api/status | jq '.'
curl -s -H "Accept: application/json" $DEV_URL/api/notifications | jq '.'

# Expected Response:
# Health: {"status":"healthy","timestamp":"2024-01-20T10:00:00Z","uptime":3600}
```

#### **2. Node.js Backend 2 - Analytics Service**
```bash
# Environment URLs  
DEV_URL="https://dev.mydomain.com/backend2"
STAGING_URL="https://staging.mydomain.com/backend2"
PROD_URL="https://production.mydomain.com/backend2"

# Health Checks
echo "=== Node.js Backend 2 Health Checks ==="
curl -s $DEV_URL/health | jq '.'

# API Endpoints
curl -s $DEV_URL/api/status | jq '.'
curl -s -H "Accept: application/json" $DEV_URL/api/analytics | jq '.'
curl -s -H "Accept: application/json" $DEV_URL/api/reports | jq '.'
```

#### **3. Node.js Backend 3 - File Management Service**
```bash
# Environment URLs
DEV_URL="https://dev.mydomain.com/backend3"
STAGING_URL="https://staging.mydomain.com/backend3"
PROD_URL="https://production.mydomain.com/backend3"

# Health Checks
echo "=== Node.js Backend 3 Health Checks ==="
curl -s $DEV_URL/health | jq '.'

# API Endpoints
curl -s $DEV_URL/api/status | jq '.'
curl -s -H "Accept: application/json" $DEV_URL/api/files | jq '.'
```

## 📊 **Monitoring Stack Verification**

### **Prometheus Verification**
```bash
# Prometheus Health Check
PROMETHEUS_URL="https://dev.mydomain.com/prometheus"

echo "=== Prometheus Verification ==="
# Health endpoint
curl -s $PROMETHEUS_URL/-/healthy

# Ready endpoint  
curl -s $PROMETHEUS_URL/-/ready

# Configuration status
curl -s $PROMETHEUS_URL/api/v1/status/config | jq '.status'

# Check targets are being scraped
curl -s $PROMETHEUS_URL/api/v1/targets | jq '.data.activeTargets[] | {job: .discoveredLabels.job, health: .health}'

# Check if metrics are being collected
curl -s "$PROMETHEUS_URL/api/v1/query?query=up" | jq '.data.result[] | {instance: .metric.instance, value: .value[1]}'

# Verify application metrics
curl -s "$PROMETHEUS_URL/api/v1/query?query=http_requests_total" | jq '.data.result | length'
```

### **Grafana Verification**
```bash
# Grafana Health Check
GRAFANA_URL="https://dev.mydomain.com/grafana"

echo "=== Grafana Verification ==="
# Health API
curl -s $GRAFANA_URL/api/health | jq '.'

# Database check
curl -s $GRAFANA_URL/api/health | jq '.database'

# Data source connectivity
curl -s -u admin:$(kubectl get secret grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d) \
  $GRAFANA_URL/api/datasources | jq '.[].name'

# Dashboard availability
curl -s -u admin:$(kubectl get secret grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d) \
  $GRAFANA_URL/api/search | jq '.[].title'
```

### **AlertManager Verification**
```bash
# AlertManager Health Check
ALERTMANAGER_URL="https://dev.mydomain.com/alertmanager"

echo "=== AlertManager Verification ==="
# Health endpoint
curl -s $ALERTMANAGER_URL/-/healthy

# Check active alerts
curl -s $ALERTMANAGER_URL/api/v1/alerts | jq '.data[] | {alertname: .labels.alertname, state: .status.state}'

# Check configuration
curl -s $ALERTMANAGER_URL/api/v1/status | jq '.data.configYAML' | head -20
```

### **Loki Verification**
```bash
# Loki Health Check  
LOKI_URL="https://dev.mydomain.com/loki"

echo "=== Loki Verification ==="
# Health endpoint
curl -s $LOKI_URL/ready

# Check if logs are being ingested
curl -s "$LOKI_URL/loki/api/v1/query?query={namespace=\"default\"}" | jq '.data.result | length'

# Check label values
curl -s $LOKI_URL/loki/api/v1/labels | jq '.data[]'
```

## 🛠️ **Infrastructure Verification**

### **Kubernetes Resources**
```bash
echo "=== Kubernetes Resources Verification ==="

# Check all deployments are ready
kubectl get deployments --all-namespaces -o wide

# Check pod status
kubectl get pods --all-namespaces | grep -E "(java-backend|nodejs-backend|prometheus|grafana)"

# Check services
kubectl get services --all-namespaces | grep -E "(java-backend|nodejs-backend|prometheus|grafana)"

# Check ingress
kubectl get ingress --all-namespaces

# Check persistent volumes
kubectl get pv,pvc --all-namespaces

# Resource usage
kubectl top pods --all-namespaces | grep -E "(java-backend|nodejs-backend|prometheus|grafana)"
```

### **Ingress Controller Verification**
```bash
echo "=== Ingress Controller Verification ==="

# Check NGINX ingress controller status
kubectl get pods -n ingress-nginx

# Check ingress controller logs for errors
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50

# Verify SSL certificates
echo | openssl s_client -servername dev.mydomain.com -connect dev.mydomain.com:443 2>/dev/null | openssl x509 -noout -dates

# Test ingress routing
curl -I https://dev.mydomain.com/backend1/actuator/health
curl -I https://dev.mydomain.com/backend2/actuator/health  
curl -I https://dev.mydomain.com/backend3/actuator/health
```

### **DNS Resolution**
```bash
echo "=== DNS Resolution Verification ==="

# Check DNS resolution
nslookup dev.mydomain.com
nslookup staging.mydomain.com
nslookup production.mydomain.com

# Verify DNS points to correct load balancer
dig dev.mydomain.com +short
```

## 🔐 **Security Verification**

### **HTTPS and TLS**
```bash
echo "=== HTTPS/TLS Verification ==="

# Check SSL certificate validity
for env in dev staging production; do
  echo "=== $env.mydomain.com SSL Check ==="
  echo | openssl s_client -servername $env.mydomain.com -connect $env.mydomain.com:443 2>/dev/null | openssl x509 -noout -text | grep -E "(Subject:|Issuer:|Not Before:|Not After:)"
  
  # Check SSL rating
  curl -s "https://api.ssllabs.com/api/v3/analyze?host=$env.mydomain.com&publish=off&startNew=on" | jq '.status'
done
```



### **Network Policies** 
```bash
echo "=== Network Policies Verification ==="

# Check network policies
kubectl get networkpolicies --all-namespaces

# Verify pod-to-pod communication (should work within namespace)
kubectl exec -n default deployment/java-backend1 -- curl -s http://java-backend2:8080/actuator/health

# Verify monitoring can scrape application metrics
kubectl exec -n monitoring deployment/prometheus -- curl -s http://java-backend1.default.svc.cluster.local:8080/actuator/prometheus | head -5
```

## 🧪 **End-to-End Testing**

### **Automated Health Check Script**
```bash
#!/bin/bash
# Complete health check script

set -e

ENVIRONMENT=${1:-dev}
DOMAIN="$ENVIRONMENT.mydomain.com"

echo "🚀 Starting comprehensive health check for $ENVIRONMENT environment..."

# Function to check URL and report status
check_url() {
    local url=$1
    local description=$2
    local expected_status=${3:-200}
    
    if response=$(curl -s -w "%{http_code}" -o /tmp/response "$url"); then
        status_code=$(tail -n1 <<< "$response")
        if [[ $status_code -eq $expected_status ]]; then
            echo "✅ $description: OK ($status_code)"
            return 0
        else
            echo "❌ $description: FAILED ($status_code)"
            return 1
        fi
    else
        echo "❌ $description: CONNECTION FAILED"
        return 1
    fi
}

# Backend services health checks
echo ""
echo "🏗️ Backend Services Health Check"
echo "================================="

# Java services
check_url "https://$DOMAIN/backend1/actuator/health" "Java Backend 1 (User Management)"
check_url "https://$DOMAIN/backend2/actuator/health" "Java Backend 2 (Product Catalog)"  
check_url "https://$DOMAIN/backend3/actuator/health" "Java Backend 3 (Order Management)"

# Node.js services
check_url "https://$DOMAIN/backend1/health" "Node.js Backend 1 (Notification)"
check_url "https://$DOMAIN/backend2/health" "Node.js Backend 2 (Analytics)"
check_url "https://$DOMAIN/backend3/health" "Node.js Backend 3 (File Management)"

# API endpoints
echo ""
echo "🔗 API Endpoints Check"
echo "======================"
check_url "https://$DOMAIN/backend1/api/status" "Java Backend 1 API"
check_url "https://$DOMAIN/backend2/api/status" "Java Backend 2 API"
check_url "https://$DOMAIN/backend3/api/status" "Java Backend 3 API"

# Monitoring stack
echo ""
echo "📊 Monitoring Stack Check"
echo "========================="
check_url "https://$DOMAIN/prometheus/-/healthy" "Prometheus Health"
check_url "https://$DOMAIN/grafana/api/health" "Grafana Health"
check_url "https://$DOMAIN/alertmanager/-/healthy" "AlertManager Health"

# Performance test
echo ""
echo "⚡ Performance Check"
echo "==================="
for service in backend1 backend2 backend3; do
    response_time=$(curl -o /dev/null -s -w "%{time_total}" "https://$DOMAIN/$service/actuator/health")
    if (( $(echo "$response_time < 2.0" | bc -l) )); then
        echo "✅ $service response time: ${response_time}s"
    else
        echo "⚠️  $service response time: ${response_time}s (slow)"
    fi
done

echo ""
echo "🎉 Health check completed for $ENVIRONMENT environment!"
```

### **Load Testing**
```bash
#!/bin/bash
# Simple load test

echo "🔥 Load Testing Backend Services"

# Install hey if not available
if ! command -v hey &> /dev/null; then
    echo "Installing hey load testing tool..."
    go install github.com/rakyll/hey@latest
fi

ENVIRONMENT=${1:-dev}
DOMAIN="$ENVIRONMENT.mydomain.com"

# Test each backend with light load
for backend in backend1 backend2 backend3; do
    echo "Testing $backend..."
    hey -n 100 -c 10 -t 30 "https://$DOMAIN/$backend/actuator/health"
done
```

## 📈 **Monitoring Verification Dashboards**

### **Grafana Dashboard URLs**
```bash
# Access Grafana dashboards for verification
GRAFANA_URL="https://dev.mydomain.com/grafana"

echo "📊 Grafana Dashboard URLs:"
echo "=========================="
echo "🏗️ Infrastructure Overview: $GRAFANA_URL/d/infrastructure/infrastructure-overview"
echo "☕ Java Applications: $GRAFANA_URL/d/java-apps/java-applications-overview"  
echo "🟢 Node.js Applications: $GRAFANA_URL/d/nodejs-apps/nodejs-applications-overview"
echo "🚨 Alerts Overview: $GRAFANA_URL/d/alerts/alerts-overview"
echo "📝 Logs Dashboard: $GRAFANA_URL/d/logs/logs-overview"
```

### **Prometheus Queries for Verification**
```bash
# Useful Prometheus queries for verification
PROMETHEUS_URL="https://dev.mydomain.com/prometheus"

echo "📊 Key Prometheus Queries:"
echo "=========================="

# Service availability
echo "Service Up Status:"
curl -s "$PROMETHEUS_URL/api/v1/query?query=up" | jq '.data.result[] | "\(.metric.job): \(.value[1])"'

# HTTP request rates
echo "HTTP Request Rates:"
curl -s "$PROMETHEUS_URL/api/v1/query?query=rate(http_requests_total[5m])" | jq '.data.result[] | "\(.metric.job): \(.value[1])"'

# Memory usage
echo "Memory Usage:"
curl -s "$PROMETHEUS_URL/api/v1/query?query=process_resident_memory_bytes" | jq '.data.result[] | "\(.metric.job): \(.value[1] | tonumber / 1024 / 1024 | floor)MB"'

# Response times
echo "Average Response Times:"
curl -s "$PROMETHEUS_URL/api/v1/query?query=rate(http_request_duration_seconds_sum[5m])/rate(http_request_duration_seconds_count[5m])" | jq '.data.result[] | "\(.metric.job): \(.value[1])s"'
```

## 🚨 **Troubleshooting Common Issues**

### **Service Not Responding**
```bash
# Check pod status
kubectl get pods -n default | grep backend

# Check pod logs
kubectl logs deployment/java-backend1 -n default --tail=50

# Check service endpoints
kubectl get endpoints -n default

# Check ingress
kubectl describe ingress -n default
```

### **SSL/TLS Issues**
```bash
# Check certificate details
openssl s_client -servername dev.mydomain.com -connect dev.mydomain.com:443 -showcerts

# Check Let's Encrypt certificate issuer
kubectl get certificates --all-namespaces

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager --tail=50
```

### **Monitoring Issues**
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
curl http://localhost:9090/api/v1/targets

# Check ServiceMonitor configuration
kubectl get servicemonitors --all-namespaces

# Verify metric endpoints are accessible
kubectl exec -n monitoring deployment/prometheus -- curl java-backend1.default.svc.cluster.local:8080/actuator/prometheus
```

## 📋 **Verification Checklist**

### **✅ Deployment Verification Checklist**

#### **Backend Services**
- [ ] All Java backend health endpoints return 200
- [ ] All Node.js backend health endpoints return 200
- [ ] API status endpoints return service information
- [ ] Response times are under 2 seconds
- [ ] Metrics endpoints are accessible
- [ ] Database connections are healthy

#### **Monitoring Stack**
- [ ] Prometheus is collecting metrics from all services
- [ ] Grafana dashboards are loading correctly
- [ ] AlertManager is processing alerts
- [ ] Loki is receiving logs
- [ ] All monitoring targets are healthy

#### **Infrastructure**
- [ ] All pods are in Running state
- [ ] Ingress routing is working correctly
- [ ] SSL certificates are valid and not expiring soon
- [ ] DNS resolution is working
- [ ] Load balancer is distributing traffic

#### **Security**
- [ ] HTTPS is enforced on all endpoints

- [ ] Network policies are allowing necessary traffic
- [ ] Authentication is working where required

#### **Performance**
- [ ] Response times meet SLA requirements
- [ ] Resource utilization is within acceptable limits
- [ ] No memory leaks detected
- [ ] Error rates are below threshold

## 🔧 **Automated Verification Scripts**

Save the health check scripts and make them executable:

```bash
# Save complete health check script
curl -o health-check.sh https://raw.githubusercontent.com/your-org/shared-workflows/main/scripts/health-check.sh
chmod +x health-check.sh

# Run health check
./health-check.sh dev
./health-check.sh staging  
./health-check.sh production
```

## 📞 **Support and Next Steps**

### **Getting Help**
1. **📖 Check logs**: Use kubectl logs to inspect application and infrastructure logs
2. **📊 Review metrics**: Use Grafana dashboards to identify performance issues
3. **🔍 Verify configuration**: Check Helm values and Kubernetes resources
4. **🚨 Check alerts**: Review AlertManager for active alerts

### **Continuous Monitoring**
1. **📈 Set up automated health checks** in your CI/CD pipeline
2. **🔔 Configure alert notifications** for critical issues
3. **📊 Create custom dashboards** for business metrics
4. **📝 Implement log monitoring** for error detection

This verification guide ensures all deployed components are functioning correctly and provides troubleshooting steps for common issues. Regular verification helps maintain system reliability and performance! 🚀