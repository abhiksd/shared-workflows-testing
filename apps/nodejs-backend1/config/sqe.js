/**
 * Staging Environment Configuration for Node.js Application
 * Production-like configuration for AKS sqe cluster with performance optimizations
 */

module.exports = {
  app: {
    environment: 'sqe'
  },

  // Server configuration for sqe environment
  server: {
    port: process.env.PORT || 3000,
    host: '0.0.0.0',
    timeout: 30000,
    keepAliveTimeout: 5000,
    headersTimeout: 60000
  },

  // PostgreSQL Database for sqe environment
  database: {
    type: 'postgresql',
    host: process.env.DB_HOST || 'postgres-sqe.postgres.database.azure.com',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'nodejs_app_sqe',
    username: process.env.DB_USERNAME || 'nodejs_sqe_user',
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

  // Redis Cache for sqe
  redis: {
    host: process.env.REDIS_HOST || 'redis-sqe.redis.cache.windows.net',
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
    keyPrefix: 'nodejs-app:sqe:',
    cluster: {
      enableReadyCheck: true,
      redisOptions: {
        password: process.env.REDIS_PASSWORD
      }
    }
  },

  // Security configuration for sqe
  security: {
    cors: {
      origin: [
        'https://*.sqe.company.com',
        'https://app-sqe.company.com',
        'https://admin-sqe.company.com'
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
          connectSrc: ["'self'", "https://*.sqe.company.com"]
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
      issuer: process.env.JWT_ISSUER || 'nodejs-app-sqe',
      expiresIn: '2h'
    }
  },

  // OAuth2/OIDC configuration for sqe
  oauth2: {
    clientId: process.env.OAUTH2_CLIENT_ID,
    clientSecret: process.env.OAUTH2_CLIENT_SECRET,
    issuerUrl: process.env.OAUTH2_ISSUER_URL || `https://login.microsoftonline.com/${process.env.AZURE_TENANT_ID}/v2.0`,
    redirectUri: process.env.OAUTH2_REDIRECT_URI || 'https://app-sqe.company.com/auth/callback',
    scope: 'openid profile email',
    responseType: 'code',
    grantType: 'authorization_code'
  },

  // Logging configuration for sqe
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

  // Caching configuration for sqe
  cache: {
    enabled: true,
    defaultTTL: 600,
    checkPeriod: 600,
    maxKeys: 5000,
    redis: {
      enabled: true,
      keyPrefix: 'cache:sqe:',
      ttl: 1800,
      compression: true
    }
  },

  // Session configuration for sqe
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
      prefix: 'sess:sqe:',
      ttl: 7200 // 2 hours
    }
  },

  // Monitoring configuration for sqe
  monitoring: {
    enabled: true,
    metrics: {
      enabled: true,
      endpoint: '/metrics',
      collectDefaultMetrics: true,
      httpMetrics: true,
      prefix: 'nodejs_app_sqe_'
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
      serviceName: 'nodejs-app-sqe',
      jaegerEndpoint: process.env.JAEGER_ENDPOINT,
      samplingRate: 0.1 // 10% sampling
    }
  },

  // External services configuration for sqe
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
      url: process.env.USER_SERVICE_URL || 'https://user-service-sqe.company.com',
      timeout: 12000,
      apiKey: process.env.USER_SERVICE_API_KEY,
      circuitBreaker: {
        threshold: 3,
        timeout: 60000
      }
    },
    notificationService: {
      url: process.env.NOTIFICATION_SERVICE_URL || 'https://notification-service-sqe.company.com',
      timeout: 8000,
      apiKey: process.env.NOTIFICATION_SERVICE_API_KEY,
      circuitBreaker: {
        threshold: 3,
        timeout: 30000
      }
    },
    paymentService: {
      url: process.env.PAYMENT_SERVICE_URL || 'https://payment-service-sqe.company.com',
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

  // API configuration for sqe
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

  // File upload configuration for sqe
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
          url: process.env.USER_SERVICE_URL || 'https://user-service-sqe.company.com/health',
          timeout: 3000
        },
        {
          name: 'notification-service',
          url: process.env.NOTIFICATION_SERVICE_URL || 'https://notification-service-sqe.company.com/health',
          timeout: 3000
        },
        {
          name: 'payment-service',
          url: process.env.PAYMENT_SERVICE_URL || 'https://payment-service-sqe.company.com/health',
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