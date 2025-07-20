const express = require('express');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const config = require('config');

const logger = require('../utils/logger');
const { BlobStorageOperations } = require('../config/azure');
const { trackFileUpload } = require('../middleware/monitoring');
const { asyncHandler, ValidationError } = require('../middleware/errorHandler');

const router = express.Router();

// Configure multer for file uploads
const storage = multer.memoryStorage();
const upload = multer({
  storage,
  limits: {
    fileSize: config.get('upload.maxFileSize') || 10 * 1024 * 1024, // 10MB default
    files: 5
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = config.get('upload.allowedTypes') || [
      'jpg', 'jpeg', 'png', 'gif', 'pdf', 'doc', 'docx', 'txt'
    ];
    const fileExtension = path.extname(file.originalname).toLowerCase().slice(1);
    
    if (allowedTypes.includes(fileExtension)) {
      cb(null, true);
    } else {
      cb(new ValidationError(`File type .${fileExtension} not allowed`), false);
    }
  }
});

/**
 * @swagger
 * /files/upload:
 *   post:
 *     summary: Upload file
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *               category:
 *                 type: string
 *                 description: File category
 *     responses:
 *       200:
 *         description: File uploaded successfully
 *       400:
 *         description: Upload error
 */
router.post('/upload',
  upload.single('file'),
  trackFileUpload('general'),
  asyncHandler(async (req, res) => {
    if (!req.file) {
      throw new ValidationError('No file provided');
    }

    const file = req.file;
    const category = req.body.category || 'general';
    const userId = req.user.id;
    
    // Generate unique filename
    const fileExtension = path.extname(file.originalname);
    const fileName = `${uuidv4()}${fileExtension}`;
    const blobName = `${category}/${userId}/${fileName}`;
    
    try {
      let uploadResult;
      
      // Upload to Azure Blob Storage if available
      if (config.get('azure.storage.enabled')) {
        const containerName = config.get('azure.storage.container') || 'uploads';
        uploadResult = await BlobStorageOperations.uploadBlob(
          containerName,
          blobName,
          file.buffer,
          {
            contentType: file.mimetype,
            metadata: {
              originalName: file.originalname,
              uploadedBy: userId,
              category: category,
              uploadDate: new Date().toISOString()
            }
          }
        );
      } else {
        // Fallback to local storage simulation
        uploadResult = {
          url: `/files/${blobName}`,
          size: file.size
        };
      }
      
      // Log the upload
      logger.userActivity(userId, 'file_uploaded', {
        fileName: file.originalname,
        size: file.size,
        category,
        contentType: file.mimetype
      });
      
      res.status(200).json({
        message: 'File uploaded successfully',
        file: {
          id: fileName.split('.')[0],
          originalName: file.originalname,
          fileName: fileName,
          size: file.size,
          contentType: file.mimetype,
          category: category,
          url: uploadResult.url,
          uploadedAt: new Date().toISOString(),
          uploadedBy: userId
        }
      });
      
    } catch (error) {
      logger.error('File upload failed', {
        error: error.message,
        fileName: file.originalname,
        userId
      });
      throw error;
    }
  })
);

/**
 * @swagger
 * /files/upload-multiple:
 *   post:
 *     summary: Upload multiple files
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               files:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: binary
 *               category:
 *                 type: string
 *     responses:
 *       200:
 *         description: Files uploaded successfully
 */
router.post('/upload-multiple',
  upload.array('files', 5),
  trackFileUpload('batch'),
  asyncHandler(async (req, res) => {
    if (!req.files || req.files.length === 0) {
      throw new ValidationError('No files provided');
    }

    const files = req.files;
    const category = req.body.category || 'general';
    const userId = req.user.id;
    const uploadResults = [];
    
    for (const file of files) {
      try {
        const fileExtension = path.extname(file.originalname);
        const fileName = `${uuidv4()}${fileExtension}`;
        const blobName = `${category}/${userId}/${fileName}`;
        
        let uploadResult;
        
        if (config.get('azure.storage.enabled')) {
          const containerName = config.get('azure.storage.container') || 'uploads';
          uploadResult = await BlobStorageOperations.uploadBlob(
            containerName,
            blobName,
            file.buffer,
            {
              contentType: file.mimetype,
              metadata: {
                originalName: file.originalname,
                uploadedBy: userId,
                category: category,
                uploadDate: new Date().toISOString()
              }
            }
          );
        } else {
          uploadResult = {
            url: `/files/${blobName}`,
            size: file.size
          };
        }
        
        uploadResults.push({
          id: fileName.split('.')[0],
          originalName: file.originalname,
          fileName: fileName,
          size: file.size,
          contentType: file.mimetype,
          category: category,
          url: uploadResult.url,
          status: 'success'
        });
        
      } catch (error) {
        logger.error('Individual file upload failed', {
          error: error.message,
          fileName: file.originalname,
          userId
        });
        
        uploadResults.push({
          originalName: file.originalname,
          status: 'failed',
          error: error.message
        });
      }
    }
    
    const successCount = uploadResults.filter(r => r.status === 'success').length;
    const failCount = uploadResults.filter(r => r.status === 'failed').length;
    
    logger.userActivity(userId, 'files_batch_uploaded', {
      totalFiles: files.length,
      successCount,
      failCount,
      category
    });
    
    res.status(200).json({
      message: `Batch upload completed: ${successCount} successful, ${failCount} failed`,
      results: uploadResults,
      summary: {
        total: files.length,
        successful: successCount,
        failed: failCount
      }
    });
  })
);

/**
 * @swagger
 * /files/{filename}:
 *   get:
 *     summary: Download file
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: filename
 *         required: true
 *         schema:
 *           type: string
 *         description: File name
 *     responses:
 *       200:
 *         description: File content
 *       404:
 *         description: File not found
 */
router.get('/:filename',
  asyncHandler(async (req, res) => {
    const { filename } = req.params;
    const userId = req.user.id;
    
    // Simple filename validation
    if (!/^[a-f0-9-]+\.[a-z0-9]+$/i.test(filename)) {
      throw new ValidationError('Invalid filename format');
    }
    
    try {
      if (config.get('azure.storage.enabled')) {
        // For production, you'd want more sophisticated file access control
        const containerName = config.get('azure.storage.container') || 'uploads';
        const blobName = `general/${userId}/${filename}`;
        
        const downloadResult = await BlobStorageOperations.downloadBlob(containerName, blobName);
        
        res.set({
          'Content-Type': downloadResult.contentType || 'application/octet-stream',
          'Content-Length': downloadResult.data.length,
          'Content-Disposition': `attachment; filename="${filename}"`
        });
        
        res.send(downloadResult.data);
        
        logger.userActivity(userId, 'file_downloaded', {
          fileName: filename,
          size: downloadResult.data.length
        });
      } else {
        // Fallback response for development
        res.status(200).json({
          message: 'File download endpoint - Azure Storage not configured',
          filename,
          note: 'Configure Azure Blob Storage for actual file downloads'
        });
      }
    } catch (error) {
      if (error.statusCode === 404) {
        res.status(404).json({
          error: 'File not found',
          filename
        });
      } else {
        throw error;
      }
    }
  })
);

/**
 * @swagger
 * /files/list:
 *   get:
 *     summary: List user files
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *         description: Filter by category
 *     responses:
 *       200:
 *         description: List of files
 */
router.get('/list',
  asyncHandler(async (req, res) => {
    const userId = req.user.id;
    const category = req.query.category;
    
    try {
      if (config.get('azure.storage.enabled')) {
        const containerName = config.get('azure.storage.container') || 'uploads';
        const prefix = category ? `${category}/${userId}/` : `${userId}/`;
        
        const files = await BlobStorageOperations.listBlobs(containerName, prefix);
        
        const formattedFiles = files.map(file => ({
          name: path.basename(file.name),
          size: file.size,
          lastModified: file.lastModified,
          contentType: file.contentType,
          category: file.name.split('/')[0]
        }));
        
        res.status(200).json({
          message: 'Files retrieved successfully',
          files: formattedFiles,
          total: formattedFiles.length
        });
      } else {
        res.status(200).json({
          message: 'File listing endpoint - Azure Storage not configured',
          files: [],
          note: 'Configure Azure Blob Storage for actual file listing'
        });
      }
    } catch (error) {
      logger.error('File listing failed', {
        error: error.message,
        userId,
        category
      });
      throw error;
    }
  })
);

module.exports = router;