# Helm Chart Migration Templates

This directory contains templates and documentation for migrating Spring Boot applications to use standardized Helm charts.

## 🎯 Purpose

Provides reusable Helm chart templates and Spring Boot configuration templates that can be easily adapted for any Java Spring Boot application.

## 📁 Structure

- **templates/**: Reusable templates for Helm charts and Spring Boot configs
- **examples/**: Complete example implementations
- **docs/**: Detailed documentation and guides
- **scripts/**: Helper scripts for setup and deployment

## 🚀 Quick Start

1. Copy the `helm-chart-template` to your application directory
2. Customize the values according to your application
3. Update Spring Boot configuration files
4. Test and deploy

See `docs/migration-guide.md` for detailed instructions.

## 📚 Documentation

- [Migration Guide](docs/migration-guide.md) - Complete step-by-step guide
- [Helm Best Practices](docs/helm-best-practices.md) - Recommended practices
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

## 🛠️ Scripts

- `scripts/setup-new-app.sh` - Automated setup for new applications
- `scripts/fix-helm-templates.sh` - Fix template references in existing charts
- `scripts/validate-chart.sh` - Validation and testing
- `scripts/deploy-helper.sh` - Deployment utilities

## 📋 Template Usage

### For New Applications

```bash
# Use the automated setup script
./helm-migrations/scripts/setup-new-app.sh my-new-app

# Or manually copy templates
cp -r helm-migrations/templates/helm-chart-template apps/my-new-app/helm
cp helm-migrations/templates/spring-boot-configs/* apps/my-new-app/src/main/resources/
```

### Customization Required

1. **Application Name**: Replace `your-app-name` throughout
2. **Package Names**: Update Java package references
3. **Database Config**: Configure for your database type
4. **Domain Names**: Update ingress hosts and CORS origins
5. **Resources**: Adjust CPU/memory limits for your needs

## 🔄 Migration from Existing Charts

If migrating from an existing chart, see the detailed migration guide in `docs/migration-guide.md`.

## ✅ Validation

```bash
# Validate your customized chart
helm lint apps/your-app/helm

# Test template rendering
helm template test apps/your-app/helm --values apps/your-app/helm/values-dev.yaml

# Dry run deployment
helm install test apps/your-app/helm --values apps/your-app/helm/values-dev.yaml --dry-run
```