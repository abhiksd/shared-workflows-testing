const express = require('express');
const { body, query, validationResult } = require('express-validator');
const bcrypt = require('bcryptjs');
const config = require('config');

const logger = require('../utils/logger');
const { DatabaseOperations } = require('../config/database');
const { CacheOperations } = require('../config/redis');
const { requireRole, requireOwnership } = require('../middleware/auth');
const { 
  asyncHandler,
  ValidationError,
  NotFoundError,
  ConflictError,
  ForbiddenError
} = require('../middleware/errorHandler');

const router = express.Router();

/**
 * @swagger
 * /users:
 *   get:
 *     summary: Get list of users (Admin only)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           minimum: 1
 *         description: Page number
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 100
 *         description: Number of items per page
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Search term for email or name
 *     responses:
 *       200:
 *         description: List of users
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Forbidden
 */
router.get('/',
  requireRole(['admin', 'super_admin']),
  [
    query('page')
      .optional()
      .isInt({ min: 1 })
      .withMessage('Page must be a positive integer'),
    query('limit')
      .optional()
      .isInt({ min: 1, max: 100 })
      .withMessage('Limit must be between 1 and 100'),
    query('search')
      .optional()
      .isLength({ max: 100 })
      .withMessage('Search term too long')
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      throw new ValidationError('Validation failed', errors.array());
    }

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const search = req.query.search || '';
    const offset = (page - 1) * limit;

    // Cache key for this query
    const cacheKey = `users_list:${page}:${limit}:${search}`;
    
    // Try to get from cache first
    let users = null;
    if (config.get('redis.enabled')) {
      try {
        users = await CacheOperations.getObject(cacheKey);
        if (users) {
          logger.cache('users_list', cacheKey, true, 0);
          return res.status(200).json(users);
        }
      } catch (redisError) {
        logger.warn('Cache retrieval failed', { error: redisError.message });
      }
    }

    // Build query
    const db = require('../config/database').getDatabase();
    let query = db('users').select(
      'id', 'email', 'first_name', 'last_name', 'role', 
      'is_active', 'created_at', 'updated_at', 'last_login'
    );

    // Add search filter
    if (search) {
      query = query.where(function() {
        this.where('email', 'ilike', `%${search}%`)
            .orWhere('first_name', 'ilike', `%${search}%`)
            .orWhere('last_name', 'ilike', `%${search}%`);
      });
    }

    // Get total count
    const totalQuery = query.clone();
    const [{ count }] = await totalQuery.count('* as count');
    const total = parseInt(count);

    // Get paginated results
    const results = await query
      .limit(limit)
      .offset(offset)
      .orderBy('created_at', 'desc');

    const response = {
      message: 'Users retrieved successfully',
      data: results,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNext: page < Math.ceil(total / limit),
        hasPrev: page > 1
      }
    };

    // Cache the results
    if (config.get('redis.enabled')) {
      try {
        await CacheOperations.setObject(cacheKey, response, 300); // 5 minutes
        logger.cache('users_list', cacheKey, false, 0);
      } catch (redisError) {
        logger.warn('Cache storage failed', { error: redisError.message });
      }
    }

    logger.userActivity(req.user.id, 'users_list_viewed', {
      search,
      page,
      limit,
      total
    });

    res.status(200).json(response);
  })
);

/**
 * @swagger
 * /users/{id}:
 *   get:
 *     summary: Get user by ID
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: User ID
 *     responses:
 *       200:
 *         description: User retrieved successfully
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Forbidden
 *       404:
 *         description: User not found
 */
router.get('/:id',
  requireOwnership('id', 'user'),
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const requestingUserId = req.user.id;
    const requestingUserRole = req.user.role;

    // Check if user can access this profile
    if (id !== requestingUserId && !['admin', 'super_admin'].includes(requestingUserRole)) {
      throw new ForbiddenError('Access denied to this user profile');
    }

    // Try cache first
    let user = null;
    const cacheKey = `user_profile:${id}`;
    
    if (config.get('redis.enabled')) {
      try {
        user = await CacheOperations.getObject(cacheKey);
        if (user) {
          logger.cache('user_profile', cacheKey, true, 0);
          return res.status(200).json({
            message: 'User retrieved successfully',
            user
          });
        }
      } catch (redisError) {
        logger.warn('Cache retrieval failed', { error: redisError.message });
      }
    }

    // Get from database
    const users = await DatabaseOperations.users.findById(id);
    if (users.length === 0) {
      throw new NotFoundError('User');
    }

    const { password, ...userProfile } = users[0];

    // Cache the profile
    if (config.get('redis.enabled')) {
      try {
        await CacheOperations.setObject(cacheKey, userProfile, 600); // 10 minutes
        logger.cache('user_profile', cacheKey, false, 0);
      } catch (redisError) {
        logger.warn('Cache storage failed', { error: redisError.message });
      }
    }

    logger.userActivity(requestingUserId, 'user_profile_viewed', {
      targetUserId: id
    });

    res.status(200).json({
      message: 'User retrieved successfully',
      user: userProfile
    });
  })
);

/**
 * @swagger
 * /users:
 *   post:
 *     summary: Create new user (Admin only)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
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
 *               - role
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
 *               role:
 *                 type: string
 *                 enum: [user, admin]
 *     responses:
 *       201:
 *         description: User created successfully
 *       400:
 *         description: Validation error
 *       409:
 *         description: User already exists
 */
router.post('/',
  requireRole(['admin', 'super_admin']),
  [
    body('email')
      .isEmail()
      .normalizeEmail()
      .withMessage('Valid email is required'),
    body('password')
      .isLength({ min: 8 })
      .withMessage('Password must be at least 8 characters long'),
    body('firstName')
      .trim()
      .isLength({ min: 1, max: 50 })
      .withMessage('First name is required and must be less than 50 characters'),
    body('lastName')
      .trim()
      .isLength({ min: 1, max: 50 })
      .withMessage('Last name is required and must be less than 50 characters'),
    body('role')
      .isIn(['user', 'admin'])
      .withMessage('Role must be either user or admin')
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      throw new ValidationError('Validation failed', errors.array());
    }

    const { email, password, firstName, lastName, role } = req.body;

    // Only super_admin can create admin users
    if (role === 'admin' && req.user.role !== 'super_admin') {
      throw new ForbiddenError('Only super administrators can create admin users');
    }

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
      role,
      is_active: true,
      created_at: new Date(),
      updated_at: new Date()
    };

    const [newUser] = await DatabaseOperations.users.create(userData);
    const { password: _, ...userResponse } = newUser;

    // Invalidate users list cache
    if (config.get('redis.enabled')) {
      try {
        await CacheOperations.deletePattern('users_list:*');
      } catch (redisError) {
        logger.warn('Cache invalidation failed', { error: redisError.message });
      }
    }

    logger.userActivity(req.user.id, 'user_created', {
      createdUserId: newUser.id,
      createdUserEmail: email,
      createdUserRole: role
    });

    res.status(201).json({
      message: 'User created successfully',
      user: userResponse
    });
  })
);

/**
 * @swagger
 * /users/{id}:
 *   put:
 *     summary: Update user
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: User ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               firstName:
 *                 type: string
 *               lastName:
 *                 type: string
 *               role:
 *                 type: string
 *                 enum: [user, admin]
 *               isActive:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: User updated successfully
 *       400:
 *         description: Validation error
 *       403:
 *         description: Forbidden
 *       404:
 *         description: User not found
 */
router.put('/:id',
  requireOwnership('id', 'user'),
  [
    body('firstName')
      .optional()
      .trim()
      .isLength({ min: 1, max: 50 })
      .withMessage('First name must be less than 50 characters'),
    body('lastName')
      .optional()
      .trim()
      .isLength({ min: 1, max: 50 })
      .withMessage('Last name must be less than 50 characters'),
    body('role')
      .optional()
      .isIn(['user', 'admin'])
      .withMessage('Role must be either user or admin'),
    body('isActive')
      .optional()
      .isBoolean()
      .withMessage('isActive must be a boolean')
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      throw new ValidationError('Validation failed', errors.array());
    }

    const { id } = req.params;
    const { firstName, lastName, role, isActive } = req.body;
    const requestingUserId = req.user.id;
    const requestingUserRole = req.user.role;

    // Check if user exists
    const users = await DatabaseOperations.users.findById(id);
    if (users.length === 0) {
      throw new NotFoundError('User');
    }

    const targetUser = users[0];

    // Authorization checks
    const isOwnProfile = id === requestingUserId;
    const isAdmin = ['admin', 'super_admin'].includes(requestingUserRole);

    // Users can only update their own profile (limited fields)
    if (isOwnProfile && !isAdmin) {
      // Regular users can only update name fields
      if (role !== undefined || isActive !== undefined) {
        throw new ForbiddenError('Users cannot modify role or active status');
      }
    }

    // Only admins can update other users
    if (!isOwnProfile && !isAdmin) {
      throw new ForbiddenError('Access denied to modify this user');
    }

    // Only super_admin can modify admin users or set admin role
    if (targetUser.role === 'admin' && requestingUserRole !== 'super_admin') {
      throw new ForbiddenError('Only super administrators can modify admin users');
    }

    if (role === 'admin' && requestingUserRole !== 'super_admin') {
      throw new ForbiddenError('Only super administrators can assign admin role');
    }

    // Prepare update data
    const updateData = {
      updated_at: new Date()
    };

    if (firstName !== undefined) updateData.first_name = firstName;
    if (lastName !== undefined) updateData.last_name = lastName;
    if (role !== undefined) updateData.role = role;
    if (isActive !== undefined) updateData.is_active = isActive;

    // Update user
    const [updatedUser] = await DatabaseOperations.users.update(id, updateData);
    const { password: _, ...userResponse } = updatedUser;

    // Invalidate caches
    if (config.get('redis.enabled')) {
      try {
        await CacheOperations.del(`user_profile:${id}`);
        await CacheOperations.deletePattern('users_list:*');
      } catch (redisError) {
        logger.warn('Cache invalidation failed', { error: redisError.message });
      }
    }

    logger.userActivity(requestingUserId, 'user_updated', {
      targetUserId: id,
      updatedFields: Object.keys(updateData).filter(key => key !== 'updated_at'),
      isOwnProfile
    });

    res.status(200).json({
      message: 'User updated successfully',
      user: userResponse
    });
  })
);

/**
 * @swagger
 * /users/{id}:
 *   delete:
 *     summary: Delete user (Admin only)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: User ID
 *     responses:
 *       200:
 *         description: User deleted successfully
 *       403:
 *         description: Forbidden
 *       404:
 *         description: User not found
 */
router.delete('/:id',
  requireRole(['admin', 'super_admin']),
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const requestingUserRole = req.user.role;

    // Check if user exists
    const users = await DatabaseOperations.users.findById(id);
    if (users.length === 0) {
      throw new NotFoundError('User');
    }

    const targetUser = users[0];

    // Only super_admin can delete admin users
    if (targetUser.role === 'admin' && requestingUserRole !== 'super_admin') {
      throw new ForbiddenError('Only super administrators can delete admin users');
    }

    // Don't allow deleting yourself
    if (id === req.user.id) {
      throw new ForbiddenError('Cannot delete your own account');
    }

    // Soft delete by deactivating
    await DatabaseOperations.users.update(id, {
      is_active: false,
      updated_at: new Date()
    });

    // Invalidate caches
    if (config.get('redis.enabled')) {
      try {
        await CacheOperations.del(`user_profile:${id}`);
        await CacheOperations.del(`user_session:${id}`);
        await CacheOperations.deletePattern('users_list:*');
      } catch (redisError) {
        logger.warn('Cache invalidation failed', { error: redisError.message });
      }
    }

    logger.userActivity(req.user.id, 'user_deleted', {
      deletedUserId: id,
      deletedUserEmail: targetUser.email
    });

    res.status(200).json({
      message: 'User deactivated successfully'
    });
  })
);

/**
 * @swagger
 * /users/{id}/reactivate:
 *   post:
 *     summary: Reactivate user (Admin only)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: User ID
 *     responses:
 *       200:
 *         description: User reactivated successfully
 *       403:
 *         description: Forbidden
 *       404:
 *         description: User not found
 */
router.post('/:id/reactivate',
  requireRole(['admin', 'super_admin']),
  asyncHandler(async (req, res) => {
    const { id } = req.params;

    // Check if user exists
    const users = await DatabaseOperations.users.findById(id);
    if (users.length === 0) {
      throw new NotFoundError('User');
    }

    // Reactivate user
    const [reactivatedUser] = await DatabaseOperations.users.update(id, {
      is_active: true,
      updated_at: new Date()
    });

    const { password: _, ...userResponse } = reactivatedUser;

    // Invalidate caches
    if (config.get('redis.enabled')) {
      try {
        await CacheOperations.del(`user_profile:${id}`);
        await CacheOperations.deletePattern('users_list:*');
      } catch (redisError) {
        logger.warn('Cache invalidation failed', { error: redisError.message });
      }
    }

    logger.userActivity(req.user.id, 'user_reactivated', {
      reactivatedUserId: id,
      reactivatedUserEmail: reactivatedUser.email
    });

    res.status(200).json({
      message: 'User reactivated successfully',
      user: userResponse
    });
  })
);

module.exports = router;