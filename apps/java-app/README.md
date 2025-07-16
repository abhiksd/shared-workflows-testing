# Java Spring Boot Application with JDK 21

A simple Spring Boot REST API application built with Java 21 and packaged in a Docker container.

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

- `GET /` - Welcome message with Java version info
- `GET /hello` - Simple hello world message
- `GET /hello/{name}` - Personalized greeting
- `GET /health` - Health check endpoint
- `GET /actuator/health` - Detailed health information

## Local Development

### Build and Run with Maven

```bash
# Build the application
./mvnw clean package

# Run the application
./mvnw spring-boot:run
```

The application will start on `http://localhost:8080`

### Run Tests

```bash
./mvnw test
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