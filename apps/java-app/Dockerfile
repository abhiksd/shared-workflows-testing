# Use Eclipse Temurin JDK 21 for build stage
FROM eclipse-temurin:21-jdk-alpine AS build

# Set working directory
WORKDIR /app

# Copy Maven wrapper and pom.xml
COPY mvnw pom.xml ./
COPY .mvn .mvn

# Download dependencies (this layer will be cached if pom.xml doesn't change)
RUN ./mvnw dependency:resolve

# Copy source code
COPY src ./src

# Build the application
RUN ./mvnw clean package -DskipTests

# Use Eclipse Temurin JRE 21 for runtime stage
FROM eclipse-temurin:21-jre-alpine

# Set working directory
WORKDIR /app

# Copy the built jar from build stage
COPY --from=build /app/target/*.jar app.jar

# Expose port 8080
EXPOSE 8080

# Create a non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Change ownership of the app directory
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]