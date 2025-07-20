const winston = require('winston');
const config = require('config');

// Custom format for structured logging
const customFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    return JSON.stringify({
      timestamp,
      level,
      message,
      ...meta,
      service: config.get('app.name'),
      environment: config.get('app.environment'),
      version: config.get('app.version')
    });
  })
);

// Console format for development
const consoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    const metaStr = Object.keys(meta).length ? JSON.stringify(meta, null, 2) : '';
    return `${timestamp} [${level}]: ${message} ${metaStr}`;
  })
);

// Create logger instance
const logger = winston.createLogger({
  level: config.get('logging.level'),
  format: customFormat,
  defaultMeta: {
    service: config.get('app.name'),
    environment: config.get('app.environment')
  },
  transports: []
});

// Add console transport for non-production environments
if (config.get('app.environment') !== 'production') {
  logger.add(new winston.transports.Console({
    format: consoleFormat
  }));
} else {
  logger.add(new winston.transports.Console({
    format: customFormat
  }));
}

// Add file transport if configured
if (config.has('logging.file.enabled') && config.get('logging.file.enabled')) {
  logger.add(new winston.transports.File({
    filename: config.get('logging.file.path'),
    format: customFormat,
    maxsize: config.get('logging.file.maxSize'),
    maxFiles: config.get('logging.file.maxFiles'),
    tailable: true
  }));
  
  // Error file
  logger.add(new winston.transports.File({
    filename: config.get('logging.file.errorPath'),
    level: 'error',
    format: customFormat,
    maxsize: config.get('logging.file.maxSize'),
    maxFiles: config.get('logging.file.maxFiles'),
    tailable: true
  }));
}

// Add Azure Application Insights transport if configured
if (config.has('azure.applicationInsights.enabled') && config.get('azure.applicationInsights.enabled')) {
  try {
    const { AzureApplicationInsightsLogger } = require('winston-azure-application-insights');
    
    logger.add(new AzureApplicationInsightsLogger({
      insights: {
        instrumentationKey: config.get('azure.applicationInsights.instrumentationKey')
      },
      treatErrorsAsExceptions: true
    }));
    
    logger.info('Azure Application Insights logging enabled');
  } catch (error) {
    logger.warn('Failed to initialize Azure Application Insights logging', { error: error.message });
  }
}

// Enhanced logger with additional methods
const enhancedLogger = {
  // Standard logging methods
  error: (message, meta = {}) => logger.error(message, meta),
  warn: (message, meta = {}) => logger.warn(message, meta),
  info: (message, meta = {}) => logger.info(message, meta),
  debug: (message, meta = {}) => logger.debug(message, meta),
  verbose: (message, meta = {}) => logger.verbose(message, meta),
  
  // HTTP request logging
  request: (req, res, duration) => {
    const logData = {
      requestId: req.id,
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('User-Agent'),
      ip: req.ip,
      userId: req.user?.id
    };
    
    if (res.statusCode >= 400) {
      logger.error('HTTP Request Error', logData);
    } else {
      logger.info('HTTP Request', logData);
    }
  },
  
  // Database operation logging
  database: (operation, table, duration, error = null) => {
    const logData = {
      operation,
      table,
      duration: `${duration}ms`
    };
    
    if (error) {
      logger.error('Database Operation Failed', { ...logData, error: error.message });
    } else {
      logger.debug('Database Operation', logData);
    }
  },
  
  // Redis operation logging
  redis: (operation, key, duration, error = null) => {
    const logData = {
      operation,
      key,
      duration: `${duration}ms`
    };
    
    if (error) {
      logger.error('Redis Operation Failed', { ...logData, error: error.message });
    } else {
      logger.debug('Redis Operation', logData);
    }
  },
  
  // Security event logging
  security: (event, details = {}) => {
    logger.warn('Security Event', {
      event,
      ...details,
      timestamp: new Date().toISOString()
    });
  },
  
  // Business event logging
  business: (event, details = {}) => {
    logger.info('Business Event', {
      event,
      ...details,
      timestamp: new Date().toISOString()
    });
  },
  
  // Performance logging
  performance: (operation, duration, details = {}) => {
    const logData = {
      operation,
      duration: `${duration}ms`,
      ...details
    };
    
    if (duration > 1000) {
      logger.warn('Slow Operation', logData);
    } else {
      logger.debug('Performance', logData);
    }
  },
  
  // User activity logging
  userActivity: (userId, action, details = {}) => {
    logger.info('User Activity', {
      userId,
      action,
      ...details,
      timestamp: new Date().toISOString()
    });
  },
  
  // API integration logging
  apiCall: (service, endpoint, method, duration, statusCode, error = null) => {
    const logData = {
      service,
      endpoint,
      method,
      duration: `${duration}ms`,
      statusCode
    };
    
    if (error || statusCode >= 400) {
      logger.error('API Call Failed', { ...logData, error: error?.message });
    } else {
      logger.info('API Call', logData);
    }
  },
  
  // File operation logging
  fileOperation: (operation, filename, size, duration, error = null) => {
    const logData = {
      operation,
      filename,
      size: `${size} bytes`,
      duration: `${duration}ms`
    };
    
    if (error) {
      logger.error('File Operation Failed', { ...logData, error: error.message });
    } else {
      logger.info('File Operation', logData);
    }
  },
  
  // Cache operation logging
  cache: (operation, key, hit, duration) => {
    logger.debug('Cache Operation', {
      operation,
      key,
      hit: hit ? 'HIT' : 'MISS',
      duration: `${duration}ms`
    });
  },
  
  // Startup/shutdown logging
  startup: (component, duration) => {
    logger.info('Component Started', {
      component,
      duration: `${duration}ms`
    });
  },
  
  shutdown: (component, duration) => {
    logger.info('Component Shutdown', {
      component,
      duration: `${duration}ms`
    });
  }
};

// Handle uncaught exceptions and unhandled rejections
if (config.get('app.environment') === 'production') {
  winston.exceptions.handle(
    new winston.transports.File({
      filename: config.get('logging.file.exceptionsPath', 'logs/exceptions.log'),
      format: customFormat
    })
  );
  
  winston.rejections.handle(
    new winston.transports.File({
      filename: config.get('logging.file.rejectionsPath', 'logs/rejections.log'),
      format: customFormat
    })
  );
}

module.exports = enhancedLogger;