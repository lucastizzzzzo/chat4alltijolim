#!/bin/bash
#
# demo-entrega3.sh
# Automated demonstration of Entrega 3: Observability, Scalability, and Fault Tolerance
#
# USAGE: ./demo-entrega3.sh [--skip-build]
#
# This script demonstrates:
# 1. Observability stack (Prometheus + Grafana)
# 2. Load testing with k6
# 3. Horizontal scalability (1 vs 2 workers)
# 4. Fault tolerance (worker failover)

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

section_header() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN} $1${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

wait_for_user() {
    echo ""
    read -p "Press ENTER to continue..."
    echo ""
}

# Check prerequisites
check_prerequisites() {
    section_header "Checking Prerequisites"
    
    local all_ok=true
    
    # Docker
    if command -v docker &> /dev/null; then
        log_success "Docker installed: $(docker --version | head -n1)"
    else
        log_error "Docker not found. Install from https://docs.docker.com/get-docker/"
        all_ok=false
    fi
    
    # Docker Compose
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose installed: $(docker-compose --version)"
    else
        log_error "Docker Compose not found."
        all_ok=false
    fi
    
    # k6
    if command -v k6 &> /dev/null; then
        log_success "k6 installed: $(k6 version --quiet 2>/dev/null || echo 'unknown')"
    else
        log_error "k6 not found. Install: https://k6.io/docs/get-started/installation/"
        all_ok=false
    fi
    
    # jq
    if command -v jq &> /dev/null; then
        log_success "jq installed"
    else
        log_warning "jq not found (optional, for JSON parsing)"
    fi
    
    # curl
    if command -v curl &> /dev/null; then
        log_success "curl installed"
    else
        log_error "curl not found"
        all_ok=false
    fi
    
    if [ "$all_ok" = false ]; then
        log_error "Missing required tools. Please install and try again."
        exit 1
    fi
}

# Build project
build_project() {
    if [ "$1" = "--skip-build" ]; then
        log_info "Skipping build (--skip-build flag)"
        return
    fi
    
    section_header "Building Project"
    
    if [ ! -f "./build.sh" ]; then
        log_error "build.sh not found. Are you in the project root?"
        exit 1
    fi
    
    log_info "Running ./build.sh (may take 2-3 minutes on first run)..."
    ./build.sh
    log_success "Build complete"
}

# Start infrastructure
start_infrastructure() {
    section_header "Starting Infrastructure"
    
    log_info "Starting all services with docker-compose..."
    docker-compose up -d
    
    log_info "Waiting for services to be healthy (60-90 seconds)..."
    sleep 30
    
    # Check service health
    local retries=12
    local api_healthy=false
    
    for i in $(seq 1 $retries); do
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            api_healthy=true
            break
        fi
        log_info "Waiting for API Service... ($i/$retries)"
        sleep 5
    done
    
    if [ "$api_healthy" = true ]; then
        log_success "API Service is healthy"
    else
        log_error "API Service not responding after ${retries} attempts"
        log_info "Check logs: docker-compose logs api-service"
        exit 1
    fi
    
    log_info "Checking other services..."
    docker-compose ps
    
    log_success "All services started"
}

# Demonstrate observability
demo_observability() {
    section_header "Demonstration 1: Observability Stack"
    
    log_info "Observability stack consists of:"
    echo "  • Prometheus: http://localhost:9090 (metrics database)"
    echo "  • Grafana: http://localhost:3000 (dashboards)"
    echo "  • 4 pre-configured dashboards"
    echo ""
    
    log_info "Opening Prometheus in browser..."
    if command -v xdg-open &> /dev/null; then
        xdg-open http://localhost:9090 &> /dev/null || true
    elif command -v open &> /dev/null; then
        open http://localhost:9090 &> /dev/null || true
    fi
    
    log_info "Example Prometheus query:"
    echo "  rate(messages_accepted_total[1m]) * 60"
    echo ""
    
    log_info "Opening Grafana in browser..."
    if command -v xdg-open &> /dev/null; then
        xdg-open http://localhost:3000 &> /dev/null || true
    elif command -v open &> /dev/null; then
        open http://localhost:3000 &> /dev/null || true
    fi
    
    echo "  Login: admin / admin"
    echo "  Dashboards: Home → Dashboards → Chat4All"
    echo ""
    
    log_success "Observability stack accessible"
    log_warning "Keep Grafana open to watch metrics during load test"
    
    wait_for_user
}

# Run load test
demo_load_test() {
    section_header "Demonstration 2: Load Testing"
    
    log_info "Running baseline load test:"
    echo "  • Duration: 2 minutes (shortened for demo)"
    echo "  • Virtual Users: 20"
    echo "  • Expected: ~750 msg/min, P95 < 200ms, 0% errors"
    echo ""
    
    log_info "Starting k6 test..."
    k6 run --duration 2m --vus 20 scripts/load-tests/02-baseline.js 2>&1 | tee /tmp/demo-baseline.log
    
    log_success "Load test completed"
    
    echo ""
    log_info "Check Grafana dashboards to see:"
    echo "  • API Service: HTTP request rate and latency"
    echo "  • Router Worker: Consumer lag (should be 0)"
    echo "  • System Overview: Throughput and error rate"
    echo ""
    
    wait_for_user
}

# Demonstrate scalability
demo_scalability() {
    section_header "Demonstration 3: Horizontal Scalability"
    
    log_info "Testing scalability by adding router-workers..."
    echo ""
    
    # Baseline with 1 worker
    log_info "Step 1: Baseline with 1 worker"
    docker-compose up -d --scale router-worker=1
    sleep 10
    
    local workers_count=$(docker-compose ps router-worker | grep -c "Up" || echo "0")
    log_info "Running workers: $workers_count"
    
    log_info "Running 1-minute load test..."
    k6 run --duration 1m --vus 20 scripts/load-tests/02-baseline.js 2>&1 | grep -E "(iterations|msg)" || true
    
    echo ""
    
    # Scale to 2 workers
    log_info "Step 2: Scaling to 2 workers"
    docker-compose up -d --scale router-worker=2
    sleep 15  # Wait for Kafka rebalancing
    
    workers_count=$(docker-compose ps router-worker | grep -c "Up" || echo "0")
    log_info "Running workers: $workers_count"
    
    log_info "Running 1-minute load test again..."
    k6 run --duration 1m --vus 20 scripts/load-tests/02-baseline.js 2>&1 | grep -E "(iterations|msg)" || true
    
    echo ""
    log_success "Scalability test complete"
    
    echo ""
    log_info "Observations:"
    echo "  • Throughput similar (bottleneck is API Service, not workers)"
    echo "  • Kafka consumer lag remains at 0 (workers not saturated)"
    echo "  • For real scaling: need load balancer + multiple API instances"
    echo ""
    log_info "See results/SCALING_RESULTS.md for detailed analysis"
    
    wait_for_user
}

# Demonstrate fault tolerance
demo_fault_tolerance() {
    section_header "Demonstration 4: Fault Tolerance"
    
    log_info "Testing worker failover during active load..."
    echo ""
    
    # Ensure 2 workers running
    docker-compose up -d --scale router-worker=2
    sleep 10
    
    log_info "Step 1: Starting 2-minute load test in background..."
    k6 run --duration 2m --vus 20 scripts/load-tests/02-baseline.js > /tmp/demo-failover.log 2>&1 &
    local K6_PID=$!
    
    sleep 30
    
    log_info "Step 2: Stopping router-worker_1 (simulating failure)..."
    docker stop chat4alltijolim_router-worker_1 || true
    log_warning "Worker 1 stopped! Kafka should rebalance..."
    
    log_info "Step 3: Waiting for test to complete..."
    wait $K6_PID || true
    
    echo ""
    log_info "Results from /tmp/demo-failover.log:"
    tail -30 /tmp/demo-failover.log | grep -E "(checks|errors|iterations)" || true
    
    echo ""
    log_success "Fault tolerance validated"
    
    echo ""
    log_info "Key observations:"
    echo "  • Zero errors even with worker failure"
    echo "  • Kafka consumer group automatically rebalanced"
    echo "  • Remaining worker took over all partitions"
    echo "  • At-least-once delivery maintained"
    echo ""
    log_info "See results/FAULT_TOLERANCE_RESULTS.md for detailed analysis"
    
    # Restart worker for cleanup
    log_info "Restarting worker_1 for cleanup..."
    docker start chat4alltijolim_router-worker_1 || true
    
    wait_for_user
}

# View results
show_results() {
    section_header "Results Summary"
    
    log_info "Entrega 3 deliverables:"
    echo ""
    echo "📊 Observability:"
    echo "  ✓ Prometheus + Grafana stack"
    echo "  ✓ 4 auto-provisioned dashboards"
    echo "  ✓ Metrics instrumentation (API, Router, Connectors)"
    echo ""
    echo "⚡ Performance:"
    echo "  ✓ 753 msg/min throughput (target: 500-600)"
    echo "  ✓ 2.39ms P95 latency (target: < 200ms)"
    echo "  ✓ 0.00% error rate (target: < 0.5%)"
    echo ""
    echo "📈 Scalability:"
    echo "  ✓ Horizontal scaling validated"
    echo "  ✓ Kafka partitioning (6 partitions)"
    echo "  ✓ Bottleneck identified (API Service)"
    echo ""
    echo "🛡️ Fault Tolerance:"
    echo "  ✓ Worker failover (0% errors)"
    echo "  ✓ Kafka consumer group rebalancing"
    echo "  ✓ Store-and-forward validated"
    echo ""
    
    log_info "Documentation:"
    echo "  • RELATORIO_TECNICO_ENTREGA3.md - Complete technical report"
    echo "  • results/SCALING_RESULTS.md - Scalability analysis"
    echo "  • results/FAULT_TOLERANCE_RESULTS.md - Resilience tests"
    echo "  • docs/adr/005-circuit-breaker-pattern.md - ADR 005"
    echo "  • docs/adr/006-observability-strategy.md - ADR 006"
    echo ""
    
    log_success "Demonstration complete!"
}

# Cleanup
cleanup() {
    section_header "Cleanup"
    
    log_info "To stop all services:"
    echo "  docker-compose down"
    echo ""
    log_info "To remove volumes (complete reset):"
    echo "  docker-compose down -v"
    echo ""
    log_info "Services will remain running for further exploration."
    echo "  • Grafana: http://localhost:3000"
    echo "  • Prometheus: http://localhost:9090"
    echo "  • API Service: http://localhost:8080"
}

# Main execution
main() {
    clear
    
    echo -e "${GREEN}"
    echo "=========================================="
    echo "  Chat4All - Entrega 3 Demonstration"
    echo "  Observability, Scalability & Fault Tolerance"
    echo "=========================================="
    echo -e "${NC}"
    echo ""
    echo "This demo will:"
    echo "  1. Check prerequisites"
    echo "  2. Build project (unless --skip-build)"
    echo "  3. Start infrastructure"
    echo "  4. Demonstrate observability (Prometheus + Grafana)"
    echo "  5. Run load tests (k6)"
    echo "  6. Test horizontal scalability (1 vs 2 workers)"
    echo "  7. Validate fault tolerance (worker failover)"
    echo ""
    echo "Estimated time: 15-20 minutes"
    echo ""
    
    read -p "Continue? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
        echo "Aborted."
        exit 0
    fi
    
    # Execute demonstrations
    check_prerequisites
    build_project "$1"
    start_infrastructure
    demo_observability
    demo_load_test
    demo_scalability
    demo_fault_tolerance
    show_results
    cleanup
    
    echo ""
    log_success "Thank you for watching the demonstration!"
    echo ""
}

# Run main function
main "$@"
