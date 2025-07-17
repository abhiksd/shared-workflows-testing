# 🚀 Node.js Configuration & Environment Management Guide

## ✅ **COMPREHENSIVE NODE.JS INTEGRATION**

This guide documents the complete Node.js configuration, environment management, and secrets injection setup implemented in the Helm charts, matching the Spring Boot capabilities.

## 🎯 **ENVIRONMENT-BASED CONFIGURATION**

### **Environment-Specific Settings**

The system automatically configures Node.js applications based on the deployment environment:

| Environment | NODE_ENV | Configuration Focus | Debug Mode |
|-------------|----------|-------------------|------------|
| **dev** | `development` | Full debugging, hot reload, verbose logging | Enabled with inspector |
| **staging** | `staging` | Production-like with monitoring | Disabled |
| **production** | `production` | Optimized performance, security | Disabled |

### **Configuration Sources**

1. **Environment Variables**: Direct Node.js process environment
2. **ConfigMap Properties**: Key-value pairs from Kubernetes ConfigMap
3. **Configuration Files**: JSON files mounted at `/etc/config/`
4. **Azure Key Vault**: Secure secrets via mounted filesystem

## 🔧 **CONFIGURATION INJECTION METHODS**

### **1. Environment Variables** ✅
Direct injection of Node.js configuration via environment variables:

```yaml
env:
  - name: NODE_ENV
    value: "{{ .Values.global.environment }}"
  - name: APP_NAME
    value: "{{ .Values.global.applicationName }}"
  - name: LOG_LEVEL
    valueFrom:
      configMapKeyRef:
        name: {{ include "nodejs-app.fullname" . }}-config
        key: LOG_LEVEL
```

### **2. ConfigMap Mount** ✅
Configuration files mounted at `/etc/config/`:

```yaml
volumeMounts:
  - name: config-volume
    mountPath: /etc/config
    readOnly: true

env:
  - name: CONFIG_PATH
    value: "/etc/config"
```

### **3. Azure Key Vault Secrets** ✅
Secure secrets injection via Azure Key Vault CSI driver:

```yaml
volumeMounts:
  - name: secrets-store
    mountPath: /mnt/secrets-store
    readOnly: true

env:
  - name: AZURE_KEYVAULT_SECRETS_PATH
    value: "/mnt/secrets-store"
  - name: SECRETS_ENABLED
    value: "true"
```

## 📊 **ENVIRONMENT-SPECIFIC CONFIGURATIONS**

### **Development Environment** 🔧

**Focus**: Full debugging and development productivity

```yaml
# Environment Variables
NODE_ENV: "development"
DEBUG_MODE: "true"
ENABLE_HOT_RELOAD: "true"
LOG_LEVEL: "debug"

# Node.js Options
NODE_OPTIONS: "--max-old-space-size=512 --inspect=0.0.0.0:9229"

# Debug Configuration
DEBUG: "nodejs-app:*,express:*"
ENABLE_DEBUGGING: "true"
HOT_RELOAD: "true"
WATCH_FILES: "true"
```

**Features**:
- ✅ Node.js Inspector enabled on port 9229
- ✅ Hot reload and file watching
- ✅ Verbose debug logging
- ✅ Express.js debug output
- ✅ Lower memory allocation for faster startup

### **Staging Environment** 🧪

**Focus**: Production-like testing with monitoring

```yaml
# Environment Variables
NODE_ENV: "staging"
DEBUG_MODE: "false"
PERFORMANCE_MONITORING: "true"
LOG_LEVEL: "info"

# Node.js Options
NODE_OPTIONS: "--max-old-space-size=1024"

# Monitoring Configuration
PERFORMANCE_MONITORING: "true"
METRICS_ENABLED: "true"
```

**Features**:
- ✅ Production-like performance settings
- ✅ Performance monitoring enabled
- ✅ Metrics collection
- ✅ Balanced memory allocation
- ✅ Info-level logging for testing

### **Production Environment** 🏭

**Focus**: Security, performance, and reliability

```yaml
# Environment Variables
NODE_ENV: "production"
DEBUG_MODE: "false"
PERFORMANCE_MONITORING: "true"
SECURITY_MODE: "strict"
LOG_LEVEL: "warn"

# Node.js Options
NODE_OPTIONS: "--max-old-space-size=2048 --optimize-for-size"

# Production Configuration
PERFORMANCE_MONITORING: "true"
METRICS_ENABLED: "true"
SECURITY_HEADERS: "true"
REQUEST_LOGGING: "false"
```

**Features**:
- ✅ Optimized Node.js runtime settings
- ✅ Security headers enforcement
- ✅ Minimal logging for performance
- ✅ Memory optimization
- ✅ Production monitoring

## 🔐 **SECRETS MANAGEMENT INTEGRATION**

### **Azure Key Vault Configuration**

Secrets are automatically mounted and accessible in Node.js applications:

```javascript
// config.json automatically includes Key Vault configuration
{
  "secrets": {
    "enabled": true,
    "provider": "azure-keyvault",
    "mountPath": "/mnt/secrets-store",
    "autoReload": false
  }
}
```

### **Accessing Secrets in Node.js**

**Method 1: File System Access**
```javascript
const fs = require('fs');
const path = require('path');

const secretsPath = process.env.AZURE_KEYVAULT_SECRETS_PATH || '/mnt/secrets-store';

// Read database password
const dbPassword = fs.readFileSync(path.join(secretsPath, 'db-password'), 'utf8');

// Read API key
const apiKey = fs.readFileSync(path.join(secretsPath, 'api-key'), 'utf8');
```

**Method 2: Configuration Helper**
```javascript
class SecretsManager {
  constructor() {
    this.secretsPath = process.env.AZURE_KEYVAULT_SECRETS_PATH;
    this.enabled = process.env.SECRETS_ENABLED === 'true';
  }

  getSecret(secretName) {
    if (!this.enabled || !this.secretsPath) {
      throw new Error('Secrets not enabled or path not configured');
    }
    
    const secretPath = path.join(this.secretsPath, secretName);
    return fs.readFileSync(secretPath, 'utf8').trim();
  }
}

// Usage
const secrets = new SecretsManager();
const dbConnectionString = secrets.getSecret('db-connection-string');
```

**Method 3: Environment Variable Fallback**
```javascript
function getSecret(secretName, fallbackEnvVar) {
  const secretsPath = process.env.AZURE_KEYVAULT_SECRETS_PATH;
  
  if (secretsPath && process.env.SECRETS_ENABLED === 'true') {
    try {
      return fs.readFileSync(path.join(secretsPath, secretName), 'utf8').trim();
    } catch (error) {
      console.warn(`Failed to read secret ${secretName} from Key Vault:`, error.message);
    }
  }
  
  // Fallback to environment variable
  return process.env[fallbackEnvVar];
}

// Usage
const dbPassword = getSecret('db-password', 'DB_PASSWORD');
```

## 📝 **CONFIGURATION FILES STRUCTURE**

### **Mounted Configuration Files** (Kubernetes ConfigMap)
```
/etc/config/
├── config.json              # Main application configuration
└── npm-scripts.json         # Environment-specific npm scripts
```

### **Configuration Loading in Node.js**

```javascript
const fs = require('fs');
const path = require('path');

class ConfigManager {
  constructor() {
    this.configPath = process.env.CONFIG_PATH || '/etc/config';
    this.config = this.loadConfiguration();
  }

  loadConfiguration() {
    // Load from mounted ConfigMap
    const configFile = path.join(this.configPath, 'config.json');
    
    if (fs.existsSync(configFile)) {
      const fileConfig = JSON.parse(fs.readFileSync(configFile, 'utf8'));
      
      // Merge with environment variables
      return {
        ...fileConfig,
        app: {
          ...fileConfig.app,
          name: process.env.APP_NAME || fileConfig.app.name,
          version: process.env.APP_VERSION || fileConfig.app.version,
          environment: process.env.NODE_ENV || fileConfig.app.environment
        },
        server: {
          ...fileConfig.server,
          port: parseInt(process.env.PORT) || fileConfig.server.port
        }
      };
    }
    
    // Fallback to environment variables only
    return this.getDefaultConfig();
  }

  getDefaultConfig() {
    return {
      app: {
        name: process.env.APP_NAME || 'nodejs-app',
        version: process.env.APP_VERSION || '1.0.0',
        environment: process.env.NODE_ENV || 'development',
        port: parseInt(process.env.PORT) || 3000
      }
    };
  }

  get(path, defaultValue = null) {
    return path.split('.').reduce((config, key) => 
      config && config[key] !== undefined ? config[key] : defaultValue, this.config);
  }
}

// Usage
const config = new ConfigManager();
const appName = config.get('app.name');
const dbConfig = config.get('database');
```

## 🚀 **NODE.JS OPTIMIZATION BY ENVIRONMENT**

### **Development Node.js Settings**
```bash
NODE_OPTIONS="--max-old-space-size=512 --inspect=0.0.0.0:9229"
```
**Focus**: Fast startup, debugging support, hot reload

### **Staging Node.js Settings**
```bash
NODE_OPTIONS="--max-old-space-size=1024"
```
**Focus**: Production-like performance testing

### **Production Node.js Settings**
```bash
NODE_OPTIONS="--max-old-space-size=2048 --optimize-for-size"
```
**Focus**: Optimal performance, memory efficiency

## 🔍 **MONITORING & HEALTH CHECKS**

### **Health Check Implementation**

```javascript
const express = require('express');
const app = express();

// Health check endpoint
app.get('/health', (req, res) => {
  const healthCheck = {
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV,
    version: process.env.APP_VERSION
  };

  // Add additional health checks based on environment
  if (process.env.NODE_ENV !== 'production') {
    healthCheck.memory = process.memoryUsage();
    healthCheck.pid = process.pid;
  }

  res.status(200).json(healthCheck);
});

// Readiness check endpoint
app.get('/ready', (req, res) => {
  // Check if application is ready to serve requests
  const readyCheck = {
    status: 'READY',
    timestamp: new Date().toISOString(),
    dependencies: {
      database: 'connected', // Check actual database connection
      secrets: process.env.SECRETS_ENABLED === 'true' ? 'loaded' : 'disabled'
    }
  };

  res.status(200).json(readyCheck);
});
```

### **Logging Configuration**

```javascript
const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: process.env.NODE_ENV === 'production' 
    ? winston.format.json()
    : winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      ),
  transports: [
    new winston.transports.Console({
      handleExceptions: true,
      handleRejections: true
    })
  ]
});

// Environment-specific logging
if (process.env.NODE_ENV === 'development') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.printf(({ level, message, timestamp }) => {
        return `${timestamp} [${level}]: ${message}`;
      })
    )
  }));
}
```

## ✅ **VERIFICATION CHECKLIST**

### **Configuration Injection** ✅
- [x] Environment variables properly set
- [x] ConfigMap mounted and accessible
- [x] Azure Key Vault secrets mounted
- [x] Node.js environment configured correctly

### **Environment-Specific Settings** ✅
- [x] Development: Full debugging enabled
- [x] Staging: Production-like with monitoring
- [x] Production: Optimized and secure

### **Secrets Management** ✅
- [x] Azure Key Vault integration configured
- [x] Workload Identity authentication
- [x] Secrets mounted to filesystem
- [x] Node.js secret access methods

### **Monitoring & Health Checks** ✅
- [x] Health check endpoints configured
- [x] Kubernetes liveness/readiness probes
- [x] Environment-specific logging
- [x] Performance monitoring setup

## 🎯 **USAGE EXAMPLES**

### **Basic Application Setup**

```javascript
const express = require('express');
const ConfigManager = require('./config/ConfigManager');
const SecretsManager = require('./config/SecretsManager');

const app = express();
const config = new ConfigManager();
const secrets = new SecretsManager();

// Configure application based on environment
const port = config.get('server.port', 3000);
const environment = config.get('app.environment', 'development');

// Use secrets for sensitive data
if (config.get('secrets.enabled')) {
  const dbPassword = secrets.getSecret('db-password');
  // Use dbPassword for database connection
}

// Environment-specific middleware
if (environment === 'development') {
  app.use(require('morgan')('dev')); // Request logging
}

if (environment === 'production') {
  app.use(require('helmet')()); // Security headers
}

app.listen(port, () => {
  console.log(`Server running on port ${port} in ${environment} mode`);
});
```

### **Configuration-Driven Database Connection**

```javascript
class DatabaseManager {
  constructor(config, secrets) {
    this.config = config;
    this.secrets = secrets;
  }

  async connect() {
    const dbConfig = {
      host: this.config.get('database.host'),
      port: this.config.get('database.port'),
      database: this.config.get('database.name'),
      username: this.config.get('database.username'),
      password: this.secrets.getSecret('db-password')
    };

    // Use dbConfig for connection
  }
}
```

## 🚀 **READY FOR DEPLOYMENT**

The Node.js application will automatically:

1. **Configure environment** based on NODE_ENV
2. **Load configuration** from ConfigMaps and environment variables
3. **Access secrets** from Azure Key Vault seamlessly
4. **Apply performance optimizations** suitable for the environment
5. **Provide health checks** for Kubernetes
6. **Enable debugging** in development environments

**No additional configuration required** - everything is handled by the Helm chart during deployment, providing the same level of configuration management as Spring Boot!