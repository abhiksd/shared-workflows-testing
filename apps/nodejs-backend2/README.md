# Node.js Backend Application

A production-ready Node.js backend application built with Express.js, featuring comprehensive monitoring, security, and Azure integration.

## 🚀 Features

- **Authentication & Authorization**: JWT-based auth with role-based access control
- **Monitoring & Observability**: Prometheus metrics, OpenTelemetry tracing, health checks
- **Security**: Helmet, CORS, rate limiting, input validation
- **Database**: PostgreSQL with Knex.js ORM
- **Caching**: Redis integration with fallback support
- **Azure Integration**: Blob Storage, Application Insights
- **File Uploads**: Multipart file handling with Azure Blob Storage
- **API Documentation**: Swagger/OpenAPI integration
- **Logging**: Structured logging with Winston
- **Error Handling**: Comprehensive error management
- **Testing**: Jest test framework setup
- **Docker**: Production-ready containerization

## 📋 Prerequisites

- Node.js 18+ 
- PostgreSQL 12+
- Redis 6+ (optional)
- Docker (for containerization)
- Azure account (for Azure services)

## 🛠️ Installation

### Local Development

1. **Install dependencies**:
```bash
npm install
```

2. **Set up environment variables**:
```bash
cp .env.example .env
# Edit .env with your configuration
```

3. **Database setup**:
```bash
# Run migrations
npm run migrate

# Seed database (optional)
npm run seed
```

4. **Start development server**:
```bash
npm run dev
```

The application will be available at `http://localhost:3000`

### Docker Deployment

1. **Build Docker image**:
```bash
npm run docker:build
```

2. **Run container**:
```bash
npm run docker:run
```

## 🔧 Configuration

The application uses environment-specific configuration files:

- `config/default.js` - Base configuration
- `config/local.js` - Local development
- `config/development.js` - Development environment
- `config/sqe.js` - Staging environment  
- `config/production.js` - Production environment

### Key Configuration Options

```javascript
{
  app: {
    name: "Node.js Backend App",
    version: "1.0.0",
    environment: "development"
  },
  server: {
    port: 3000
  },
  database: {
    host: "localhost",
    port: 5432,
    name: "nodejs_app",
    username: "user",
    password: "password"
  },
  redis: {
    enabled: true,
    host: "localhost",
    port: 6379
  },
  azure: {
    enabled: false,
    storage: {
      enabled: false,
      accountName: ""
    }
  }
}
```

## 🔐 Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Environment | `development` |
| `PORT` | Server port | `3000` |
| `DB_HOST` | Database host | `localhost` |
| `DB_PORT` | Database port | `5432` |
| `DB_NAME` | Database name | `nodejs_app` |
| `DB_USERNAME` | Database username | `user` |
| `DB_PASSWORD` | Database password | `password` |
| `REDIS_HOST` | Redis host | `localhost` |
| `REDIS_PORT` | Redis port | `6379` |
| `JWT_SECRET` | JWT secret key | Required |


## 📡 API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - User login
- `POST /api/auth/logout` - User logout
- `POST /api/auth/refresh` - Refresh token
- `GET /api/auth/profile` - Get user profile
- `POST /api/auth/change-password` - Change password

### Users (Admin only)
- `GET /api/users` - List users
- `GET /api/users/:id` - Get user by ID
- `POST /api/users` - Create user
- `PUT /api/users/:id` - Update user
- `DELETE /api/users/:id` - Delete user

### Products
- `GET /api/products` - List products
- `GET /api/products/:id` - Get product by ID
- `POST /api/products` - Create product (Admin)
- `PUT /api/products/:id` - Update product (Admin)
- `DELETE /api/products/:id` - Delete product (Admin)
- `GET /api/products/search` - Search products

### Files
- `POST /api/files/upload` - Upload file
- `POST /api/files/upload-multiple` - Upload multiple files
- `GET /api/files/:filename` - Download file
- `GET /api/files/list` - List user files

### Health & Monitoring
- `GET /health` - Basic health check
- `GET /health/detailed` - Detailed health check
- `GET /health/live` - Kubernetes liveness probe
- `GET /health/ready` - Kubernetes readiness probe
- `GET /health/metrics` - Prometheus metrics

## 📊 Monitoring

### Prometheus Metrics

The application exposes metrics at `/health/metrics`:

- HTTP request duration and count
- Active connections
- Database query performance
- Redis operation performance
- Memory and CPU usage
- Business metrics (user registrations, logins, etc.)

### Health Checks

Multiple health check endpoints for different purposes:

- `/health` - Basic application health
- `/health/detailed` - Comprehensive system health
- `/health/live` - Kubernetes liveness probe
- `/health/ready` - Kubernetes readiness probe

### Logging

Structured logging with Winston:

- Console output (development)
- File output (production)
- Azure Application Insights integration
- Request/response logging
- Security event logging
- Performance monitoring

## 🧪 Testing

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Run integration tests
npm run test:integration

# Generate coverage report
npm test -- --coverage
```

## 🔒 Security Features

- **Helmet**: Security headers
- **CORS**: Cross-origin resource sharing
- **Rate Limiting**: Request throttling
- **Input Validation**: Express-validator
- **JWT Authentication**: Secure token-based auth
- **Password Hashing**: bcrypt
- **SQL Injection Protection**: Parameterized queries
- **XSS Protection**: Input sanitization

## 🏗️ Architecture

```
src/
├── app.js              # Application entry point
├── config/             # Configuration files
│   ├── database.js     # Database configuration
│   ├── redis.js        # Redis configuration
│   └── azure.js        # Azure services configuration
├── middleware/         # Express middleware
│   ├── auth.js         # Authentication middleware
│   ├── monitoring.js   # Monitoring and metrics
│   └── errorHandler.js # Error handling
├── routes/             # API routes
│   ├── auth.js         # Authentication routes
│   ├── users.js        # User management
│   ├── products.js     # Product management
│   ├── orders.js       # Order management
│   ├── files.js        # File operations
│   └── health.js       # Health checks
└── utils/              # Utility modules
    └── logger.js       # Logging utility
```

## 🚢 Deployment

### Kubernetes

The application is designed for Kubernetes deployment with:

- Health checks for liveness and readiness probes
- Graceful shutdown handling
- Resource monitoring
- Service mesh compatibility

### Docker

Multi-stage Dockerfile for optimized production builds:

```dockerfile
FROM node:18-alpine AS production
# ... (see Dockerfile for details)
```

### Azure Deployment

Supports Azure services:


- **Azure Blob Storage**: File storage
- **Azure Application Insights**: Monitoring
- **Azure Database for PostgreSQL**: Database
- **Azure Cache for Redis**: Caching

## 📈 Performance

- Connection pooling for database
- Redis caching with TTL
- Compression middleware
- Request/response optimization
- Memory usage monitoring
- Database query optimization

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Run linting and tests
6. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🆘 Support

- Check the logs: `npm run logs`
- Health check: `curl http://localhost:3000/health`
- Metrics: `curl http://localhost:3000/health/metrics`
- API docs: `http://localhost:3000/api/docs` (development)

## 🔄 Scripts

| Script | Description |
|--------|-------------|
| `npm start` | Start production server |
| `npm run dev` | Start development server |
| `npm test` | Run tests |
| `npm run lint` | Run ESLint |
| `npm run build` | Build for production |
| `npm run migrate` | Run database migrations |
| `npm run docker:build` | Build Docker image |
| `npm run security-audit` | Security audit |