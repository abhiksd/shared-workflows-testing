const express = require('express');
const config = require('config');
const logger = require('../utils/logger');
const { checkDatabaseHealth } = require('../config/database');
const { healthChecks, getMetrics } = require('../middleware/monitoring');

const router = express.Router();

// Basic health check
router.get('/', async (req, res) => {
  try {
    const health = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: config.get('app.environment'),
      version: config.get('app.version'),
      nodeVersion: process.version
    };
    
    res.status(200).json(health);
  } catch (error) {
    logger.error('Health check failed', { error: error.message });
    res.status(500).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Detailed health check
router.get('/detailed', async (req, res) => {
  try {
    const startTime = Date.now();
    
    // Check database
    const databaseHealth = await checkDatabaseHealth();
    healthChecks.database.set(databaseHealth.status === 'healthy' ? 1 : 0);
    
    // Check Redis if enabled
    let redisHealth = { status: 'disabled' };
    if (config.get('redis.enabled')) {
      try {
        const { checkRedisHealth } = require('../config/redis');
        redisHealth = await checkRedisHealth();
        healthChecks.redis.set(redisHealth.status === 'healthy' ? 1 : 0);
      } catch (error) {
        redisHealth = { status: 'unhealthy', error: error.message };
        healthChecks.redis.set(0);
      }
    }
    
    // Check external APIs
    let externalApiHealth = { status: 'healthy' };
    try {
      // Add external API health checks here
      healthChecks.external_api.set(1);
    } catch (error) {
      externalApiHealth = { status: 'unhealthy', error: error.message };
      healthChecks.external_api.set(0);
    }
    
    // Memory usage
    const memoryUsage = process.memoryUsage();
    const memoryInfo = {
      rss: `${Math.round(memoryUsage.rss / 1024 / 1024)} MB`,
      heapUsed: `${Math.round(memoryUsage.heapUsed / 1024 / 1024)} MB`,
      heapTotal: `${Math.round(memoryUsage.heapTotal / 1024 / 1024)} MB`,
      external: `${Math.round(memoryUsage.external / 1024 / 1024)} MB`
    };
    
    // CPU usage
    const cpuUsage = process.cpuUsage();
    
    // Determine overall health
    const isHealthy = databaseHealth.status === 'healthy' && 
                     (redisHealth.status === 'healthy' || redisHealth.status === 'disabled') &&
                     externalApiHealth.status === 'healthy';
    
    const health = {
      status: isHealthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: config.get('app.environment'),
      version: config.get('app.version'),
      nodeVersion: process.version,
      pid: process.pid,
      responseTime: `${Date.now() - startTime}ms`,
      checks: {
        database: databaseHealth,
        redis: redisHealth,
        externalApi: externalApiHealth
      },
      system: {
        memory: memoryInfo,
        cpu: {
          user: cpuUsage.user,
          system: cpuUsage.system
        },
        platform: process.platform,
        arch: process.arch
      }
    };
    
    const statusCode = isHealthy ? 200 : 503;
    res.status(statusCode).json(health);
    
  } catch (error) {
    logger.error('Detailed health check failed', { error: error.message });
    res.status(500).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Liveness probe (Kubernetes)
router.get('/live', (req, res) => {
  // Simple check to ensure the application is running
  res.status(200).json({
    status: 'alive',
    timestamp: new Date().toISOString()
  });
});

// Readiness probe (Kubernetes)
router.get('/ready', async (req, res) => {
  try {
    // Check if application is ready to serve traffic
    const databaseHealth = await checkDatabaseHealth();
    
    let redisReady = true;
    if (config.get('redis.enabled')) {
      try {
        const { checkRedisHealth } = require('../config/redis');
        const redisHealth = await checkRedisHealth();
        redisReady = redisHealth.status === 'healthy';
      } catch (error) {
        redisReady = false;
      }
    }
    
    const isReady = databaseHealth.status === 'healthy' && redisReady;
    
    const response = {
      status: isReady ? 'ready' : 'not ready',
      timestamp: new Date().toISOString(),
      checks: {
        database: databaseHealth.status,
        redis: redisReady ? 'ready' : 'not ready'
      }
    };
    
    const statusCode = isReady ? 200 : 503;
    res.status(statusCode).json(response);
    
  } catch (error) {
    logger.error('Readiness check failed', { error: error.message });
    res.status(503).json({
      status: 'not ready',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Startup probe (Kubernetes)
router.get('/startup', async (req, res) => {
  try {
    // Check if application has started successfully
    const response = {
      status: 'started',
      timestamp: new Date().toISOString(),
      uptime: process.uptime()
    };
    
    res.status(200).json(response);
    
  } catch (error) {
    logger.error('Startup check failed', { error: error.message });
    res.status(503).json({
      status: 'not started',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Prometheus metrics endpoint
router.get('/metrics', async (req, res) => {
  try {
    const metrics = await getMetrics();
    res.set('Content-Type', 'text/plain');
    res.status(200).send(metrics);
  } catch (error) {
    logger.error('Failed to get metrics', { error: error.message });
    res.status(500).json({
      error: 'Failed to get metrics',
      timestamp: new Date().toISOString()
    });
  }
});

// Application info
router.get('/info', (req, res) => {
  const info = {
    name: config.get('app.name'),
    version: config.get('app.version'),
    environment: config.get('app.environment'),
    nodeVersion: process.version,
    platform: process.platform,
    arch: process.arch,
    pid: process.pid,
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  };
  
  res.status(200).json(info);
});

// Database connection test
router.get('/db', async (req, res) => {
  try {
    const databaseHealth = await checkDatabaseHealth();
    const statusCode = databaseHealth.status === 'healthy' ? 200 : 503;
    res.status(statusCode).json(databaseHealth);
  } catch (error) {
    logger.error('Database health check failed', { error: error.message });
    res.status(503).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Redis connection test
router.get('/redis', async (req, res) => {
  if (!config.get('redis.enabled')) {
    return res.status(200).json({
      status: 'disabled',
      timestamp: new Date().toISOString()
    });
  }
  
  try {
    const { checkRedisHealth } = require('../config/redis');
    const redisHealth = await checkRedisHealth();
    const statusCode = redisHealth.status === 'healthy' ? 200 : 503;
    res.status(statusCode).json(redisHealth);
  } catch (error) {
    logger.error('Redis health check failed', { error: error.message });
    res.status(503).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

module.exports = router;