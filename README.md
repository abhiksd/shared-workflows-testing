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
│   └── nodejs-backend1/                    # Notification Service (Express.js)
│       ├── .github/workflows/deploy.yml    # Individual deployment workflow
│       ├── src/, package.json, Dockerfile # Complete source code
│       ├── helm/                           # Kubernetes Helm charts
│       └── DEPLOYMENT.md                   # Service-specific documentation
├── .github/workflows/                      # 🔄 Shared Workflow Infrastructure
│   ├── shared-deploy.yml                  # Reusable deployment workflow
│   ├── rollback-deployment.yml            # Centralized rollback capability
│   ├── deploy-monitoring.yml              # Monitoring stack deployment
│   ├── monitoring-deploy.yml              # Additional monitoring deployment
│   ├── shared-security-scan.yml           # Shared security scanning workflow
│   └── pr-security-check.yml              # Security validation workflow
├── .github/actions/                        # 🔧 Composite Action Infrastructure
│   ├── check-changes/                     # Change detection action
│   ├── checkmarx-scan/                    # Security scanning action
│   ├── create-release/                    # Release creation action
│   ├── docker-build-push/                 # Docker build and push action
│   ├── helm-deploy/                       # Helm deployment action
│   ├── maven-build/                       # Maven build action
│   ├── sonar-scan/                        # SonarQube scanning action
│   ├── version-strategy/                  # Version strategy action
│   └── workspace-cleanup/                 # Workspace cleanup action
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

# Example migration for Notification Service
git clone https://github.com/your-org/nodejs-backend1-notifications.git
cp -r apps/nodejs-backend1/* nodejs-backend1-notifications/
# Update workflow references to external shared workflows
# Push to new repository
```

### **Option 2: Use as Monorepo Template**

Deploy all services from this repository:

```bash
# Clone the repository
git clone https://github.com/your-org/shared-workflows-be.git
cd shared-workflows-be

# Deploy Java service
cd apps/java-backend1
gh workflow run deploy.yml -f environment=dev

# Deploy Node.js service
cd apps/nodejs-backend1
gh workflow run deploy.yml -f environment=dev

# Deploy monitoring stack
gh workflow run deploy-monitoring.yml -f environment=dev
```

## 🏗️ **Backend Services Available**

### **Java Spring Boot Services**
| Service | Purpose | Endpoints | Status |
|---------|---------|-----------|---------|
| **java-backend1** | User Management | `/api/users`, `/actuator/health` | ✅ Ready |

### **Node.js Express Services**
| Service | Purpose | Endpoints | Status |
|---------|---------|-----------|---------|
| **nodejs-backend1** | Notification Service | `/api/notifications`, `/health` | ✅ Ready |

## 🔄 **Shared Workflow Infrastructure**

### **Available Workflows**

#### **shared-deploy.yml** - Universal Deployment
- ✅ Supports Java Spring Boot and Node.js applications
- ✅ Multi-environment deployment (dev, sqe, production)
- ✅ Azure Container Registry and AKS integration
- ✅ Helm chart deployment with environment-specific values
- ✅ Comprehensive health checks and rollback support

#### **rollback-deployment.yml** - Centralized Rollback
- ✅ Helm-based rollback capabilities
- ✅ Multi-environment rollback support
- ✅ Automated rollback triggers on deployment failures

#### **deploy-monitoring.yml** & **monitoring-deploy.yml** - Monitoring Stack
- ✅ Prometheus and Grafana deployment
- ✅ AlertManager configuration
- ✅ Service discovery and monitoring rules

#### **shared-security-scan.yml** - Shared Security Scanning
- ✅ Centralized security scanning workflow
- ✅ Code quality and vulnerability assessment
- ✅ Reusable across multiple services

#### **pr-security-check.yml** - Security Validation
- ✅ Code security scanning
- ✅ Dependency vulnerability checks
- ✅ Docker image security validation

### **Available Composite Actions**

The repository includes comprehensive composite actions in `.github/actions/`:
- **check-changes/** - Intelligent change detection for targeted deployments
- **checkmarx-scan/** - Security vulnerability scanning with Checkmarx
- **create-release/** - Automated release creation and tagging
- **docker-build-push/** - Docker image building and registry pushing
- **helm-deploy/** - Kubernetes Helm chart deployment
- **maven-build/** - Java Maven project building and testing
- **sonar-scan/** - Code quality analysis with SonarQube
- **version-strategy/** - Semantic versioning and release management
- **workspace-cleanup/** - Build environment cleanup and optimization

## 📚 **Comprehensive Documentation**

### **Setup Guides**
- **[Azure Setup Guide](./docs/AZURE_SETUP_GUIDE.md)** - Complete Azure cloud infrastructure setup
- **[Helm Chart Guide](./docs/HELM_CHART_GUIDE.md)** - Kubernetes deployment configuration
- **[Monitoring Setup Guide](./docs/MONITORING_SETUP_GUIDE.md)** - Observability stack configuration
- **[Spring Boot Profiles Guide](./docs/SPRING_BOOT_PROFILES_AND_SECRETS.md)** - Application configuration and secrets management
- **[Deployment Verification Guide](./docs/DEPLOYMENT_VERIFICATION_GUIDE.md)** - Comprehensive post-deployment testing and health checks

### **Migration & Deployment**
- **[Repository Migration Guide](./REPOSITORY_MIGRATION_GUIDE.md)** - Step-by-step migration to separate repositories
- **Individual Service Deployment Guides** - Located in each `apps/[service]/DEPLOYMENT.md`

## 🛠️ **Infrastructure Requirements**

### **Azure Resources**
- **Azure Kubernetes Service (AKS)** - Container orchestration
- **Azure Container Registry (ACR)** - Docker image storage

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
# Check Azure identity and permissions
./scripts/azure-identity-check.sh

# Deploy monitoring stack
gh workflow run deploy-monitoring.yml -f environment=dev
```

### **3. Deploy Services**
```bash
# Deploy services
cd apps/java-backend1
gh workflow run deploy.yml -f environment=dev

cd apps/nodejs-backend1
gh workflow run deploy.yml -f environment=dev

# Verify deployments
curl https://dev.mydomain.com/java-backend1/actuator/health
curl https://dev.mydomain.com/nodejs-backend1/health
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
# Java Service - User Management
curl https://dev.mydomain.com/java-backend1/actuator/health

# Node.js Service - Notifications
curl https://dev.mydomain.com/nodejs-backend1/health
```

---

**🎯 Purpose**: Template and migration hub for microservices architecture  
**🔄 Workflows**: Centralized shared deployment infrastructure  
**📊 Monitoring**: Comprehensive observability and alerting  
**🚀 Deployment**: Production-ready Kubernetes with Helm  
**☁️ Cloud**: Azure-native with enterprise security patterns

This repository provides everything needed to establish a robust microservices architecture with operational excellence! 🚀