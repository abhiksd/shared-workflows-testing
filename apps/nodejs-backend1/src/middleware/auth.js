const jwt = require('jsonwebtoken');
const config = require('config');
const logger = require('../utils/logger');
const { UnauthorizedError, ForbiddenError } = require('./errorHandler');
const { CacheOperations } = require('../config/redis');

// JWT token verification
const verifyToken = async (req, res, next) => {
  try {
    // Get token from header
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      logger.security('Missing or invalid authorization header', {
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        url: req.url
      });
      throw new UnauthorizedError('Access token required');
    }
    
    const token = authHeader.substring(7); // Remove 'Bearer ' prefix
    
    // Check if token is blacklisted (if Redis is enabled)
    if (config.get('redis.enabled')) {
      try {
        const isBlacklisted = await CacheOperations.getWithPrefix('blacklist', token);
        if (isBlacklisted) {
          logger.security('Blacklisted token used', {
            token: token.substring(0, 10) + '...',
            ip: req.ip,
            userAgent: req.get('User-Agent')
          });
          throw new UnauthorizedError('Token has been revoked');
        }
      } catch (redisError) {
        logger.warn('Redis check failed during token validation', { error: redisError.message });
      }
    }
    
    // Verify JWT token
    const decoded = jwt.verify(token, config.get('jwt.secret'));
    
    // Check token expiration
    if (decoded.exp < Date.now() / 1000) {
      logger.security('Expired token used', {
        userId: decoded.userId,
        exp: decoded.exp,
        ip: req.ip
      });
      throw new UnauthorizedError('Token has expired');
    }
    
    // Add user info to request
    req.user = {
      id: decoded.userId,
      email: decoded.email,
      role: decoded.role,
      permissions: decoded.permissions || []
    };
    
    req.token = token;
    
    logger.debug('Token verified successfully', {
      userId: req.user.id,
      role: req.user.role,
      ip: req.ip
    });
    
    next();
  } catch (error) {
    if (error instanceof jwt.JsonWebTokenError) {
      logger.security('Invalid JWT token', {
        error: error.message,
        ip: req.ip,
        userAgent: req.get('User-Agent')
      });
      throw new UnauthorizedError('Invalid token');
    }
    
    if (error instanceof jwt.TokenExpiredError) {
      logger.security('JWT token expired', {
        ip: req.ip,
        userAgent: req.get('User-Agent')
      });
      throw new UnauthorizedError('Token has expired');
    }
    
    throw error;
  }
};

// Optional authentication (doesn't fail if no token)
const optionalAuth = async (req, res, next) => {
  try {
    await verifyToken(req, res, next);
  } catch (error) {
    // If authentication fails, continue without user info
    req.user = null;
    req.token = null;
    next();
  }
};

// Role-based authorization
const requireRole = (requiredRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      throw new UnauthorizedError('Authentication required');
    }
    
    const userRole = req.user.role;
    const hasRequiredRole = Array.isArray(requiredRoles) 
      ? requiredRoles.includes(userRole)
      : userRole === requiredRoles;
    
    if (!hasRequiredRole) {
      logger.security('Insufficient permissions', {
        userId: req.user.id,
        userRole,
        requiredRoles,
        url: req.url,
        method: req.method,
        ip: req.ip
      });
      throw new ForbiddenError('Insufficient permissions');
    }
    
    logger.debug('Role authorization successful', {
      userId: req.user.id,
      userRole,
      requiredRoles
    });
    
    next();
  };
};

// Permission-based authorization
const requirePermission = (requiredPermissions) => {
  return (req, res, next) => {
    if (!req.user) {
      throw new UnauthorizedError('Authentication required');
    }
    
    const userPermissions = req.user.permissions || [];
    const hasRequiredPermission = Array.isArray(requiredPermissions)
      ? requiredPermissions.every(permission => userPermissions.includes(permission))
      : userPermissions.includes(requiredPermissions);
    
    if (!hasRequiredPermission) {
      logger.security('Insufficient permissions', {
        userId: req.user.id,
        userPermissions,
        requiredPermissions,
        url: req.url,
        method: req.method,
        ip: req.ip
      });
      throw new ForbiddenError('Insufficient permissions');
    }
    
    logger.debug('Permission authorization successful', {
      userId: req.user.id,
      userPermissions,
      requiredPermissions
    });
    
    next();
  };
};

// Resource ownership check
const requireOwnership = (resourceIdParam = 'id', resourceType = 'resource') => {
  return (req, res, next) => {
    if (!req.user) {
      throw new UnauthorizedError('Authentication required');
    }
    
    const resourceId = req.params[resourceIdParam];
    const userId = req.user.id;
    
    // Admin users can access all resources
    if (req.user.role === 'admin' || req.user.role === 'super_admin') {
      return next();
    }
    
    // For now, we'll need to implement resource-specific ownership checks
    // This is a placeholder that should be customized based on your data model
    req.checkOwnership = async (actualOwnerId) => {
      if (actualOwnerId !== userId) {
        logger.security('Unauthorized resource access attempt', {
          userId,
          resourceId,
          resourceType,
          actualOwnerId,
          url: req.url,
          method: req.method,
          ip: req.ip
        });
        throw new ForbiddenError(`Access denied to ${resourceType}`);
      }
    };
    
    next();
  };
};

// Rate limiting per user
const userRateLimit = (maxRequests = 100, windowMs = 60000) => {
  const requests = new Map();
  
  return (req, res, next) => {
    if (!req.user) {
      return next();
    }
    
    const userId = req.user.id;
    const now = Date.now();
    const windowStart = now - windowMs;
    
    // Clean old entries
    const userRequests = requests.get(userId) || [];
    const validRequests = userRequests.filter(timestamp => timestamp > windowStart);
    
    if (validRequests.length >= maxRequests) {
      logger.security('User rate limit exceeded', {
        userId,
        requestCount: validRequests.length,
        maxRequests,
        windowMs,
        ip: req.ip
      });
      
      return res.status(429).json({
        error: 'Too many requests',
        message: `Rate limit exceeded. Maximum ${maxRequests} requests per ${windowMs / 1000} seconds.`,
        retryAfter: Math.ceil((validRequests[0] + windowMs - now) / 1000)
      });
    }
    
    // Add current request
    validRequests.push(now);
    requests.set(userId, validRequests);
    
    next();
  };
};

// Token blacklisting (logout)
const blacklistToken = async (token, expiresIn = 3600) => {
  if (config.get('redis.enabled')) {
    try {
      await CacheOperations.setWithPrefix('blacklist', token, 'true', expiresIn);
      logger.info('Token blacklisted successfully', {
        tokenHash: require('crypto').createHash('sha256').update(token).digest('hex').substring(0, 16)
      });
    } catch (error) {
      logger.error('Failed to blacklist token', { error: error.message });
    }
  }
};

// Generate JWT token
const generateToken = (payload, expiresIn = null) => {
  const options = {};
  
  if (expiresIn) {
    options.expiresIn = expiresIn;
  } else {
    options.expiresIn = config.get('jwt.expiresIn');
  }
  
  const token = jwt.sign(payload, config.get('jwt.secret'), options);
  
  logger.debug('JWT token generated', {
    userId: payload.userId,
    expiresIn: options.expiresIn
  });
  
  return token;
};

// Refresh token validation
const verifyRefreshToken = (refreshToken) => {
  try {
    const decoded = jwt.verify(refreshToken, config.get('jwt.refreshSecret'));
    return decoded;
  } catch (error) {
    logger.security('Invalid refresh token', { error: error.message });
    throw new UnauthorizedError('Invalid refresh token');
  }
};

// API key authentication (for service-to-service communication)
const verifyApiKey = (req, res, next) => {
  const apiKey = req.headers['x-api-key'];
  
  if (!apiKey) {
    throw new UnauthorizedError('API key required');
  }
  
  const validApiKeys = config.get('auth.apiKeys') || [];
  
  if (!validApiKeys.includes(apiKey)) {
    logger.security('Invalid API key used', {
      apiKeyHash: require('crypto').createHash('sha256').update(apiKey).digest('hex').substring(0, 16),
      ip: req.ip,
      userAgent: req.get('User-Agent')
    });
    throw new UnauthorizedError('Invalid API key');
  }
  
  req.apiKeyAuth = true;
  next();
};

module.exports = {
  verifyToken,
  optionalAuth,
  requireRole,
  requirePermission,
  requireOwnership,
  userRateLimit,
  blacklistToken,
  generateToken,
  verifyRefreshToken,
  verifyApiKey
};