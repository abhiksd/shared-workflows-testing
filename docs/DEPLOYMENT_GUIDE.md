# Production Deployment Guide

This guide provides comprehensive instructions for deploying applications using the production-grade AKS deployment platform.

## 📋 Table of Contents

- [Environment Overview](#-environment-overview)
- [Deployment Scenarios](#-deployment-scenarios)
- [Production Deployment](#-production-deployment)
- [Environment Configuration](#-environment-configuration)
- [Security Considerations](#-security-considerations)
- [Monitoring & Health Checks](#-monitoring--health-checks)
- [Rollback Procedures](#-rollback-procedures)
- [Performance Optimization](#-performance-optimization)

## 🌍 Environment Overview

### Environment Hierarchy
```
Development → Staging → Production
     ↓           ↓         ↓
Feature     Integration  Live
Testing     Testing      Workloads
```

### Environment Characteristics

| Environment | Purpose | Auto-Deploy | Resources | Security Level |
|-------------|---------|-------------|-----------|---------------|
| **Development** | Feature development and unit testing | ✅ | Minimal | Basic |
| **Staging** | Integration testing and validation | ✅ | Production-like | Enhanced |
| **Production** | Live customer workloads | ✅ | Full scale | Maximum |

### Branch-Environment Mapping
- `N630-6258_Helm_deploy` → Development
- `main` → Staging  
- `release/*` → Production

## 🚀 Deployment Scenarios

### 1. Feature Development Deployment

**Trigger**: Push to `N630-6258_Helm_deploy` branch

```bash
# Development workflow
git checkout N630-6258_Helm_deploy
git add .
git commit -m "feat: add new feature"
git push origin N630-6258_Helm_deploy
```

**Characteristics**:
- Fast feedback cycle
- Relaxed security policies
- Debug logging enabled
- Single replica
- Always pull latest images

### 2. Integration Testing Deployment

**Trigger**: Push to `main` branch

```bash
# Staging workflow  
git checkout main
git merge N630-6258_Helm_deploy
git push origin main
```

**Characteristics**:
- Production-like environment
- Multi-replica setup
- Performance testing enabled
- Security policies enforced
- Monitoring enabled

### 3. Production Release Deployment

**Trigger**: Create release branch or tag

```bash
# Production release workflow
git checkout main
git checkout -b release/v1.2.3
git push origin release/v1.2.3

# OR create tag
git tag v1.2.3
git push origin v1.2.3
```

**Characteristics**:
- Zero-downtime deployment
- Auto-scaling enabled
- Full security hardening
- Comprehensive monitoring
- Backup verification

### 4. Hotfix Deployment

**Trigger**: Manual workflow dispatch

```bash
# Emergency hotfix
# Use GitHub Actions UI:
# Actions → Deploy Java App → Run workflow
# Select: Environment: production, Force deploy: true
```

**Characteristics**:
- Bypass normal gates
- Immediate deployment
- Enhanced logging
- Automatic rollback on failure

## 🏭 Production Deployment

### Pre-Deployment Checklist

#### Infrastructure Readiness
- [ ] AKS cluster health verified
- [ ] Azure Container Registry accessible
- [ ] Key Vault secrets updated
- [ ] Network policies configured
- [ ] Backup systems verified

#### Application Readiness
- [ ] Health check endpoints implemented
- [ ] Performance testing completed
- [ ] Security scans passed
- [ ] Documentation updated
- [ ] Rollback plan prepared

#### Monitoring Setup
- [ ] Application insights configured
- [ ] Log analytics workspace ready
- [ ] Alert rules defined
- [ ] Dashboard configured
- [ ] On-call team notified

### Production Deployment Process

#### Phase 1: Pre-deployment Validation
```yaml
# Automatic validations performed:
- Environment compatibility check
- Resource availability verification
- Secret accessibility validation
- Network connectivity test
- Previous deployment status check
```

#### Phase 2: Blue-Green Deployment
```yaml
# Deployment strategy for zero downtime:
1. Deploy new version alongside current (Green)
2. Run health checks on new version
3. Gradually shift traffic (10% → 50% → 100%)
4. Monitor metrics and error rates
5. Complete switch or rollback
```

#### Phase 3: Post-deployment Verification
```yaml
# Automated verification steps:
- Health endpoint checks
- Database connectivity verification
- External service integration tests
- Performance baseline comparison
- Security posture validation
```

### Production Deployment Commands

```bash
# Manual production deployment
gh workflow run deploy-java-app.yml \
  -f environment=production \
  -f force_deploy=false

# Emergency production deployment
gh workflow run deploy-java-app.yml \
  -f environment=production \
  -f force_deploy=true

# Check deployment status
gh run list --workflow=deploy-java-app.yml --limit=5

# Monitor deployment logs
gh run view --log
```

## ⚙️ Environment Configuration

### Development Environment

```yaml
# helm/java-app/values-dev.yaml
global:
  environment: dev

replicaCount: 1

image:
  pullPolicy: Always

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 1Gi

env:
  - name: SPRING_PROFILES_ACTIVE
    value: "dev"
  - name: LOG_LEVEL
    value: "DEBUG"
  - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
    value: "*"

autoscaling:
  enabled: false

monitoring:
  enabled: false

security:
  networkPolicy:
    enabled: false
```

### Staging Environment

```yaml
# helm/java-app/values-staging.yaml
global:
  environment: staging

replicaCount: 2

image:
  pullPolicy: IfNotPresent

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 1000m
    memory: 2Gi

env:
  - name: SPRING_PROFILES_ACTIVE
    value: "staging"
  - name: LOG_LEVEL
    value: "INFO"

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70

monitoring:
  enabled: true

security:
  networkPolicy:
    enabled: true
```

### Production Environment

```yaml
# helm/java-app/values-production.yaml
global:
  environment: production

replicaCount: 3

image:
  pullPolicy: IfNotPresent

resources:
  requests:
    cpu: 1000m
    memory: 2Gi
  limits:
    cpu: 2000m
    memory: 4Gi

env:
  - name: SPRING_PROFILES_ACTIVE
    value: "production"
  - name: LOG_LEVEL
    value: "WARN"

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 60
  targetMemoryUtilizationPercentage: 70

monitoring:
  enabled: true
  
security:
  networkPolicy:
    enabled: true
  podSecurityPolicy:
    enabled: true

azureKeyVault:
  enabled: true
```

## 🔐 Security Considerations

### Security by Environment

#### Development Security
```yaml
security:
  level: basic
  features:
    - Basic authentication
    - HTTP allowed
    - Debug endpoints enabled
    - Relaxed CORS policies
```

#### Staging Security  
```yaml
security:
  level: enhanced
  features:
    - HTTPS enforced
    - Network policies enabled
    - Security headers required
    - Access logging enabled
```

#### Production Security
```yaml
security:
  level: maximum
  features:
    - Mutual TLS required
    - Pod security policies enforced
    - Network segmentation
    - Audit logging
    - Secret rotation
    - Compliance monitoring
```

### Secret Management Strategy

```yaml
# Environment-specific secret handling
dev:
  secrets:
    source: ConfigMap (non-sensitive)
    rotation: Manual
    encryption: Basic

staging:
  secrets:
    source: Azure Key Vault
    rotation: Monthly
    encryption: AES-256

production:
  secrets:
    source: Azure Key Vault
    rotation: Weekly
    encryption: AES-256 + HSM
    compliance: SOC2, ISO27001
```

## 📊 Monitoring & Health Checks

### Health Check Strategy

#### Liveness Probe Configuration
```yaml
# Optimized for each environment
development:
  livenessProbe:
    initialDelaySeconds: 30
    periodSeconds: 10
    failureThreshold: 5

staging:
  livenessProbe:
    initialDelaySeconds: 45
    periodSeconds: 10
    failureThreshold: 3

production:
  livenessProbe:
    initialDelaySeconds: 60
    periodSeconds: 5
    failureThreshold: 3
```

#### Readiness Probe Configuration
```yaml
# Environment-specific readiness checks
development:
  readinessProbe:
    httpGet:
      path: /actuator/health
      port: 8080
    initialDelaySeconds: 20
    periodSeconds: 10

staging:
  readinessProbe:
    httpGet:
      path: /actuator/health/readiness
      port: 8080
    initialDelaySeconds: 30
    periodSeconds: 5

production:
  readinessProbe:
    httpGet:
      path: /actuator/health/readiness
      port: 8080
    initialDelaySeconds: 30
    periodSeconds: 5
    successThreshold: 2
```

### Monitoring Dashboards

#### Application Metrics
```yaml
metrics:
  jvm:
    - Heap usage
    - GC performance  
    - Thread count
    - Class loading
  
  application:
    - Request rate
    - Response time
    - Error rate
    - Business metrics
  
  infrastructure:
    - CPU utilization
    - Memory usage
    - Network I/O
    - Disk usage
```

#### Alert Thresholds
```yaml
critical:
  - Application down (0 healthy replicas)
  - Error rate > 5%
  - Response time > 5s
  - Memory usage > 90%

warning:
  - Error rate > 1%
  - Response time > 2s
  - CPU usage > 80%
  - Replica count at maximum

info:
  - Deployment started/completed
  - Scaling events
  - Configuration changes
```

## 🔄 Rollback Procedures

### Automatic Rollback Triggers
- Health check failures
- High error rates
- Performance degradation
- Security policy violations

### Manual Rollback Process

#### Using Helm
```bash
# Check deployment history
helm history java-app -n production

# Rollback to previous version
helm rollback java-app -n production

# Rollback to specific version
helm rollback java-app 5 -n production
```

#### Using Kubernetes
```bash
# Check rollout history
kubectl rollout history deployment/java-app -n production

# Rollback deployment
kubectl rollout undo deployment/java-app -n production

# Rollback to specific revision
kubectl rollout undo deployment/java-app --to-revision=3 -n production
```

#### Using GitHub Actions
```bash
# Trigger rollback workflow with different strategies

# Rollback to previous version (default)
gh workflow run rollback-deployment.yml \
  -f environment=production \
  -f application_name=java-app \
  -f rollback_strategy=previous-version

# Rollback to specific version
gh workflow run rollback-deployment.yml \
  -f environment=production \
  -f application_name=java-app \
  -f rollback_strategy=specific-version \
  -f target_version=1.2.2

# Rollback to specific Helm revision
gh workflow run rollback-deployment.yml \
  -f environment=production \
  -f application_name=java-app \
  -f rollback_strategy=specific-revision \
  -f target_revision=3
```

### Post-Rollback Verification
```bash
# Verify application health
kubectl get pods -n production -l app=java-app

# Check service endpoints
kubectl get svc -n production

# Verify traffic routing
curl -H "Host: java-app.example.com" https://your-ingress-ip/health

# Monitor logs
kubectl logs -f deployment/java-app -n production
```

## ⚡ Performance Optimization

### Resource Optimization by Environment

#### Development Optimization
```yaml
resources:
  strategy: minimal
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 1Gi
  
jvm:
  heap: 512m
  gc: G1GC
  options: "-XX:+UseContainerSupport"
```

#### Production Optimization
```yaml
resources:
  strategy: performance
  requests:
    cpu: 1000m
    memory: 2Gi
  limits:
    cpu: 2000m
    memory: 4Gi

jvm:
  heap: 3g
  gc: G1GC
  options: |
    -XX:+UseG1GC
    -XX:+UseContainerSupport
    -XX:InitialRAMPercentage=50.0
    -XX:MaxRAMPercentage=75.0
    -XX:+OptimizeStringConcat
    -XX:+UseStringDeduplication
```

### Scaling Configuration

#### Horizontal Pod Autoscaling
```yaml
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 70
```

#### Vertical Pod Autoscaling
```yaml
vpa:
  enabled: true
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: java-app
      maxAllowed:
        cpu: 4000m
        memory: 8Gi
      minAllowed:
        cpu: 500m
        memory: 1Gi
```

### Performance Monitoring
```yaml
monitoring:
  performance:
    - Application response time
    - Database query performance
    - External API call latency
    - Resource utilization trends
    - Scaling decision metrics

  optimization:
    - JVM garbage collection metrics
    - Thread pool utilization
    - Connection pool metrics
    - Cache hit/miss ratios
```

## 🎯 Best Practices Summary

### Deployment Best Practices
1. **Always test in lower environments first**
2. **Use feature flags for gradual rollouts**
3. **Maintain deployment artifacts for rollbacks**
4. **Monitor deployment progress continuously**
5. **Verify health checks before traffic routing**

### Security Best Practices
1. **Apply principle of least privilege**
2. **Rotate secrets regularly**
3. **Enable audit logging**
4. **Use network policies**
5. **Scan containers for vulnerabilities**

### Performance Best Practices
1. **Right-size resources based on metrics**
2. **Use appropriate JVM settings**
3. **Configure proper health check timeouts**
4. **Enable autoscaling based on actual usage**
5. **Monitor and optimize database queries**

### Monitoring Best Practices
1. **Set up meaningful alerts**
2. **Create comprehensive dashboards**
3. **Monitor business metrics alongside technical metrics**
4. **Establish baseline performance metrics**
5. **Implement distributed tracing**

---

**Last Updated**: $(date '+%Y-%m-%d')  
**Version**: 1.0.0  
**Maintained by**: DevOps Team