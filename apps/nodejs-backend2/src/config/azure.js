const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');
const { BlobServiceClient } = require('@azure/storage-blob');
const config = require('config');
const logger = require('../utils/logger');

let keyVaultClient = null;
let blobServiceClient = null;
let isAzureEnabled = false;

// Initialize Azure services
async function initializeAzureServices() {
  try {
    const startTime = Date.now();
    logger.info('Initializing Azure services...');

    if (!config.get('azure.enabled')) {
      logger.info('Azure services disabled by configuration');
      return;
    }

    // Initialize Azure credential
    const credential = new DefaultAzureCredential();

    // Initialize Key Vault client
    if (config.get('azure.keyVault.enabled')) {
      const keyVaultUrl = config.get('azure.keyVault.uri');
      if (keyVaultUrl) {
        keyVaultClient = new SecretClient(keyVaultUrl, credential);
        
        // Test Key Vault connection
        try {
          await keyVaultClient.getSecret('test-connection');
        } catch (error) {
          // It's OK if the secret doesn't exist, we just want to test connectivity
          if (error.code !== 'SecretNotFound') {
            logger.warn('Key Vault connectivity test failed', { error: error.message });
          }
        }
        
        logger.info('Key Vault client initialized successfully');
      }
    }

    // Initialize Blob Storage client
    if (config.get('azure.storage.enabled')) {
      const storageAccount = config.get('azure.storage.accountName');
      if (storageAccount) {
        const blobServiceUrl = `https://${storageAccount}.blob.core.windows.net`;
        blobServiceClient = new BlobServiceClient(blobServiceUrl, credential);
        
        // Test Blob Storage connection
        try {
          await blobServiceClient.getProperties();
          logger.info('Blob Storage client initialized successfully');
        } catch (error) {
          logger.warn('Blob Storage connectivity test failed', { error: error.message });
        }
      }
    }

    isAzureEnabled = true;
    const duration = Date.now() - startTime;
    logger.startup('Azure Services', duration);

  } catch (error) {
    logger.error('Failed to initialize Azure services', { error: error.message });
    // Don't throw error - app should still work without Azure services
  }
}

// Key Vault operations
const KeyVaultOperations = {
  async getSecret(secretName) {
    if (!keyVaultClient) {
      throw new Error('Key Vault client not initialized');
    }

    try {
      const startTime = Date.now();
      const secret = await keyVaultClient.getSecret(secretName);
      const duration = Date.now() - startTime;
      
      logger.debug('Key Vault secret retrieved', {
        secretName,
        duration: `${duration}ms`
      });
      
      return secret.value;
    } catch (error) {
      logger.error('Failed to retrieve secret from Key Vault', {
        secretName,
        error: error.message
      });
      throw error;
    }
  },

  async setSecret(secretName, secretValue) {
    if (!keyVaultClient) {
      throw new Error('Key Vault client not initialized');
    }

    try {
      const startTime = Date.now();
      const result = await keyVaultClient.setSecret(secretName, secretValue);
      const duration = Date.now() - startTime;
      
      logger.info('Key Vault secret stored', {
        secretName,
        duration: `${duration}ms`
      });
      
      return result;
    } catch (error) {
      logger.error('Failed to store secret in Key Vault', {
        secretName,
        error: error.message
      });
      throw error;
    }
  },

  async deleteSecret(secretName) {
    if (!keyVaultClient) {
      throw new Error('Key Vault client not initialized');
    }

    try {
      const startTime = Date.now();
      const result = await keyVaultClient.beginDeleteSecret(secretName);
      const duration = Date.now() - startTime;
      
      logger.info('Key Vault secret deleted', {
        secretName,
        duration: `${duration}ms`
      });
      
      return result;
    } catch (error) {
      logger.error('Failed to delete secret from Key Vault', {
        secretName,
        error: error.message
      });
      throw error;
    }
  },

  async listSecrets() {
    if (!keyVaultClient) {
      throw new Error('Key Vault client not initialized');
    }

    try {
      const startTime = Date.now();
      const secrets = [];
      
      for await (const secretProperties of keyVaultClient.listPropertiesOfSecrets()) {
        secrets.push({
          name: secretProperties.name,
          enabled: secretProperties.enabled,
          createdOn: secretProperties.createdOn,
          updatedOn: secretProperties.updatedOn
        });
      }
      
      const duration = Date.now() - startTime;
      logger.debug('Key Vault secrets listed', {
        count: secrets.length,
        duration: `${duration}ms`
      });
      
      return secrets;
    } catch (error) {
      logger.error('Failed to list secrets from Key Vault', {
        error: error.message
      });
      throw error;
    }
  }
};

// Blob Storage operations
const BlobStorageOperations = {
  async uploadBlob(containerName, blobName, data, options = {}) {
    if (!blobServiceClient) {
      throw new Error('Blob Storage client not initialized');
    }

    try {
      const startTime = Date.now();
      const containerClient = blobServiceClient.getContainerClient(containerName);
      
      // Ensure container exists
      await containerClient.createIfNotExists();
      
      const blockBlobClient = containerClient.getBlockBlobClient(blobName);
      const uploadResponse = await blockBlobClient.upload(data, data.length, {
        metadata: options.metadata || {},
        blobHTTPHeaders: {
          blobContentType: options.contentType || 'application/octet-stream'
        }
      });
      
      const duration = Date.now() - startTime;
      logger.fileOperation('upload', blobName, data.length, duration);
      
      return {
        url: blockBlobClient.url,
        etag: uploadResponse.etag,
        lastModified: uploadResponse.lastModified
      };
    } catch (error) {
      logger.fileOperation('upload', blobName, data.length, 0, error);
      throw error;
    }
  },

  async downloadBlob(containerName, blobName) {
    if (!blobServiceClient) {
      throw new Error('Blob Storage client not initialized');
    }

    try {
      const startTime = Date.now();
      const containerClient = blobServiceClient.getContainerClient(containerName);
      const blockBlobClient = containerClient.getBlockBlobClient(blobName);
      
      const downloadResponse = await blockBlobClient.download();
      const downloaded = await streamToBuffer(downloadResponse.readableStreamBody);
      
      const duration = Date.now() - startTime;
      logger.fileOperation('download', blobName, downloaded.length, duration);
      
      return {
        data: downloaded,
        metadata: downloadResponse.metadata,
        contentType: downloadResponse.contentType,
        lastModified: downloadResponse.lastModified
      };
    } catch (error) {
      logger.fileOperation('download', blobName, 0, 0, error);
      throw error;
    }
  },

  async deleteBlob(containerName, blobName) {
    if (!blobServiceClient) {
      throw new Error('Blob Storage client not initialized');
    }

    try {
      const startTime = Date.now();
      const containerClient = blobServiceClient.getContainerClient(containerName);
      const blockBlobClient = containerClient.getBlockBlobClient(blobName);
      
      await blockBlobClient.delete();
      
      const duration = Date.now() - startTime;
      logger.fileOperation('delete', blobName, 0, duration);
      
      return true;
    } catch (error) {
      logger.fileOperation('delete', blobName, 0, 0, error);
      throw error;
    }
  },

  async listBlobs(containerName, prefix = '') {
    if (!blobServiceClient) {
      throw new Error('Blob Storage client not initialized');
    }

    try {
      const startTime = Date.now();
      const containerClient = blobServiceClient.getContainerClient(containerName);
      const blobs = [];
      
      for await (const blob of containerClient.listBlobsFlat({ prefix })) {
        blobs.push({
          name: blob.name,
          size: blob.properties.contentLength,
          lastModified: blob.properties.lastModified,
          contentType: blob.properties.contentType,
          etag: blob.properties.etag
        });
      }
      
      const duration = Date.now() - startTime;
      logger.debug('Blob Storage listing completed', {
        containerName,
        prefix,
        count: blobs.length,
        duration: `${duration}ms`
      });
      
      return blobs;
    } catch (error) {
      logger.error('Failed to list blobs', {
        containerName,
        prefix,
        error: error.message
      });
      throw error;
    }
  },

  async getBlobUrl(containerName, blobName, expiresInMinutes = 60) {
    if (!blobServiceClient) {
      throw new Error('Blob Storage client not initialized');
    }

    try {
      const containerClient = blobServiceClient.getContainerClient(containerName);
      const blockBlobClient = containerClient.getBlockBlobClient(blobName);
      
      // Generate SAS URL for temporary access
      const expiresOn = new Date();
      expiresOn.setMinutes(expiresOn.getMinutes() + expiresInMinutes);
      
      // Note: This requires additional SAS token generation logic
      // For now, return the base URL
      return blockBlobClient.url;
    } catch (error) {
      logger.error('Failed to generate blob URL', {
        containerName,
        blobName,
        error: error.message
      });
      throw error;
    }
  }
};

// Helper function to convert stream to buffer
async function streamToBuffer(readableStream) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    readableStream.on('data', (data) => {
      chunks.push(data instanceof Buffer ? data : Buffer.from(data));
    });
    readableStream.on('end', () => {
      resolve(Buffer.concat(chunks));
    });
    readableStream.on('error', reject);
  });
}

// Health check for Azure services
async function checkAzureHealth() {
  const health = {
    keyVault: { status: 'disabled' },
    blobStorage: { status: 'disabled' }
  };

  if (!isAzureEnabled) {
    return health;
  }

  // Check Key Vault health
  if (keyVaultClient) {
    try {
      const startTime = Date.now();
      await keyVaultClient.getSecret('health-check');
      health.keyVault = {
        status: 'healthy',
        responseTime: `${Date.now() - startTime}ms`
      };
    } catch (error) {
      if (error.code === 'SecretNotFound') {
        health.keyVault = { status: 'healthy', note: 'Connected but health-check secret not found' };
      } else {
        health.keyVault = { status: 'unhealthy', error: error.message };
      }
    }
  }

  // Check Blob Storage health
  if (blobServiceClient) {
    try {
      const startTime = Date.now();
      await blobServiceClient.getProperties();
      health.blobStorage = {
        status: 'healthy',
        responseTime: `${Date.now() - startTime}ms`
      };
    } catch (error) {
      health.blobStorage = { status: 'unhealthy', error: error.message };
    }
  }

  return health;
}

// Get environment-specific configuration from Key Vault
async function loadConfigFromKeyVault() {
  if (!keyVaultClient || !config.get('azure.keyVault.loadConfig')) {
    return {};
  }

  try {
    const environment = config.get('app.environment');
    const configSecrets = config.get('azure.keyVault.configSecrets') || [];
    const loadedConfig = {};

    for (const secretName of configSecrets) {
      try {
        const fullSecretName = `${environment}-${secretName}`;
        const secretValue = await KeyVaultOperations.getSecret(fullSecretName);
        loadedConfig[secretName] = secretValue;
      } catch (error) {
        logger.warn(`Failed to load config secret: ${secretName}`, { error: error.message });
      }
    }

    logger.info('Configuration loaded from Key Vault', {
      secretsLoaded: Object.keys(loadedConfig).length
    });

    return loadedConfig;
  } catch (error) {
    logger.error('Failed to load configuration from Key Vault', { error: error.message });
    return {};
  }
}

module.exports = {
  initializeAzureServices,
  KeyVaultOperations,
  BlobStorageOperations,
  checkAzureHealth,
  loadConfigFromKeyVault,
  isAzureEnabled: () => isAzureEnabled
};