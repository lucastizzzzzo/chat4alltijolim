# Observabilidade - Chat4All

## 📊 Visão Geral

Este documento descreve a implementação completa de observabilidade no Chat4All, conforme **Seção 2.4** do `esqueleto.md`. O sistema expõe métricas em formato Prometheus, dashboards Grafana para visualização, Circuit Breakers para resiliência, e scripts de load testing k6 para validação de performance.

## 🏗️ Arquitetura de Monitoramento

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ API Service │────▶│ Prometheus  │────▶│   Grafana   │────▶│  Dashboards │
│ :8080       │     │ :9090       │     │ :3000       │     │             │
│ /actuator/  │     │  Scraper    │     │Visualization│     │ - Overview  │
│ prometheus  │     │  (10-15s)   │     │             │     │ - API       │
└─────────────┘     └─────────────┘     └─────────────┘     │ - Router    │
       │                                                     │ - Connectors│
       ├─── Router Worker :8082 (Kafka, Cassandra)         └─────────────┘
       ├─── WhatsApp Connector :8083 (Circuit Breaker)
       └─── Instagram Connector :8084 (Circuit Breaker)
```

## 🎯 Métricas Implementadas

### API Service (`:8080/actuator/prometheus`)
- `http_requests_total{method, endpoint, status}` - Total de requisições HTTP
- `http_request_duration_seconds{method, endpoint}` - Latência de requisições
- `messages_accepted_total` - Mensagens aceitas pela API
- `messages_rejected_total{reason}` - Mensagens rejeitadas (auth_missing, auth_invalid, validation_failed)
- `files_uploaded_total` - Arquivos enviados
- `kafka_publish_duration_seconds` - Latência de publicação no Kafka

### Router Worker (`:8082/actuator/prometheus`)
- `messages_consumed_total` - Mensagens consumidas do Kafka
- `kafka_consumer_lag` - Consumer lag (atraso no processamento)
- `processing_duration_seconds` - Tempo total de processamento
- `messages_processed_total{status}` - Mensagens processadas por status (SENT, ROUTED, DELIVERED, FAILED, DUPLICATE)
- `cassandra_write_duration_seconds` - Latência de escrita no Cassandra
- `messages_failed_total{reason}` - Falhas por razão (cassandra_error, processing_error, runtime_error)

### Conectores WhatsApp/Instagram (`:8083`, `:8084`)
- `messages_sent_total{channel, status}` - Mensagens enviadas por canal (whatsapp, instagram)
- `connector_api_duration_seconds{channel}` - Latência de chamadas API externa
- `circuit_breaker_state{channel}` - Estado do circuit breaker (0=CLOSED, 1=OPEN, 50=HALF_OPEN)
- `circuit_breaker_transitions_total{channel, from, to}` - Transições de estado do circuit breaker

## 🚀 Início Rápido

### 1. Demo Completo (Recomendado)

```bash
# Executa script automático que:
# - Constrói aplicação
# - Inicia todos os serviços
# - Executa health checks
# - Oferece executar baseline test
./scripts/demo-observability.sh
```

### 2. Acesso aos Componentes

| Componente | URL | Credenciais |
|------------|-----|-------------|
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | - |
| API Service | http://localhost:8080 | - |
| MinIO Console | http://localhost:9001 | minioadmin / minioadmin |

### 3. Dashboards Grafana

Navegue para **Dashboards → Chat4All** folder:

1. **System Overview** - Visão geral do sistema
   - HTTP RPS total
   - Messages/sec aceitos
   - Consumer lag
   - Processing latency p95

2. **API Service** - Métricas HTTP e Kafka
   - Request rate por endpoint
   - HTTP latency p95
   - Message acceptance/rejection rate
   - Kafka publish latency (p50, p95, p99)

3. **Router Worker** - Processamento de mensagens
   - Kafka consumer lag (gauge com thresholds)
   - Message consumption rate
   - Processing status distribution (DELIVERED, ROUTED, DUPLICATE, FAILED)
   - Processing duration (p50, p95, p99)
   - Cassandra write latency p95

4. **Connectors** - WhatsApp e Instagram
   - Messages sent per channel (success/failed)
   - Circuit breaker state (CLOSED/OPEN/HALF_OPEN)
   - Connector API latency (p50, p95, p99)
   - Circuit breaker transitions (visualiza quando abre/fecha)

## 📈 Load Testing com k6

### Testes Disponíveis

| Teste | Duração | Carga | Propósito |
|-------|---------|-------|-----------|
| **baseline.js** | 5 min | 100 RPS | Estabelecer baseline de performance |
| **spike.js** | 2 min | 0→1000 RPS | Validar comportamento em picos de tráfego |
| **stress.js** | 10 min | 0→500 RPS gradual | Encontrar ponto de degradação |
| **soak.js** | 30 min | 200 RPS constante | Detectar memory leaks e estabilidade |
| **breakpoint.js** | Variável | Até falhar | Encontrar RPS máximo absoluto |
| **file-upload.js** | 5 min | 50 RPS | Performance com uploads de 1MB |
| **mixed-workload.js** | 10 min | 150 RPS | 80% texto + 20% arquivos (cenário real) |

### Executar Testes

```bash
# Baseline (recomendado para começar)
k6 run scripts/load-tests/baseline.js

# Spike test
k6 run scripts/load-tests/spike.js

# Stress test (encontra limites)
k6 run scripts/load-tests/stress.js

# Soak test (30 minutos - detecta memory leaks)
k6 run scripts/load-tests/soak.js

# Breakpoint (encontra RPS máximo)
k6 run scripts/load-tests/breakpoint.js

# File upload test
k6 run scripts/load-tests/file-upload.js

# Mixed workload (cenário realista)
k6 run scripts/load-tests/mixed-workload.js
```

### Interpretar Resultados

```bash
# Após cada teste, k6 exibe:
# - Total de requisições
# - RPS médio e máximo
# - Latência (p50, p95, p99, max)
# - Taxa de erro
# - Checks que passaram/falharam

# Exemplo de saída:
# ✓ status is 200
# ✓ response time < 200ms
# 
# http_req_duration..........: avg=85.2ms  p95=145ms  p99=180ms
# http_reqs..................: 30000 (100/s)
# errors.....................: 0.01% ✓ (3 requests failed)
```

### Thresholds (Critérios de Sucesso)

Cada teste define thresholds para validar performance:

```javascript
thresholds: {
  'http_req_duration': ['p(95)<200'],  // 95% das requests < 200ms
  'errors': ['rate<0.01'],             // Taxa de erro < 1%
  'http_req_failed': ['rate<0.01'],    // Falhas < 1%
}
```

Se algum threshold falhar, k6 retorna exit code 1.

## 🔧 Circuit Breaker

### Implementação

Ambos conectores (WhatsApp e Instagram) implementam o padrão Circuit Breaker para prevenir cascata de falhas:

**Estados:**
- **CLOSED** - Normal, todas as requisições passam
- **OPEN** - Falhas detectadas, requisições rejeitadas imediatamente (fail-fast)
- **HALF_OPEN** - Testando recuperação, permite 1 requisição de teste

**Transições:**
```
CLOSED ──(5 falhas consecutivas)──▶ OPEN
OPEN ──(30 segundos timeout)──▶ HALF_OPEN
HALF_OPEN ──(sucesso)──▶ CLOSED
HALF_OPEN ──(falha)──▶ OPEN
```

**Configuração:**
- `failureThreshold`: 5 falhas consecutivas abrem o circuito
- `recoveryTimeout`: 30 segundos antes de tentar HALF_OPEN
- `simulatedFailureRate`: 10% (apenas para testes)

### Monitoramento

```promql
# Ver estado atual do circuit breaker (0=CLOSED, 1=OPEN, 50=HALF_OPEN)
circuit_breaker_state{channel="whatsapp"}
circuit_breaker_state{channel="instagram"}

# Contar transições de estado
rate(circuit_breaker_transitions_total[5m])

# Detectar quando o circuit breaker abre
changes(circuit_breaker_state{channel="whatsapp"}[5m]) > 0 and circuit_breaker_state{channel="whatsapp"} == 1
```

### Código

Localização: `connector-*/src/main/java/.../CircuitBreaker.java`

```java
public boolean allowRequest() {
    synchronized (this) {
        if (state == State.OPEN) {
            if (System.currentTimeMillis() - lastFailureTime >= RECOVERY_TIMEOUT_MS) {
                transitionTo(State.HALF_OPEN);
                return true; // Permite request de teste
            }
            return false; // Rejeita request (fail-fast)
        }
        return true; // CLOSED ou HALF_OPEN permitem
    }
}
```

## 🚨 Alertas Prometheus

### Configuração de Alertas

Crie arquivo `monitoring/alerts.yml`:

```yaml
groups:
  - name: chat4all_alerts
    interval: 30s
    rules:
      # High Error Rate
      - alert: HighErrorRate
        expr: |
          rate(http_requests_total{status=~"5.."}[5m]) 
          / rate(http_requests_total[5m]) > 0.05
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High error rate on {{ $labels.service }}"
          description: "Error rate is {{ $value | humanizePercentage }}"

      # High Latency
      - alert: HighLatency
        expr: |
          histogram_quantile(0.95, 
            rate(http_request_duration_seconds_bucket[5m])
          ) > 0.5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High latency on {{ $labels.service }}"
          description: "P95 latency is {{ $value }}s"

      # Circuit Breaker Open
      - alert: CircuitBreakerOpen
        expr: circuit_breaker_state > 0.5
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Circuit breaker OPEN on {{ $labels.channel }}"
          description: "Connector {{ $labels.channel }} circuit breaker is OPEN"

      # High Consumer Lag
      - alert: HighConsumerLag
        expr: kafka_consumer_lag > 1000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High Kafka consumer lag"
          description: "Consumer lag is {{ $value }} messages"

      # Memory Usage High
      - alert: HighMemoryUsage
        expr: |
          jvm_memory_used_bytes{area="heap"} 
          / jvm_memory_max_bytes{area="heap"} > 0.90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.service }}"
          description: "Heap usage is {{ $value | humanizePercentage }}"

      # Service Down
      - alert: ServiceDown
        expr: up{job=~"api-service|router-worker|connector-.*"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "Prometheus cannot scrape {{ $labels.job }}"
```

### Adicionar Alertas ao Prometheus

Edite `monitoring/prometheus.yml`:

```yaml
rule_files:
  - "alerts.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']  # Opcional
```

### Testar Alertas

```bash
# Ver alertas ativos
curl http://localhost:9090/api/v1/alerts

# Ou na UI Prometheus: http://localhost:9090/alerts
```

## 🔍 Troubleshooting

### 1. Métricas não aparecem no Prometheus

**Sintoma:** Prometheus scrape failing ou métricas ausentes

**Diagnóstico:**
```bash
# Verificar targets no Prometheus
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job, health, lastError}'

# Testar endpoint diretamente
curl http://localhost:8080/actuator/prometheus
```

**Soluções:**
- Verificar se serviço está rodando: `docker ps`
- Verificar logs: `docker logs api-service`
- Validar `prometheus.yml` scrape config
- Confirmar porta correta no `scrape_configs`

### 2. Grafana não conecta ao Prometheus

**Sintoma:** "Data source not found" ou "Failed to fetch"

**Diagnóstico:**
```bash
# Testar conectividade do container Grafana
docker exec grafana wget -O- http://prometheus:9090/api/v1/query?query=up

# Ver logs do Grafana
docker logs grafana
```

**Soluções:**
- Confirmar Prometheus rodando: `curl http://localhost:9090`
- Verificar datasource em Grafana: Settings → Data sources → Prometheus
- URL deve ser `http://prometheus:9090` (nome do container, não localhost)
- Restart Grafana: `docker-compose restart grafana`

### 3. Dashboards vazios

**Sintoma:** Painéis mostram "No data" ou queries retornam vazio

**Diagnóstico:**
```bash
# Verificar se métricas existem no Prometheus
curl 'http://localhost:9090/api/v1/query?query=up'

# Verificar time range no dashboard (canto superior direito)
# Verificar se serviços estão gerando tráfego
```

**Soluções:**
- Gerar tráfego: `k6 run scripts/load-tests/baseline.js`
- Ajustar time range: "Last 15 minutes" → "Last 5 minutes"
- Verificar se Prometheus está scraping: http://localhost:9090/targets
- Confirmar query syntax no painel: Edit → Query inspector

### 4. Circuit breaker sempre OPEN

**Sintoma:** `circuit_breaker_state` sempre 1 (OPEN)

**Diagnóstico:**
```bash
# Ver logs do conector
docker logs connector-whatsapp 2>&1 | grep -i "circuit"

# Verificar transições de estado
curl 'http://localhost:9090/api/v1/query?query=circuit_breaker_transitions_total'
```

**Soluções:**
- Confirmar que serviço externo está acessível
- Verificar logs: `docker logs connector-whatsapp --tail 50`
- Reduzir `simulatedFailureRate` em `WhatsAppConnector.java` (atualmente 10%)
- Aguardar 30 segundos (recoveryTimeout) para HALF_OPEN

### 5. k6 test falha com "Connection refused"

**Sintoma:** `ERRO[0001] GoError: dial tcp 127.0.0.1:8080: connect: connection refused`

**Diagnóstico:**
```bash
# Verificar se API está rodando
curl http://localhost:8080/health

# Verificar portas
docker ps | grep 8080
```

**Soluções:**
- Iniciar stack: `docker-compose up -d`
- Aguardar health checks: `./scripts/demo-observability.sh`
- Confirmar porta correta no script k6
- Verificar firewall/iptables não está bloqueando

### 6. Consumer lag crescendo infinitamente

**Sintoma:** `kafka_consumer_lag` aumenta continuamente

**Diagnóstico:**
```bash
# Verificar taxa de consumo vs produção
curl 'http://localhost:9090/api/v1/query?query=rate(messages_consumed_total[5m])'
curl 'http://localhost:9090/api/v1/query?query=rate(messages_accepted_total[5m])'

# Ver logs do router-worker
docker logs router-worker --tail 100
```

**Soluções:**
- Escalar router-worker: `docker-compose up -d --scale router-worker=3`
- Verificar se Cassandra está respondendo: `docker logs cassandra`
- Reduzir carga de entrada (parar k6 tests)
- Aumentar `KAFKA_CONSUMER_THREADS` em `router-worker/Dockerfile`

### 7. Grafana dashboard não salva

**Sintoma:** "Dashboard not found" após refresh

**Diagnóstico:**
```bash
# Verificar volume Grafana
docker volume ls | grep grafana

# Ver logs
docker logs grafana --tail 50
```

**Soluções:**
- Dashboards em `monitoring/grafana/dashboards/` são read-only (provisioned)
- Para editar: salve uma cópia com novo nome
- Ou edite JSON diretamente e reinicie: `docker-compose restart grafana`

## 📊 Queries PromQL Úteis

### Performance Metrics

```promql
# Request rate por segundo
rate(http_requests_total[5m])

# Latência p95 (última hora)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[1h]))

# Taxa de erro (últimos 5 min)
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])

# Throughput total (messages/sec)
sum(rate(messages_accepted_total[5m]))
```

### Resource Utilization

```promql
# CPU usage (%)
process_cpu_usage * 100

# Heap memory usage (%)
jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"} * 100

# GC time (% of time in GC)
rate(jvm_gc_pause_seconds_sum[5m]) / rate(jvm_gc_pause_seconds_count[5m])
```

### Kafka Metrics

```promql
# Consumer lag total
sum(kafka_consumer_lag)

# Consumption rate (messages/sec)
rate(messages_consumed_total[5m])

# Kafka publish latency p99
histogram_quantile(0.99, rate(kafka_publish_duration_seconds_bucket[5m]))
```

### Circuit Breaker Metrics

```promql
# Estado atual (0=CLOSED, 1=OPEN, 50=HALF_OPEN)
circuit_breaker_state

# Taxa de transições (transições/min)
rate(circuit_breaker_transitions_total[5m]) * 60

# Tempo em estado OPEN (segundos)
time() - (circuit_breaker_state > 0) * time()
```

## 🧪 Testes de Validação

### Smoke Test (Validação Rápida)

```bash
#!/bin/bash
# scripts/smoke-test-observability.sh

echo "=== Smoke Test - Observability ==="

# 1. Verificar Prometheus up
if curl -sf http://localhost:9090/-/healthy > /dev/null; then
  echo "✓ Prometheus healthy"
else
  echo "✗ Prometheus down"; exit 1
fi

# 2. Verificar Grafana up
if curl -sf http://localhost:3000/api/health > /dev/null; then
  echo "✓ Grafana healthy"
else
  echo "✗ Grafana down"; exit 1
fi

# 3. Verificar métricas API Service
if curl -sf http://localhost:8080/actuator/prometheus | grep -q "http_requests_total"; then
  echo "✓ API metrics exposed"
else
  echo "✗ API metrics missing"; exit 1
fi

# 4. Verificar métricas Router Worker
if curl -sf http://localhost:8082/actuator/prometheus | grep -q "messages_consumed_total"; then
  echo "✓ Router metrics exposed"
else
  echo "✗ Router metrics missing"; exit 1
fi

# 5. Verificar targets Prometheus
TARGETS=$(curl -sf http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.health=="up") | .job' | wc -l)
if [ "$TARGETS" -ge 4 ]; then
  echo "✓ Prometheus scraping $TARGETS targets"
else
  echo "✗ Only $TARGETS targets up (expected 4+)"; exit 1
fi

# 6. Enviar mensagem de teste
TOKEN=$(curl -sf -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"userId":"smoke_test"}' | jq -r '.token')

if [ -n "$TOKEN" ]; then
  echo "✓ Auth token obtained"
else
  echo "✗ Auth failed"; exit 1
fi

MSG_ID=$(curl -sf -X POST http://localhost:8080/api/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"content":"Smoke test","channel":"whatsapp"}' | jq -r '.id')

if [ -n "$MSG_ID" ]; then
  echo "✓ Message sent: $MSG_ID"
else
  echo "✗ Message send failed"; exit 1
fi

# 7. Verificar métrica foi incrementada
sleep 2
COUNT=$(curl -sf 'http://localhost:9090/api/v1/query?query=messages_accepted_total' | jq -r '.data.result[0].value[1]')
if [ "$COUNT" -gt 0 ]; then
  echo "✓ Metrics updated (messages_accepted_total=$COUNT)"
else
  echo "✗ Metrics not updating"; exit 1
fi

echo ""
echo "=== ✓ All smoke tests passed ==="
```

### Executar Smoke Test

```bash
chmod +x scripts/smoke-test-observability.sh
./scripts/smoke-test-observability.sh
```

## 📚 Referências

### Documentação Oficial
- [Prometheus](https://prometheus.io/docs/)
- [Grafana](https://grafana.com/docs/)
- [k6](https://k6.io/docs/)
- [Micrometer](https://micrometer.io/docs)

### Padrões e Best Practices
- [Circuit Breaker Pattern - Martin Fowler](https://martinfowler.com/bliki/CircuitBreaker.html)
- [Google SRE Book - Monitoring](https://sre.google/sre-book/monitoring-distributed-systems/)
- [RED Method](https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/) - Rate, Errors, Duration
- [USE Method](http://www.brendangregg.com/usemethod.html) - Utilization, Saturation, Errors

### Arquivos do Projeto
- Configuração Prometheus: `monitoring/prometheus.yml`
- Dashboards Grafana: `monitoring/grafana/dashboards/*.json`
- Load tests k6: `scripts/load-tests/*.js`
- Demo script: `scripts/demo-observability.sh`
- Circuit Breaker: `connector-*/src/main/java/.../CircuitBreaker.java`

---

**Status**: ✅ Implementação completa - Entrega 3  
**Última atualização**: 2024

**Sintoma:** "Data source not found" ou "Failed to fetch"

**Diagnóstico:**
```bash
# Testar conectividade do container Grafana
docker exec grafana wget -O- http://prometheus:9090/api/v1/query?query=up

# Ver logs do Grafana
docker logs grafana
```

**Soluções:**
- Confirmar Prometheus rodando: `curl http://localhost:9090`
- Verificar datasource em Grafana: Settings → Data sources → Prometheus
- URL deve ser `http://prometheus:9090` (nome do container, não localhost)
- Restart Grafana: `docker-compose restart grafana`

### 3. Dashboards vazios
  - Latência HTTP (P50, P95, P99)
  - Error rate (%)
  - Top 10 conversas por volume

### Dashboard 2: Kafka & Event Processing
- **Objetivo**: Monitorar barramento de eventos
- **Painéis**:
  - Messages published vs consumed
  - Consumer lag por partition
  - Tempo de processamento do Router Worker
  - Total de mensagens pendentes

### Dashboard 3: Infrastructure Health
- **Objetivo**: Saúde da infraestrutura
- **Painéis**:
  - CPU usage por container
  - Memory usage por container
  - Cassandra write latency
  - MinIO bandwidth (upload/download)
  - Health check status (verde/vermelho)

### Dashboard 4: Business Metrics
- **Objetivo**: Métricas de negócio
- **Painéis**:
  - Distribuição de mensagens por status (SENT/DELIVERED/READ)
  - Top canais de entrega (WhatsApp vs Instagram)
  - Files uploaded (count + total size)
  - Últimas mensagens com file_id (real-time)

> 🚧 **Dashboards em Desenvolvimento** - Os JSON files serão adicionados em `monitoring/grafana/dashboards/`

## 🔍 Queries Prometheus Úteis

### Validar Requisitos de Performance

```promql
# Throughput: Mensagens aceitas por segundo
rate(messages_accepted_total[1m])

# Latência P95: Duração de requisições HTTP (95º percentil)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Latência P99
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Error rate: Percentual de erros 5xx
rate(http_requests_by_status_total{status=~"5.."}[1m]) 
/ 
rate(http_requests_total[1m]) * 100

# Tempo médio de publicação no Kafka
rate(kafka_publish_duration_seconds_sum[5m]) 
/ 
rate(kafka_publish_duration_seconds_count[5m])

# Arquivos grandes (>100MB) enviados por hora
increase(files_uploaded_by_size_total{size_bucket="xlarge"}[1h])
```

### Monitorar Saúde do Sistema

```promql
# Memory usage por serviço
jvm_memory_used_bytes{service="api-service", area="heap"}

# CPU usage (processo Java)
process_cpu_usage{service="api-service"}

# Threads ativas
jvm_threads_live{service="api-service"}

# GC pauses longas (> 100ms)
histogram_quantile(0.99, rate(jvm_gc_pause_seconds_bucket[5m])) > 0.1
```

## 🔧 Health Checks

### Liveness Check (Simple)
```bash
# Endpoint: GET /health
# Propósito: Verificar se o serviço está vivo
# Uso: Docker healthcheck, Kubernetes liveness probe

curl http://localhost:8080/health
# Response: {"status":"UP"}
```

### Readiness Check (Detailed)
```bash
# Endpoint: GET /actuator/health
# Propósito: Verificar se o serviço está pronto para receber tráfego
# Uso: Kubernetes readiness probe, load balancer checks

curl http://localhost:8080/actuator/health
# Response:
{
  "status": "UP",
  "components": {
    "kafka": {
      "status": "UP",
      "latency_ms": 5
    },
    "cassandra": {
      "status": "UP",
      "latency_ms": 12
    }
  },
  "timestamp": "2025-11-26T21:30:45Z",
  "check_duration_ms": 18
}
```

### Docker Healthcheck
```yaml
# Configurado em docker-compose.yml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

## 📊 Validação de SLA

### Requisitos (esqueleto.md - Seção 1.1)

| Requisito | Métrica | Query Prometheus | Target |
|-----------|---------|------------------|--------|
| **Throughput** | Mensagens/minuto | `rate(messages_accepted_total[1m]) * 60` | ≥ 10,000 |
| **Latência P95** | HTTP request duration | `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))` | < 0.2s (200ms) |
| **Error Rate** | % de erros | `rate(http_requests_by_status_total{status=~"5.."}[1m]) / rate(http_requests_total[1m]) * 100` | < 0.1% |
| **Disponibilidade** | Uptime | `up{job="api-service"}` | > 99.9% |

### Comandos de Verificação

```bash
# Verificar throughput atual
curl -s 'http://localhost:9090/api/v1/query?query=rate(messages_accepted_total[1m])*60' | jq '.data.result[0].value[1]'

# Verificar P95 latency
curl -s 'http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,rate(http_request_duration_seconds_bucket[5m]))' | jq '.data.result[0].value[1]'

# Verificar error rate
curl -s 'http://localhost:9090/api/v1/query?query=rate(http_requests_by_status_total{status=~"5.."}[1m])/rate(http_requests_total[1m])*100' | jq '.data.result[0].value[1]'
```

## 🐛 Troubleshooting

### Prometheus não está coletando métricas

```bash
# 1. Verificar se Prometheus está rodando
docker ps | grep prometheus

# 2. Verificar targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job, health, lastError}'

# 3. Verificar se o endpoint está acessível
curl http://api-service:8080/actuator/prometheus

# 4. Verificar logs do Prometheus
docker logs chat4all-prometheus
```

### Grafana não mostra dados

```bash
# 1. Verificar datasource
curl -u admin:admin http://localhost:3000/api/datasources | jq '.[].name'

# 2. Testar query no Prometheus
curl 'http://localhost:9090/api/v1/query?query=up'

# 3. Verificar logs do Grafana
docker logs chat4all-grafana
```

### Métricas não aparecem

```bash
# 1. Verificar se o endpoint existe
curl -v http://localhost:8080/actuator/prometheus 2>&1 | grep "HTTP/"

# 2. Verificar se há métricas sendo geradas
# Enviar algumas mensagens e verificar
curl http://localhost:8080/actuator/prometheus | grep messages_accepted_total

# 3. Verificar logs da aplicação
docker logs api-service 2>&1 | grep -i metric
```

## 📚 Referências

- **Arquitetura**: `esqueleto.md` - Seção 2.4 (Observabilidade)
- **Requisitos**: `esqueleto.md` - Seção 1.1 (Requisitos Críticos de Performance)
- **Implementação**: `entrega3.md` - Atividade 1 (Implementar Stack de Observabilidade)
- **Prometheus**: https://prometheus.io/docs/
- **Grafana**: https://grafana.com/docs/
- **Micrometer**: https://micrometer.io/docs/

## ✅ Status de Implementação

- [x] Prometheus configurado no docker-compose.yml
- [x] Grafana configurado no docker-compose.yml
- [x] prometheus.yml com targets dos microsserviços
- [x] Datasource Prometheus no Grafana (auto-provisioning)
- [x] API Service: endpoint /actuator/prometheus
- [x] API Service: métricas HTTP, mensagens, arquivos, Kafka
- [x] API Service: health checks (/health e /actuator/health)
- [x] MetricsInterceptor: captura automática de métricas HTTP
- [ ] Router Worker: endpoint /actuator/prometheus
- [ ] Connectors: endpoint /actuator/prometheus
- [ ] Dashboards Grafana (JSON files)
- [ ] Alertas configurados
- [ ] Documentação de queries avançadas

---

**Chat4All - Observabilidade**  
**Status**: 🔄 Parcialmente Implementado (60%)  
**Próximo**: Implementar métricas no Router Worker e Connectors
