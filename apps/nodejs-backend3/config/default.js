/**
 * Default Configuration for Node.js Application
 * Base configuration that applies to all environments
 */

module.exports = {
  // Application metadata
  app: {
    name: 'nodejs-app',
    version: process.env.npm_package_version || '1.0.0',
    description: 'Production-grade Node.js application',
    environment: process.env.NODE_ENV || 'local'
  },

  // Server configuration
  server: {
    port: process.env.PORT || 3000,
    host: process.env.HOST || '0.0.0.0'
  },

  // Database configuration
  database: {
    type: 'postgresql',
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'nodejs_app',
    username: process.env.DB_USERNAME || 'nodejs_user',
    password: process.env.DB_PASSWORD || 'password'
  },

  // Monitoring configuration
  monitoring: {
    enabled: true,
    metrics: {
      enabled: true,
      endpoint: '/metrics'
    },
    health: {
      enabled: true,
      endpoint: '/health'
    }
  }
};