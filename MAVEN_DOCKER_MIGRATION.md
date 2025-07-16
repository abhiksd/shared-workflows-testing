# Maven Build Migration: From Dockerfile to GitHub Actions

## Overview
This migration moves the Maven build process from the Dockerfile to GitHub Actions composite actions, resulting in improved build performance, better security, and more maintainable CI/CD pipelines.

## Changes Made

### 1. New Maven Build Action
- **Location**: `.github/actions/maven-build/action.yml`
- **Purpose**: Handles Java/Maven builds with caching, security scanning, and artifact management
- **Features**:
  - Maven dependency caching for faster builds
  - Security vulnerability scanning with OWASP dependency check
  - Configurable test execution
  - Automatic artifact upload
  - Build summary reporting

### 2. Updated Dockerfile
- **Location**: `apps/java-app/Dockerfile`
- **Changes**:
  - Removed multi-stage build (no longer building from source)
  - Now only copies pre-built JAR files
  - Enhanced security features:
    - Added health checks using Spring Boot Actuator
    - Improved JVM configuration for containers
    - Added signal handling with dumb-init
    - Security updates and hardening
  - Smaller final image size (JRE only, no build tools)

### 3. Updated Workflow
- **Location**: `.github/workflows/shared-deploy.yml`
- **Changes**:
  - Added `maven-build` job before Docker build
  - Downloads Maven artifacts before Docker build
  - Improved job dependencies and error handling
  - Conditional execution based on application type

### 4. Enhanced Docker Build Action
- **Location**: `.github/actions/docker-build-push/action.yml`
- **Changes**:
  - Added preparation step for Java applications
  - Validates JAR files are present before Docker build
  - Better error reporting and diagnostics

### 5. Optimized .dockerignore
- **Location**: `apps/java-app/.dockerignore`
- **Changes**:
  - Excludes source code (not needed for runtime image)
  - Allows only JAR files to be copied
  - Improved security by excluding sensitive files

## Benefits

### Performance Improvements
- **Faster CI/CD**: Maven dependencies are cached across builds
- **Parallel Execution**: Maven build and other CI steps can run in parallel
- **Smaller Images**: Runtime images only contain JRE and application JAR
- **Layer Optimization**: Better Docker layer caching

### Security Enhancements
- **Vulnerability Scanning**: Automated dependency security checks
- **Minimal Attack Surface**: Runtime images don't contain build tools
- **Security Hardening**: Enhanced container security configurations
- **Health Monitoring**: Built-in health checks

### Maintainability
- **Separation of Concerns**: Build logic separated from runtime configuration
- **Reusable Components**: Maven build action can be used across multiple projects
- **Better Debugging**: Clearer separation between build and deployment failures
- **Artifact Management**: Centralized artifact handling

## Usage

### For Java Spring Boot Applications
The migration is automatic for applications with `application_type: java-springboot`. The workflow will:

1. Run Maven build in the `maven-build` job
2. Upload JAR artifacts
3. Download artifacts in the `build` job
4. Build and push Docker image with pre-built JAR

### Configuration Options
The Maven build action supports several configuration options:

```yaml
- name: Build Java application with Maven
  uses: ./.github/actions/maven-build
  with:
    application_name: 'my-app'
    build_context: 'apps/my-app'
    java_version: '21'           # Default: '21'
    run_tests: 'true'            # Default: 'false'
    maven_args: '-DskipTests'    # Default: '-DskipTests'
    upload_artifacts: 'true'     # Default: 'true'
```

### Health Checks
The new Dockerfile includes health checks using Spring Boot Actuator:
- **Endpoint**: `http://localhost:8080/actuator/health`
- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Start Period**: 60 seconds
- **Retries**: 3

Ensure your Spring Boot application has the `spring-boot-starter-actuator` dependency.

## Migration Verification

### Build Logs
Check the GitHub Actions logs for:
- Maven build success in the `maven-build` job
- JAR file verification before Docker build
- Successful artifact download in the `build` job

### Docker Image
Verify the final Docker image:
```bash
# Check image size (should be smaller)
docker images | grep your-app

# Verify health check is working
docker run -d -p 8080:8080 your-app:latest
curl http://localhost:8080/actuator/health
```

### Security Scan Reports
- OWASP dependency check reports are uploaded as artifacts
- Review security scan results in the Actions tab

## Troubleshooting

### Common Issues
1. **JAR not found**: Ensure Maven build completed successfully and artifacts were uploaded
2. **Health check failures**: Verify Spring Boot Actuator is configured and accessible
3. **Permission issues**: Check that the non-root user has proper permissions

### Debug Steps
1. Check Maven build job logs for compilation errors
2. Verify artifact upload/download steps
3. Check Docker build context preparation logs
4. Review health check configuration in application.properties

## Next Steps
- Consider adding integration tests to the Maven build
- Implement advanced security scanning with additional tools
- Add performance monitoring and metrics collection
- Explore multi-architecture builds for ARM64 support