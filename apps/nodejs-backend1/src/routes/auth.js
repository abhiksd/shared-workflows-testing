const express = require('express');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const rateLimit = require('express-rate-limit');
const config = require('config');

const logger = require('../utils/logger');
const { DatabaseOperations } = require('../config/database');
const { CacheOperations } = require('../config/redis');
const { 
  generateToken, 
  verifyRefreshToken, 
  blacklistToken,
  verifyToken 
} = require('../middleware/auth');
const { 
  asyncHandler,
  ValidationError,
  UnauthorizedError,
  ConflictError,
  NotFoundError
} = require('../middleware/errorHandler');
const { 
  trackUserRegistration,
  trackUserLogin,
  businessMetrics 
} = require('../middleware/monitoring');

const router = express.Router();

// Rate limiting for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts per window
  message: {
    error: 'Too many authentication attempts',
    retryAfter: '15 minutes'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 3, // 3 registration attempts per hour
  message: {
    error: 'Too many registration attempts',
    retryAfter: '1 hour'
  }
});

/**
 * @swagger
 * /auth/register:
 *   post:
 *     summary: Register a new user
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *               - firstName
 *               - lastName
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *                 minLength: 8
 *               firstName:
 *                 type: string
 *               lastName:
 *                 type: string
 *     responses:
 *       201:
 *         description: User registered successfully
 *       400:
 *         description: Validation error
 *       409:
 *         description: User already exists
 */
router.post('/register', 
  registerLimiter,
  trackUserRegistration,
  [
    body('email')
      .isEmail()
      .normalizeEmail()
      .withMessage('Valid email is required'),
    body('password')
      .isLength({ min: 8 })
      .withMessage('Password must be at least 8 characters long')
      .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
      .withMessage('Password must contain uppercase, lowercase, number and special character'),
    body('firstName')
      .trim()
      .isLength({ min: 1, max: 50 })
      .withMessage('First name is required and must be less than 50 characters'),
    body('lastName')
      .trim()
      .isLength({ min: 1, max: 50 })
      .withMessage('Last name is required and must be less than 50 characters')
  ],
  asyncHandler(async (req, res) => {
    // Check validation results
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      throw new ValidationError('Validation failed', errors.array());
    }

    const { email, password, firstName, lastName } = req.body;

    // Check if user already exists
    const existingUser = await DatabaseOperations.users.findByEmail(email);
    if (existingUser.length > 0) {
      throw new ConflictError('User with this email already exists');
    }

    // Hash password
    const saltRounds = config.get('auth.saltRounds') || 12;
    const hashedPassword = await bcrypt.hash(password, saltRounds);

    // Create user
    const userData = {
      email,
      password: hashedPassword,
      first_name: firstName,
      last_name: lastName,
      role: 'user',
      is_active: true,
      created_at: new Date(),
      updated_at: new Date()
    };

    const [newUser] = await DatabaseOperations.users.create(userData);
    
    // Remove password from response
    const { password: _, ...userResponse } = newUser;

    // Generate tokens
    const tokenPayload = {
      userId: newUser.id,
      email: newUser.email,
      role: newUser.role
    };

    const accessToken = generateToken(tokenPayload);
    const refreshTokenPayload = { ...tokenPayload, type: 'refresh' };
    const refreshToken = generateToken(refreshTokenPayload, '7d');

    // Log user registration
    logger.userActivity(newUser.id, 'user_registered', {
      email: newUser.email,
      ip: req.ip
    });

    res.status(201).json({
      message: 'User registered successfully',
      user: userResponse,
      tokens: {
        accessToken,
        refreshToken,
        expiresIn: config.get('jwt.expiresIn')
      }
    });
  })
);

/**
 * @swagger
 * /auth/login:
 *   post:
 *     summary: Login user
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Login successful
 *       401:
 *         description: Invalid credentials
 */
router.post('/login',
  authLimiter,
  trackUserLogin,
  [
    body('email')
      .isEmail()
      .normalizeEmail()
      .withMessage('Valid email is required'),
    body('password')
      .notEmpty()
      .withMessage('Password is required')
  ],
  asyncHandler(async (req, res) => {
    // Check validation results
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      throw new ValidationError('Validation failed', errors.array());
    }

    const { email, password } = req.body;

    // Find user
    const users = await DatabaseOperations.users.findByEmail(email);
    if (users.length === 0) {
      logger.security('Login attempt with non-existent email', {
        email,
        ip: req.ip,
        userAgent: req.get('User-Agent')
      });
      throw new UnauthorizedError('Invalid credentials');
    }

    const user = users[0];

    // Check if user is active
    if (!user.is_active) {
      logger.security('Login attempt with inactive account', {
        userId: user.id,
        email,
        ip: req.ip
      });
      throw new UnauthorizedError('Account is deactivated');
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      logger.security('Login attempt with invalid password', {
        userId: user.id,
        email,
        ip: req.ip,
        userAgent: req.get('User-Agent')
      });
      throw new UnauthorizedError('Invalid credentials');
    }

    // Generate tokens
    const tokenPayload = {
      userId: user.id,
      email: user.email,
      role: user.role
    };

    const accessToken = generateToken(tokenPayload);
    const refreshTokenPayload = { ...tokenPayload, type: 'refresh' };
    const refreshToken = generateToken(refreshTokenPayload, '7d');

    // Update last login
    await DatabaseOperations.users.update(user.id, {
      last_login: new Date(),
      updated_at: new Date()
    });

    // Cache user session info (if Redis is enabled)
    if (config.get('redis.enabled')) {
      try {
        await CacheOperations.setObject(`user_session:${user.id}`, {
          userId: user.id,
          email: user.email,
          role: user.role,
          loginTime: new Date().toISOString(),
          ip: req.ip
        }, 3600); // 1 hour cache
      } catch (redisError) {
        logger.warn('Failed to cache user session', { error: redisError.message });
      }
    }

    // Remove password from response
    const { password: _, ...userResponse } = user;

    // Log successful login
    logger.userActivity(user.id, 'user_login', {
      email: user.email,
      ip: req.ip,
      userAgent: req.get('User-Agent')
    });

    res.status(200).json({
      message: 'Login successful',
      user: userResponse,
      tokens: {
        accessToken,
        refreshToken,
        expiresIn: config.get('jwt.expiresIn')
      }
    });
  })
);

/**
 * @swagger
 * /auth/refresh:
 *   post:
 *     summary: Refresh access token
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - refreshToken
 *             properties:
 *               refreshToken:
 *                 type: string
 *     responses:
 *       200:
 *         description: Token refreshed successfully
 *       401:
 *         description: Invalid refresh token
 */
router.post('/refresh',
  [
    body('refreshToken')
      .notEmpty()
      .withMessage('Refresh token is required')
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      throw new ValidationError('Validation failed', errors.array());
    }

    const { refreshToken } = req.body;

    // Verify refresh token
    const decoded = verifyRefreshToken(refreshToken);

    // Check if refresh token is blacklisted
    if (config.get('redis.enabled')) {
      try {
        const isBlacklisted = await CacheOperations.getWithPrefix('blacklist', refreshToken);
        if (isBlacklisted) {
          throw new UnauthorizedError('Refresh token has been revoked');
        }
      } catch (redisError) {
        logger.warn('Redis check failed during refresh token validation', { error: redisError.message });
      }
    }

    // Get current user data
    const users = await DatabaseOperations.users.findById(decoded.userId);
    if (users.length === 0) {
      throw new UnauthorizedError('User not found');
    }

    const user = users[0];
    if (!user.is_active) {
      throw new UnauthorizedError('Account is deactivated');
    }

    // Generate new tokens
    const tokenPayload = {
      userId: user.id,
      email: user.email,
      role: user.role
    };

    const accessToken = generateToken(tokenPayload);
    const newRefreshToken = generateToken({ ...tokenPayload, type: 'refresh' }, '7d');

    // Blacklist old refresh token
    await blacklistToken(refreshToken, 7 * 24 * 3600); // 7 days

    logger.userActivity(user.id, 'token_refresh', {
      ip: req.ip,
      userAgent: req.get('User-Agent')
    });

    res.status(200).json({
      message: 'Token refreshed successfully',
      tokens: {
        accessToken,
        refreshToken: newRefreshToken,
        expiresIn: config.get('jwt.expiresIn')
      }
    });
  })
);

/**
 * @swagger
 * /auth/logout:
 *   post:
 *     summary: Logout user
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Logout successful
 *       401:
 *         description: Unauthorized
 */
router.post('/logout',
  verifyToken,
  asyncHandler(async (req, res) => {
    const { token } = req;
    const userId = req.user.id;

    // Blacklist current access token
    await blacklistToken(token, 3600); // 1 hour (or until natural expiration)

    // Clear user session cache
    if (config.get('redis.enabled')) {
      try {
        await CacheOperations.del(`user_session:${userId}`);
      } catch (redisError) {
        logger.warn('Failed to clear user session cache', { error: redisError.message });
      }
    }

    logger.userActivity(userId, 'user_logout', {
      ip: req.ip,
      userAgent: req.get('User-Agent')
    });

    res.status(200).json({
      message: 'Logout successful'
    });
  })
);

/**
 * @swagger
 * /auth/profile:
 *   get:
 *     summary: Get user profile
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User profile retrieved successfully
 *       401:
 *         description: Unauthorized
 */
router.get('/profile',
  verifyToken,
  asyncHandler(async (req, res) => {
    const userId = req.user.id;

    // Get current user data
    const users = await DatabaseOperations.users.findById(userId);
    if (users.length === 0) {
      throw new NotFoundError('User');
    }

    const user = users[0];
    const { password, ...userProfile } = user;

    res.status(200).json({
      message: 'Profile retrieved successfully',
      user: userProfile
    });
  })
);

/**
 * @swagger
 * /auth/change-password:
 *   post:
 *     summary: Change user password
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - currentPassword
 *               - newPassword
 *             properties:
 *               currentPassword:
 *                 type: string
 *               newPassword:
 *                 type: string
 *                 minLength: 8
 *     responses:
 *       200:
 *         description: Password changed successfully
 *       400:
 *         description: Validation error
 *       401:
 *         description: Invalid current password
 */
router.post('/change-password',
  verifyToken,
  [
    body('currentPassword')
      .notEmpty()
      .withMessage('Current password is required'),
    body('newPassword')
      .isLength({ min: 8 })
      .withMessage('New password must be at least 8 characters long')
      .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
      .withMessage('New password must contain uppercase, lowercase, number and special character')
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      throw new ValidationError('Validation failed', errors.array());
    }

    const { currentPassword, newPassword } = req.body;
    const userId = req.user.id;

    // Get current user
    const users = await DatabaseOperations.users.findById(userId);
    if (users.length === 0) {
      throw new NotFoundError('User');
    }

    const user = users[0];

    // Verify current password
    const isValidPassword = await bcrypt.compare(currentPassword, user.password);
    if (!isValidPassword) {
      logger.security('Invalid current password during password change', {
        userId,
        ip: req.ip
      });
      throw new UnauthorizedError('Current password is incorrect');
    }

    // Hash new password
    const saltRounds = config.get('auth.saltRounds') || 12;
    const hashedNewPassword = await bcrypt.hash(newPassword, saltRounds);

    // Update password
    await DatabaseOperations.users.update(userId, {
      password: hashedNewPassword,
      updated_at: new Date()
    });

    logger.userActivity(userId, 'password_changed', {
      ip: req.ip,
      userAgent: req.get('User-Agent')
    });

    res.status(200).json({
      message: 'Password changed successfully'
    });
  })
);

module.exports = router;