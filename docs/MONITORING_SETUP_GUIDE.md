# AKS Monitoring Setup Guide

This guide provides comprehensive instructions for setting up monitoring for AKS clusters using Prometheus, Grafana, Loki, and Azure Monitor integration.

## 🏗️ Architecture Overview

Our monitoring stack consists of the following components:

### Core Monitoring Components
- **Prometheus**: Metrics collection, storage, and alerting
- **Grafana**: Visualization dashboards and data exploration
- **AlertManager**: Alert routing and notification management
- **Loki**: Log aggregation and querying
- **Promtail**: Log collection agent

### Azure Integration
- **Azure Monitor**: Native Azure monitoring integration
- **Container Insights**: AKS-specific monitoring and logging
- **Log Analytics Workspace**: Centralized log storage and analysis

### Application Monitoring
- **ServiceMonitors**: Automatic service discovery for metrics collection
- **Custom Dashboards**: Application-specific visualization
- **Alert Rules**: Comprehensive alerting strategy

## 📋 Prerequisites

### Azure Resources
- AKS cluster with Container Insights enabled
- Azure Log Analytics workspace
- Azure Application Insights (optional)
- Azure subscription with monitoring permissions

### Tools Required
- `kubectl` CLI
- `helm` CLI (v3.x)
- `azure-cli`
- Access to the AKS cluster

### GitHub Secrets Configuration
Ensure the following secrets are configured in your GitHub repository:

```yaml
AZURE_CLIENT_ID          # Azure Service Principal Client ID for OIDC
AZURE_TENANT_ID          # Azure AD Tenant ID
AZURE_SUBSCRIPTION_ID    # Azure Subscription ID
```

## 🚀 Deployment Methods

### Method 1: Automated Deployment via GitHub Actions

The monitoring stack can be deployed automatically using the provided GitHub workflow.

#### Triggering the Deployment

**Via Workflow Call (Recommended for CI/CD)**:
```yaml
jobs:
  deploy-monitoring:
    uses: ./.github/workflows/deploy-monitoring.yml
    with:
      environment: "dev"
      aks_cluster_name: "your-aks-cluster"
      aks_resource_group: "your-resource-group"
      azure_subscription_id: "your-subscription-id"
    secrets:
      AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
      AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

**Via Manual Dispatch**:
1. Go to GitHub Actions tab
2. Select "Deploy AKS Monitoring Stack" workflow
3. Click "Run workflow"
4. Fill in the required parameters
5. Click "Run workflow"

### Method 2: Manual Deployment

#### Step 1: Prepare Environment
```bash
# Set environment variables
export ENVIRONMENT="dev"  # or sqe, production
export AKS_CLUSTER_NAME="your-aks-cluster"
export AKS_RESOURCE_GROUP="your-resource-group"
export AZURE_SUBSCRIPTION_ID="your-subscription-id"

# Login to Azure
az login

# Get AKS credentials
az aks get-credentials \
  --resource-group $AKS_RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME
```

#### Step 2: Create Monitoring Namespace
```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace monitoring name=monitoring --overwrite
```

#### Step 3: Add Helm Repositories
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

#### Step 4: Deploy Monitoring Components

**Deploy Prometheus Stack**:
```bash
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values helm/monitoring/values.yaml \
  --values helm/monitoring/values-${ENVIRONMENT}.yaml \
  --set global.environment=${ENVIRONMENT} \
  --set global.clusterName=${AKS_CLUSTER_NAME} \
  --set global.azureSubscriptionId=${AZURE_SUBSCRIPTION_ID} \
  --set global.azureResourceGroup=${AKS_RESOURCE_GROUP} \
  --wait \
  --timeout=600s
```

**Deploy Grafana**:
```bash
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --values helm/monitoring/values.yaml \
  --values helm/monitoring/values-${ENVIRONMENT}.yaml \
  --set global.environment=${ENVIRONMENT} \
  --set global.clusterName=${AKS_CLUSTER_NAME} \
  --wait \
  --timeout=300s
```

**Deploy Loki Stack**:
```bash
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --values helm/monitoring/values.yaml \
  --values helm/monitoring/values-${ENVIRONMENT}.yaml \
  --set global.environment=${ENVIRONMENT} \
  --set global.clusterName=${AKS_CLUSTER_NAME} \
  --wait \
  --timeout=300s
```

**Deploy Custom Monitoring Resources**:
```bash
helm upgrade --install aks-monitoring ./helm/monitoring \
  --namespace monitoring \
  --values helm/monitoring/values-${ENVIRONMENT}.yaml \
  --set global.environment=${ENVIRONMENT} \
  --set global.clusterName=${AKS_CLUSTER_NAME} \
  --set global.azureSubscriptionId=${AZURE_SUBSCRIPTION_ID} \
  --set global.azureResourceGroup=${AKS_RESOURCE_GROUP} \
  --wait \
  --timeout=300s
```

## 📊 Accessing Monitoring Components

### Grafana Dashboard

#### Development Environment
```bash
# Get NodePort
kubectl get svc grafana -n monitoring

# Access via browser
http://<node-ip>:<node-port>
```

#### Staging/Production Environment
```bash
# Get LoadBalancer IP
kubectl get svc grafana -n monitoring

# Access via browser
http://<external-ip>
```

#### Default Credentials
- **Username**: `admin`
- **Password**: Retrieved from secret
```bash
kubectl get secret grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d
```

### Prometheus

#### Access via Port Forward
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```
Access at: http://localhost:9090

### AlertManager

#### Access via Port Forward
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
```
Access at: http://localhost:9093

## 🔧 Configuration

### Environment-Specific Configurations

#### Development Environment (`values-dev.yaml`)
- Reduced resource requirements
- NodePort service for Grafana
- Simplified alerting thresholds
- Shorter data retention

#### Staging Environment (`values-sqe.yaml`)
- Medium resource allocation
- Internal LoadBalancer
- Production-like alerting
- Medium data retention

#### Production Environment (`values-production.yaml`)
- Full resource allocation
- High availability configuration
- Strict alerting thresholds
- Extended data retention
- Network policies enabled

### Alerting Strategy

#### Critical Alerts
- **Application Down**: Application unavailable
  - Threshold: `up{job=~".*app.*"} == 0`
  - Duration: 2-5 minutes (environment-dependent)
  - Action: Immediate response required

- **High Error Rate**: Application returning 5xx errors
  - Threshold: 5-10% error rate (environment-dependent)
  - Duration: 5-10 minutes
  - Action: Investigate application issues

- **Pod Crash Loop**: Pods continuously restarting
  - Threshold: Restart count increase
  - Duration: 3-5 minutes
  - Action: Check pod logs and resources

#### Warning Alerts
- **High CPU Usage**: Node CPU utilization
  - Threshold: 80-90% (environment-dependent)
  - Duration: 10-15 minutes
  - Action: Monitor and consider scaling

- **High Memory Usage**: Node memory utilization
  - Threshold: 80-90% (environment-dependent)
  - Duration: 10-15 minutes
  - Action: Monitor and consider scaling

- **High Disk Usage**: Filesystem utilization
  - Threshold: 85% disk usage
  - Duration: 5 minutes
  - Action: Clean up or expand storage

#### Info Alerts
- **Deployment Events**: Application deployments
  - Trigger: Replica count changes
  - Action: Informational tracking

- **Scaling Events**: HPA scaling activities
  - Trigger: Replica count changes via HPA
  - Action: Informational tracking

## 📱 Application Monitoring Integration

### Java Spring Boot Applications

#### Add Dependencies
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

#### Configure Actuator
```yaml
# application.yml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    prometheus:
      enabled: true
  metrics:
    export:
      prometheus:
        enabled: true
```

#### Update Helm Chart
```yaml
# Add metrics port to service
service:
  ports:
    - name: http
      port: 8080
    - name: metrics
      port: 8080
      targetPort: 8080

# Add Prometheus annotations
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/path: "/actuator/prometheus"
  prometheus.io/port: "8080"
```

### Node.js Applications

#### Add Dependencies
```json
{
  "dependencies": {
    "prom-client": "^14.0.0"
  }
}
```

#### Configure Metrics
```javascript
const client = require('prom-client');

// Create a Registry
const register = new client.Registry();

// Add default metrics
client.collectDefaultMetrics({ register });

// Expose metrics endpoint
app.get('/metrics', (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(register.metrics());
});
```

## 🎯 Dashboard Configuration

### Pre-configured Dashboards

#### Kubernetes Overview Dashboard
- Cluster resource utilization
- Node status and metrics
- Pod status and distribution
- Namespace resource usage

#### Application Performance Dashboard
- Request rate and latency
- Error rate monitoring
- JVM metrics (Java apps)
- Custom application metrics

### Importing Additional Dashboards

1. Access Grafana web interface
2. Navigate to "+" → Import
3. Enter dashboard ID or upload JSON
4. Configure data source (Prometheus)
5. Save dashboard

### Popular Dashboard IDs
- **Node Exporter**: 1860
- **Kubernetes Cluster**: 7249
- **Java JVM**: 4701
- **NGINX Ingress**: 9614

## 🔍 Log Management with Loki

### Log Collection

#### Automatic Collection
Promtail automatically collects logs from:
- All pod stdout/stderr
- Kubernetes events
- Node-level logs

#### Custom Log Collection
```yaml
# Add to pod spec for custom log collection
annotations:
  loki.io/collect: "true"
  loki.io/path: "/var/log/app.log"
```

### Log Querying

#### Basic Queries
```promql
# All logs from a namespace
{namespace="default"}

# Application-specific logs
{app="java-app"}

# Error logs
{app="java-app"} |= "ERROR"

# Log rate
rate({app="java-app"}[5m])
```

#### Advanced Queries
```promql
# Error rate per minute
sum(rate({app="java-app"} |= "ERROR" [1m])) by (pod)

# Log volume by severity
sum by (level) (rate({app="java-app"} | json | __error__="" [5m]))
```

## 🚨 Alert Configuration

### AlertManager Configuration

#### Slack Integration
```yaml
# alertmanager.yml
global:
  slack_api_url: 'YOUR_SLACK_WEBHOOK_URL'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'slack-notifications'

receivers:
- name: 'slack-notifications'
  slack_configs:
  - channel: '#alerts'
    title: 'Alert: {{ .GroupLabels.alertname }}'
    text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

#### Email Integration
```yaml
receivers:
- name: 'email-notifications'
  email_configs:
  - to: 'team@company.com'
    from: 'alerts@company.com'
    subject: 'Alert: {{ .GroupLabels.alertname }}'
    body: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

### Custom Alert Rules

#### Application-Specific Alerts
```yaml
groups:
- name: application.rules
  rules:
  - alert: HighLatency
    expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High latency detected"
      description: "95th percentile latency is {{ $value }}s"
```

## 🛡️ Security Considerations

### Network Policies

#### Monitoring Namespace Isolation
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: monitoring-network-policy
  namespace: monitoring
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
  egress:
  - {}
```

### RBAC Configuration

#### Prometheus Service Account
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources: ["nodes", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
```

## 🔧 Troubleshooting

### Common Issues

#### Prometheus Not Scraping Targets
1. Check ServiceMonitor configuration
2. Verify pod annotations
3. Check network policies
4. Verify service endpoints

```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Navigate to http://localhost:9090/targets
```

#### Grafana Dashboard Not Loading Data
1. Verify Prometheus data source configuration
2. Check query syntax
3. Verify time range settings
4. Check Prometheus connectivity

```bash
# Test Prometheus connectivity from Grafana
kubectl exec -n monitoring deployment/grafana -- wget -qO- http://kube-prometheus-stack-prometheus:9090/api/v1/query?query=up
```

#### High Memory Usage
1. Adjust retention settings
2. Optimize query patterns
3. Scale resources
4. Review series cardinality

```bash
# Check Prometheus memory usage
kubectl top pods -n monitoring
```

#### Loki Not Receiving Logs
1. Check Promtail configuration
2. Verify log file permissions
3. Check network connectivity
4. Review Loki configuration

```bash
# Check Promtail logs
kubectl logs -n monitoring daemonset/loki-promtail
```

### Monitoring Health Checks

```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# Check persistent volumes
kubectl get pv -l app.kubernetes.io/part-of=kube-prometheus-stack

# Check services
kubectl get svc -n monitoring

# Check ingress (if configured)
kubectl get ingress -n monitoring
```

## 📈 Performance Optimization

### Prometheus Optimization

#### Query Optimization
- Use recording rules for expensive queries
- Limit query time ranges
- Use appropriate aggregations
- Avoid high-cardinality metrics

#### Storage Optimization
- Configure appropriate retention policies
- Use external storage for long-term retention
- Monitor storage growth

#### Resource Optimization
- Scale based on metrics volume
- Use node affinity for storage
- Configure resource limits appropriately

### Grafana Optimization

#### Dashboard Performance
- Use template variables efficiently
- Limit time ranges for heavy queries
- Use dashboard links instead of embedding
- Cache query results where possible

#### Resource Management
- Configure session management
- Use LDAP/SSO for authentication
- Implement proper user management

## 🔄 Maintenance and Updates

### Regular Maintenance Tasks

#### Weekly Tasks
- Review alert noise and tune thresholds
- Check storage usage and cleanup old data
- Review dashboard performance
- Update alert notification channels

#### Monthly Tasks
- Update Helm charts to latest versions
- Review and optimize queries
- Audit user access and permissions
- Test backup and restore procedures

#### Quarterly Tasks
- Review monitoring strategy and coverage
- Evaluate new monitoring tools and features
- Conduct disaster recovery testing
- Update documentation and runbooks

### Upgrade Procedures

#### Helm Chart Updates
```bash
# Update helm repositories
helm repo update

# Check current versions
helm list -n monitoring

# Upgrade components
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values helm/monitoring/values.yaml \
  --values helm/monitoring/values-${ENVIRONMENT}.yaml
```

#### Backup Procedures
```bash
# Backup Grafana dashboards
kubectl exec -n monitoring deployment/grafana -- \
  grafana-cli admin export-dashboard > grafana-backup.json

# Backup Prometheus configuration
kubectl get configmap -n monitoring kube-prometheus-stack-prometheus-rulefiles-0 -o yaml > prometheus-rules-backup.yaml
```

## 📚 Additional Resources

### Documentation Links
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [Azure Monitor Documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/)

### Community Resources
- [Prometheus Community Helm Charts](https://github.com/prometheus-community/helm-charts)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Azure Monitor Community](https://github.com/microsoft/Application-Insights-Workbooks)

### Training and Certification
- [Prometheus Certified Associate](https://www.cncf.io/certification/prometheus/)
- [Grafana Fundamentals](https://grafana.com/tutorials/grafana-fundamentals/)
- [Azure Monitor Training](https://docs.microsoft.com/en-us/learn/paths/monitor-azure-resources/)

---

For additional support or questions, please refer to the project documentation or contact the platform team.