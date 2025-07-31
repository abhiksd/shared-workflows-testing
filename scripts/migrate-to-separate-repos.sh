#!/bin/bash

# Migration Script: Split Monorepo into Separate Repositories
# This script helps migrate each backend service to its own repository

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ORG_NAME="${1:-your-org}"
SHARED_WORKFLOWS_REPO="${2:-shared-workflows}"

# Backend services configuration
declare -A BACKENDS=(
    ["java-backend1"]="java-backend1-user-management:User Management Service:java-springboot"
    ["nodejs-backend1"]="nodejs-backend1-notification:Notification Service:nodejs"
)

print_header() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}  🚀 Microservices Repository Migration Tool${NC}"
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
    
    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed. Please install it first."
        echo "Install: https://cli.github.com/"
        exit 1
    fi
    
    # Check if user is authenticated
    if ! gh auth status &> /dev/null; then
        print_error "Please authenticate with GitHub CLI first:"
        echo "Run: gh auth login"
        exit 1
    fi
    
    # Check if we're in the correct directory
    if [[ ! -d "apps" ]] || [[ ! -d ".github/workflows" ]]; then
        print_error "Please run this script from the root of the shared-workflows-be repository"
        exit 1
    fi
    
    print_step "Prerequisites check passed!"
}

create_shared_workflows_repo() {
    print_step "Creating shared workflows repository..."
    
    local repo_name="${ORG_NAME}/${SHARED_WORKFLOWS_REPO}"
    
    # Check if repository already exists
    if gh repo view "$repo_name" &> /dev/null; then
        print_warning "Repository $repo_name already exists. Skipping creation."
        return 0
    fi
    
    # Create repository
    gh repo create "$repo_name" --public --description "Centralized GitHub Actions workflows for microservices"
    
    # Clone and setup
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    gh repo clone "$repo_name"
    cd "$SHARED_WORKFLOWS_REPO"
    
    # Copy shared infrastructure
    mkdir -p .github/workflows
    cp "$OLDPWD"/.github/workflows/shared-deploy.yml .github/workflows/
    cp "$OLDPWD"/.github/workflows/rollback-deployment.yml .github/workflows/
    cp "$OLDPWD"/.github/workflows/pr-security-check.yml .github/workflows/
    cp "$OLDPWD"/.github/workflows/deploy-monitoring.yml .github/workflows/
    
    # Create README
    cat > README.md << 'EOF'
# Shared GitHub Actions Workflows

This repository contains reusable GitHub Actions workflows for all microservices.

## Available Workflows

### shared-deploy.yml
- Handles Java Spring Boot and Node.js deployments
- Supports multiple environments (dev, staging, production)
- Integrates with Azure Container Registry and AKS

### rollback-deployment.yml
- Provides rollback capabilities for failed deployments
- Supports Helm-based rollbacks

### deploy-monitoring.yml
- Deploys monitoring stack (Prometheus, Grafana)
- Configures alerting and service discovery

### pr-security-check.yml
- Automated security scanning for pull requests
- Vulnerability detection and compliance checks

## Usage

Reference these workflows from your service repositories:

```yaml
jobs:
  deploy:
    uses: your-org/shared-workflows/.github/workflows/shared-deploy.yml@main
    with:
      application_name: your-service-name
      application_type: java-springboot # or nodejs
      build_context: .
      dockerfile_path: ./Dockerfile
      helm_chart_path: ./helm
```

## Maintenance

This repository is centrally maintained by the DevOps team. 
All microservices reference these workflows for consistent deployment patterns.
EOF
    
    # Commit and push
    git add .
    git commit -m "Initial shared workflows setup

- Added reusable deployment workflows
- Added rollback and monitoring workflows
- Added security scanning workflow
- Comprehensive documentation"
    git push origin main
    
    cd "$OLDPWD"
    rm -rf "$temp_dir"
    
    print_step "✅ Shared workflows repository created: $repo_name"
}

migrate_backend() {
    local backend_dir="$1"
    local repo_info="$2"
    
    IFS=':' read -r repo_name service_name app_type <<< "$repo_info"
    local full_repo_name="${ORG_NAME}/${repo_name}"
    
    print_step "Migrating $backend_dir to $full_repo_name..."
    
    # Check if repository already exists
    if gh repo view "$full_repo_name" &> /dev/null; then
        print_warning "Repository $full_repo_name already exists. Skipping migration."
        return 0
    fi
    
    # Create repository
    gh repo create "$full_repo_name" --public --description "$service_name microservice"
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Clone new repository
    gh repo clone "$full_repo_name"
    cd "$repo_name"
    
    # Copy all files from backend
    cp -r "$OLDPWD/apps/$backend_dir"/* .
    
    # Update workflow to use external shared workflow
    sed -i "s|uses: \\./\\.github/workflows/shared-deploy\\.yml|uses: ${ORG_NAME}/${SHARED_WORKFLOWS_REPO}/.github/workflows/shared-deploy.yml@main|g" .github/workflows/deploy.yml
    
    # Update build context paths (since we're now at repo root)
    sed -i "s|build_context: apps/$backend_dir|build_context: .|g" .github/workflows/deploy.yml
    sed -i "s|dockerfile_path: apps/$backend_dir/Dockerfile|dockerfile_path: ./Dockerfile|g" .github/workflows/deploy.yml
    sed -i 's|helm_chart_path: helm|helm_chart_path: ./helm|g' .github/workflows/deploy.yml
    
    # Update path triggers (since we're now at repo root)
    sed -i "s|apps/$backend_dir/\\*\\*|**|g" .github/workflows/deploy.yml
    
    # Create repository-specific README
    create_service_readme "$service_name" "$app_type" "$backend_dir"
    
    # Update deployment documentation paths
    sed -i 's|apps/[^/]*/||g' DEPLOYMENT.md
    sed -i 's|Navigate to specific backend[^$]*|Deploy from repository root|g' DEPLOYMENT.md
    
    # Commit and push
    git add .
    git commit -m "Initial commit: $service_name

- Complete $app_type application with REST APIs
- Kubernetes Helm charts for deployment  
- GitHub Actions workflow for CI/CD
- Comprehensive deployment documentation
- Ready for independent development and deployment"
    git push origin main
    
    cd "$OLDPWD"
    rm -rf "$temp_dir"
    
    print_step "✅ Successfully migrated $backend_dir to $full_repo_name"
}

create_service_readme() {
    local service_name="$1"
    local app_type="$2"
    local backend_dir="$3"
    
    if [[ $app_type == "java-springboot" ]]; then
        create_java_readme "$service_name" "$backend_dir"
    else
        create_nodejs_readme "$service_name" "$backend_dir"
    fi
}

create_java_readme() {
    local service_name="$1"
    local backend_dir="$2"
    
    cat > README.md << EOF
# $service_name

A Spring Boot microservice for $service_name functionality.

## 🚀 Quick Start

### Local Development
\`\`\`bash
# Build and run
mvn clean spring-boot:run

# Or with Docker
docker build -t $backend_dir .
docker run -p 8080:8080 $backend_dir
\`\`\`

### Deployment
See [DEPLOYMENT.md](./DEPLOYMENT.md) for comprehensive deployment instructions.

## 🏗️ Architecture

- **Framework**: Spring Boot 3.x
- **Java Version**: 17
- **Build Tool**: Maven
- **Database**: PostgreSQL (configurable)
- **Monitoring**: Prometheus + Grafana
- **Deployment**: Kubernetes with Helm

## 📊 Health Checks

- Health: \`/actuator/health\`
- Metrics: \`/actuator/prometheus\`
- API Status: \`/api/status\`

## 🔗 API Endpoints

See the service-specific API documentation in the source code.

## 🛠️ Development

### Prerequisites
- Java 17+
- Maven 3.6+
- Docker (for containerized development)

### Build
\`\`\`bash
mvn clean package
\`\`\`

### Test
\`\`\`bash
mvn test
\`\`\`

### Docker Build
\`\`\`bash
docker build -t $backend_dir:latest .
\`\`\`

## 🚀 Deployment

This service uses centralized GitHub Actions workflows for deployment:

\`\`\`bash
# Manual deployment
gh workflow run deploy.yml -f environment=dev

# Automatic deployment on push to main/develop branches
git push origin main
\`\`\`

## 📊 Monitoring

- **Metrics**: Exposed via Spring Boot Actuator
- **Health Checks**: Kubernetes liveness and readiness probes
- **Logging**: Structured logging with logback
- **Tracing**: Distributed tracing support

---

**Service**: $service_name  
**Type**: Java Spring Boot Microservice  
**Deployment**: GitHub Actions + Kubernetes + Helm
EOF
}

create_nodejs_readme() {
    local service_name="$1"
    local backend_dir="$2"
    
    cat > README.md << EOF
# $service_name

A Node.js Express microservice for $service_name functionality.

## 🚀 Quick Start

### Local Development
\`\`\`bash
# Install dependencies
npm install

# Start development server
npm run dev

# Or with Docker
docker build -t $backend_dir .
docker run -p 3000:3000 $backend_dir
\`\`\`

### Deployment
See [DEPLOYMENT.md](./DEPLOYMENT.md) for comprehensive deployment instructions.

## 🏗️ Architecture

- **Framework**: Express.js
- **Node.js Version**: 18+ LTS
- **Package Manager**: npm
- **Database**: MongoDB/PostgreSQL (configurable)
- **Monitoring**: Prometheus + Grafana
- **Deployment**: Kubernetes with Helm

## 📊 Health Checks

- Health: \`/health\`
- Metrics: \`/metrics\`
- API Status: \`/api/status\`

## 🔗 API Endpoints

See the service-specific API documentation in the source code.

## 🛠️ Development

### Prerequisites
- Node.js 18+ LTS
- npm 8+
- Docker (for containerized development)

### Install Dependencies
\`\`\`bash
npm install
\`\`\`

### Start Development Server
\`\`\`bash
npm run dev
\`\`\`

### Run Tests
\`\`\`bash
npm test
\`\`\`

### Docker Build
\`\`\`bash
docker build -t $backend_dir:latest .
\`\`\`

## 🚀 Deployment

This service uses centralized GitHub Actions workflows for deployment:

\`\`\`bash
# Manual deployment
gh workflow run deploy.yml -f environment=dev

# Automatic deployment on push to main/develop branches
git push origin main
\`\`\`

## 📊 Monitoring

- **Metrics**: Custom Prometheus metrics
- **Health Checks**: Kubernetes liveness and readiness probes
- **Logging**: Structured logging with Winston
- **Performance**: Application performance monitoring

---

**Service**: $service_name  
**Type**: Node.js Express Microservice  
**Deployment**: GitHub Actions + Kubernetes + Helm
EOF
}

print_summary() {
    echo ""
    echo -e "${GREEN}🎉 Migration Complete!${NC}"
    echo ""
    echo -e "${BLUE}Created Repositories:${NC}"
    echo -e "📦 ${ORG_NAME}/${SHARED_WORKFLOWS_REPO} - Centralized workflows"
    
    for backend_dir in "${!BACKENDS[@]}"; do
        IFS=':' read -r repo_name service_name app_type <<< "${BACKENDS[$backend_dir]}"
        echo -e "📦 ${ORG_NAME}/${repo_name} - ${service_name}"
    done
    
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. 🔐 Configure repository secrets for each service repository"
    echo "2. 🛠️ Set up Azure infrastructure (AKS, ACR)"
    echo "3. 🚀 Test deployments for each service independently"
    echo "4. 👥 Set up team access permissions for each repository"
    echo "5. 📊 Configure monitoring and alerting"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "- Each service has comprehensive DEPLOYMENT.md"
    echo "- Shared workflows documentation in ${SHARED_WORKFLOWS_REPO}/README.md"
    echo "- Original migration guide: REPOSITORY_MIGRATION_GUIDE.md"
}

# Main execution
main() {
    print_header
    
    if [[ $# -lt 1 ]]; then
        print_warning "Usage: $0 <org-name> [shared-workflows-repo-name]"
        print_warning "Example: $0 my-company shared-workflows"
        echo ""
        echo "This will create repositories like:"
        echo "  - my-company/shared-workflows"
        echo "  - my-company/java-backend1-user-management"
        echo "  - my-company/nodejs-backend1-notification"
        echo ""
        exit 1
    fi
    
    check_prerequisites
    
    print_step "Starting migration for organization: $ORG_NAME"
    print_step "Shared workflows repository: ${ORG_NAME}/${SHARED_WORKFLOWS_REPO}"
    echo ""
    
    # Create shared workflows repository
    create_shared_workflows_repo
    echo ""
    
    # Migrate each backend
    for backend_dir in "${!BACKENDS[@]}"; do
        migrate_backend "$backend_dir" "${BACKENDS[$backend_dir]}"
        echo ""
    done
    
    print_summary
}

# Run main function with all arguments
main "$@"