# Shared Workflows & Microservices Template Repository

This repository serves as a **template and migration hub** for creating independent microservices with centralized shared workflows. It contains ready-to-migrate backend services and comprehensive infrastructure setup guides.

## 🎯 **Repository Purpose**

### **Primary Use Cases:**
1. **📦 Backend Service Templates**: Complete, production-ready backend services ready for migration to independent repositories
2. **🔄 Shared Workflow Infrastructure**: Centralized GitHub Actions workflows for consistent deployment patterns
3. **📖 Migration Guidance**: Comprehensive guides for splitting monorepo into microservices architecture
4. **🛠️ Infrastructure Setup**: Azure cloud infrastructure and Kubernetes deployment guides

## 🏗️ **Current Repository Structure**

```
📁 Shared Workflows Template Repository
├── apps/                                    # 🎁 Ready-to-Migrate Backend Services
│   ├── java-backend1/                      # User Management Service (Spring Boot)
│   │   ├── .github/workflows/deploy.yml    # Individual deployment workflow
│   │   ├── src/, pom.xml, Dockerfile      # Complete source code
│   │   ├── helm/                           # Kubernetes Helm charts
│   │   └── DEPLOYMENT.md                   # Service-specific documentation
│   ├── java-backend2/                      # Product Catalog Service (Spring Boot)
│   ├── java-backend3/                      # Order Management Service (Spring Boot)
│   ├── nodejs-backend1/                    # Notification Service (Express.js)
│   ├── nodejs-backend2/                    # Analytics Service (Express.js)
│   └── nodejs-backend3/                    # File Management Service (Express.js)
├── .github/workflows/                      # 🔄 Shared Workflow Infrastructure
│   ├── shared-deploy.yml                  # Reusable deployment workflow
│   ├── rollback-deployment.yml            # Centralized rollback capability
│   ├── deploy-monitoring.yml              # Monitoring stack deployment
│   └── pr-security-check.yml              # Security validation workflow
├── helm/monitoring/                        # 📊 Shared monitoring infrastructure
├── scripts/                               # 🛠️ Infrastructure setup scripts
├── docs/                                  # 📚 Comprehensive setup guides
└── REPOSITORY_MIGRATION_GUIDE.md          # 🚀 Migration instructions
```

## 🚀 **Quick Start - Using This Repository**

### **Option 1: Migrate to Separate Repositories (Recommended)**

Follow the comprehensive [Repository Migration Guide](./REPOSITORY_MIGRATION_GUIDE.md) to:

1. **Create separate repositories** for each backend service
2. **Set up centralized shared workflows** repository 
3. **Migrate each service** with all dependencies included
4. **Test independent deployments** for each service

```bash
# Example migration for User Management Service
git clone https://github.com/your-org/java-backend1-user-management.git
cp -r apps/java-backend1/* java-backend1-user-management/
# Update workflow references to external shared workflows
# Push to new repository
```

### **Option 2: Use as Monorepo Template**

Deploy all services from this repository:

```bash
# Clone the repository
git clone https://github.com/your-org/shared-workflows-be.git
cd shared-workflows-be

# Deploy individual service
cd apps/java-backend1
gh workflow run deploy.yml -f environment=dev

# Deploy monitoring stack
gh workflow run deploy-monitoring.yml -f environment=dev
```

## 🏗️ **Backend Services Available**

### **Java Spring Boot Services**
| Service | Purpose | Endpoints | Status |
|---------|---------|-----------|---------|
| **java-backend1** | User Management | `/api/users`, `/actuator/health` | ✅ Ready |
| **java-backend2** | Product Catalog | `/api/products`, `/actuator/health` | ✅ Ready |
| **java-backend3** | Order Management | `/api/orders`, `/actuator/health` | ✅ Ready |

### **Node.js Express Services**
| Service | Purpose | Endpoints | Status |
|---------|---------|-----------|---------|
| **nodejs-backend1** | Notification Service | `/api/notifications`, `/health` | ✅ Ready |
| **nodejs-backend2** | Analytics Service | `/api/analytics`, `/health` | ✅ Ready |
| **nodejs-backend3** | File Management | `/api/files`, `/health` | ✅ Ready |

## 🔄 **Shared Workflow Infrastructure**

### **Available Workflows**

#### **shared-deploy.yml** - Universal Deployment
- ✅ Supports Java Spring Boot and Node.js applications
- ✅ Multi-environment deployment (dev, staging, production)
- ✅ Azure Container Registry and AKS integration
- ✅ Helm chart deployment with environment-specific values
- ✅ Comprehensive health checks and rollback support

#### **rollback-deployment.yml** - Centralized Rollback
- ✅ Helm-based rollback capabilities
- ✅ Multi-environment rollback support
- ✅ Automated rollback triggers on deployment failures

#### **deploy-monitoring.yml** - Monitoring Stack
- ✅ Prometheus and Grafana deployment
- ✅ AlertManager configuration
- ✅ Service discovery and monitoring rules

#### **pr-security-check.yml** - Security Validation
- ✅ Code security scanning
- ✅ Dependency vulnerability checks
- ✅ Docker image security validation

## 📚 **Comprehensive Documentation**

### **Setup Guides**
- **[Azure Setup Guide](./docs/AZURE_SETUP_GUIDE.md)** - Complete Azure cloud infrastructure setup
- **[Helm Chart Guide](./docs/HELM_CHART_GUIDE.md)** - Kubernetes deployment configuration
- **[Monitoring Setup Guide](./docs/MONITORING_SETUP_GUIDE.md)** - Observability stack configuration
- **[Spring Boot Profiles Guide](./docs/SPRING_BOOT_PROFILES_AND_SECRETS.md)** - Application configuration and secrets management

### **Migration & Deployment**
- **[Repository Migration Guide](./REPOSITORY_MIGRATION_GUIDE.md)** - Step-by-step migration to separate repositories
- **Individual Service Deployment Guides** - Located in each `apps/[service]/DEPLOYMENT.md`

## 🛠️ **Infrastructure Requirements**

### **Azure Resources**
- **Azure Kubernetes Service (AKS)** - Container orchestration
- **Azure Container Registry (ACR)** - Docker image storage
- **Azure Key Vault** - Secrets management
- **Azure Application Gateway** - Ingress and load balancing

### **Kubernetes Components**
- **NGINX Ingress Controller** - HTTP routing and SSL termination
- **Helm 3.x** - Package management and deployments
- **Prometheus + Grafana** - Monitoring and observability
- **Azure CSI Driver** - Secrets injection

## 🎯 **Architecture Benefits**

### **🔄 Microservices Independence**
- ✅ Each service can be deployed independently
- ✅ Service-specific scaling and resource allocation
- ✅ Isolated failure domains and fault tolerance
- ✅ Technology diversity (Java + Node.js + more)

### **🚀 Operational Excellence**
- ✅ Centralized deployment standards via shared workflows
- ✅ Consistent monitoring and observability across services
- ✅ Automated rollback and disaster recovery
- ✅ Security scanning and compliance validation

### **👥 Team Productivity**
- ✅ Clear service ownership boundaries
- ✅ Independent development and release cycles
- ✅ Reduced coordination overhead
- ✅ Self-service deployment capabilities

## 🔐 **Security & Compliance**

### **Security Features**
- **🔒 Azure Key Vault Integration** - Centralized secrets management
- **🛡️ RBAC and Identity Management** - Azure AD integration
- **🔍 Security Scanning** - Automated vulnerability detection
- **🌐 Network Security** - Private networking and ingress controls

### **Compliance Standards**
- **📋 Infrastructure as Code** - Version-controlled infrastructure
- **📊 Audit Logging** - Comprehensive deployment and access logs
- **🔄 Automated Compliance Checks** - Policy validation and enforcement
- **🚨 Monitoring and Alerting** - Proactive issue detection

## 🚀 **Getting Started**

### **1. Choose Your Path**
```bash
# Option A: Migrate to separate repositories (recommended for production)
# Follow: ./REPOSITORY_MIGRATION_GUIDE.md

# Option B: Use as monorepo template (good for experimentation)
git clone <this-repo>
cd apps/java-backend1
gh workflow run deploy.yml -f environment=dev
```

### **2. Set Up Infrastructure**
```bash
# Follow Azure setup guide
./scripts/azure-keyvault-setup.sh
./scripts/azure-identity-check.sh

# Deploy monitoring stack
gh workflow run deploy-monitoring.yml -f environment=dev
```

### **3. Deploy Services**
```bash
# Deploy individual services
cd apps/java-backend1
gh workflow run deploy.yml -f environment=dev

# Verify deployment
curl https://dev.mydomain.com/backend1/actuator/health
```

## 📞 **Support & Contributing**

### **Getting Help**
1. 📖 Check the comprehensive documentation in `/docs`
2. 🔍 Review service-specific deployment guides
3. 🛠️ Run infrastructure setup scripts for environment validation
4. 📋 Follow troubleshooting guides in individual service documentation

### **Contributing**
1. **🔧 Infrastructure Improvements** - Enhance shared workflows and infrastructure
2. **📚 Documentation Updates** - Improve setup guides and examples
3. **🎯 New Service Templates** - Add additional backend service examples
4. **🔐 Security Enhancements** - Strengthen security patterns and practices

## 📊 **Monitoring & Observability**

### **Available Dashboards**
- **🏗️ Infrastructure Metrics** - AKS cluster health and resource utilization
- **🚀 Application Performance** - Service response times and error rates
- **🔍 Business Metrics** - Custom application metrics per service
- **🚨 Alerting Rules** - Proactive monitoring and incident response

### **Health Check Endpoints**
```bash
# Java Services
curl https://dev.mydomain.com/backend1/actuator/health
curl https://dev.mydomain.com/backend2/actuator/health
curl https://dev.mydomain.com/backend3/actuator/health

# Node.js Services  
curl https://dev.mydomain.com/backend1/health
curl https://dev.mydomain.com/backend2/health
curl https://dev.mydomain.com/backend3/health
```

---

**🎯 Purpose**: Template and migration hub for microservices architecture  
**🔄 Workflows**: Centralized shared deployment infrastructure  
**📊 Monitoring**: Comprehensive observability and alerting  
**🚀 Deployment**: Production-ready Kubernetes with Helm  
**☁️ Cloud**: Azure-native with enterprise security patterns

This repository provides everything needed to establish a robust microservices architecture with operational excellence! 🚀