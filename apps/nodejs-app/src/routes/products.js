const express = require('express');
const { body, query, validationResult } = require('express-validator');
const config = require('config');

const logger = require('../utils/logger');
const { DatabaseOperations } = require('../config/database');
const { CacheOperations } = require('../config/redis');
const { requireRole } = require('../middleware/auth');
const { 
  asyncHandler,
  ValidationError,
  NotFoundError,
  ForbiddenError
} = require('../middleware/errorHandler');

const router = express.Router();

/**
 * @swagger
 * /products:
 *   get:
 *     summary: Get list of products
 *     tags: [Products]
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
 *         name: category
 *         schema:
 *           type: string
 *         description: Filter by category
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Search in name and description
 *     responses:
 *       200:
 *         description: List of products
 *       401:
 *         description: Unauthorized
 */
router.get('/',
  [
    query('page')
      .optional()
      .isInt({ min: 1 })
      .withMessage('Page must be a positive integer'),
    query('limit')
      .optional()
      .isInt({ min: 1, max: 100 })
      .withMessage('Limit must be between 1 and 100'),
    query('category')
      .optional()
      .isLength({ max: 50 })
      .withMessage('Category name too long'),
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
    const category = req.query.category || '';
    const search = req.query.search || '';
    const offset = (page - 1) * limit;

    // Cache key for this query
    const cacheKey = `products_list:${page}:${limit}:${category}:${search}`;
    
    // Try to get from cache first
    if (config.get('redis.enabled')) {
      try {
        const cached = await CacheOperations.getObject(cacheKey);
        if (cached) {
          logger.cache('products_list', cacheKey, true, 0);
          return res.status(200).json(cached);
        }
      } catch (redisError) {
        logger.warn('Cache retrieval failed', { error: redisError.message });
      }
    }

    // Build query
    const db = require('../config/database').getDatabase();
    let query = db('products').select(
      'id', 'name', 'description', 'price', 'category', 
      'stock_quantity', 'is_active', 'created_at', 'updated_at'
    ).where('is_active', true);

    // Add filters
    if (category) {
      query = query.where('category', 'ilike', `%${category}%`);
    }

    if (search) {
      query = query.where(function() {
        this.where('name', 'ilike', `%${search}%`)
            .orWhere('description', 'ilike', `%${search}%`);
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
      message: 'Products retrieved successfully',
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
        logger.cache('products_list', cacheKey, false, 0);
      } catch (redisError) {
        logger.warn('Cache storage failed', { error: redisError.message });
      }
    }

    logger.userActivity(req.user.id, 'products_viewed', {
      search,
      category,
      page,
      limit,
      total
    });

    res.status(200).json(response);
  })
);

/**
 * @swagger
 * /products/{id}:
 *   get:
 *     summary: Get product by ID
 *     tags: [Products]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Product ID
 *     responses:
 *       200:
 *         description: Product retrieved successfully
 *       404:
 *         description: Product not found
 */
router.get('/:id',
  asyncHandler(async (req, res) => {
    const { id } = req.params;

    // Try cache first
    const cacheKey = `product:${id}`;
    
    if (config.get('redis.enabled')) {
      try {
        const cached = await CacheOperations.getObject(cacheKey);
        if (cached) {
          logger.cache('product_detail', cacheKey, true, 0);
          return res.status(200).json({
            message: 'Product retrieved successfully',
            product: cached
          });
        }
      } catch (redisError) {
        logger.warn('Cache retrieval failed', { error: redisError.message });
      }
    }

    // Get from database
    const products = await DatabaseOperations.products.findById(id);
    if (products.length === 0) {
      throw new NotFoundError('Product');
    }

    const product = products[0];

    // Cache the product
    if (config.get('redis.enabled')) {
      try {
        await CacheOperations.setObject(cacheKey, product, 600); // 10 minutes
        logger.cache('product_detail', cacheKey, false, 0);
      } catch (redisError) {
        logger.warn('Cache storage failed', { error: redisError.message });
      }
    }

    logger.userActivity(req.user.id, 'product_viewed', {
      productId: id,
      productName: product.name
    });

    res.status(200).json({
      message: 'Product retrieved successfully',
      product
    });
  })
);

/**
 * @swagger
 * /products:
 *   post:
 *     summary: Create new product (Admin only)
 *     tags: [Products]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *               - description
 *               - price
 *               - category
 *               - stockQuantity
 *             properties:
 *               name:
 *                 type: string
 *               description:
 *                 type: string
 *               price:
 *                 type: number
 *                 minimum: 0
 *               category:
 *                 type: string
 *               stockQuantity:
 *                 type: integer
 *                 minimum: 0
 *     responses:
 *       201:
 *         description: Product created successfully
 *       400:
 *         description: Validation error
 *       403:
 *         description: Forbidden
 */
router.post('/',
  requireRole(['admin', 'super_admin']),
  [
    body('name')
      .trim()
      .isLength({ min: 1, max: 200 })
      .withMessage('Product name is required and must be less than 200 characters'),
    body('description')
      .trim()
      .isLength({ min: 1, max: 1000 })
      .withMessage('Product description is required and must be less than 1000 characters'),
    body('price')
      .isFloat({ min: 0 })
      .withMessage('Price must be a positive number'),
    body('category')
      .trim()
      .isLength({ min: 1, max: 100 })
      .withMessage('Category is required and must be less than 100 characters'),
    body('stockQuantity')
      .isInt({ min: 0 })
      .withMessage('Stock quantity must be a non-negative integer')
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      throw new ValidationError('Validation failed', errors.array());
    }

    const { name, description, price, category, stockQuantity } = req.body;

    // Create product
    const productData = {
      name,
      description,
      price: parseFloat(price),
      category,
      stock_quantity: parseInt(stockQuantity),
      is_active: true,
      created_by: req.user.id,
      created_at: new Date(),
      updated_at: new Date()
    };

    const [newProduct] = await DatabaseOperations.products.create(productData);

    // Invalidate products list cache
    if (config.get('redis.enabled')) {
      try {
        await CacheOperations.deletePattern('products_list:*');
      } catch (redisError) {
        logger.warn('Cache invalidation failed', { error: redisError.message });
      }
    }

    logger.userActivity(req.user.id, 'product_created', {
      productId: newProduct.id,
      productName: name,
      category,
      price
    });

    res.status(201).json({
      message: 'Product created successfully',
      product: newProduct
    });
  })
);

/**
 * @swagger
 * /products/{id}:
 *   put:
 *     summary: Update product (Admin only)
 *     tags: [Products]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Product ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               description:
 *                 type: string
 *               price:
 *                 type: number
 *                 minimum: 0
 *               category:
 *                 type: string
 *               stockQuantity:
 *                 type: integer
 *                 minimum: 0
 *               isActive:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Product updated successfully
 *       400:
 *         description: Validation error
 *       403:
 *         description: Forbidden
 *       404:
 *         description: Product not found
 */
router.put('/:id',
  requireRole(['admin', 'super_admin']),
  [
    body('name')
      .optional()
      .trim()
      .isLength({ min: 1, max: 200 })
      .withMessage('Product name must be less than 200 characters'),
    body('description')
      .optional()
      .trim()
      .isLength({ min: 1, max: 1000 })
      .withMessage('Product description must be less than 1000 characters'),
    body('price')
      .optional()
      .isFloat({ min: 0 })
      .withMessage('Price must be a positive number'),
    body('category')
      .optional()
      .trim()
      .isLength({ min: 1, max: 100 })
      .withMessage('Category must be less than 100 characters'),
    body('stockQuantity')
      .optional()
      .isInt({ min: 0 })
      .withMessage('Stock quantity must be a non-negative integer'),
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
    const { name, description, price, category, stockQuantity, isActive } = req.body;

    // Check if product exists
    const products = await DatabaseOperations.products.findById(id);
    if (products.length === 0) {
      throw new NotFoundError('Product');
    }

    // Prepare update data
    const updateData = {
      updated_at: new Date(),
      updated_by: req.user.id
    };

    if (name !== undefined) updateData.name = name;
    if (description !== undefined) updateData.description = description;
    if (price !== undefined) updateData.price = parseFloat(price);
    if (category !== undefined) updateData.category = category;
    if (stockQuantity !== undefined) updateData.stock_quantity = parseInt(stockQuantity);
    if (isActive !== undefined) updateData.is_active = isActive;

    // Update product
    const [updatedProduct] = await DatabaseOperations.products.update(id, updateData);

    // Invalidate caches
    if (config.get('redis.enabled')) {
      try {
        await CacheOperations.del(`product:${id}`);
        await CacheOperations.deletePattern('products_list:*');
      } catch (redisError) {
        logger.warn('Cache invalidation failed', { error: redisError.message });
      }
    }

    logger.userActivity(req.user.id, 'product_updated', {
      productId: id,
      updatedFields: Object.keys(updateData).filter(key => !key.includes('_at') && !key.includes('_by'))
    });

    res.status(200).json({
      message: 'Product updated successfully',
      product: updatedProduct
    });
  })
);

/**
 * @swagger
 * /products/{id}:
 *   delete:
 *     summary: Delete product (Admin only)
 *     tags: [Products]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Product ID
 *     responses:
 *       200:
 *         description: Product deleted successfully
 *       403:
 *         description: Forbidden
 *       404:
 *         description: Product not found
 */
router.delete('/:id',
  requireRole(['admin', 'super_admin']),
  asyncHandler(async (req, res) => {
    const { id } = req.params;

    // Check if product exists
    const products = await DatabaseOperations.products.findById(id);
    if (products.length === 0) {
      throw new NotFoundError('Product');
    }

    const product = products[0];

    // Soft delete by deactivating
    await DatabaseOperations.products.update(id, {
      is_active: false,
      updated_at: new Date(),
      updated_by: req.user.id
    });

    // Invalidate caches
    if (config.get('redis.enabled')) {
      try {
        await CacheOperations.del(`product:${id}`);
        await CacheOperations.deletePattern('products_list:*');
      } catch (redisError) {
        logger.warn('Cache invalidation failed', { error: redisError.message });
      }
    }

    logger.userActivity(req.user.id, 'product_deleted', {
      productId: id,
      productName: product.name
    });

    res.status(200).json({
      message: 'Product deactivated successfully'
    });
  })
);

/**
 * @swagger
 * /products/search:
 *   get:
 *     summary: Search products
 *     tags: [Products]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: q
 *         required: true
 *         schema:
 *           type: string
 *         description: Search query
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 50
 *         description: Number of results to return
 *     responses:
 *       200:
 *         description: Search results
 *       400:
 *         description: Validation error
 */
router.get('/search',
  [
    query('q')
      .notEmpty()
      .isLength({ min: 1, max: 100 })
      .withMessage('Search query is required and must be less than 100 characters'),
    query('limit')
      .optional()
      .isInt({ min: 1, max: 50 })
      .withMessage('Limit must be between 1 and 50')
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      throw new ValidationError('Validation failed', errors.array());
    }

    const searchQuery = req.query.q;
    const limit = parseInt(req.query.limit) || 20;

    // Cache key for this search
    const cacheKey = `product_search:${Buffer.from(searchQuery).toString('base64')}:${limit}`;
    
    // Try cache first
    if (config.get('redis.enabled')) {
      try {
        const cached = await CacheOperations.getObject(cacheKey);
        if (cached) {
          logger.cache('product_search', cacheKey, true, 0);
          return res.status(200).json(cached);
        }
      } catch (redisError) {
        logger.warn('Cache retrieval failed', { error: redisError.message });
      }
    }

    // Perform search
    const results = await DatabaseOperations.products.search(searchQuery);
    const limitedResults = results.slice(0, limit);

    const response = {
      message: 'Search completed successfully',
      query: searchQuery,
      totalResults: results.length,
      results: limitedResults
    };

    // Cache the results
    if (config.get('redis.enabled')) {
      try {
        await CacheOperations.setObject(cacheKey, response, 600); // 10 minutes
        logger.cache('product_search', cacheKey, false, 0);
      } catch (redisError) {
        logger.warn('Cache storage failed', { error: redisError.message });
      }
    }

    logger.userActivity(req.user.id, 'product_search', {
      query: searchQuery,
      resultCount: limitedResults.length
    });

    res.status(200).json(response);
  })
);

module.exports = router;