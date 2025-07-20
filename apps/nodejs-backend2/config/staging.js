/**
 * Staging Environment Configuration for Node.js Application
 * Production-like configuration for AKS staging cluster with performance optimizations
 */

module.exports = {
  app: {
    environment: 'staging'
  },

  // Server configuration for staging environment
  server: {
    port: process.env.PORT || 3000,
    host: '0.0.0.0',
    timeout: 30000,
    keepAliveTimeout: 5000,
    headersTimeout: 60000
  },

  // PostgreSQL Database for staging environment
  database: {
    type: 'postgresql',
    host: process.env.DB_HOST || 'postgres-staging.postgres.database.azure.com',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'nodejs_app_staging',
    username: process.env.DB_USERNAME || 'nodejs_staging_user',
    password: process.env.DB_PASSWORD,
    ssl: process.env.DB_SSL === 'true' || true,
    synchronize: false,
    logging: ['error'],
    pool: {
      min: 10,
      max: 30,
      acquire: 30000,
      idle: 10000
    },
    dialectOptions: {
      ssl: {
        require: true,
        rejectUnauthorized: false
      },
      statement_timeout: 30000,
      idle_in_transaction_session_timeout: 30000,
      query_timeout: 30000
    },
    extra: {
      charset: 'utf8mb4_unicode_ci',
      connectionLimit: 30,
      acquireTimeout: 30000,
      timeout: 30000
    }
  },

  // Redis Cache for staging
  redis: {
    host: process.env.REDIS_HOST || 'redis-staging.redis.cache.windows.net',
    port: process.env.REDIS_PORT || 6380,
    password: process.env.REDIS_PASSWORD,
    db: process.env.REDIS_DB || 0,
    tls: process.env.REDIS_TLS === 'true' || true,
    family: 4,
    connectTimeout: 10000,
    commandTimeout: 3000,
    retryDelayOnFailover: 100,
    enableReadyCheck: true,
    maxRetriesPerRequest: 3,
    keyPrefix: 'nodejs-app:staging:',
    cluster: {
      enableReadyCheck: true,
      redisOptions: {
        password: process.env.REDIS_PASSWORD
      }
    }
  },

  // Security configuration for staging
  security: {
    cors: {
      origin: [
        'https://*.staging.company.com',
        'https://app-staging.company.com',
        'https://admin-staging.company.com'
      ],
      credentials: true,
      maxAge: 3600
    },
    helmet: {
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          scriptSrc: ["'self'"],
          imgSrc: ["'self'", "data:", "https:"],
          connectSrc: ["'self'", "https://*.staging.company.com"]
        }
      },
      hsts: {
        maxAge: 31536000,
        includeSubDomains: true,
        preload: true
      }
    },
    rateLimiting: {
      windowMs: 15 * 60 * 1000,
      max: 2000,
      standardHeaders: true,
      legacyHeaders: false
    },
    jwt: {
      issuer: process.env.JWT_ISSUER || 'nodejs-app-staging',
      expiresIn: '2h'
    }
  },

  // OAuth2/OIDC configuration for staging
  oauth2: {
    clientId: process.env.OAUTH2_CLIENT_ID,
    clientSecret: process.env.OAUTH2_CLIENT_SECRET,
    issuerUrl: process.env.OAUTH2_ISSUER_URL || `https://login.microsoftonline.com/${process.env.AZURE_TENANT_ID}/v2.0`,
    redirectUri: process.env.OAUTH2_REDIRECT_URI || 'https://app-staging.company.com/auth/callback',
    scope: 'openid profile email',
    responseType: 'code',
    grantType: 'authorization_code'
  },

  // Logging configuration for staging
  logging: {
    level: 'info',
    format: 'json',
    file: {
      enabled: true,
      filename: '/var/log/app/application.log',
      maxSize: '100m',
      maxFiles: 60,
      datePattern: 'YYYY-MM-DD'
    },
    console: {
      enabled: true,
      colorize: false
    },
    errorFile: {
      enabled: true,
      filename: '/var/log/app/error.log',
      level: 'error'
    }
  },

  // Caching configuration for staging
  cache: {
    enabled: true,
    defaultTTL: 600,
    checkPeriod: 600,
    maxKeys: 5000,
    redis: {
      enabled: true,
      keyPrefix: 'cache:staging:',
      ttl: 1800,
      compression: true
    }
  },

  // Session configuration for staging
  session: {
    secret: process.env.SESSION_SECRET,
    name: 'sessionId',
    resave: false,
    saveUninitialized: false,
    rolling: false,
    cookie: {
      secure: true,
      httpOnly: true,
      maxAge: 2 * 60 * 60 * 1000, // 2 hours
      sameSite: 'strict'
    },
    store: {
      type: 'redis',
      prefix: 'sess:staging:',
      ttl: 7200 // 2 hours
    }
  },

  // Monitoring configuration for staging
  monitoring: {
    enabled: true,
    metrics: {
      enabled: true,
      endpoint: '/metrics',
      collectDefaultMetrics: true,
      httpMetrics: true,
      prefix: 'nodejs_app_staging_'
    },
    health: {
      enabled: true,
      endpoint: '/health',
      checks: {
        database: true,
        redis: true,
        externalServices: true
      }
    },
    tracing: {
      enabled: true,
      serviceName: 'nodejs-app-staging',
      jaegerEndpoint: process.env.JAEGER_ENDPOINT,
      samplingRate: 0.1 // 10% sampling
    }
  },

  // External services configuration for staging
  externalServices: {
    timeout: 25000,
    retries: 3,
    retryDelay: 1000,
    circuitBreaker: {
      enabled: true,
      threshold: 5,
      timeout: 60000,
      resetTimeout: 30000,
      halfOpenMaxCalls: 3
    },
    userService: {
      url: process.env.USER_SERVICE_URL || 'https://user-service-staging.company.com',
      timeout: 12000,
      apiKey: process.env.USER_SERVICE_API_KEY,
      circuitBreaker: {
        threshold: 3,
        timeout: 60000
      }
    },
    notificationService: {
      url: process.env.NOTIFICATION_SERVICE_URL || 'https://notification-service-staging.company.com',
      timeout: 8000,
      apiKey: process.env.NOTIFICATION_SERVICE_API_KEY,
      circuitBreaker: {
        threshold: 3,
        timeout: 30000
      }
    },
    paymentService: {
      url: process.env.PAYMENT_SERVICE_URL || 'https://payment-service-staging.company.com',
      timeout: 20000,
      apiKey: process.env.PAYMENT_SERVICE_API_KEY,
      circuitBreaker: {
        threshold: 2,
        timeout: 60000
      }
    }
  },

  // Staging feature flags
  features: {
    enableNewFeature: true,
    enableBetaFeatures: false,
    enableMetrics: true,
    enableTracing: true,
    enableCaching: true,
    debugMode: false,
    enableSwagger: false,
    enablePerformanceMonitoring: true
  },

  // API configuration for staging
  api: {
    version: 'v1',
    basePath: '/api',
    timeout: 25000,
    pagination: {
      defaultLimit: 20,
      maxLimit: 100
    },
    validation: {
      abortEarly: false,
      allowUnknown: false,
      stripUnknown: true
    }
  },

  // File upload configuration for staging
  upload: {
    maxSize: 20 * 1024 * 1024, // 20MB
    allowedTypes: [
      'image/jpeg',
      'image/png',
      'image/gif',
      'application/pdf',
      'text/csv',
      'application/json',
      'application/xml'
    ],
    destination: process.env.UPLOAD_DIR || '/app/uploads',
    tempDir: process.env.TEMP_DIR || '/tmp'
  },

  // Azure Key Vault integration
  azure: {
    keyVault: {
      uri: process.env.AZURE_KEYVAULT_URI || 'https://keyvault-staging.vault.azure.net/',
      clientId: process.env.AZURE_CLIENT_ID,
      tenantId: process.env.AZURE_TENANT_ID,
      refreshPeriod: 30 * 60 * 1000 // 30 minutes
    }
  },

  // Staging-specific health checks
  health: {
    database: {
      enabled: true,
      timeout: 3000
    },
    redis: {
      enabled: true,
      timeout: 2000
    },
    externalServices: {
      enabled: true,
      timeout: 5000,
      services: [
        {
          name: 'user-service',
          url: process.env.USER_SERVICE_URL || 'https://user-service-staging.company.com/health',
          timeout: 3000
        },
        {
          name: 'notification-service',
          url: process.env.NOTIFICATION_SERVICE_URL || 'https://notification-service-staging.company.com/health',
          timeout: 3000
        },
        {
          name: 'payment-service',
          url: process.env.PAYMENT_SERVICE_URL || 'https://payment-service-staging.company.com/health',
          timeout: 5000
        }
      ]
    }
  },

  // Performance monitoring
  performance: {
    monitoring: {
      enabled: true,
      slowQueryThreshold: 2000,
      memoryMonitoring: true,
      cpuMonitoring: true
    }
  }
};