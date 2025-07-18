# Azure Key Vault Integration - Complete Guide

## 📋 **Overview**

This guide provides comprehensive step-by-step instructions for implementing Azure Key Vault integration with your Java and Node.js applications in AKS (Azure Kubernetes Service).

## 🎯 **What's Implemented**

### ✅ **Current Implementation Status:**

1. **✅ Helm Chart Integration** - Key Vault configuration in Helm charts
2. **✅ Workload Identity Setup** - Azure Workload Identity for pod-level authentication  
3. **✅ CSI Secret Store Driver** - Automatic secret mounting from Key Vault
4. **✅ GitHub Actions Integration** - Automated Key Vault configuration during deployment
5. **⚠️ Application Code** - Basic setup (needs enhancement for full integration)

## 🏗️ **Architecture Overview**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub        │    │   Azure         │    │   AKS           │
│   Actions       │───▶│   Key Vault     │───▶│   Application   │
│                 │    │                 │    │                 │
│ • Deploy with   │    │ • Stores        │    │ • Mounts        │
│   Tenant ID     │    │   secrets       │    │   secrets as    │
│ • Client ID     │    │ • RBAC access   │    │   files         │
│ • Key Vault     │    │ • Managed by    │    │ • Reads from    │
│   name          │    │   CSI driver    │    │   /mnt/secrets  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### **Security Flow:**
1. **GitHub Actions** authenticates using Managed Identity (no stored credentials)
2. **Helm deployment** injects Key Vault configuration
3. **Azure Workload Identity** provides pod-level authentication
4. **CSI Secrets Store Driver** mounts secrets from Key Vault to pod filesystem
5. **Applications** read secrets from mounted files

## 🔧 **Step-by-Step Implementation**

### **Step 1: Verify Current Helm Configuration**

#### **Java Application Helm Chart:**
```yaml
# helm/java-app/values-production.yaml
azureKeyVault:
  enabled: true
  keyvaultName: "java-app-prod-kv"          # ✅ Configured
  tenantId: ""                              # ✅ Injected by GitHub Actions
  userAssignedIdentityID: ""                # ✅ Injected by GitHub Actions
  mountPath: "/mnt/secrets-store"           # ✅ Configured
  secrets:                                  # ✅ Configured
    - objectName: "db-password"
      objectAlias: "db-password"
    - objectName: "api-key"
      objectAlias: "api-key"
    - objectName: "jwt-secret"
      objectAlias: "jwt-secret"
    - objectName: "redis-password"
      objectAlias: "redis-password"
```

#### **Node.js Application Helm Chart:**
```yaml
# helm/nodejs-app/values-production.yaml
azureKeyVault:
  enabled: true
  keyvaultName: "nodejs-app-prod-kv"        # ✅ Configured
  secrets:                                  # ✅ Configured
    - objectName: "db-connection-string"
    - objectName: "api-key"
    - objectName: "session-secret"
    - objectName: "redis-url"
```

### **Step 2: Configure Azure Key Vault**

#### **2.1 Create Key Vault and Secrets**

```bash
# Set variables
RESOURCE_GROUP="your-resource-group"
KEYVAULT_NAME="java-app-prod-kv"  # or "nodejs-app-prod-kv"
LOCATION="eastus"

# Create Key Vault
az keyvault create \
  --name $KEYVAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --enable-rbac-authorization

# Create secrets for Java app
az keyvault secret set --vault-name $KEYVAULT_NAME --name "db-password" --value "your-secure-db-password"
az keyvault secret set --vault-name $KEYVAULT_NAME --name "api-key" --value "your-api-key"
az keyvault secret set --vault-name $KEYVAULT_NAME --name "jwt-secret" --value "your-jwt-secret"
az keyvault secret set --vault-name $KEYVAULT_NAME --name "redis-password" --value "your-redis-password"

# Create secrets for Node.js app
az keyvault secret set --vault-name "nodejs-app-prod-kv" --name "db-connection-string" --value "your-connection-string"
az keyvault secret set --vault-name "nodejs-app-prod-kv" --name "api-key" --value "your-api-key"
az keyvault secret set --vault-name "nodejs-app-prod-kv" --name "session-secret" --value "your-session-secret"
az keyvault secret set --vault-name "nodejs-app-prod-kv" --name "redis-url" --value "your-redis-url"
```

#### **2.2 Setup Managed Identity and Permissions**

```bash
# Get AKS cluster managed identity
CLUSTER_NAME="your-aks-cluster"
MANAGED_IDENTITY_ID=$(az aks show --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query identity.principalId -o tsv)

# Grant Key Vault access to managed identity
az role assignment create \
  --assignee $MANAGED_IDENTITY_ID \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME"

# Verify access
az role assignment list --assignee $MANAGED_IDENTITY_ID --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME"
```

### **Step 3: Configure GitHub Repository Secrets**

#### **3.1 Get Required IDs**

```bash
# Get Tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "Tenant ID: $TENANT_ID"

# Get Client ID (Managed Identity)
CLIENT_ID=$(az aks show --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query identityProfile.kubeletidentity.clientId -o tsv)
echo "Client ID: $CLIENT_ID"

# Key Vault name
echo "Key Vault Name: $KEYVAULT_NAME"
```

#### **3.2 Add to GitHub Repository Secrets**

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

```yaml
# Required secrets
AZURE_TENANT_ID: "12345678-1234-1234-1234-123456789012"     # From step 3.1
AZURE_CLIENT_ID: "87654321-4321-4321-4321-210987654321"     # From step 3.1
KEYVAULT_NAME: "java-app-prod-kv"                           # Your Key Vault name
AZURE_SUBSCRIPTION_ID: "your-subscription-id"               # Your Azure subscription ID
```

### **Step 4: Enable CSI Secrets Store Driver on AKS**

```bash
# Enable the Azure Key Vault Provider for Secrets Store CSI driver
az aks enable-addons \
  --addons azure-keyvault-secrets-provider \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP

# Verify installation
kubectl get pods -n kube-system | grep secrets-store

# Expected output:
# secrets-store-csi-driver-xxxxx        3/3     Running
# secrets-store-provider-azure-xxxxx    1/1     Running
```

### **Step 5: Verify Helm Templates**

#### **5.1 Check Secret Provider Class** ✅

The `SecretProviderClass` is already configured in both applications:

```yaml
# Generated from helm/java-app/templates/secretproviderclass.yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: java-app-production-keyvault
spec:
  provider: azure
  parameters:
    clientID: "your-client-id"           # ✅ Injected by GitHub Actions
    keyvaultName: "java-app-prod-kv"     # ✅ Configured
    tenantId: "your-tenant-id"           # ✅ Injected by GitHub Actions
    objects: |
      array:
        - objectName: "db-password"       # ✅ Configured
          objectType: secret
        - objectName: "api-key"
          objectType: secret
```

#### **5.2 Check Service Account** ✅

Workload Identity is configured:

```yaml
# Generated from helm/java-app/templates/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: java-app-production
  annotations:
    azure.workload.identity/client-id: "your-client-id"    # ✅ Injected
    azure.workload.identity/tenant-id: "your-tenant-id"    # ✅ Injected
```

#### **5.3 Check Deployment Volume Mounts** ✅

Secrets are mounted to pods:

```yaml
# Generated from helm/java-app/templates/deployment.yaml
spec:
  template:
    spec:
      volumes:
        - name: secrets-store                               # ✅ Configured
          csi:
            driver: secrets-store.csi.k8s.io
            secretProviderClass: java-app-production-keyvault
      containers:
        - name: java-app
          env:
            - name: AZURE_KEYVAULT_SECRETS_PATH             # ✅ Configured
              value: "/mnt/secrets-store"
          volumeMounts:
            - name: secrets-store                           # ✅ Configured
              mountPath: "/mnt/secrets-store"
              readOnly: true
```

### **Step 6: Enhance Application Code**

#### **6.1 Java Application Enhancement**

**Add Key Vault dependency to `pom.xml`:**

```xml
<!-- Add to apps/java-app/pom.xml -->
<dependency>
    <groupId>com.azure.spring</groupId>
    <artifactId>spring-cloud-azure-starter-keyvault-secrets</artifactId>
    <version>5.8.0</version>
</dependency>
```

**Create Secret Service:**

```java
// apps/java-app/src/main/java/com/example/javaapp/service/SecretService.java
package com.example.javaapp.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.io.IOException;

@Service
public class SecretService {

    @Value("${azure.keyvault.secrets.path:/mnt/secrets-store}")
    private String secretsPath;

    public String getSecret(String secretName) {
        try {
            Path secretFile = Paths.get(secretsPath, secretName);
            if (Files.exists(secretFile)) {
                return Files.readString(secretFile).trim();
            } else {
                throw new RuntimeException("Secret not found: " + secretName);
            }
        } catch (IOException e) {
            throw new RuntimeException("Failed to read secret: " + secretName, e);
        }
    }

    public boolean isSecretAvailable(String secretName) {
        Path secretFile = Paths.get(secretsPath, secretName);
        return Files.exists(secretFile);
    }
}
```

**Update Controller:**

```java
// Update apps/java-app/src/main/java/com/example/javaapp/controller/HelloController.java
package com.example.javaapp.controller;

import com.example.javaapp.service.SecretService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.time.LocalDateTime;
import java.util.Map;

@RestController
public class HelloController {

    @Autowired
    private SecretService secretService;

    @GetMapping("/")
    public Map<String, Object> home() {
        return Map.of(
            "message", "Hello World from Java 21!",
            "timestamp", LocalDateTime.now(),
            "java.version", System.getProperty("java.version"),
            "app.version", "1.0.0",
            "keyvault.enabled", secretService.isSecretAvailable("api-key")
        );
    }

    @GetMapping("/secrets/status")
    public Map<String, Object> secretsStatus() {
        return Map.of(
            "db-password", secretService.isSecretAvailable("db-password"),
            "api-key", secretService.isSecretAvailable("api-key"),
            "jwt-secret", secretService.isSecretAvailable("jwt-secret"),
            "redis-password", secretService.isSecretAvailable("redis-password"),
            "secrets-path", "/mnt/secrets-store"
        );
    }

    @GetMapping("/config")
    public Map<String, Object> config() {
        // In production, you would use these secrets for actual configuration
        // This is just a demonstration - NEVER expose actual secret values!
        try {
            return Map.of(
                "database", Map.of(
                    "host", "database.example.com",
                    "port", "5432",
                    "password.configured", secretService.isSecretAvailable("db-password")
                ),
                "api", Map.of(
                    "key.configured", secretService.isSecretAvailable("api-key")
                ),
                "jwt", Map.of(
                    "secret.configured", secretService.isSecretAvailable("jwt-secret")
                ),
                "redis", Map.of(
                    "password.configured", secretService.isSecretAvailable("redis-password")
                )
            );
        } catch (Exception e) {
            return Map.of("error", "Failed to check secret configuration: " + e.getMessage());
        }
    }
}
```

**Update Application Properties:**

```properties
# Add to apps/java-app/src/main/resources/application.properties
# Azure Key Vault Configuration
azure.keyvault.secrets.path=${AZURE_KEYVAULT_SECRETS_PATH:/mnt/secrets-store}

# Spring Cloud Azure Key Vault (alternative approach)
spring.cloud.azure.keyvault.secret.enabled=${SPRING_CLOUD_AZURE_KEYVAULT_SECRET_ENABLED:false}
spring.cloud.azure.keyvault.secret.property-sources[0].endpoint=${SPRING_CLOUD_AZURE_KEYVAULT_ENDPOINT:}
spring.cloud.azure.keyvault.secret.property-sources[0].name=${SPRING_CLOUD_AZURE_KEYVAULT_NAME:}
```

#### **6.2 Node.js Application Enhancement**

**Create Secrets Manager:**

```javascript
// apps/nodejs-app/src/services/secretsManager.js
const fs = require('fs').promises;
const path = require('path');

class SecretsManager {
    constructor() {
        this.secretsPath = process.env.AZURE_KEYVAULT_SECRETS_PATH || '/mnt/secrets-store';
    }

    async getSecret(secretName) {
        try {
            const secretFile = path.join(this.secretsPath, secretName);
            const secret = await fs.readFile(secretFile, 'utf8');
            return secret.trim();
        } catch (error) {
            throw new Error(`Failed to read secret ${secretName}: ${error.message}`);
        }
    }

    async isSecretAvailable(secretName) {
        try {
            const secretFile = path.join(this.secretsPath, secretName);
            await fs.access(secretFile);
            return true;
        } catch {
            return false;
        }
    }

    async getAllSecretsStatus() {
        const secrets = ['db-connection-string', 'api-key', 'session-secret', 'redis-url'];
        const status = {};
        
        for (const secret of secrets) {
            status[secret] = await this.isSecretAvailable(secret);
        }
        
        return status;
    }
}

module.exports = new SecretsManager();
```

**Update App Configuration:**

```javascript
// apps/nodejs-app/src/app.js
const express = require('express');
const secretsManager = require('./services/secretsManager');

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

// Basic routes
app.get('/', (req, res) => {
    res.json({
        message: 'Hello World from Node.js!',
        timestamp: new Date().toISOString(),
        node_version: process.version,
        app_version: '1.0.0'
    });
});

// Secrets status endpoint
app.get('/secrets/status', async (req, res) => {
    try {
        const status = await secretsManager.getAllSecretsStatus();
        res.json({
            secrets: status,
            secretsPath: process.env.AZURE_KEYVAULT_SECRETS_PATH || '/mnt/secrets-store'
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Configuration endpoint (demonstrates secret usage)
app.get('/config', async (req, res) => {
    try {
        res.json({
            database: {
                connectionString: await secretsManager.isSecretAvailable('db-connection-string') ? 'configured' : 'missing'
            },
            api: {
                key: await secretsManager.isSecretAvailable('api-key') ? 'configured' : 'missing'
            },
            session: {
                secret: await secretsManager.isSecretAvailable('session-secret') ? 'configured' : 'missing'
            },
            redis: {
                url: await secretsManager.isSecretAvailable('redis-url') ? 'configured' : 'missing'
            }
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.listen(port, () => {
    console.log(`Node.js app listening at http://localhost:${port}`);
});

module.exports = app;
```

### **Step 7: Deploy and Test**

#### **7.1 Deploy Application**

```bash
# Push your enhanced application code
git add .
git commit -m "feat: Add Azure Key Vault integration to applications"
git push origin main

# Deploy using your existing GitHub Actions workflow
# The workflow will automatically inject Key Vault configuration
```

#### **7.2 Verify Deployment**

```bash
# Check if secrets are mounted
kubectl exec -it deployment/java-app-production -- ls -la /mnt/secrets-store

# Expected output:
# drwxrwxrwt 3 root root   140 Nov 20 10:30 .
# drwxr-xr-x 1 root root  4096 Nov 20 10:30 ..
# -rw-r--r-- 1 root root    20 Nov 20 10:30 api-key
# -rw-r--r-- 1 root root    25 Nov 20 10:30 db-password
# -rw-r--r-- 1 root root    32 Nov 20 10:30 jwt-secret
# -rw-r--r-- 1 root root    18 Nov 20 10:30 redis-password

# Test secret content (be careful with this in production!)
kubectl exec -it deployment/java-app-production -- cat /mnt/secrets-store/api-key
```

#### **7.3 Test Application Endpoints**

```bash
# Get service URL
kubectl get service java-app-production

# Test endpoints (replace with your actual service URL)
curl http://java-app-production.default.svc.cluster.local:8080/secrets/status
curl http://java-app-production.default.svc.cluster.local:8080/config

# Expected response:
{
  "db-password": true,
  "api-key": true,
  "jwt-secret": true,
  "redis-password": true,
  "secrets-path": "/mnt/secrets-store"
}
```

## 🚨 **Troubleshooting Guide**

### **Issue 1: Secrets not mounting**

```bash
# Check CSI driver pods
kubectl get pods -n kube-system | grep secrets-store

# Check SecretProviderClass
kubectl describe secretproviderclass java-app-production-keyvault

# Check pod events
kubectl describe pod -l app=java-app-production
```

### **Issue 2: Authentication failures**

```bash
# Verify managed identity permissions
az role assignment list --assignee $CLIENT_ID

# Check Key Vault access policies
az keyvault show --name $KEYVAULT_NAME --query properties.accessPolicies

# Test Key Vault access
az keyvault secret show --vault-name $KEYVAULT_NAME --name api-key
```

### **Issue 3: Application can't read secrets**

```bash
# Check file permissions
kubectl exec -it deployment/java-app-production -- ls -la /mnt/secrets-store

# Check environment variables
kubectl exec -it deployment/java-app-production -- env | grep AZURE

# Check application logs
kubectl logs deployment/java-app-production
```

## ✅ **Security Best Practices**

1. **✅ Use RBAC** instead of Key Vault access policies
2. **✅ Implement least privilege** - only grant required permissions
3. **✅ Use Workload Identity** instead of pod identity
4. **✅ Rotate secrets regularly** in Key Vault
5. **✅ Monitor access** with Azure Monitor
6. **✅ Never log secret values** in application logs
7. **✅ Use separate Key Vaults** for different environments

## 📊 **Integration Status Summary**

| Component | Status | Notes |
|-----------|--------|-------|
| **Helm Charts** | ✅ **Complete** | Key Vault configuration ready |
| **CSI Driver Config** | ✅ **Complete** | SecretProviderClass templates |
| **Workload Identity** | ✅ **Complete** | Service account annotations |
| **GitHub Actions** | ✅ **Complete** | Automated injection of IDs |
| **Volume Mounts** | ✅ **Complete** | Secrets mounted to `/mnt/secrets-store` |
| **Java App Code** | ⚠️ **Needs Enhancement** | Basic setup, requires SecretService |
| **Node.js App Code** | ⚠️ **Needs Enhancement** | Basic setup, requires SecretsManager |
| **Environment Variables** | ✅ **Complete** | `AZURE_KEYVAULT_SECRETS_PATH` configured |

## 🎯 **Next Steps**

1. **✅ Infrastructure is ready** - Key Vault integration is fully configured in Helm charts
2. **⚠️ Enhance application code** - Implement the SecretService/SecretsManager classes
3. **✅ Configure GitHub secrets** - Add required Azure IDs to repository
4. **✅ Deploy and test** - Use existing workflows to deploy enhanced applications
5. **✅ Monitor and maintain** - Set up Azure Monitor for Key Vault access

The foundation is solid - you just need to enhance the application code to utilize the mounted secrets! 🚀