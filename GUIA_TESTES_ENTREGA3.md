# 🧪 Guia de Testes - Entrega 3

**Objetivo:** Validar todos os componentes da Entrega 3 (observabilidade, escalabilidade, tolerância a falhas)  
**Tempo estimado:** 30-45 minutos  
**Pré-requisitos:** Docker, Docker Compose, k6, curl, jq

---

## 📋 Índice

1. [Preparação do Ambiente](#1-preparação-do-ambiente)
2. [Teste Rápido (5 minutos)](#2-teste-rápido-5-minutos)
3. [Teste Completo (30 minutos)](#3-teste-completo-30-minutos)
4. [Testes Individuais](#4-testes-individuais)
5. [Troubleshooting](#5-troubleshooting)

---

## 1. Preparação do Ambiente

### 1.1. Verificar Pré-requisitos

```bash
cd /home/tizzo/chat4alltijolim

# Verificar Docker
docker --version
# Esperado: Docker version 24.0.0 ou superior

# Verificar Docker Compose
docker-compose --version
# Esperado: Docker Compose version 2.20.0 ou superior

# Verificar k6
k6 version
# Esperado: k6 v0.45.0 ou superior

# Verificar curl e jq
curl --version
jq --version
```

**Se k6 não estiver instalado:**
```bash
# macOS
brew install k6

# Linux (Debian/Ubuntu)
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6

# Ou download direto
wget https://github.com/grafana/k6/releases/download/v0.45.0/k6-v0.45.0-linux-amd64.tar.gz
tar -xzf k6-v0.45.0-linux-amd64.tar.gz
sudo mv k6-v0.45.0-linux-amd64/k6 /usr/local/bin/
```

### 1.2. Limpar Ambiente Anterior (Se Necessário)

```bash
# Parar containers antigos
docker-compose down -v

# Limpar volumes órfãos
docker volume prune -f

# Verificar que nada está rodando
docker-compose ps
# Esperado: Empty response
```

---

## 2. Teste Rápido (5 minutos)

**Objetivo:** Validação rápida de que tudo está funcionando

### 2.1. Build do Projeto

```bash
# Build de todos os módulos
./build.sh

# Verificar que JARs foram criados
ls -lh api-service/target/*.jar
ls -lh router-worker/target/*.jar
ls -lh connector-*/target/*.jar
# Esperado: 4 arquivos .jar (~10-15 MB cada)
```

### 2.2. Iniciar Infraestrutura

```bash
# Subir toda a stack
docker-compose up -d

# Aguardar containers ficarem healthy (30-60s)
echo "Aguardando containers..."
sleep 60

# Verificar status
docker-compose ps
```

**Esperado:**
```
NAME                          STATUS
chat4alltijolim-api-service   Up (healthy)
chat4alltijolim-cassandra     Up (healthy)
chat4alltijolim-grafana       Up (healthy)
chat4alltijolim-instagram     Up (healthy)
chat4alltijolim-kafka         Up (healthy)
chat4alltijolim-minio         Up (healthy)
chat4alltijolim-prometheus    Up (healthy)
chat4alltijolim-router-worker Up (healthy)
chat4alltijolim-whatsapp      Up (healthy)
chat4alltijolim-zookeeper     Up (healthy)
```

### 2.3. Smoke Test de Observabilidade

```bash
# Executar smoke test automatizado
./scripts/smoke-test-observability.sh
```

**Esperado:**
```
✅ Prometheus responding (200)
✅ Grafana responding (200)
✅ API Service metrics endpoint (200)
✅ Router Worker metrics endpoint (200)
✅ WhatsApp Connector metrics endpoint (200)
✅ Instagram Connector metrics endpoint (200)
✅ Prometheus scraping 6 targets
✅ All targets are UP

🎉 All observability checks passed!
```

### 2.4. Verificar Dashboards Grafana

```bash
# Abrir Grafana no navegador
echo "Abra: http://localhost:3000"
echo "Login: admin"
echo "Senha: admin"
```

**Passos no navegador:**
1. Acesse http://localhost:3000
2. Login com `admin` / `admin` (skip password change)
3. Vá em **Dashboards** (ícone de 4 quadrados)
4. Verifique que existem 4 dashboards:
   - ✅ Chat4All - System Overview
   - ✅ Chat4All - API Service
   - ✅ Chat4All - Router Worker
   - ✅ Chat4All - Connectors

### 2.5. Teste Funcional Básico

```bash
# Registrar usuário
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "test123",
    "email": "test@example.com"
  }'
# Esperado: {"status":"success","userId":"..."}

# Login
TOKEN=$(curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "test123"
  }' | jq -r '.token')

echo "Token obtido: $TOKEN"

# Enviar mensagem
curl -X POST http://localhost:8080/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "userId": "'$TOKEN'",
    "message": "Hello from test!",
    "channel": "whatsapp",
    "destination": "+5511999999999"
  }'
# Esperado: {"status":"pending","messageId":"..."}
```

### 2.6. Verificar Métricas no Prometheus

```bash
# Abrir Prometheus
echo "Abra: http://localhost:9090"
echo "Query de teste: http_requests_total"
```

**No navegador Prometheus:**
1. Acesse http://localhost:9090
2. Cole a query: `http_requests_total`
3. Clique em **Execute**
4. Verifique que aparecem valores > 0

**✅ Se tudo passou, ambiente está OK!**

---

## 3. Teste Completo (30 minutos)

**Objetivo:** Executar demonstração completa automatizada

### 3.1. Demonstração Automatizada

```bash
# Executar demo completa (15-20 min)
./demo-entrega3.sh
```

**O script executará:**
1. ✅ Verificação de pré-requisitos
2. ✅ Build do projeto
3. ✅ Start da infraestrutura (Docker Compose)
4. ✅ Demonstração de observabilidade
   - Prometheus targets
   - Grafana dashboards
   - Métricas dos serviços
5. ✅ Load test baseline (5 min)
   - 20 VUs simultâneos
   - 5 minutos de execução
   - Validação de throughput e latência
6. ✅ Teste de escalabilidade (1 vs 2 workers)
   - Baseline com 1 worker
   - Scale para 2 workers
   - Comparação de performance
7. ✅ Teste de failover (3 min)
   - Load test ativo
   - Worker parado aos 30s
   - Validação de 0% erros
8. ✅ Resumo de resultados

**Saída esperada (final):**
```
╔══════════════════════════════════════════════════════════════╗
║           📊 RESUMO DOS RESULTADOS - ENTREGA 3              ║
╚══════════════════════════════════════════════════════════════╝

✅ Observabilidade
   • Prometheus: http://localhost:9090
   • Grafana: http://localhost:3000 (admin/admin)
   • Targets: 6/6 UP
   • Dashboards: 4 provisionados

✅ Performance (Baseline Test - 5min)
   • Throughput: 753 msg/min (meta: 500-600)
   • P95 Latency: 2.39ms (meta: <200ms)
   • P99 Latency: 4.85ms (meta: <500ms)
   • Error Rate: 0.00% (meta: <0.5%)

✅ Escalabilidade
   • 1 worker: 746 msg/min
   • 2 workers: 744 msg/min
   • Bottleneck: API Service (não workers)
   • Consumer lag: 0 msgs

✅ Tolerância a Falhas
   • Failover test: 0.00% erros
   • Recovery time: ~5 segundos
   • Message loss: Zero
   • Kafka rebalancing: OK

🎉 TODOS OS TESTES PASSARAM!
```

### 3.2. Validar Resultados Detalhados

```bash
# Ver resultados do load test
cat scripts/load-tests/results/baseline-*.json | jq '{
  http_req_duration_p95: .metrics.http_req_duration.values."p(95)",
  http_req_duration_p99: .metrics.http_req_duration.values."p(99)",
  iterations: .metrics.iterations.values.count,
  http_req_failed_rate: .metrics.http_req_failed.values.rate
}'

# Ver análise de escalabilidade
cat results/SCALING_RESULTS.md

# Ver análise de fault tolerance
cat results/FAULT_TOLERANCE_RESULTS.md
```

---

## 4. Testes Individuais

**Se preferir executar cada teste separadamente:**

### 4.1. Load Test - Warmup (2 min)

```bash
cd scripts/load-tests

# Primeiro, obter um token
TOKEN=$(curl -s -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{"username":"loadtest","password":"test123","email":"load@test.com"}' \
  | jq -r '.userId' && \
  curl -s -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"loadtest","password":"test123"}' \
  | jq -r '.token')

# Executar warmup
k6 run --env AUTH_TOKEN=$TOKEN 01-warmup.js

cd ../..
```

**Validação:**
- ✅ `checks.........................: 100.00%`
- ✅ `http_req_failed...............: 0.00%`
- ✅ `iterations.....................: ~100` (5 VUs × 2 min × ~10 iter/min)

### 4.2. Load Test - Baseline (5 min) 🔥

```bash
cd scripts/load-tests

# Executar teste principal
k6 run --env AUTH_TOKEN=$TOKEN 02-baseline.js

cd ../..
```

**Métricas Esperadas:**
- ✅ Throughput: **700-800 msg/min** (~12 msg/s)
- ✅ P95 latency: **< 10ms**
- ✅ P99 latency: **< 20ms**
- ✅ Error rate: **0.00%**
- ✅ Checks: **100.00%**

**Durante o teste, acompanhe no Grafana:**
1. Acesse http://localhost:3000
2. Dashboard: **Chat4All - System Overview**
3. Observe:
   - Request Rate aumentando
   - Latência estável
   - Zero erros

### 4.3. Load Test - Spike (3m30s)

```bash
cd scripts/load-tests

# Executar spike test
k6 run --env AUTH_TOKEN=$TOKEN 03-spike.js

cd ../..
```

**Validação:**
- ✅ Fase 1 (30s): 5 VUs → baseline
- ✅ Fase 2 (60s): 50 VUs → **peak ~1,800 msg/min**
- ✅ Fase 3 (120s): 5 VUs → recovery, consumer lag reduzindo
- ✅ Error rate: **0.00%** durante todo o teste
- ✅ Store-and-forward: mensagens acumulam e são processadas

### 4.4. Load Test - File Upload (3 min)

```bash
cd scripts/load-tests

# Executar teste de upload
k6 run --env AUTH_TOKEN=$TOKEN 04-file-upload.js

cd ../..
```

**Validação:**
- ✅ Uploads de 100KB: sucesso
- ✅ Uploads de 1MB: sucesso
- ✅ Presigned URLs: geradas corretamente
- ✅ MinIO storage: arquivos salvos

### 4.5. Teste de Escalabilidade

#### Passo 1: Baseline com 1 Worker

```bash
# Garantir que há 1 worker
docker-compose up -d --scale router-worker=1

# Aguardar 30s para estabilizar
sleep 30

# Executar load test
cd scripts/load-tests
k6 run --env AUTH_TOKEN=$TOKEN 02-baseline.js > baseline-1worker.txt
cd ../..

# Capturar throughput
grep "iterations" baseline-1worker.txt
```

#### Passo 2: Scale para 2 Workers

```bash
# Aumentar para 2 workers
docker-compose up -d --scale router-worker=2

# Aguardar consumer group rebalancing (60s)
echo "Aguardando rebalancing..."
sleep 60

# Executar load test novamente
cd scripts/load-tests
k6 run --env AUTH_TOKEN=$TOKEN 02-baseline.js > baseline-2workers.txt
cd ../..

# Capturar throughput
grep "iterations" baseline-2workers.txt
```

#### Passo 3: Comparar Resultados

```bash
echo "=== 1 Worker ==="
grep -E "iterations|http_req_duration" baseline-1worker.txt

echo "=== 2 Workers ==="
grep -E "iterations|http_req_duration" baseline-2workers.txt
```

**Análise Esperada:**
- Throughput similar (~746 msg/min vs ~744 msg/min)
- Bottleneck identificado: **API Service**, não workers
- Consumer lag: **0 msgs** (workers ociosos)
- Distribuição: **~50/50** entre workers

### 4.6. Teste de Fault Tolerance (Worker Failover)

#### Passo 1: Iniciar Load Test em Background

```bash
# Em um terminal separado, iniciar load test de 3 min
cd scripts/load-tests
k6 run --env AUTH_TOKEN=$TOKEN --duration 3m 02-baseline.js &
LOAD_TEST_PID=$!
```

#### Passo 2: Parar um Worker Durante Execução

```bash
# Aguardar 30s (load test estável)
sleep 30

# Identificar um dos workers
WORKER_ID=$(docker ps --filter "name=router-worker" --format "{{.ID}}" | head -1)
echo "Parando worker: $WORKER_ID"

# Parar worker
docker stop $WORKER_ID

# Logs do Kafka (em outro terminal)
docker-compose logs -f router-worker | grep -i "rebalance"
```

#### Passo 3: Validar Resultado

```bash
# Aguardar load test terminar
wait $LOAD_TEST_PID

# Verificar erro rate
echo "Error rate deve ser 0.00%"

# Verificar logs de rebalancing
docker-compose logs router-worker | grep "partitions assigned"
```

**Validação:**
- ✅ Error rate: **0.00%** (zero mensagens perdidas)
- ✅ Recovery time: **~5 segundos** (Kafka rebalancing)
- ✅ Mensagens roteadas automaticamente para worker sobrevivente
- ✅ Nenhuma intervenção manual necessária

### 4.7. Verificar Métricas Prometheus

```bash
# Query de throughput
curl -s 'http://localhost:9090/api/v1/query?query=rate(http_requests_total[1m])' \
  | jq '.data.result[] | {instance: .metric.instance, rate: .value[1]}'

# Query de latência P95
curl -s 'http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,rate(http_request_duration_seconds_bucket[1m]))' \
  | jq '.data.result[] | {instance: .metric.instance, p95_ms: (.value[1] | tonumber * 1000)}'

# Query de consumer lag
curl -s 'http://localhost:9090/api/v1/query?query=kafka_consumer_lag' \
  | jq '.data.result[] | {partition: .metric.partition, lag: .value[1]}'

# Query de circuit breaker (preparado)
curl -s 'http://localhost:9090/api/v1/query?query=circuit_breaker_state' \
  | jq '.data.result[] | {connector: .metric.connector, state: .value[1]}'
```

### 4.8. Explorar Dashboards Grafana

#### Dashboard: System Overview
```bash
# Abrir no navegador
open http://localhost:3000/d/system-overview/chat4all-system-overview
```

**Painéis a verificar:**
- HTTP Request Rate (por serviço)
- Request Latency (P50, P95, P99)
- Error Rate
- JVM Memory Usage
- Kafka Consumer Lag

#### Dashboard: API Service
```bash
open http://localhost:3000/d/api-service/chat4all-api-service
```

**Painéis a verificar:**
- Request Duration (histogram)
- Messages Accepted vs Rejected
- Files Uploaded
- Kafka Publish Duration

#### Dashboard: Router Worker
```bash
open http://localhost:3000/d/router-worker/chat4all-router-worker
```

**Painéis a verificar:**
- Messages Processed
- Consumer Lag (por partition)
- Processing Duration
- Status Updates Published

#### Dashboard: Connectors
```bash
open http://localhost:3000/d/connectors/chat4all-connectors
```

**Painéis a verificar:**
- Messages Sent (por channel e status)
- Connector API Latency
- Circuit Breaker State (quando ativado)

---

## 5. Troubleshooting

### Problema 1: Containers não ficam healthy

**Sintoma:**
```bash
docker-compose ps
# NAME                      STATUS
# chat4alltijolim-kafka    Up (health: starting)
```

**Diagnóstico:**
```bash
# Ver logs do container problemático
docker-compose logs kafka

# Verificar health check
docker inspect chat4alltijolim-kafka | jq '.[0].State.Health'
```

**Solução:**
```bash
# Aguardar mais tempo (Kafka demora ~60s)
sleep 60

# Ou reiniciar container específico
docker-compose restart kafka
```

### Problema 2: k6 retorna erros 401 (Unauthorized)

**Sintoma:**
```
✗ status is 200
↳  0% — ✓ 0 / ✗ 100
```

**Diagnóstico:**
```bash
# Verificar se token está válido
echo $TOKEN

# Verificar endpoint de login
curl -v -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"loadtest","password":"test123"}'
```

**Solução:**
```bash
# Recriar usuário de teste
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "loadtest",
    "password": "test123",
    "email": "load@test.com"
  }'

# Obter novo token
TOKEN=$(curl -s -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"loadtest","password":"test123"}' \
  | jq -r '.token')

# Re-executar teste
k6 run --env AUTH_TOKEN=$TOKEN 02-baseline.js
```

### Problema 3: Prometheus não scraping targets

**Sintoma:**
```
http://localhost:9090/targets
# Todos os targets em DOWN
```

**Diagnóstico:**
```bash
# Verificar network do Docker
docker network ls
docker network inspect chat4all-network

# Testar conectividade entre containers
docker exec chat4alltijolim-prometheus wget -O- http://api-service:8080/actuator/prometheus
```

**Solução:**
```bash
# Reiniciar Prometheus
docker-compose restart prometheus

# Ou recriar network
docker-compose down
docker network rm chat4all-network
docker-compose up -d
```

### Problema 4: Grafana não mostra dados

**Sintoma:**
- Dashboards carregam, mas gráficos vazios

**Diagnóstico:**
```bash
# Verificar datasource no Grafana
curl -s http://admin:admin@localhost:3000/api/datasources | jq
```

**Solução:**
```bash
# Verificar que Prometheus está respondendo
curl http://localhost:9090/api/v1/query?query=up

# Re-provisionar Grafana
docker-compose restart grafana

# Aguardar 30s
sleep 30

# Recarregar dashboards no navegador (Ctrl+Shift+R)
```

### Problema 5: Load test com throughput baixo

**Sintoma:**
- k6 reporta apenas 100-200 msg/min (esperado: 700+)

**Diagnóstico:**
```bash
# Verificar CPU/RAM dos containers
docker stats

# Ver logs de erros
docker-compose logs api-service | grep -i error
docker-compose logs router-worker | grep -i error
```

**Possíveis Causas:**
1. **Build não executado:** Execute `./build.sh`
2. **Kafka partitions:** Verificar 6 partitions em `docker-compose.yml`
3. **Recursos limitados:** Aumentar memória Docker (Settings > Resources > 4GB+)
4. **Token inválido:** Recriar usuário de teste

**Solução:**
```bash
# Rebuild completo
docker-compose down -v
./build.sh
docker-compose up -d
sleep 60

# Re-executar teste
```

### Problema 6: Worker failover com erros

**Sintoma:**
- Durante teste de failover, error rate > 0%

**Diagnóstico:**
```bash
# Ver tempo de rebalancing
docker-compose logs router-worker | grep -A 5 "Revoking"

# Verificar session.timeout.ms (deve ser ~30s)
docker-compose exec kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --describe --group router-group
```

**Solução:**
- ✅ Comportamento esperado: **0% erros** (at-least-once delivery)
- ✅ Recovery time: **~5 segundos**
- ❌ Se houver erros, verificar logs detalhados:

```bash
docker-compose logs router-worker > worker-logs.txt
grep -i "error\|exception\|failed" worker-logs.txt
```

### Problema 7: Build.sh falha

**Sintoma:**
```
[ERROR] Failed to execute goal ... compilation failure
```

**Diagnóstico:**
```bash
# Verificar versão do Maven
mvn --version
# Esperado: Apache Maven 3.8.0+, Java 17+

# Ver erro completo
./build.sh 2>&1 | tee build-error.txt
```

**Solução:**
```bash
# Limpar cache Maven
mvn clean

# Rebuild com verbose
mvn clean package -X
```

---

## 6. Validação Final - Checklist

Antes de considerar os testes concluídos, verifique:

### Infraestrutura
- [ ] 10 containers rodando (docker-compose ps)
- [ ] Todos com status "Up (healthy)"
- [ ] Prometheus: http://localhost:9090 acessível
- [ ] Grafana: http://localhost:3000 acessível
- [ ] 4 dashboards Grafana provisionados

### Métricas
- [ ] Prometheus scraping 6 targets (todos UP)
- [ ] API Service: métricas em /actuator/prometheus
- [ ] Router Worker: métricas em /actuator/prometheus
- [ ] Connectors: métricas em /actuator/prometheus
- [ ] Grafana mostrando dados em tempo real

### Performance
- [ ] Baseline test: 700-800 msg/min
- [ ] P95 latency: < 10ms
- [ ] P99 latency: < 20ms
- [ ] Error rate: 0.00%

### Escalabilidade
- [ ] 1 worker: throughput medido
- [ ] 2 workers: throughput similar (bottleneck API Service)
- [ ] Consumer lag: 0 msgs
- [ ] Distribuição: ~50/50 entre workers

### Tolerância a Falhas
- [ ] Failover test: 0.00% erros
- [ ] Recovery time: ~5 segundos
- [ ] Kafka rebalancing automático
- [ ] Zero message loss

### Documentação
- [ ] RELATORIO_TECNICO_ENTREGA3.md lido
- [ ] ADR 005 (Circuit Breaker) revisado
- [ ] ADR 006 (Observability) revisado
- [ ] SCALING_RESULTS.md consultado
- [ ] FAULT_TOLERANCE_RESULTS.md consultado

---

## 7. Comandos Úteis

### Monitoramento em Tempo Real

```bash
# CPU/RAM de todos os containers
watch -n 2 'docker stats --no-stream'

# Logs de todos os serviços
docker-compose logs -f

# Logs de um serviço específico
docker-compose logs -f api-service

# Número de mensagens no tópico Kafka
docker-compose exec kafka kafka-run-class.sh kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic messages \
  | awk -F ":" '{sum += $3} END {print sum}'

# Consumer lag
docker-compose exec kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe --group router-group
```

### Limpeza Completa

```bash
# Parar tudo e limpar volumes
docker-compose down -v

# Remover imagens antigas
docker image prune -a -f

# Limpar resultados de testes
rm -rf scripts/load-tests/results/*.json

# Rebuild completo
./build.sh
docker-compose up -d
```

### Screenshots para Relatório

```bash
# Capturar métricas Prometheus
curl -s 'http://localhost:9090/api/v1/query?query=http_requests_total' \
  | jq '.' > prometheus-query.json

# Exportar dashboard Grafana
curl -s http://admin:admin@localhost:3000/api/dashboards/uid/system-overview \
  | jq '.dashboard' > grafana-dashboard.json

# Salvar resultados k6
k6 run --out json=baseline-results.json 02-baseline.js
```

---

## 8. Próximos Passos

Após completar os testes:

1. **Revisão:** Ler `RELATORIO_TECNICO_ENTREGA3.md` completo
2. **Screenshots:** Capturar telas do Grafana para apresentação
3. **Apresentação:** Preparar demo usando `./demo-entrega3.sh`
4. **Perguntas:** Revisar conceitos em ADR 005 e ADR 006
5. **Cleanup:** `docker-compose down -v` ao finalizar

---

**Última atualização:** 30 de Novembro de 2024  
**Tempo estimado total:** 30-45 minutos  
**Dificuldade:** ⭐⭐⭐ Intermediário

**Dúvidas?** Consulte:
- `RELATORIO_TECNICO_ENTREGA3.md` - Documentação completa
- `docs/OBSERVABILITY.md` - Guia de observabilidade
- `scripts/load-tests/README.md` - Guia de testes k6
- Logs: `docker-compose logs <serviço>`

🎉 **Boa sorte nos testes!**
