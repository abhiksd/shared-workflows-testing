# Java Backend 1 - User Management Service

A Spring Boot REST API application for user management built with Java 21 and packaged in a Docker container.

## Features

- **Java 21**: Uses the latest LTS version of Java with modern language features
- **Spring Boot 3.3.0**: Latest Spring Boot framework
- **Docker**: Multi-stage build with Alpine Linux for minimal image size
- **REST API**: Simple endpoints for testing
- **Actuator**: Health checks and metrics endpoints
- **Security**: Runs as non-root user in container

## Requirements

- JDK 21 (for local development)
- Maven 3.6+ (or use included Maven wrapper)
- Docker (for containerization)

## API Endpoints

### User Management
- `GET /api/users` - List all users (Admin only)
- `GET /api/users/{id}` - Get user by ID
- `POST /api/users` - Create new user
- `PUT /api/users/{id}` - Update user
- `DELETE /api/users/{id}` - Delete user

### Health & Monitoring
- `GET /health` - Basic health check endpoint
- `GET /actuator/health` - Detailed health information
- `GET /actuator/metrics` - Application metrics
- `GET /actuator/info` - Application information

## Local Development

### Build and Run with Maven

```bash
# Build the application
mvn clean package

# Run the application
mvn spring-boot:run
```

The application will start on `http://localhost:8080`

### Run Tests

```bash
mvn test
```

## Docker

### Build Docker Image

```bash
docker build -t java-app:latest .
```

### Run Docker Container

```bash
docker run -p 8080:8080 java-app:latest
```

### Multi-platform Build

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t java-app:latest .
```

## Docker Image Details

- **Base Images**: 
  - Build stage: `eclipse-temurin:21-jdk-alpine`
  - Runtime stage: `eclipse-temurin:21-jre-alpine`
- **Security**: Runs as non-root user (`appuser`)
- **Size**: Optimized with multi-stage build
- **Port**: Exposes port 8080

## Java 21 Features

This application is configured to use Java 21 features:
- Modern language syntax
- Improved performance
- Enhanced security
- Preview features enabled in compiler configuration

## Configuration

The application can be configured through:
- `src/main/resources/application.properties` - Main configuration
- Environment variables in Docker container
- Spring profiles for different environments

## Monitoring

Health check endpoints:
- `/health` - Basic health status
- `/actuator/health` - Detailed health information
- `/actuator/metrics` - Application metrics

## Development Notes

- Uses Maven wrapper for consistent builds
- Configured for Java 21 with preview features
- Multi-stage Docker build for optimized image size
- Security-first approach with non-root container user