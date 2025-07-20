const promClient = require('prom-client');
const promMiddleware = require('express-prometheus-middleware');
const config = require('config');
const logger = require('../utils/logger');

// Prometheus metrics
const register = new promClient.Registry();

// Default metrics
promClient.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10],
  registers: [register]
});

const httpRequestTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const activeConnections = new promClient.Gauge({
  name: 'active_connections',
  help: 'Number of active connections',
  registers: [register]
});

const databaseQueryDuration = new promClient.Histogram({
  name: 'database_query_duration_seconds',
  help: 'Duration of database queries in seconds',
  labelNames: ['operation', 'table'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5],
  registers: [register]
});

const redisOperationDuration = new promClient.Histogram({
  name: 'redis_operation_duration_seconds',
  help: 'Duration of Redis operations in seconds',
  labelNames: ['operation'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1],
  registers: [register]
});

const memoryUsage = new promClient.Gauge({
  name: 'process_memory_usage_bytes',
  help: 'Memory usage of the process in bytes',
  labelNames: ['type'],
  registers: [register]
});

const errorTotal = new promClient.Counter({
  name: 'errors_total',
  help: 'Total number of errors',
  labelNames: ['type', 'method', 'route'],
  registers: [register]
});

// Update memory metrics every 30 seconds
setInterval(() => {
  const memUsage = process.memoryUsage();
  memoryUsage.set({ type: 'rss' }, memUsage.rss);
  memoryUsage.set({ type: 'heapUsed' }, memUsage.heapUsed);
  memoryUsage.set({ type: 'heapTotal' }, memUsage.heapTotal);
  memoryUsage.set({ type: 'external' }, memUsage.external);
}, 30000);

// OpenTelemetry setup
let tracer;
if (config.get('monitoring.openTelemetry.enabled')) {
  const { NodeSDK } = require('@opentelemetry/sdk-node');
  const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
  const { AzureMonitorTraceExporter } = require('@azure/monitor-opentelemetry-exporter');
  
  const traceExporter = new AzureMonitorTraceExporter({
    connectionString: config.get('azure.applicationInsights.connectionString')
  });
  
  const sdk = new NodeSDK({
    traceExporter,
    instrumentations: [getNodeAutoInstrumentations()],
  });
  
  sdk.start();
  
  const { trace } = require('@opentelemetry/api');
  tracer = trace.getTracer('nodejs-backend-app');
}

// Monitoring middleware
const monitoringMiddleware = (req, res, next) => {
  const startTime = Date.now();
  
  // Increment active connections
  activeConnections.inc();
  
  // OpenTelemetry span
  let span;
  if (tracer) {
    span = tracer.startSpan(`${req.method} ${req.route?.path || req.path}`);
    span.setAttributes({
      'http.method': req.method,
      'http.url': req.url,
      'http.route': req.route?.path || req.path,
      'user.agent': req.get('User-Agent') || '',
      'request.id': req.id
    });
  }
  
  // Override res.end to capture metrics
  const originalEnd = res.end;
  res.end = function(...args) {
    const duration = (Date.now() - startTime) / 1000;
    const route = req.route?.path || req.path;
    const method = req.method;
    const statusCode = res.statusCode.toString();
    
    // Record metrics
    httpRequestDuration.observe({ method, route, status_code: statusCode }, duration);
    httpRequestTotal.inc({ method, route, status_code: statusCode });
    
    // Record errors
    if (res.statusCode >= 400) {
      errorTotal.inc({ type: 'http', method, route });
    }
    
    // Decrement active connections
    activeConnections.dec();
    
    // Complete OpenTelemetry span
    if (span) {
      span.setAttributes({
        'http.status_code': res.statusCode,
        'http.response_time': duration
      });
      
      if (res.statusCode >= 400) {
        span.recordException(new Error(`HTTP ${res.statusCode}`));
      }
      
      span.end();
    }
    
    // Log request
    logger.info('HTTP Request', {
      requestId: req.id,
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration: `${duration}s`,
      userAgent: req.get('User-Agent'),
      ip: req.ip
    });
    
    originalEnd.apply(this, args);
  };
  
  next();
};

// Database query monitoring
const monitorDatabaseQuery = (operation, table) => {
  const startTime = Date.now();
  
  return {
    end: () => {
      const duration = (Date.now() - startTime) / 1000;
      databaseQueryDuration.observe({ operation, table }, duration);
      
      logger.debug('Database Query', {
        operation,
        table,
        duration: `${duration}s`
      });
    }
  };
};

// Redis operation monitoring
const monitorRedisOperation = (operation) => {
  const startTime = Date.now();
  
  return {
    end: () => {
      const duration = (Date.now() - startTime) / 1000;
      redisOperationDuration.observe({ operation }, duration);
      
      logger.debug('Redis Operation', {
        operation,
        duration: `${duration}s`
      });
    }
  };
};

// Health check metrics
const healthChecks = {
  database: new promClient.Gauge({
    name: 'health_check_database',
    help: 'Database health check status (1 = healthy, 0 = unhealthy)',
    registers: [register]
  }),
  redis: new promClient.Gauge({
    name: 'health_check_redis',
    help: 'Redis health check status (1 = healthy, 0 = unhealthy)',
    registers: [register]
  }),
  external_api: new promClient.Gauge({
    name: 'health_check_external_api',
    help: 'External API health check status (1 = healthy, 0 = unhealthy)',
    registers: [register]
  })
};

// Application metrics
const businessMetrics = {
  userRegistrations: new promClient.Counter({
    name: 'user_registrations_total',
    help: 'Total number of user registrations',
    registers: [register]
  }),
  userLogins: new promClient.Counter({
    name: 'user_logins_total',
    help: 'Total number of user logins',
    labelNames: ['status'],
    registers: [register]
  }),
  ordersCreated: new promClient.Counter({
    name: 'orders_created_total',
    help: 'Total number of orders created',
    registers: [register]
  }),
  filesUploaded: new promClient.Counter({
    name: 'files_uploaded_total',
    help: 'Total number of files uploaded',
    labelNames: ['type'],
    registers: [register]
  })
};

// Initialize monitoring
async function initializeMonitoring() {
  try {
    logger.info('Initializing monitoring...');
    
    // Set application info
    const appInfo = new promClient.Gauge({
      name: 'app_info',
      help: 'Application information',
      labelNames: ['version', 'environment', 'node_version'],
      registers: [register]
    });
    
    appInfo.set({
      version: config.get('app.version'),
      environment: config.get('app.environment'),
      node_version: process.version
    }, 1);
    
    logger.info('Monitoring initialized successfully');
  } catch (error) {
    logger.error('Failed to initialize monitoring', { error: error.message });
    throw error;
  }
}

// Export metrics endpoint
const getMetrics = async () => {
  return register.metrics();
};

// Custom middleware for specific business metrics
const trackUserRegistration = (req, res, next) => {
  const originalSend = res.send;
  res.send = function(data) {
    if (res.statusCode === 201) {
      businessMetrics.userRegistrations.inc();
    }
    originalSend.call(this, data);
  };
  next();
};

const trackUserLogin = (req, res, next) => {
  const originalSend = res.send;
  res.send = function(data) {
    const status = res.statusCode === 200 ? 'success' : 'failure';
    businessMetrics.userLogins.inc({ status });
    originalSend.call(this, data);
  };
  next();
};

const trackOrderCreation = (req, res, next) => {
  const originalSend = res.send;
  res.send = function(data) {
    if (res.statusCode === 201) {
      businessMetrics.ordersCreated.inc();
    }
    originalSend.call(this, data);
  };
  next();
};

const trackFileUpload = (fileType) => (req, res, next) => {
  const originalSend = res.send;
  res.send = function(data) {
    if (res.statusCode === 200 || res.statusCode === 201) {
      businessMetrics.filesUploaded.inc({ type: fileType });
    }
    originalSend.call(this, data);
  };
  next();
};

module.exports = {
  initializeMonitoring,
  monitoringMiddleware,
  monitorDatabaseQuery,
  monitorRedisOperation,
  healthChecks,
  businessMetrics,
  getMetrics,
  trackUserRegistration,
  trackUserLogin,
  trackOrderCreation,
  trackFileUpload,
  register
};