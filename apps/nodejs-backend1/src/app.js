require('dotenv').config();
const express = require('express');
const config = require('config');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

// Import custom modules
const logger = require('./utils/logger');
const { initializeMonitoring } = require('./middleware/monitoring');
const { initializeDatabase } = require('./config/database');
const { initializeRedis } = require('./config/redis');
const { initializeAzureServices } = require('./config/azure');
const errorHandler = require('./middleware/errorHandler');
const authMiddleware = require('./middleware/auth');

// Import routes
const healthRoutes = require('./routes/health');
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const productRoutes = require('./routes/products');
const orderRoutes = require('./routes/orders');
const fileRoutes = require('./routes/files');

class Application {
  constructor() {
    this.app = express();
    this.port = config.get('server.port') || 3000;
    this.environment = config.get('app.environment') || 'development';
  }

  async initialize() {
    try {
      // Initialize monitoring first
      await initializeMonitoring();
      
      // Initialize external services
      await this.initializeServices();
      
      // Setup middleware
      this.setupMiddleware();
      
      // Setup routes
      this.setupRoutes();
      
      // Setup error handling
      this.setupErrorHandling();
      
      logger.info('Application initialized successfully', {
        environment: this.environment,
        port: this.port
      });
    } catch (error) {
      logger.error('Failed to initialize application', { error: error.message });
      process.exit(1);
    }
  }

  async initializeServices() {
    logger.info('Initializing external services...');
    
    try {
      // Initialize database
      await initializeDatabase();
      logger.info('Database initialized');
      
      // Initialize Redis (optional)
      if (config.get('redis.enabled')) {
        await initializeRedis();
        logger.info('Redis initialized');
      }
      
      // Initialize Azure services (optional)
      if (config.get('azure.enabled')) {
        await initializeAzureServices();
        logger.info('Azure services initialized');
      }
    } catch (error) {
      logger.error('Failed to initialize services', { error: error.message });
      throw error;
    }
  }

  setupMiddleware() {
    logger.info('Setting up middleware...');
    
    // Trust proxy (important for Azure/Kubernetes)
    this.app.set('trust proxy', 1);
    
    // Security middleware
    this.app.use(helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          scriptSrc: ["'self'"],
          imgSrc: ["'self'", "data:", "https:"],
        },
      },
      hsts: {
        maxAge: 31536000,
        includeSubDomains: true,
        preload: true
      }
    }));
    
    // CORS
    const corsOptions = {
      origin: config.get('cors.allowedOrigins'),
      methods: config.get('cors.allowedMethods'),
      allowedHeaders: config.get('cors.allowedHeaders'),
      credentials: config.get('cors.allowCredentials'),
      maxAge: config.get('cors.maxAge')
    };
    this.app.use(cors(corsOptions));
    
    // Compression
    this.app.use(compression());
    
    // Rate limiting
    const limiter = rateLimit({
      windowMs: 60 * 1000, // 1 minute
      max: config.get('rateLimit.requestsPerMinute'),
      message: {
        error: 'Too many requests from this IP, please try again later.',
        retryAfter: '60 seconds'
      },
      standardHeaders: true,
      legacyHeaders: false,
    });
    this.app.use('/api/', limiter);
    
    // Body parsing
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true, limit: '10mb' }));
    
    // Logging
    if (this.environment !== 'test') {
      this.app.use(morgan('combined', {
        stream: {
          write: (message) => logger.info(message.trim())
        }
      }));
    }
    
    // Request ID middleware
    this.app.use((req, res, next) => {
      req.id = require('uuid').v4();
      res.setHeader('X-Request-ID', req.id);
      next();
    });
    
    // Request timing
    this.app.use((req, res, next) => {
      req.startTime = Date.now();
      next();
    });
  }

  setupRoutes() {
    logger.info('Setting up routes...');
    
    // Health check routes (no auth required)
    this.app.use('/health', healthRoutes);
    this.app.use('/api/health', healthRoutes);
    
    // API routes with authentication
    this.app.use('/api/auth', authRoutes);
    this.app.use('/api/users', authMiddleware, userRoutes);
    this.app.use('/api/products', authMiddleware, productRoutes);
    this.app.use('/api/orders', authMiddleware, orderRoutes);
    this.app.use('/api/files', authMiddleware, fileRoutes);
    
    // API documentation
    if (this.environment !== 'production') {
      const swaggerJsDoc = require('swagger-jsdoc');
      const swaggerUi = require('swagger-ui-express');
      
      const swaggerOptions = {
        definition: {
          openapi: '3.0.0',
          info: {
            title: 'Node.js Backend API',
            version: '1.0.0',
            description: 'Production-ready Node.js backend application API',
          },
          servers: [
            {
              url: `http://localhost:${this.port}/api`,
              description: 'Development server',
            },
          ],
        },
        apis: ['./src/routes/*.js'],
      };
      
      const specs = swaggerJsDoc(swaggerOptions);
      this.app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(specs));
    }
    
    // 404 handler
    this.app.use('*', (req, res) => {
      res.status(404).json({
        error: 'Route not found',
        message: `Cannot ${req.method} ${req.originalUrl}`,
        timestamp: new Date().toISOString()
      });
    });
  }

  setupErrorHandling() {
    // Global error handler
    this.app.use(errorHandler);
    
    // Graceful shutdown
    const gracefulShutdown = async (signal) => {
      logger.info(`Received ${signal}. Starting graceful shutdown...`);
      
      const server = this.server;
      if (server) {
        server.close(async () => {
          try {
            // Close database connections
            const { closeDatabase } = require('./config/database');
            await closeDatabase();
            
            // Close Redis connections
            if (config.get('redis.enabled')) {
              const { closeRedis } = require('./config/redis');
              await closeRedis();
            }
            
            logger.info('Graceful shutdown completed');
            process.exit(0);
          } catch (error) {
            logger.error('Error during graceful shutdown', { error: error.message });
            process.exit(1);
          }
        });
      } else {
        process.exit(0);
      }
    };
    
    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));
    
    // Handle uncaught exceptions
    process.on('uncaughtException', (error) => {
      logger.error('Uncaught Exception', { error: error.message, stack: error.stack });
      process.exit(1);
    });
    
    // Handle unhandled promise rejections
    process.on('unhandledRejection', (reason, promise) => {
      logger.error('Unhandled Rejection', { reason, promise });
      process.exit(1);
    });
  }

  async start() {
    try {
      await this.initialize();
      
      this.server = this.app.listen(this.port, () => {
        logger.info(`Server started successfully`, {
          port: this.port,
          environment: this.environment,
          nodeVersion: process.version,
          pid: process.pid
        });
      });
      
      return this.server;
    } catch (error) {
      logger.error('Failed to start server', { error: error.message });
      process.exit(1);
    }
  }
}

// Start the application
if (require.main === module) {
  const app = new Application();
  app.start();
}

module.exports = Application;