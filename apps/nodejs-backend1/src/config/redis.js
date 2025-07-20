const redis = require('redis');
const config = require('config');
const logger = require('../utils/logger');
const { monitorRedisOperation } = require('../middleware/monitoring');

let redisClient = null;

// Redis configuration
const redisConfig = {
  host: config.get('redis.host'),
  port: config.get('redis.port'),
  password: config.get('redis.password'),
  db: config.get('redis.database'),
  retryDelayOnFailover: config.get('redis.retryDelayOnFailover'),
  enableReadyCheck: config.get('redis.enableReadyCheck'),
  maxRetriesPerRequest: config.get('redis.maxRetriesPerRequest'),
  lazyConnect: config.get('redis.lazyConnect'),
  keepAlive: config.get('redis.keepAlive'),
  family: config.get('redis.family')
};

// Initialize Redis connection
async function initializeRedis() {
  try {
    const startTime = Date.now();
    logger.info('Initializing Redis connection...');
    
    redisClient = redis.createClient(redisConfig);
    
    // Event handlers
    redisClient.on('connect', () => {
      logger.info('Redis client connected');
    });
    
    redisClient.on('ready', () => {
      logger.info('Redis client ready');
    });
    
    redisClient.on('error', (error) => {
      logger.error('Redis client error', { error: error.message });
    });
    
    redisClient.on('end', () => {
      logger.info('Redis client connection ended');
    });
    
    redisClient.on('reconnecting', (delay, attempt) => {
      logger.warn('Redis client reconnecting', { delay, attempt });
    });
    
    // Connect to Redis
    await redisClient.connect();
    
    // Test connection
    await redisClient.ping();
    
    const duration = Date.now() - startTime;
    logger.startup('Redis', duration);
    
    return redisClient;
  } catch (error) {
    logger.error('Failed to initialize Redis', { error: error.message });
    throw error;
  }
}

// Close Redis connection
async function closeRedis() {
  if (redisClient) {
    const startTime = Date.now();
    logger.info('Closing Redis connection...');
    
    try {
      await redisClient.quit();
      const duration = Date.now() - startTime;
      logger.shutdown('Redis', duration);
    } catch (error) {
      logger.error('Error closing Redis connection', { error: error.message });
      throw error;
    }
  }
}

// Get Redis client
function getRedisClient() {
  if (!redisClient) {
    throw new Error('Redis not initialized. Call initializeRedis() first.');
  }
  return redisClient;
}

// Redis health check
async function checkRedisHealth() {
  try {
    const startTime = Date.now();
    await redisClient.ping();
    const duration = Date.now() - startTime;
    
    return {
      status: 'healthy',
      duration: `${duration}ms`,
      timestamp: new Date().toISOString()
    };
  } catch (error) {
    logger.error('Redis health check failed', { error: error.message });
    return {
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    };
  }
}

// Enhanced Redis operations with monitoring
const RedisOperations = {
  // String operations
  set: async (key, value, ttl = null) => {
    const monitor = monitorRedisOperation('SET');
    try {
      const result = ttl ? await redisClient.setEx(key, ttl, value) : await redisClient.set(key, value);
      monitor.end();
      logger.redis('SET', key, Date.now() - monitor.startTime);
      return result;
    } catch (error) {
      monitor.end();
      logger.redis('SET', key, Date.now() - monitor.startTime, error);
      throw error;
    }
  },
  
  get: async (key) => {
    const monitor = monitorRedisOperation('GET');
    try {
      const result = await redisClient.get(key);
      monitor.end();
      logger.redis('GET', key, Date.now() - monitor.startTime);
      return result;
    } catch (error) {
      monitor.end();
      logger.redis('GET', key, Date.now() - monitor.startTime, error);
      throw error;
    }
  },
  
  del: async (key) => {
    const monitor = monitorRedisOperation('DEL');
    try {
      const result = await redisClient.del(key);
      monitor.end();
      logger.redis('DEL', key, Date.now() - monitor.startTime);
      return result;
    } catch (error) {
      monitor.end();
      logger.redis('DEL', key, Date.now() - monitor.startTime, error);
      throw error;
    }
  },
  
  exists: async (key) => {
    const monitor = monitorRedisOperation('EXISTS');
    try {
      const result = await redisClient.exists(key);
      monitor.end();
      logger.redis('EXISTS', key, Date.now() - monitor.startTime);
      return result;
    } catch (error) {
      monitor.end();
      logger.redis('EXISTS', key, Date.now() - monitor.startTime, error);
      throw error;
    }
  },
  
  expire: async (key, ttl) => {
    const monitor = monitorRedisOperation('EXPIRE');
    try {
      const result = await redisClient.expire(key, ttl);
      monitor.end();
      logger.redis('EXPIRE', key, Date.now() - monitor.startTime);
      return result;
    } catch (error) {
      monitor.end();
      logger.redis('EXPIRE', key, Date.now() - monitor.startTime, error);
      throw error;
    }
  },
  
  // Hash operations
  hSet: async (key, field, value) => {
    const monitor = monitorRedisOperation('HSET');
    try {
      const result = await redisClient.hSet(key, field, value);
      monitor.end();
      logger.redis('HSET', key, Date.now() - monitor.startTime);
      return result;
    } catch (error) {
      monitor.end();
      logger.redis('HSET', key, Date.now() - monitor.startTime, error);
      throw error;
    }
  },
  
  hGet: async (key, field) => {
    const monitor = monitorRedisOperation('HGET');
    try {
      const result = await redisClient.hGet(key, field);
      monitor.end();
      logger.redis('HGET', key, Date.now() - monitor.startTime);
      return result;
    } catch (error) {
      monitor.end();
      logger.redis('HGET', key, Date.now() - monitor.startTime, error);
      throw error;
    }
  },
  
  hGetAll: async (key) => {
    const monitor = monitorRedisOperation('HGETALL');
    try {
      const result = await redisClient.hGetAll(key);
      monitor.end();
      logger.redis('HGETALL', key, Date.now() - monitor.startTime);
      return result;
    } catch (error) {
      monitor.end();
      logger.redis('HGETALL', key, Date.now() - monitor.startTime, error);
      throw error;
    }
  },
  
  hDel: async (key, field) => {
    const monitor = monitorRedisOperation('HDEL');
    try {
      const result = await redisClient.hDel(key, field);
      monitor.end();
      logger.redis('HDEL', key, Date.now() - monitor.startTime);
      return result;
    } catch (error) {
      monitor.end();
      logger.redis('HDEL', key, Date.now() - monitor.startTime, error);
      throw error;
    }
  },
  
  // List operations
  lPush: async (key, value) => {
    const monitor = monitorRedisOperation('LPUSH');
    try {
      const result = await redisClient.lPush(key, value);
      monitor.end();
      logger.redis('LPUSH', key, Date.now() - monitor.startTime);
      return result;
    } catch (error) {
      monitor.end();
      logger.redis('LPUSH', key, Date.now() - monitor.startTime, error);
      throw error;
    }
  },
  
  rPop: async (key) => {
    const monitor = monitorRedisOperation('RPOP');
    try {
      const result = await redisClient.rPop(key);
      monitor.end();
      logger.redis('RPOP', key, Date.now() - monitor.startTime);
      return result;
    } catch (error) {
      monitor.end();
      logger.redis('RPOP', key, Date.now() - monitor.startTime, error);
      throw error;
    }
  },
  
  lRange: async (key, start, stop) => {
    const monitor = monitorRedisOperation('LRANGE');
    try {
      const result = await redisClient.lRange(key, start, stop);
      monitor.end();
      logger.redis('LRANGE', key, Date.now() - monitor.startTime);
      return result;
    } catch (error) {
      monitor.end();
      logger.redis('LRANGE', key, Date.now() - monitor.startTime, error);
      throw error;
    }
  },
  
  // Set operations
  sAdd: async (key, member) => {
    const monitor = monitorRedisOperation('SADD');
    try {
      const result = await redisClient.sAdd(key, member);
      monitor.end();
      logger.redis('SADD', key, Date.now() - monitor.startTime);
      return result;
    } catch (error) {
      monitor.end();
      logger.redis('SADD', key, Date.now() - monitor.startTime, error);
      throw error;
    }
  },
  
  sMembers: async (key) => {
    const monitor = monitorRedisOperation('SMEMBERS');
    try {
      const result = await redisClient.sMembers(key);
      monitor.end();
      logger.redis('SMEMBERS', key, Date.now() - monitor.startTime);
      return result;
    } catch (error) {
      monitor.end();
      logger.redis('SMEMBERS', key, Date.now() - monitor.startTime, error);
      throw error;
    }
  },
  
  sRem: async (key, member) => {
    const monitor = monitorRedisOperation('SREM');
    try {
      const result = await redisClient.sRem(key, member);
      monitor.end();
      logger.redis('SREM', key, Date.now() - monitor.startTime);
      return result;
    } catch (error) {
      monitor.end();
      logger.redis('SREM', key, Date.now() - monitor.startTime, error);
      throw error;
    }
  }
};

// Cache wrapper with JSON serialization
const CacheOperations = {
  setObject: async (key, object, ttl = 3600) => {
    const serialized = JSON.stringify(object);
    return RedisOperations.set(key, serialized, ttl);
  },
  
  getObject: async (key) => {
    const serialized = await RedisOperations.get(key);
    return serialized ? JSON.parse(serialized) : null;
  },
  
  setWithPrefix: async (prefix, key, value, ttl = 3600) => {
    const prefixedKey = `${prefix}:${key}`;
    return RedisOperations.set(prefixedKey, value, ttl);
  },
  
  getWithPrefix: async (prefix, key) => {
    const prefixedKey = `${prefix}:${key}`;
    return RedisOperations.get(prefixedKey);
  },
  
  deletePattern: async (pattern) => {
    const monitor = monitorRedisOperation('SCAN_DELETE');
    try {
      const keys = await redisClient.keys(pattern);
      if (keys.length > 0) {
        const result = await redisClient.del(keys);
        monitor.end();
        logger.redis('SCAN_DELETE', pattern, Date.now() - monitor.startTime);
        return result;
      }
      monitor.end();
      return 0;
    } catch (error) {
      monitor.end();
      logger.redis('SCAN_DELETE', pattern, Date.now() - monitor.startTime, error);
      throw error;
    }
  }
};

module.exports = {
  initializeRedis,
  closeRedis,
  getRedisClient,
  checkRedisHealth,
  RedisOperations,
  CacheOperations
};