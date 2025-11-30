#!/bin/bash

################################################################################
# Chat4All - Observability Demo Script
################################################################################
# Purpose: Demonstrate complete observability stack
# - Start all services (Kafka, Cassandra, MinIO, Prometheus, Grafana)
# - Build and deploy application services
# - Generate load with k6
# - Show Grafana dashboards
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate prerequisites
log_info "Validating prerequisites..."

if ! command_exists docker; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command_exists docker-compose; then
    log_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

if ! command_exists mvn; then
    log_error "Maven is not installed. Please install Maven first."
    exit 1
fi

if ! command_exists k6; then
    log_warning "k6 is not installed. Load testing will be skipped."
    log_info "Install k6 from: https://k6.io/docs/getting-started/installation/"
fi

log_success "All prerequisites validated"

# Build application
log_info "Building Chat4All application..."
mvn clean package -DskipTests

if [ $? -ne 0 ]; then
    log_error "Maven build failed"
    exit 1
fi

log_success "Application built successfully"

# Stop any existing containers
log_info "Stopping existing containers..."
docker-compose down -v

# Start infrastructure services
log_info "Starting infrastructure services (Kafka, Cassandra, MinIO, Prometheus, Grafana)..."
docker-compose up -d kafka cassandra minio prometheus grafana

# Wait for services to be ready
log_info "Waiting for services to start (60s)..."
sleep 60

# Initialize Cassandra schema
log_info "Initializing Cassandra schema..."
docker-compose up -d cassandra-init

sleep 10

# Start application services
log_info "Starting application services..."
docker-compose up -d api-service router-worker connector-whatsapp connector-instagram

# Wait for application to be ready
log_info "Waiting for application services to start (30s)..."
sleep 30

# Health checks
log_info "Performing health checks..."

API_HEALTH=$(curl -s http://localhost:8080/health || echo "FAIL")
if [ "$API_HEALTH" != "OK" ]; then
    log_warning "API Service health check failed"
else
    log_success "API Service: OK"
fi

ROUTER_HEALTH=$(curl -s http://localhost:8082/health || echo "FAIL")
if [ "$ROUTER_HEALTH" != "OK" ]; then
    log_warning "Router Worker health check failed"
else
    log_success "Router Worker: OK"
fi

WHATSAPP_HEALTH=$(curl -s http://localhost:8083/health || echo "FAIL")
if [ "$WHATSAPP_HEALTH" != "OK" ]; then
    log_warning "WhatsApp Connector health check failed"
else
    log_success "WhatsApp Connector: OK"
fi

INSTAGRAM_HEALTH=$(curl -s http://localhost:8084/health || echo "FAIL")
if [ "$INSTAGRAM_HEALTH" != "OK" ]; then
    log_warning "Instagram Connector health check failed"
else
    log_success "Instagram Connector: OK"
fi

# Display URLs
echo ""
log_success "==================================================================="
log_success "Chat4All Observability Stack is Running!"
log_success "==================================================================="
echo ""
log_info "Application Services:"
echo "  - API Service:         http://localhost:8080"
echo "  - Router Worker:       http://localhost:8082/actuator/prometheus"
echo "  - WhatsApp Connector:  http://localhost:8083/actuator/prometheus"
echo "  - Instagram Connector: http://localhost:8084/actuator/prometheus"
echo ""
log_info "Observability Stack:"
echo "  - Prometheus:          http://localhost:9090"
echo "  - Grafana:             http://localhost:3000"
echo "    Username: admin"
echo "    Password: admin"
echo ""
log_info "Infrastructure:"
echo "  - MinIO Console:       http://localhost:9001"
echo "    Username: minioadmin"
echo "    Password: minioadmin"
echo ""
log_success "==================================================================="
echo ""

# Ask if user wants to run load tests
if command_exists k6; then
    echo ""
    read -p "$(echo -e ${YELLOW}Run baseline load test? [y/N]:${NC} )" -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Starting k6 baseline load test (5 minutes)..."
        log_info "Monitor in Grafana: http://localhost:3000"
        k6 run scripts/load-tests/baseline.js
        
        log_success "Baseline test complete!"
        log_info "Check Grafana dashboards for detailed metrics"
    fi
fi

# Show next steps
echo ""
log_info "Next Steps:"
echo "  1. Open Grafana: http://localhost:3000 (admin/admin)"
echo "  2. Navigate to Dashboards > Chat4All folder"
echo "  3. View available dashboards:"
echo "     - System Overview (overall health)"
echo "     - API Service (HTTP metrics)"
echo "     - Router Worker (processing metrics)"
echo "     - Connectors (circuit breaker, API latency)"
echo ""
echo "  4. Run additional load tests:"
echo "     - Spike Test:    k6 run scripts/load-tests/spike.js"
echo "     - Stress Test:   k6 run scripts/load-tests/stress.js"
echo "     - Soak Test:     k6 run scripts/load-tests/soak.js"
echo "     - Breakpoint:    k6 run scripts/load-tests/breakpoint.js"
echo "     - File Upload:   k6 run scripts/load-tests/file-upload.js"
echo "     - Mixed:         k6 run scripts/load-tests/mixed-workload.js"
echo ""
echo "  5. To stop all services:"
echo "     docker-compose down"
echo ""
log_success "Demo setup complete! Happy monitoring! 📊"
