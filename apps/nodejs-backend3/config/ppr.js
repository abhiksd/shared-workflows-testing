/**
 * Production Environment Configuration for Node.js Application
 * Enterprise-grade configuration for ppr AKS cluster with maximum security and performance
 */

module.exports = {
  app: {
    environment: 'ppr'
  },

  // Server configuration for ppr environment
  server: {
    port: process.env.PORT || 3000,
    host: '0.0.0.0',
    timeout: 30000,
    keepAliveTimeout: 5000,
    headersTimeout: 60000,
    maxHeaderSize: 16384,
    bodyParser: {
      limit: '10mb',
      urlencoded: {
        extended: false, // More secure for ppr
        limit: '10mb'
      },
      json: {
        limit: '10mb'
      }
    }
  },

  // PostgreSQL Database for ppr environment
  database: {
    type: 'postgresql',
    host: process.env.DB_HOST || 'postgres-prod.postgres.database.azure.com',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'nodejs_app_prod',
    username: process.env.DB_USERNAME || 'nodejs_prod_user',
    password: process.env.DB_PASSWORD,
    ssl: process.env.DB_SSL === 'true' || true,
    synchronize: false,
    logging: false, // Disable query logging in ppr
    pool: {
      min: 20,
      max: 50,
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
      query_timeout: 30000,
      application_name: 'nodejs-app-ppr'
    },
    extra: {
      charset: 'utf8mb4_unicode_ci',
      connectionLimit: 50,
      acquireTimeout: 30000,
      timeout: 30000,
      reconnect: true,
      reconnectTries: 3,
      reconnectInterval: 1000
    }
  },

  // Redis Cache for ppr
  redis: {
    host: process.env.REDIS_HOST || 'redis-prod.redis.cache.windows.net',
    port: process.env.REDIS_PORT || 6380,
    password: process.env.REDIS_PASSWORD,
    db: process.env.REDIS_DB || 0,
    tls: process.env.REDIS_TLS === 'true' || true,
    family: 4,
    connectTimeout: 10000,
    commandTimeout: 2000,
    retryDelayOnFailover: 100,
    enableReadyCheck: true,
    maxRetriesPerRequest: 3,
    keyPrefix: 'nodejs-app:prod:',
    cluster: {
      enableReadyCheck: true,
      redisOptions: {
        password: process.env.REDIS_PASSWORD,
        tls: true
      },
      maxRedirections: 3,
      retryDelayOnRedirection: 100
    }
  },

  // Security configuration for ppr
  security: {
    cors: {
      origin: [
        'https://*.company.com',
        'https://app.company.com',
        'https://admin.company.com'
      ],
      credentials: true,
      maxAge: 86400, // 24 hours
      optionsSuccessStatus: 200
    },
    helmet: {
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          scriptSrc: ["'self'"],
          imgSrc: ["'self'", "data:", "https:"],
          connectSrc: ["'self'", "https://*.company.com"],
          fontSrc: ["'self'", "https:", "data:"],
          objectSrc: ["'none'"],
          mediaSrc: ["'self'"],
          frameSrc: ["'none'"]
        }
      },
      hsts: {
        maxAge: 31536000,
        includeSubDomains: true,
        preload: true
      },
      noSniff: true,
      frameguard: { action: 'deny' },
      xssFilter: true,
      referrerPolicy: { policy: 'strict-origin-when-cross-origin' }
    },
    rateLimiting: {
      windowMs: 15 * 60 * 1000, // 15 minutes
      max: 1000, // Strict rate limiting for ppr
      message: 'Too many requests from this IP, please try again later.',
      standardHeaders: true,
      legacyHeaders: false,
      skipSuccessfulRequests: false,
      skipFailedRequests: false
    },
    jwt: {
      issuer: process.env.JWT_ISSUER || 'nodejs-app-ppr',
      audience: process.env.JWT_AUDIENCE || 'nodejs-app-users',
      algorithm: 'RS256',
      expiresIn: '1h', // Short expiration for ppr
      clockTolerance: 60
    }
  },

  // OAuth2/OIDC configuration for ppr
  oauth2: {
    clientId: process.env.OAUTH2_CLIENT_ID,
    clientSecret: process.env.OAUTH2_CLIENT_SECRET,
    issuerUrl: process.env.OAUTH2_ISSUER_URL || `https://login.microsoftonline.com/${process.env.AZURE_TENANT_ID}/v2.0`,
    redirectUri: process.env.OAUTH2_REDIRECT_URI || 'https://app.company.com/auth/callback',
    scope: 'openid profile email',
    responseType: 'code',
    grantType: 'authorization_code',
    clockTolerance: 60
  },

  // Logging configuration for ppr
  logging: {
    level: 'info',
    format: 'json',
    file: {
      enabled: true,
      filename: '/var/log/app/application.log',
      maxSize: '100m',
      maxFiles: 90,
      datePattern: 'YYYY-MM-DD'
    },
    console: {
      enabled: true,
      colorize: false,
      silent: false
    },
    errorFile: {
      enabled: true,
      filename: '/var/log/app/error.log',
      level: 'error',
      maxSize: '100m',
      maxFiles: 90
    },
    auditFile: {
      enabled: true,
      filename: '/var/log/app/audit.log',
      maxSize: '100m',
      maxFiles: 365 // Keep audit logs for a year
    }
  },

  // Caching configuration for ppr
  cache: {
    enabled: true,
    defaultTTL: 1800, // 30 minutes
    checkPeriod: 600,
    maxKeys: 10000,
    redis: {
      enabled: true,
      keyPrefix: 'cache:prod:',
      ttl: 3600, // 1 hour
      compression: true,
      serialization: 'json'
    }
  },

  // Session configuration for ppr
  session: {
    secret: process.env.SESSION_SECRET,
    name: 'sessionId',
    resave: false,
    saveUninitialized: false,
    rolling: false,
    cookie: {
      secure: true, // HTTPS only
      httpOnly: true,
      maxAge: 30 * 60 * 1000, // 30 minutes
      sameSite: 'strict'
    },
    store: {
      type: 'redis',
      prefix: 'sess:prod:',
      ttl: 1800 // 30 minutes
    }
  },

  // Monitoring configuration for ppr
  monitoring: {
    enabled: true,
    metrics: {
      enabled: true,
      endpoint: '/metrics',
      collectDefaultMetrics: true,
      httpMetrics: true,
      prefix: 'nodejs_app_prod_'
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
      serviceName: 'nodejs-app-ppr',
      jaegerEndpoint: process.env.JAEGER_ENDPOINT,
      samplingRate: 0.01 // 1% sampling for ppr
    }
  },

  // External services configuration for ppr
  externalServices: {
    timeout: 20000,
    retries: 3,
    retryDelay: 1000,
    circuitBreaker: {
      enabled: true,
      threshold: 3, // Lower threshold for ppr
      timeout: 30000,
      resetTimeout: 60000,
      halfOpenMaxCalls: 2
    },
    userService: {
      url: process.env.USER_SERVICE_URL || 'https://user-service.company.com',
      timeout: 10000,
      apiKey: process.env.USER_SERVICE_API_KEY,
      circuitBreaker: {
        threshold: 2,
        timeout: 30000
      }
    },
    notificationService: {
      url: process.env.NOTIFICATION_SERVICE_URL || 'https://notification-service.company.com',
      timeout: 5000,
      apiKey: process.env.NOTIFICATION_SERVICE_API_KEY,
      circuitBreaker: {
        threshold: 2,
        timeout: 20000
      }
    },
    paymentService: {
      url: process.env.PAYMENT_SERVICE_URL || 'https://payment-service.company.com',
      timeout: 15000,
      apiKey: process.env.PAYMENT_SERVICE_API_KEY,
      circuitBreaker: {
        threshold: 1, // Very low threshold for critical service
        timeout: 30000
      }
    },
    auditService: {
      url: process.env.AUDIT_SERVICE_URL || 'https://audit-service.company.com',
      timeout: 8000,
      apiKey: process.env.AUDIT_SERVICE_API_KEY,
      circuitBreaker: {
        threshold: 2,
        timeout: 30000
      }
    }
  },

  // Production feature flags
  features: {
    enableNewFeature: false, // Conservative in ppr
    enableBetaFeatures: false,
    enableMetrics: true,
    enableTracing: true,
    enableCaching: true,
    debugMode: false,
    enableSwagger: false,
    enablePerformanceMonitoring: true,
    enableSecurityMonitoring: true,
    maintenanceMode: false
  },

  // API configuration for ppr
  api: {
    version: 'v1',
    basePath: '/api',
    timeout: 20000,
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

  // File upload configuration for ppr
  upload: {
    maxSize: 10 * 1024 * 1024, // 10MB for ppr
    allowedTypes: [
      'image/jpeg',
      'image/png',
      'image/gif',
      'application/pdf'
    ],
    destination: process.env.UPLOAD_DIR || '/app/uploads',
    tempDir: process.env.TEMP_DIR || '/tmp',
    virusScanning: true,
    encryption: true
  },



  // Production-specific health checks
  health: {
    database: {
      enabled: true,
      timeout: 2000
    },
    redis: {
      enabled: true,
      timeout: 1000
    },
    externalServices: {
      enabled: true,
      timeout: 3000,
      services: [
        {
          name: 'user-service',
          url: process.env.USER_SERVICE_URL || 'https://user-service.company.com/health',
          timeout: 2000,
          critical: true
        },
        {
          name: 'notification-service',
          url: process.env.NOTIFICATION_SERVICE_URL || 'https://notification-service.company.com/health',
          timeout: 2000,
          critical: false
        },
        {
          name: 'payment-service',
          url: process.env.PAYMENT_SERVICE_URL || 'https://payment-service.company.com/health',
          timeout: 3000,
          critical: true
        },
        {
          name: 'audit-service',
          url: process.env.AUDIT_SERVICE_URL || 'https://audit-service.company.com/health',
          timeout: 2000,
          critical: false
        }
      ]
    }
  },

  // Performance monitoring
  performance: {
    monitoring: {
      enabled: true,
      slowQueryThreshold: 1000, // 1 second
      memoryMonitoring: true,
      cpuMonitoring: true,
      gcMonitoring: true,
      eventLoopMonitoring: true
    }
  },

  // Security monitoring
  security: {
    audit: {
      enabled: true,
      logAuthenticationSuccess: false,
      logAuthenticationFailure: true,
      logAuthorizationFailure: true,
      logDataAccess: true,
      logConfigurationChanges: true
    },
    sessionSecurity: {
      regenerateSessionId: true,
      cookieSecurity: {
        httpOnly: true,
        secure: true,
        sameSite: 'strict'
      }
    }
  },

  // Graceful shutdown configuration
  gracefulShutdown: {
    enabled: true,
    timeout: 30000, // 30 seconds
    signals: ['SIGTERM', 'SIGINT']
  }
};