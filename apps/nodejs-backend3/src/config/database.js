const knex = require('knex');
const config = require('config');
const logger = require('../utils/logger');
const { monitorDatabaseQuery } = require('../middleware/monitoring');

let db = null;

// Database configuration
const dbConfig = {
  client: 'postgresql',
  connection: {
    host: config.get('database.host'),
    port: config.get('database.port'),
    user: config.get('database.username'),
    password: config.get('database.password'),
    database: config.get('database.name'),
    ssl: config.get('database.ssl') ? { rejectUnauthorized: false } : false,
  },
  pool: {
    min: config.get('database.pool.min'),
    max: config.get('database.pool.max'),
    acquireTimeoutMillis: config.get('database.pool.acquireTimeoutMillis'),
    createTimeoutMillis: config.get('database.pool.createTimeoutMillis'),
    destroyTimeoutMillis: config.get('database.pool.destroyTimeoutMillis'),
    idleTimeoutMillis: config.get('database.pool.idleTimeoutMillis'),
    reapIntervalMillis: config.get('database.pool.reapIntervalMillis'),
    createRetryIntervalMillis: config.get('database.pool.createRetryIntervalMillis')
  },
  migrations: {
    directory: './migrations',
    tableName: 'knex_migrations'
  },
  seeds: {
    directory: './seeds'
  },
  debug: config.get('app.environment') === 'development'
};

// Enhanced query builder with monitoring
const createMonitoredQuery = (queryBuilder, operation, table) => {
  const monitor = monitorDatabaseQuery(operation, table);
  
  const originalThen = queryBuilder.then.bind(queryBuilder);
  queryBuilder.then = function(onFulfilled, onRejected) {
    return originalThen(
      (result) => {
        monitor.end();
        logger.database(operation, table, Date.now() - monitor.startTime);
        return onFulfilled ? onFulfilled(result) : result;
      },
      (error) => {
        monitor.end();
        logger.database(operation, table, Date.now() - monitor.startTime, error);
        return onRejected ? onRejected(error) : Promise.reject(error);
      }
    );
  };
  
  return queryBuilder;
};

// Initialize database connection
async function initializeDatabase() {
  try {
    const startTime = Date.now();
    logger.info('Initializing database connection...');
    
    db = knex(dbConfig);
    
    // Test connection
    await db.raw('SELECT 1');
    
    // Run migrations in production
    if (config.get('app.environment') === 'production' && config.get('database.runMigrations')) {
      logger.info('Running database migrations...');
      await db.migrate.latest();
      logger.info('Database migrations completed');
    }
    
    const duration = Date.now() - startTime;
    logger.startup('Database', duration);
    
    // Setup connection event handlers
    db.on('query', (queryData) => {
      logger.debug('Database Query', {
        sql: queryData.sql,
        bindings: queryData.bindings,
        method: queryData.method
      });
    });
    
    db.on('query-error', (error, queryData) => {
      logger.error('Database Query Error', {
        error: error.message,
        sql: queryData.sql,
        bindings: queryData.bindings,
        method: queryData.method
      });
    });
    
    return db;
  } catch (error) {
    logger.error('Failed to initialize database', { error: error.message });
    throw error;
  }
}

// Close database connection
async function closeDatabase() {
  if (db) {
    const startTime = Date.now();
    logger.info('Closing database connection...');
    
    try {
      await db.destroy();
      const duration = Date.now() - startTime;
      logger.shutdown('Database', duration);
    } catch (error) {
      logger.error('Error closing database connection', { error: error.message });
      throw error;
    }
  }
}

// Get database instance
function getDatabase() {
  if (!db) {
    throw new Error('Database not initialized. Call initializeDatabase() first.');
  }
  return db;
}

// Database health check
async function checkDatabaseHealth() {
  try {
    const startTime = Date.now();
    await db.raw('SELECT 1');
    const duration = Date.now() - startTime;
    
    return {
      status: 'healthy',
      duration: `${duration}ms`,
      timestamp: new Date().toISOString()
    };
  } catch (error) {
    logger.error('Database health check failed', { error: error.message });
    return {
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    };
  }
}

// Enhanced database operations with monitoring
const DatabaseOperations = {
  // Users table operations
  users: {
    findById: (id) => createMonitoredQuery(db('users').where({ id }), 'SELECT', 'users'),
    findByEmail: (email) => createMonitoredQuery(db('users').where({ email }), 'SELECT', 'users'),
    create: (userData) => createMonitoredQuery(db('users').insert(userData).returning('*'), 'INSERT', 'users'),
    update: (id, userData) => createMonitoredQuery(db('users').where({ id }).update(userData).returning('*'), 'UPDATE', 'users'),
    delete: (id) => createMonitoredQuery(db('users').where({ id }).del(), 'DELETE', 'users'),
    list: (limit = 10, offset = 0) => createMonitoredQuery(db('users').limit(limit).offset(offset), 'SELECT', 'users')
  },
  
  // Products table operations
  products: {
    findById: (id) => createMonitoredQuery(db('products').where({ id }), 'SELECT', 'products'),
    findByCategory: (category) => createMonitoredQuery(db('products').where({ category }), 'SELECT', 'products'),
    create: (productData) => createMonitoredQuery(db('products').insert(productData).returning('*'), 'INSERT', 'products'),
    update: (id, productData) => createMonitoredQuery(db('products').where({ id }).update(productData).returning('*'), 'UPDATE', 'products'),
    delete: (id) => createMonitoredQuery(db('products').where({ id }).del(), 'DELETE', 'products'),
    list: (limit = 10, offset = 0) => createMonitoredQuery(db('products').limit(limit).offset(offset), 'SELECT', 'products'),
    search: (searchTerm) => createMonitoredQuery(
      db('products').where('name', 'ilike', `%${searchTerm}%`).orWhere('description', 'ilike', `%${searchTerm}%`),
      'SELECT',
      'products'
    )
  },
  
  // Orders table operations
  orders: {
    findById: (id) => createMonitoredQuery(db('orders').where({ id }), 'SELECT', 'orders'),
    findByUserId: (userId) => createMonitoredQuery(db('orders').where({ user_id: userId }), 'SELECT', 'orders'),
    create: (orderData) => createMonitoredQuery(db('orders').insert(orderData).returning('*'), 'INSERT', 'orders'),
    update: (id, orderData) => createMonitoredQuery(db('orders').where({ id }).update(orderData).returning('*'), 'UPDATE', 'orders'),
    delete: (id) => createMonitoredQuery(db('orders').where({ id }).del(), 'DELETE', 'orders'),
    list: (limit = 10, offset = 0) => createMonitoredQuery(db('orders').limit(limit).offset(offset), 'SELECT', 'orders')
  },
  
  // Generic operations
  raw: (query, bindings) => createMonitoredQuery(db.raw(query, bindings), 'RAW', 'multiple'),
  transaction: (callback) => db.transaction(callback)
};

// Database migrations helper
const runMigrations = async () => {
  try {
    logger.info('Running database migrations...');
    const [batchNo, log] = await db.migrate.latest();
    
    if (log.length === 0) {
      logger.info('Database is already up to date');
    } else {
      logger.info(`Batch ${batchNo} ran ${log.length} migrations:`, { migrations: log });
    }
  } catch (error) {
    logger.error('Migration failed', { error: error.message });
    throw error;
  }
};

// Database seeding helper
const runSeeds = async () => {
  try {
    logger.info('Running database seeds...');
    await db.seed.run();
    logger.info('Database seeding completed');
  } catch (error) {
    logger.error('Seeding failed', { error: error.message });
    throw error;
  }
};

module.exports = {
  initializeDatabase,
  closeDatabase,
  getDatabase,
  checkDatabaseHealth,
  DatabaseOperations,
  runMigrations,
  runSeeds
};