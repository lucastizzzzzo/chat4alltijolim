# ============================================================================
# Dockerfile for API Service
# ============================================================================
# Purpose: Containerize stateless REST API service
# Base image: OpenJDK 17 slim (minimal footprint)
# ============================================================================

FROM maven:3.9-eclipse-temurin-17-alpine AS build

# Set working directory
WORKDIR /app

# Copy all source code (POMs + source)
COPY pom.xml .
COPY shared/ shared/
COPY api-service/ api-service/
COPY router-worker/pom.xml router-worker/pom.xml
COPY connector-whatsapp/pom.xml connector-whatsapp/pom.xml
COPY connector-instagram/pom.xml connector-instagram/pom.xml

# Build application (skip tests in Docker build - run separately)
RUN mvn clean package -DskipTests -pl api-service -am

# ============================================================================
# Runtime stage (smaller image)
# ============================================================================
FROM eclipse-temurin:17-jre-alpine

# Add labels for documentation
LABEL maintainer="Chat4All Team"
LABEL description="API Service - REST endpoints for Chat4All platform"
LABEL educational="Demonstrates stateless microservice design"

# Create non-root user for security
RUN addgroup -S chat4all && adduser -S chat4all -G chat4all

# Set working directory
WORKDIR /app

# Copy JAR from build stage
COPY --from=build /app/api-service/target/api-service-1.0.0-SNAPSHOT.jar app.jar

# Change ownership
RUN chown -R chat4all:chat4all /app

# Switch to non-root user
USER chat4all

# Expose API port
EXPOSE 8080

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/health || exit 1

# Run application
# Educational note: Using java -jar (no application server needed)
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]
