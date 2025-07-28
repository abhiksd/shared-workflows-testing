#!/bin/bash

# Setup script for new Spring Boot application
set -e

APP_NAME=$1
if [ -z "$APP_NAME" ]; then
    echo "Usage: $0 <app-name>"
    echo "Example: $0 my-spring-app"
    exit 1
fi

echo "🚀 Setting up new Spring Boot application: $APP_NAME"

# Create directory structure
mkdir -p "apps/$APP_NAME"
cd "apps/$APP_NAME"

# Copy Helm chart template
echo "📦 Copying Helm chart template..."
cp -r ../../helm-migrations/templates/helm-chart-template helm

# Copy Spring Boot configs
echo "⚙️ Copying Spring Boot configuration templates..."
mkdir -p src/main/resources
cp ../../helm-migrations/templates/spring-boot-configs/* src/main/resources/

# Customize Chart.yaml
echo "🔧 Customizing Chart.yaml..."
sed -i "s/app-template/$APP_NAME/g" helm/Chart.yaml
sed -i "s/A Helm chart template/Helm chart for $APP_NAME/g" helm/Chart.yaml

# Customize values.yaml
echo "🔧 Customizing values.yaml..."
sed -i "s/your-app-name/$APP_NAME/g" helm/values.yaml
sed -i "s/your-app.local/$APP_NAME.local/g" helm/values.yaml

# Customize values files
for env in dev sqe production; do
    sed -i "s/your-app-name/$APP_NAME/g" "helm/values-$env.yaml"
done

# Customize _helpers.tpl
sed -i "s/app-template/$APP_NAME/g" helm/templates/_helpers.tpl

# Update Spring Boot configs
sed -i "s/your-app-name/$APP_NAME/g" src/main/resources/application*.yml

# Create basic pom.xml
echo "📄 Creating basic pom.xml..."
cat > pom.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
        <relativePath/>
    </parent>

    <groupId>com.company</groupId>
    <artifactId>$APP_NAME</artifactId>
    <version>1.0.0</version>
    <name>$APP_NAME</name>
    <description>Spring Boot application: $APP_NAME</description>

    <properties>
        <java.version>17</java.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>runtime</scope>
        </dependency>
        
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <scope>runtime</scope>
        </dependency>
        
        <dependency>
            <groupId>io.micrometer</groupId>
            <artifactId>micrometer-registry-prometheus</artifactId>
        </dependency>
        
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
EOF

# Create basic Dockerfile
echo "🐳 Creating Dockerfile..."
cat > Dockerfile << EOF
FROM openjdk:17-jre-slim

# Set working directory
WORKDIR /app

# Copy the jar file
COPY target/$APP_NAME-1.0.0.jar app.jar

# Expose port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF

# Create basic Java application structure
echo "☕ Creating basic Java application structure..."
mkdir -p src/main/java/com/company/$(echo $APP_NAME | tr '-' '_')
mkdir -p src/test/java/com/company/$(echo $APP_NAME | tr '-' '_')

# Create main application class
JAVA_PACKAGE=$(echo $APP_NAME | tr '-' '_')
JAVA_CLASS=$(echo $APP_NAME | sed 's/-//g' | sed 's/\b\w/\U&/g')

cat > "src/main/java/com/company/$JAVA_PACKAGE/${JAVA_CLASS}Application.java" << EOF
package com.company.$JAVA_PACKAGE;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class ${JAVA_CLASS}Application {

    public static void main(String[] args) {
        SpringApplication.run(${JAVA_CLASS}Application.class, args);
    }
}
EOF

# Create basic controller
cat > "src/main/java/com/company/$JAVA_PACKAGE/controller/HealthController.java" << EOF
package com.company.$JAVA_PACKAGE.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api")
public class HealthController {

    @GetMapping("/status")
    public ResponseEntity<Map<String, String>> status() {
        return ResponseEntity.ok(Map.of(
            "status", "UP",
            "application", "$APP_NAME",
            "version", "1.0.0"
        ));
    }
}
EOF

# Create deployment workflow
echo "🔄 Creating deployment workflow..."
mkdir -p ../../.github/workflows

cat > "../../.github/workflows/deploy-$APP_NAME.yml" << EOF
name: Deploy $APP_NAME

on:
  push:
    branches:
      - main
      - develop
    paths:
      - 'apps/$APP_NAME/**'
      - '.github/workflows/deploy-$APP_NAME.yml'
  
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - sqe
          - production

jobs:
  deploy-dev:
    if: github.ref == 'refs/heads/develop' || (github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'dev')
    uses: ./.github/workflows/shared-deploy.yml
    with:
      environment: dev
      application_name: $APP_NAME
      application_type: java-springboot
      build_context: apps/$APP_NAME
      helm_chart_path: apps/$APP_NAME/helm
    secrets: inherit

  deploy-sqe:
    if: github.ref == 'refs/heads/main' || (github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'sqe')
    uses: ./.github/workflows/shared-deploy.yml
    with:
      environment: sqe
      application_name: $APP_NAME
      application_type: java-springboot
      build_context: apps/$APP_NAME
      helm_chart_path: apps/$APP_NAME/helm
    secrets: inherit

  deploy-production:
    if: github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'production'
    uses: ./.github/workflows/shared-deploy.yml
    with:
      environment: production
      application_name: $APP_NAME
      application_type: java-springboot
      build_context: apps/$APP_NAME
      helm_chart_path: apps/$APP_NAME/helm
    secrets: inherit
EOF

echo "✅ Setup complete!"
echo ""
echo "📂 Created structure:"
echo "  - apps/$APP_NAME/helm/ (Helm chart)"
echo "  - apps/$APP_NAME/src/ (Java source code)"
echo "  - apps/$APP_NAME/pom.xml (Maven configuration)"
echo "  - apps/$APP_NAME/Dockerfile (Container image)"
echo "  - .github/workflows/deploy-$APP_NAME.yml (CI/CD workflow)"
echo ""
echo "🎯 Next steps:"
echo "1. Update package names in Java files and Spring Boot configs"
echo "2. Customize database configuration for your needs"
echo "3. Update CORS origins and domain names"
echo "4. Test locally: cd apps/$APP_NAME && mvn spring-boot:run"
echo "5. Test Helm chart: helm lint apps/$APP_NAME/helm"
echo "6. Build and deploy: git add . && git commit -m 'Add $APP_NAME application'"
echo ""
echo "🔧 Configuration files to customize:"
echo "  - src/main/resources/application*.yml (Spring Boot configs)"
echo "  - helm/values*.yaml (Helm values)"
echo "  - pom.xml (dependencies and build configuration)"