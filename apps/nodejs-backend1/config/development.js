/**
 * Development Environment Configuration for Node.js Application
 */

module.exports = {
  app: {
    environment: 'development'
  },

  // PostgreSQL Database for development environment
  database: {
    host: process.env.DB_HOST || 'postgres-dev.postgres.database.azure.com',
    database: process.env.DB_NAME || 'nodejs_app_dev',
    username: process.env.DB_USERNAME || 'nodejs_dev_user',
    password: process.env.DB_PASSWORD,
    ssl: true
  },

  // Redis Cache for development
  redis: {
    host: process.env.REDIS_HOST || 'redis-dev.redis.cache.windows.net',
    port: process.env.REDIS_PORT || 6380,
    password: process.env.REDIS_PASSWORD,
    tls: true
  },

  // Logging configuration for development
  logging: {
    level: 'debug',
    format: 'json'
  },

  // Monitoring configuration for development
  monitoring: {
    enabled: true,
    metrics: {
      enabled: true,
      prefix: 'nodejs_app_dev_'
    }
  }
};