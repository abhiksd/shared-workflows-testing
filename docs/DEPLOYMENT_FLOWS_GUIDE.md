# 🚀 Comprehensive Deployment Flows Guide

## 📋 Overview

This document provides a complete reference for all deployment flows in our shared workflows architecture, from Git events to final deployments. It covers deployment workflows, security scanning workflows, and their interactions.

## 🏗️ Architecture Overview

```mermaid
graph TB
    subgraph "Git Events"
        A[Push to main]
        B[Push to develop]
        C[Push to release/*]
        D[Pull Request]
        E[Manual Dispatch]
    end
    
    subgraph "Caller Workflows"
        F[apps/*/deploy.yml]
        G[apps/*/pr-security-check.yml]
    end
    
    subgraph "Shared Workflows"
        H[shared-deploy.yml]
        I[shared-security-scan.yml]
    end
    
    subgraph "Composite Actions"
        J[checkmarx-scan]
        K[sonar-scan]
        L[helm-deploy]
        M[docker-build]
        N[maven-build]
    end
    
    A --> F
    B --> F
    C --> F
    D --> G
    E --> F
    
    F --> H
    G --> I
    
    H --> J
    H --> K
    H --> L
    H --> M
    H --> N
    
    I --> J
    I --> K
```

---

## 🔄 Deployment Workflow Flows

### 1. 🌟 Push to Main Branch → Staging Deployment

```mermaid
flowchart TD
    A[Developer pushes to main] --> B[Caller: apps/*/deploy.yml triggers]
    B --> C[Shared: shared-deploy.yml called]
    C --> D[validate-environment job]
    
    D --> E{Auto-detect environment}
    E -->|github.ref = refs/heads/main| F[TARGET_ENV = 'sqe']
    
    F --> G{Branch validation}
    G -->|main branch allowed for sqe| H[SHOULD_DEPLOY = true]
    
    H --> I[setup job]
    I --> J[check-changes: Detect code changes]
    J --> K[version-strategy: Generate version tags]
    
    K --> L{Changes detected?}
    L -->|Yes| M[maven-build job]
    L -->|No + force_deploy=false| Z[Skip deployment]
    
    M --> N[Build JAR artifacts]
    N --> O[sonar-scan job]
    N --> P[checkmarx-scan job]
    
    O --> Q{SonarQube PASSED?}
    P --> R{Checkmarx PASSED?}
    
    Q -->|Yes| S[build job]
    R -->|Yes| S
    Q -->|No| Y[❌ Deployment FAILED]
    R -->|No| Y
    
    S --> T[Build & push Docker image to ACR]
    T --> U[deploy job]
    U --> V[Deploy to AKS SQE cluster via Helm]
    V --> W[health-check job]
    W --> X[✅ Staging deployment SUCCESS]
    
    style A fill:#e1f5fe
    style X fill:#c8e6c9
    style Y fill:#ffcdd2
    style Z fill:#fff3e0
```

**Key Points:**
- **Trigger**: Push to `main` branch
- **Target**: SQE/Staging environment
- **Auto-detection**: `main` → `sqe` environment
- **Security Gates**: Both SonarQube and Checkmarx must PASS
- **Final Step**: Health check validation

---

### 2. 🛠️ Push to Develop Branch → Dev Deployment

```mermaid
flowchart TD
    A[Developer pushes to develop] --> B[Caller: apps/*/deploy.yml triggers]
    B --> C[Shared: shared-deploy.yml called]
    C --> D[validate-environment job]
    
    D --> E{Auto-detect environment}
    E -->|github.ref = refs/heads/N630-6258_Helm_deploy| F[TARGET_ENV = 'dev']
    
    F --> G{Branch validation}
    G -->|develop branch allowed for dev| H[SHOULD_DEPLOY = true]
    
    H --> I[setup job]
    I --> J[Same build and security pipeline as staging]
    J --> K[deploy job]
    K --> L[Deploy to AKS Dev cluster]
    L --> M[health-check job]
    M --> N[✅ Dev deployment SUCCESS]
    
    style A fill:#e8f5e8
    style N fill:#c8e6c9
```

**Key Points:**
- **Trigger**: Push to `develop` branch (`N630-6258_Helm_deploy`)
- **Target**: Dev environment
- **Pipeline**: Same security gates as staging
- **Cluster**: AKS Dev cluster

---

### 3. 🚀 Push to Release Branch → Production Deployment

```mermaid
flowchart TD
    A[Developer pushes to release/v1.2.0] --> B[Caller: apps/*/deploy.yml triggers]
    B --> C[Shared: shared-deploy.yml called]
    C --> D[validate-environment job]
    
    D --> E{Auto-detect environment}
    E -->|github.ref = refs/heads/release/*| F[TARGET_ENV = 'prod']
    
    F --> G{Branch validation}
    G -->|release branch allowed for prod| H[SHOULD_DEPLOY = true]
    
    H --> I[setup job with version strategy]
    I --> J[maven-build job]
    J --> K[Security scans: sonar + checkmarx]
    
    K --> L{All security gates PASSED?}
    L -->|Yes| M[build job]
    L -->|No| Y[❌ Production deployment BLOCKED]
    
    M --> N[Build & push Docker image]
    N --> O[deploy job]
    O --> P[Deploy to AKS Production cluster]
    P --> Q[create_release job]
    Q --> R[Create GitHub Release with artifacts]
    R --> S[health-check job]
    S --> T[✅ Production deployment SUCCESS]
    
    style A fill:#fff3e0
    style T fill:#c8e6c9
    style Y fill:#ffcdd2
    style Q fill:#e3f2fd
```

**Key Points:**
- **Trigger**: Push to `release/*` branch or Git tags
- **Target**: Production environment
- **Extra Step**: GitHub release creation
- **Security**: Strictest validation - both scans must PASS
- **Cluster**: AKS Production cluster

---

### 4. 🎯 Manual Dispatch → Custom Environment

```mermaid
flowchart TD
    A[User triggers workflow_dispatch] --> B[User selects environment]
    B --> C{Environment choice}
    
    C -->|dev| D[Caller: environment = 'dev']
    C -->|staging| E[Caller: environment = 'staging']  
    C -->|production| F[Caller: environment = 'production']
    
    D --> G[Shared: shared-deploy.yml called]
    E --> G
    F --> G
    
    G --> H[validate-environment job]
    H --> I{Manual dispatch validation}
    I -->|workflow_dispatch always allowed| J[SHOULD_DEPLOY = true]
    
    J --> K[Deploy to specified environment]
    K --> L{Environment type}
    
    L -->|production| M[Include create_release job]
    L -->|dev/staging| N[Skip release creation]
    
    M --> O[✅ Manual deployment SUCCESS + Release]
    N --> P[✅ Manual deployment SUCCESS]
    
    style A fill:#f3e5f5
    style O fill:#c8e6c9
    style P fill:#c8e6c9
```

**Key Points:**
- **Trigger**: Manual workflow dispatch
- **Flexibility**: Can deploy any branch to any environment
- **Override**: Bypasses branch restrictions
- **Control**: User specifies target environment explicitly

---

## 🔒 Security Scanning Flows

### 1. 📥 Pull Request → Security Analysis Only

```mermaid
flowchart TD
    A[Developer opens PR to main/develop] --> B[Caller: apps/*/pr-security-check.yml triggers]
    B --> C[Shared: shared-security-scan.yml called]
    C --> D[build-app job]
    
    D --> E{Application type}
    E -->|java-springboot| F[Setup Java 21 + Maven build]
    E -->|nodejs| G[Setup Node.js 20 + npm build]
    
    F --> H[mvn clean compile test-compile]
    G --> I[npm ci && npm run build]
    
    H --> J[sonar-scan job]
    I --> K[checkmarx-scan job]
    
    J --> L[Maven: mvn test jacoco:report]
    L --> M[SonarQube analysis with thresholds]
    
    K --> N[Checkmarx security vulnerability scan]
    
    M --> O{SonarQube results}
    N --> P{Checkmarx results}
    
    O -->|PASSED| Q[security-summary job]
    O -->|FAILED| R[❌ PR blocked - Quality issues]
    P -->|PASSED| Q
    P -->|FAILED| S[❌ PR blocked - Security vulnerabilities]
    
    Q --> T[Generate comprehensive security report]
    T --> U[✅ PR security validation PASSED]
    
    style A fill:#e3f2fd
    style U fill:#c8e6c9
    style R fill:#ffcdd2
    style S fill:#ffcdd2
```

**Key Points:**
- **Trigger**: Pull request to `main` or `develop`
- **No Deployment**: Security analysis only
- **App-Specific**: Each app has its own security workflow
- **Configurable**: Different thresholds per application
- **Blocking**: Failed security scans block PR merge

---

### 2. 🔍 Security Scan Details by Application Type

```mermaid
flowchart LR
    subgraph "Java Applications"
        A1[Java Backend 1/2/3] --> B1[sonar_enabled: true]
        B1 --> C1[Maven-based SonarQube scan]
        C1 --> D1[JaCoCo coverage reports]
        A1 --> E1[Checkmarx security scan]
    end
    
    subgraph "Node.js Applications"  
        A2[Node.js Backend 1/2/3] --> B2[sonar_enabled: false]
        B2 --> C2[Skip SonarQube analysis]
        A2 --> E2[Checkmarx security scan only]
    end
    
    subgraph "Security Thresholds"
        F[Coverage: 75%]
        G[Reliability: A]
        H[Security: A] 
        I[Maintainability: B]
    end
    
    C1 --> F
    C1 --> G
    C1 --> H
    C1 --> I
    
    style C2 fill:#fff3e0
    style C1 fill:#e8f5e8
```

---

## 🎯 Environment Targeting Logic

### Branch-to-Environment Mapping

```mermaid
flowchart TD
    A[Git Event] --> B{Branch Detection}
    
    B -->|refs/heads/main| C[TARGET_ENV = 'sqe']
    B -->|refs/heads/N630-6258_Helm_deploy| D[TARGET_ENV = 'dev']
    B -->|refs/heads/release/*| E[TARGET_ENV = 'prod']
    B -->|refs/tags/*| E
    B -->|Other branches| F[TARGET_ENV = 'unknown']
    
    C --> G{Staging Validation}
    D --> H{Dev Validation}
    E --> I{Production Validation}
    F --> J[❌ Deployment BLOCKED]
    
    G -->|main branch OR manual dispatch| K[✅ Deploy to SQE cluster]
    H -->|develop branch OR manual dispatch| L[✅ Deploy to Dev cluster]
    I -->|release/tag OR manual dispatch| M[✅ Deploy to Prod cluster]
    
    G -->|Other branches| J
    H -->|Other branches| J
    I -->|Other branches| J
    
    style J fill:#ffcdd2
    style K fill:#c8e6c9
    style L fill:#c8e6c9
    style M fill:#c8e6c9
```

---

## 🔄 Complete Pipeline Dependencies

```mermaid
flowchart TD
    A[validate-environment] --> B{should_deploy == true?}
    B -->|false| Z[❌ Pipeline STOPPED]
    B -->|true| C[setup]
    
    C --> D{Changes detected OR force_deploy?}
    D -->|false| Z
    D -->|true| E[maven-build]
    
    E --> F[sonar-scan]
    E --> G[checkmarx-scan]
    
    F --> H{Scan Results}
    G --> H
    
    H -->|Both PASSED| I[build]
    H -->|Any FAILED| Y[❌ Security Gate BLOCKED]
    
    I --> J[deploy]
    J --> K{Environment Type}
    
    K -->|production + release branch| L[create_release]
    K -->|other| M[health-check]
    
    L --> M
    M --> N[✅ Deployment SUCCESS]
    
    style Z fill:#fff3e0
    style Y fill:#ffcdd2
    style N fill:#c8e6c9
```

**Note**: Monitoring deployments are now handled separately via `monitoring-deploy.yml` and only trigger when monitoring configurations change.

**Job Dependencies:**
1. **validate-environment** ← Always runs first
2. **setup** ← Requires: validate-environment success
3. **maven-build** ← Requires: setup success + changes detected
4. **sonar-scan + checkmarx-scan** ← Requires: maven-build success (parallel)
5. **build** ← Requires: ALL security scans PASSED
6. **deploy** ← Requires: build success
7. **create_release** ← Requires: deploy success + production environment
8. **health-check** ← Requires: deploy success

---

## 📊 Monitoring Stack Deployment Flow

### Dedicated Monitoring Workflow

```mermaid
flowchart TD
    A[Monitoring config changes] --> B[monitoring-deploy.yml triggers]
    B --> C[detect-changes job]
    
    C --> D{Changes detected?}
    D -->|No| E[no-changes-notification]
    D -->|Yes| F{Determine deployment strategy}
    
    F --> G{Branch/Manual input}
    
    G -->|develop branch| H[Deploy to Dev]
    G -->|main branch| I[Deploy to Staging]
    G -->|release branch| J[Deploy to Production]
    G -->|manual 'all'| K[Deploy to All Environments]
    
    H --> L[deployment-summary]
    I --> L
    J --> L
    K --> M[Deploy to Dev + Staging + Prod]
    M --> L
    
    L --> N[✅ Monitoring deployment SUCCESS]
    E --> O[⏭️ Monitoring deployment SKIPPED]
    
    style D fill:#e3f2fd
    style E fill:#fff3e0
    style N fill:#c8e6c9
    style O fill:#fff3e0
```

**Key Features:**
- **Smart Change Detection**: Only deploys when monitoring configs change
- **Multi-Environment Support**: Can deploy to specific environments or all
- **Manual Override**: Force deployment via workflow_dispatch
- **Comprehensive Reporting**: Summary of all environment deployments
- **Efficient**: No unnecessary deployments, prevents resource waste

**Monitoring Deployment Triggers:**
- **Auto**: Changes to `helm/monitoring/**`, `monitoring/**`, or monitoring workflows
- **Manual**: workflow_dispatch with environment selection (dev/staging/production/all)
- **Branch-based**: develop→dev, main→staging, release→production

---

## 📊 Trigger Events Summary

| Event Type | Branch/Pattern | Workflow Triggered | Target Environment | Security Scans | Release Created |
|------------|----------------|-------------------|-------------------|----------------|-----------------|
| **Push** | `main` | `deploy.yml` | SQE (staging) | ✅ Both | ❌ No |
| **Push** | `develop` | `deploy.yml` | Dev | ✅ Both | ❌ No |
| **Push** | `release/*` | `deploy.yml` | Production | ✅ Both | ✅ Yes |
| **Push** | `feature/*` | ❌ None | ❌ None | ❌ None | ❌ No |
| **PR** | `→ main/develop` | `pr-security-check.yml` | ❌ None | ✅ Both | ❌ No |
| **Manual** | Any branch | `deploy.yml` | User choice | ✅ Both | If prod |
| **PR Review** | Any | `pr-security-check.yml` | ❌ None | ✅ Both | ❌ No |
| **Push** | Monitoring changes | `monitoring-deploy.yml` | Based on branch | ❌ None | ❌ No |
| **Manual** | Monitoring dispatch | `monitoring-deploy.yml` | User choice | ❌ None | ❌ No |

---

## 🏗️ Composite Actions Integration

### Shared Actions Flow

```mermaid
flowchart LR
    subgraph "Build Actions"
        A[maven-build]
        B[docker-build]
    end
    
    subgraph "Security Actions"
        C[sonar-scan]
        D[checkmarx-scan]
    end
    
    subgraph "Deployment Actions"
        E[helm-deploy]
        F[health-check]
    end
    
    subgraph "Utility Actions"
        G[check-changes]
        H[version-strategy]
        I[workspace-cleanup]
    end
    
    J[Deployment Workflow] --> A
    J --> B
    J --> C
    J --> D
    J --> E
    J --> F
    J --> G
    J --> H
    J --> I
    
    K[Security Workflow] --> C
    K --> D
    K --> G
    K --> I
```

**Key Benefits:**
- **Reusability**: Same actions work for both deployment and security workflows
- **Consistency**: Standardized behavior across all applications
- **Maintainability**: Update once, affects all workflows
- **Configurability**: Actions accept parameters for customization

---

## 🔧 Configuration Parameters

### Deployment Workflow Parameters

```yaml
# Caller → Shared Workflow
environment: 'auto' | 'dev' | 'staging' | 'production'
application_name: string
application_type: 'java-springboot' | 'nodejs'
build_context: path
force_deploy: boolean
aks_cluster_name_*: string
aks_resource_group_*: string
```

### Security Workflow Parameters

```yaml
# Caller → Shared Security Workflow
application_name: string
application_type: 'java-springboot' | 'nodejs'
build_context: path
java_version: '21' (default)
node_version: '20' (default)
sonar_enabled: boolean
checkmarx_enabled: boolean
sonar_coverage_threshold: '75' (default)
sonar_*_rating: '1' | '2' (default thresholds)
```

---

## 🚨 Failure Scenarios

### Security Scan Failures

```mermaid
flowchart TD
    A[Security Scan Job] --> B{Scan Results}
    
    B -->|SonarQube FAILED| C[Quality gate violations]
    B -->|Checkmarx FAILED| D[Security vulnerabilities found]
    B -->|Both FAILED| E[Multiple issues detected]
    
    C --> F[❌ Deployment BLOCKED]
    D --> F
    E --> F
    
    F --> G[Developer must fix issues]
    G --> H[Push fixes]
    H --> I[Re-trigger workflow]
    I --> A
    
    style F fill:#ffcdd2
    style G fill:#fff3e0
```

### Environment Validation Failures

```mermaid
flowchart TD
    A[Branch Push] --> B[Environment Auto-Detection]
    B --> C{Supported Branch?}
    
    C -->|feature/* or unknown| D[TARGET_ENV = 'unknown']
    D --> E[❌ SHOULD_DEPLOY = false]
    E --> F[Workflow skipped entirely]
    
    C -->|Supported branch| G[TARGET_ENV detected]
    G --> H{Branch allowed for environment?}
    
    H -->|No| I[❌ Branch not allowed]
    H -->|Yes| J[✅ Deployment proceeds]
    
    style E fill:#ffcdd2
    style F fill:#fff3e0
    style I fill:#ffcdd2
    style J fill:#c8e6c9
```

---

## 📋 Troubleshooting Guide

### Common Issues and Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Feature branch triggers deployment** | Workflow runs but skips | ✅ **Fixed**: Removed from triggers |
| **Security scan fails** | Deployment blocked | Fix code quality/security issues |
| **Wrong environment deployment** | App in wrong cluster | Check branch naming and manual inputs |
| **Missing secrets** | Authentication failures | Verify secrets configuration in repo |
| **Build failures** | Compilation errors | Fix code issues, verify dependencies |

### Debug Commands

```bash
# Check workflow triggers
git log --oneline -10

# Verify branch patterns
git branch -a

# Check workflow status
gh workflow list
gh run list --workflow=deploy.yml
```

---

## 🎯 Best Practices

### For Developers

1. **Branch Strategy**:
   - `feature/*` → Create PR for security scans only
   - `main` → Auto-deploys to staging
   - `release/*` → Auto-deploys to production

2. **Security Requirements**:
   - Ensure all security scans pass before merge
   - Fix quality gate violations promptly
   - Monitor security thresholds

3. **Manual Deployments**:
   - Use manual dispatch for hotfixes
   - Select correct environment
   - Verify deployment health post-deploy

### For DevOps Teams

1. **Workflow Maintenance**:
   - Keep composite actions updated
   - Monitor workflow performance
   - Regular security threshold reviews

2. **Environment Management**:
   - Maintain cluster configurations
   - Update secrets regularly
   - Monitor resource usage

---

## 🔗 Related Documentation

- [Azure Setup Guide](./AZURE_SETUP_GUIDE.md)
- [Deployment Verification Guide](./DEPLOYMENT_VERIFICATION_GUIDE.md)
- [Helm Chart Guide](./HELM_CHART_GUIDE.md)
- [Monitoring Setup Guide](./MONITORING_SETUP_GUIDE.md)
- [Spring Boot Profiles and Secrets](./SPRING_BOOT_PROFILES_AND_SECRETS.md)

---

## 📞 Support

For issues or questions about deployment flows:

1. **Check workflow logs** in GitHub Actions
2. **Review this documentation** for expected behavior
3. **Contact DevOps team** for infrastructure issues
4. **Create issue** in shared-workflows repository

---

*This document is maintained by the DevOps team and updated as workflows evolve.*