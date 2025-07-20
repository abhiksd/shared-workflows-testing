const config = require('config');
const logger = require('../utils/logger');

// Custom error classes
class AppError extends Error {
  constructor(message, statusCode, isOperational = true) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = isOperational;
    this.name = this.constructor.name;
    
    Error.captureStackTrace(this, this.constructor);
  }
}

class ValidationError extends AppError {
  constructor(message, details = null) {
    super(message, 400);
    this.details = details;
    this.name = 'ValidationError';
  }
}

class NotFoundError extends AppError {
  constructor(resource = 'Resource') {
    super(`${resource} not found`, 404);
    this.name = 'NotFoundError';
  }
}

class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized access') {
    super(message, 401);
    this.name = 'UnauthorizedError';
  }
}

class ForbiddenError extends AppError {
  constructor(message = 'Access forbidden') {
    super(message, 403);
    this.name = 'ForbiddenError';
  }
}

class ConflictError extends AppError {
  constructor(message = 'Resource conflict') {
    super(message, 409);
    this.name = 'ConflictError';
  }
}

class DatabaseError extends AppError {
  constructor(message = 'Database operation failed', originalError = null) {
    super(message, 500, false);
    this.originalError = originalError;
    this.name = 'DatabaseError';
  }
}

class ExternalServiceError extends AppError {
  constructor(service, message = 'External service unavailable', statusCode = 503) {
    super(`${service}: ${message}`, statusCode, false);
    this.service = service;
    this.name = 'ExternalServiceError';
  }
}

// Error handler middleware
const errorHandler = (error, req, res, next) => {
  let err = { ...error };
  err.message = error.message;
  err.stack = error.stack;
  
  // Log error details
  const errorInfo = {
    requestId: req.id,
    method: req.method,
    url: req.url,
    userAgent: req.get('User-Agent'),
    ip: req.ip,
    userId: req.user?.id,
    error: {
      name: err.name,
      message: err.message,
      stack: err.stack,
      statusCode: err.statusCode
    }
  };
  
  // Different log levels based on error type
  if (err.statusCode >= 500) {
    logger.error('Server Error', errorInfo);
  } else if (err.statusCode >= 400) {
    logger.warn('Client Error', errorInfo);
  } else {
    logger.error('Unhandled Error', errorInfo);
  }
  
  // Handle specific error types
  if (error.name === 'ValidationError') {
    err = handleValidationError(error);
  } else if (error.name === 'CastError') {
    err = handleCastError(error);
  } else if (error.code === '23505') {
    err = handleDuplicateKeyError(error);
  } else if (error.code === '23503') {
    err = handleForeignKeyError(error);
  } else if (error.name === 'JsonWebTokenError') {
    err = handleJWTError(error);
  } else if (error.name === 'TokenExpiredError') {
    err = handleJWTExpiredError(error);
  } else if (error.name === 'SyntaxError' && error.status === 400) {
    err = handleJSONSyntaxError(error);
  } else if (error.name === 'MulterError') {
    err = handleMulterError(error);
  } else if (!err.statusCode) {
    err.statusCode = 500;
    err.message = 'Internal Server Error';
  }
  
  // Prepare response
  const response = {
    error: {
      message: err.message,
      ...(config.get('app.environment') !== 'production' && {
        stack: err.stack,
        details: err.details
      })
    },
    requestId: req.id,
    timestamp: new Date().toISOString()
  };
  
  // Add validation details if available
  if (err.details) {
    response.error.details = err.details;
  }
  
  // Security headers
  res.removeHeader('X-Powered-By');
  
  res.status(err.statusCode || 500).json(response);
};

// Specific error handlers
const handleValidationError = (error) => {
  const message = 'Validation Error';
  const details = Object.values(error.errors || {}).map(val => val.message);
  return new ValidationError(message, details);
};

const handleCastError = (error) => {
  const message = `Invalid ${error.path}: ${error.value}`;
  return new ValidationError(message);
};

const handleDuplicateKeyError = (error) => {
  const field = Object.keys(error.keyValue || {})[0];
  const message = `Duplicate value for field: ${field}`;
  return new ConflictError(message);
};

const handleForeignKeyError = (error) => {
  const message = 'Referenced resource does not exist';
  return new ValidationError(message);
};

const handleJWTError = (error) => {
  const message = 'Invalid token. Please log in again.';
  return new UnauthorizedError(message);
};

const handleJWTExpiredError = (error) => {
  const message = 'Token expired. Please log in again.';
  return new UnauthorizedError(message);
};

const handleJSONSyntaxError = (error) => {
  const message = 'Invalid JSON format';
  return new ValidationError(message);
};

const handleMulterError = (error) => {
  let message = 'File upload error';
  
  switch (error.code) {
    case 'LIMIT_FILE_SIZE':
      message = 'File too large';
      break;
    case 'LIMIT_FILE_COUNT':
      message = 'Too many files';
      break;
    case 'LIMIT_UNEXPECTED_FILE':
      message = 'Unexpected file field';
      break;
    case 'LIMIT_PART_COUNT':
      message = 'Too many parts';
      break;
    default:
      message = error.message;
  }
  
  return new ValidationError(message);
};

// Async error wrapper
const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

// 404 handler
const notFound = (req, res, next) => {
  const error = new NotFoundError(`Route ${req.originalUrl}`);
  next(error);
};

// Unhandled promise rejection handler
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Promise Rejection', {
    reason: reason.toString(),
    promise: promise.toString()
  });
  
  // Close server gracefully
  if (config.get('app.environment') === 'production') {
    process.exit(1);
  }
});

// Uncaught exception handler
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception', {
    error: error.message,
    stack: error.stack
  });
  
  // Exit process
  process.exit(1);
});

module.exports = {
  errorHandler,
  asyncHandler,
  notFound,
  AppError,
  ValidationError,
  NotFoundError,
  UnauthorizedError,
  ForbiddenError,
  ConflictError,
  DatabaseError,
  ExternalServiceError
};