# Multi-Backend Ingress Routing Setup

This document describes the comprehensive AKS monitoring setup with proper ingress routing for multiple Java and Node.js backends.

## Architecture Overview

The setup includes:
- 3 Java Backend Services (backend1, backend2, backend3)
- 3 Node.js Backend Services (backend1, backend2, backend3)
- Environment-specific domains (dev.mydomain.com, staging.mydomain.com, production.mydomain.com)
- Independent deployment capabilities for each backend
- Azure Application Gateway integration
- Comprehensive monitoring and observability

## Domain and Routing Structure

### Environment Domains
- **Development**: `dev.mydomain.com`
- **Staging**: `staging.mydomain.com`  
- **Production**: `production.mydomain.com`

### Path-based Routing
Each environment supports the following routing patterns:

```
{environment}.mydomain.com/backend1 → Java Backend 1
{environment}.mydomain.com/backend2 → Java Backend 2  
{environment}.mydomain.com/backend3 → Java Backend 3
```

## Helm Chart Structure

```
helm/
├── java-backend1/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-dev.yaml
│   ├── values-staging.yaml
│   ├── values-production.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       ├── configmap.yaml
│       ├── servicemonitor.yaml
│       └── _helpers.tpl
├── java-backend2/
├── java-backend3/
├── nodejs-backend1/
├── nodejs-backend2/
├── nodejs-backend3/
└── monitoring/
```

## Ingress Configuration

Each backend has its own ingress configuration using NGINX Ingress Controller:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullName }}-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/x-forwarded-prefix: "/{{ .Values.ingress.pathPrefix }}"
    nginx.ingress.kubernetes.io/proxy-body-size: "{{ .Values.ingress.proxyBodySize }}"
spec:
  ingressClassName: nginx
  rules:
    - host: dev.mydomain.com
      http:
        paths:
          - path: /(backend1/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: {{ $fullName }}
                port:
                  number: {{ $svcPort }}
```

## Environment-Specific Configurations

### Development
- Single replica per service
- Debug logging enabled
- Minimal resource requirements
- All actuator endpoints exposed (Java)

### Staging
- 2 replicas per service
- Autoscaling enabled (2-5 replicas)
- Production-like configurations
- INFO level logging

### Production
- 3 replicas per service
- Autoscaling enabled (3-10 replicas)
- High resource limits
- WARN level logging
- Pod disruption budgets enabled

## Deployment Workflows

Each backend has its own GitHub Actions workflow:

### Java Backends
- `deploy-java-backend1.yml`
- `deploy-java-backend2.yml`
- `deploy-java-backend3.yml`

### Node.js Backends
- `deploy-nodejs-backend1.yml`
- `deploy-nodejs-backend2.yml`
- `deploy-nodejs-backend3.yml`

### Workflow Features
- Environment auto-detection based on branch
- Manual deployment with environment selection
- Docker image building and pushing to ACR
- Helm deployment with environment-specific values
- Post-deployment verification

## Azure Application Gateway Integration

The Azure Application Gateway is configured to:
1. Route traffic to the NGINX Ingress static IP
2. Perform health checks on ingress backends
3. Forward traffic based on domain names:
   - `dev.mydomain.com` → Dev AKS cluster ingress
   - `staging.mydomain.com` → Staging AKS cluster ingress  
   - `production.mydomain.com` → Production AKS cluster ingress

## Monitoring and Observability

Each backend includes:
- **Prometheus ServiceMonitor** for metrics collection
- **Health endpoints** for liveness and readiness probes
- **Application-specific metrics** exposure
- **Environment-specific logging** configurations

### Java Applications
- Spring Boot Actuator endpoints
- JVM metrics collection
- Application performance monitoring

### Node.js Applications
- Express.js health endpoints
- Custom metrics endpoints
- Performance monitoring

## Deployment Commands

### Deploy Individual Backend
```bash
# Deploy Java Backend 1 to development
helm upgrade --install java-backend1-dev ./helm/java-backend1 \
  --namespace dev \
  --create-namespace \
  --values ./helm/java-backend1/values-dev.yaml

# Deploy Node.js Backend 2 to staging
helm upgrade --install nodejs-backend2-staging ./helm/nodejs-backend2 \
  --namespace staging \
  --create-namespace \
  --values ./helm/nodejs-backend2/values-staging.yaml
```

### Deploy All Backends
```bash
# Development environment
for backend in java-backend1 java-backend2 java-backend3 nodejs-backend1 nodejs-backend2 nodejs-backend3; do
  helm upgrade --install ${backend}-dev ./helm/${backend} \
    --namespace dev \
    --create-namespace \
    --values ./helm/${backend}/values-dev.yaml
done
```

## Testing Connectivity

### Health Check Endpoints
```bash
# Java backends
curl https://dev.mydomain.com/backend1/actuator/health
curl https://dev.mydomain.com/backend2/actuator/health
curl https://dev.mydomain.com/backend3/actuator/health

# Node.js backends (assuming they have /health endpoints)
curl https://dev.mydomain.com/backend1/health
curl https://dev.mydomain.com/backend2/health
curl https://dev.mydomain.com/backend3/health
```

### Application Endpoints
```bash
# Test API endpoints for each backend
curl https://dev.mydomain.com/backend1/api/status
curl https://staging.mydomain.com/backend2/api/info
curl https://production.mydomain.com/backend3/api/version
```

## Troubleshooting

### Common Issues

1. **Ingress Not Routing Correctly**
   ```bash
   kubectl get ingress -n <environment>
   kubectl describe ingress <backend-name>-ingress -n <environment>
   ```

2. **Backend Pod Issues**
   ```bash
   kubectl get pods -n <environment> -l app.kubernetes.io/name=<backend-name>
   kubectl logs -f <pod-name> -n <environment>
   ```

3. **Service Discovery Issues**
   ```bash
   kubectl get svc -n <environment>
   kubectl describe svc <backend-name> -n <environment>
   ```

### Monitoring and Alerts
- Check Prometheus targets for service discovery
- Verify ServiceMonitor configurations
- Monitor application logs through Grafana dashboards

## Security Considerations

1. **Network Policies**: Each backend can have isolated network policies
2. **Service Accounts**: Separate service accounts per backend for fine-grained RBAC
3. **Secret Management**: Azure Key Vault integration for sensitive configurations
4. **Image Security**: Regular vulnerability scanning of container images

## Scaling and Performance

### Horizontal Pod Autoscaling
- Configured based on CPU and memory utilization
- Environment-specific scaling policies
- Graceful handling of traffic spikes

### Resource Management
- Environment-appropriate resource requests and limits
- Quality of Service (QoS) classes configuration
- Node affinity and anti-affinity rules

## Future Enhancements

1. **Service Mesh Integration**: Consider Istio for advanced traffic management
2. **Blue-Green Deployments**: Implement deployment strategies for zero-downtime updates
3. **Canary Releases**: Gradual rollout of new versions
4. **Multi-Region Setup**: Disaster recovery and global load balancing

## Contributing

When adding new backends:
1. Copy an existing helm chart structure
2. Update Chart.yaml with new backend name
3. Modify values files for appropriate configurations
4. Create corresponding GitHub Actions workflow
5. Update this documentation

For environment-specific changes:
1. Modify the appropriate values-{env}.yaml file
2. Test in development environment first
3. Follow the promotion path: dev → staging → production