#!/bin/bash
# Smoke Test - Observability Stack Validation

set -e

echo "=== Smoke Test - Observability ==="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

success() {
  echo -e "${GREEN}✓${NC} $1"
}

error() {
  echo -e "${RED}✗${NC} $1"
  exit 1
}

# 1. Verificar Prometheus up
echo "1. Checking Prometheus..."
if curl -sf http://localhost:9090/-/healthy > /dev/null; then
  success "Prometheus healthy"
else
  error "Prometheus down"
fi

# 2. Verificar Grafana up
echo "2. Checking Grafana..."
if curl -sf http://localhost:3000/api/health > /dev/null; then
  success "Grafana healthy"
else
  error "Grafana down"
fi

# 3. Verificar métricas API Service
echo "3. Checking API Service metrics..."
if curl -sf http://localhost:8080/actuator/prometheus | grep -q "http_requests_total"; then
  success "API metrics exposed"
else
  error "API metrics missing"
fi

# 4. Verificar métricas Router Worker
echo "4. Checking Router Worker metrics..."
if curl -sf http://localhost:8082/actuator/prometheus | grep -q "messages_consumed_total"; then
  success "Router metrics exposed"
else
  error "Router metrics missing"
fi

# 5. Verificar targets Prometheus
echo "5. Checking Prometheus targets..."
TARGETS=$(curl -sf http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.health=="up") | .job' | wc -l)
if [ "$TARGETS" -ge 4 ]; then
  success "Prometheus scraping $TARGETS targets"
else
  error "Only $TARGETS targets up (expected 4+)"
fi

# 6. Enviar mensagem de teste
echo "6. Sending test message..."
TOKEN=$(curl -sf -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"userId":"smoke_test"}' | jq -r '.token')

if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
  success "Auth token obtained"
else
  error "Auth failed"
fi

MSG_ID=$(curl -sf -X POST http://localhost:8080/api/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"content":"Smoke test message","channel":"whatsapp"}' | jq -r '.id')

if [ -n "$MSG_ID" ] && [ "$MSG_ID" != "null" ]; then
  success "Message sent: $MSG_ID"
else
  error "Message send failed"
fi

# 7. Verificar métrica foi incrementada
echo "7. Validating metrics update..."
sleep 2
COUNT=$(curl -sf 'http://localhost:9090/api/v1/query?query=messages_accepted_total' | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
if [ "$COUNT" != "0" ] && [ "$COUNT" != "null" ]; then
  success "Metrics updated (messages_accepted_total=$COUNT)"
else
  error "Metrics not updating"
fi

# 8. Verificar circuit breaker metrics
echo "8. Checking circuit breaker metrics..."
if curl -sf http://localhost:8083/actuator/prometheus | grep -q "circuit_breaker_state"; then
  success "Circuit breaker metrics exposed"
else
  error "Circuit breaker metrics missing"
fi

echo ""
echo -e "${GREEN}=== ✓ All smoke tests passed ===${NC}"
echo ""
echo "You can now:"
echo "  - View dashboards: http://localhost:3000 (admin/admin)"
echo "  - Query Prometheus: http://localhost:9090"
echo "  - Run load tests: k6 run scripts/load-tests/baseline.js"
