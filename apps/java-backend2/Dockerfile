# Use Eclipse Temurin JRE 21 for runtime
FROM eclipse-temurin:21-jre-alpine

# Set working directory
WORKDIR /app

# Install security updates and required packages
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
        dumb-init \
        curl \
        ca-certificates && \
    rm -rf /var/cache/apk/*

# Create a non-root user with specific UID/GID for security
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Copy the pre-built JAR file (built in CI/CD pipeline)
# The JAR file should be provided as a build argument or copied from artifacts
COPY --chown=appuser:appgroup *.jar app.jar

# Verify the JAR file exists and has correct permissions
RUN ls -la app.jar && \
    file app.jar && \
    chmod 444 app.jar

# Change ownership of the app directory
RUN chown -R appuser:appgroup /app

# Add health check using Spring Boot Actuator
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Expose port 8080
EXPOSE 8080

# Switch to non-root user for security
USER appuser

# Set JVM security and performance options
ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -XX:+UseG1GC \
               -XX:+UseStringDeduplication \
               -Djava.security.egd=file:/dev/./urandom \
               -Dspring.profiles.active=docker \
               -Dfile.encoding=UTF-8 \
               -Duser.timezone=UTC"

# Use dumb-init to handle signals properly and run the application
ENTRYPOINT ["dumb-init", "--"]
CMD ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]