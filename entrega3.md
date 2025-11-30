**Semana 7-8 – Observabilidade, Testes de Carga e Validação da Arquitetura**

**Objetivo:**

Implementar **observabilidade básica** (Seção 2.4 do esqueleto.md) com métricas essenciais, validar o **comportamento do sistema sob carga** através de testes progressivos (começando simples), e demonstrar os **mecanismos fundamentais de escalabilidade e tolerância a falhas** (Seção 7). Produzir **relatório técnico final** documentando a arquitetura implementada e os aprendizados sobre sistemas distribuídos.

**Abordagem Pedagógica**: Começar com carga baixa e métricas básicas, validar conceitos fundamentais, depois aumentar progressivamente a carga para observar comportamento de escalabilidade.

**Atividades:**

### **1. Implementar Stack de Observabilidade (Seção 2.4 - Admin & Monitoring)**

**Justificativa Arquitetural**: O esqueleto.md define na Seção 2.4 que a Observabilidade é um componente essencial da arquitetura, incluindo ferramentas como Prometheus (coleta de métricas), Grafana (visualização) e ELK Stack (logs).

#### 1.1. Configurar Prometheus + Grafana (Stack Mínimo)
- Adicionar serviços `prometheus` e `grafana` ao `docker-compose.yml`.
- Criar arquivo `monitoring/prometheus.yml` com configuração básica:
  - Targets: api-service:8080, router-worker:8082, connectors (8083/8084).
  - Intervalo: 30 segundos (adequado para testes didáticos).
- Configurar Grafana com datasource Prometheus pré-configurado.
- Expor Grafana na porta 3000 (user: admin, password: admin).
- **Foco**: Stack funcional e simples, não otimizado para produção.

#### 1.2. Instrumentar Microsserviços com Métricas
Implementar endpoints `/metrics` (formato Prometheus) em todos os serviços Java:

**api-service** (8080/metrics):
- `http_requests_total{method, path, status}` - Total de requisições HTTP.
- `http_request_duration_seconds{method, path}` - Latência de requisições (histogram).
- `messages_accepted_total` - Total de mensagens aceitas pela API.
- `messages_rejected_total{reason}` - Mensagens rejeitadas (validação, auth).
- `files_uploaded_total{size_bucket}` - Uploads por faixa de tamanho.
- `kafka_publish_duration_seconds` - Tempo para publicar no Kafka.

**router-worker** (8082/metrics):
- `messages_consumed_total{topic, partition}` - Mensagens consumidas do Kafka.
- `messages_processed_total{status}` - Mensagens processadas (SENT, DELIVERED, FAILED).
- `messages_failed_total{reason}` - Falhas no processamento (DB error, timeout).
- `kafka_consumer_lag{topic, partition}` - Lag de consumo do Kafka.
- `processing_duration_seconds` - Tempo de processamento por mensagem.
- `cassandra_write_duration_seconds` - Latência de escrita no Cassandra.

**connector-whatsapp** (8083/metrics):
- `messages_sent_total{channel="whatsapp", status}` - Mensagens enviadas (success/failed).
- `connector_api_duration_seconds{channel="whatsapp"}` - Latência da API mock externa.
- `circuit_breaker_state{channel="whatsapp"}` - Estado do circuit breaker (closed/open/half_open).

**connector-instagram** (8084/metrics):
- `messages_sent_total{channel="instagram", status}` - Mensagens enviadas (success/failed).
- `connector_api_duration_seconds{channel="instagram"}` - Latência da API mock externa.
- `circuit_breaker_state{channel="instagram"}` - Estado do circuit breaker.

#### 1.3. Criar Dashboards Grafana (Abordagem Progressiva)
Implementar 2 dashboards essenciais (exportar em JSON para `monitoring/grafana/dashboards/`):

**Dashboard 1: System Overview (Essencial)**
- Gráfico: Total messages/sec (rate sobre 1 minuto).
- Gráfico: Latência HTTP API (P95 - simplificado).
- Gauge: Error rate atual (% de falhas).
- Stat: Total de mensagens processadas (counter).
- **Meta**: Visão geral do sistema em uma tela.

**Dashboard 2: Component Health (Diagnóstico)**
- Gráfico: Messages published vs. consumed (identificar gargalos).
- Gráfico: Consumer lag (alertar se > 100 para testes simples).
- Status: Health check de serviços (API, Router, Connectors).
- Gráfico: Tempo de processamento médio (Router Worker).
- **Meta**: Identificar componente problemático rapidamente.

**Opcional (se houver tempo):**
- Dashboard 3: Infrastructure (CPU/Memory por container).
- Dashboard 4: Business Metrics (distribuição por status/canal).

#### 1.4. Implementar Logging Estruturado
- Adicionar correlation_id (request_id) em todas as requisições HTTP.
- Propagar correlation_id nos eventos Kafka (header).
- Formatar logs em JSON com campos: timestamp, level, service, correlation_id, message.
- Exemplo: `{"timestamp":"2025-11-26T10:30:45Z","level":"INFO","service":"router-worker","correlation_id":"abc123","message":"Message processed","message_id":"msg789","duration_ms":45}`

---

### **2. Testes de Carga Progressivos (Abordagem Didática)**

**Justificativa Arquitetural**: O esqueleto.md define na Seção 1.1 requisitos de throughput elevados. Esta seção valida os **conceitos fundamentais** primeiro, depois escala progressivamente.

**Filosofia**: Começar com carga baixa para entender o comportamento, depois aumentar para observar limites e gargalos.

#### 2.1. Setup de Ferramentas de Load Testing
- Instalar **k6** (https://k6.io) para testes de carga:
  ```bash
  # Ubuntu/Debian
  sudo apt install k6
  
  # macOS
  brew install k6
  
  # Ou via Docker
  docker pull grafana/k6
  ```
- Criar diretório `scripts/load-tests/` com scripts JavaScript para k6.
- Configurar Virtual Users (VUs) e duração de testes.

#### 2.2. Casos de Teste (Progressão Realista)

**Fase 1: Baseline - Entender o Sistema** (Essencial)

**Test Case 1: Warmup - Carga Mínima**
- **Objetivo**: Validar que o sistema funciona sem erros sob carga controlada.
- **Configuração**: 5 VUs, 2 minutos, ~50 req/min.
- **Endpoint**: `POST /v1/messages` (payload: 100 bytes de texto).
- **Métricas esperadas**:
  - Throughput: ~50 mensagens/minuto (baseline).
  - P95 latency < 100ms (sem contenção).
  - Error rate = 0% (sistema estável).
- **Script**: `load-tests/01-warmup.js`
- **Aprendizado**: Sistema funciona sem erros, latência base estabelecida.

**Test Case 2: Baseline Normal - Carga Sustentada**
- **Objetivo**: Medir throughput e latência em uso "normal".
- **Configuração**: 20 VUs, 5 minutos, ~500 req/min.
- **Endpoint**: `POST /v1/messages` (payload: 200 bytes de texto).
- **Métricas esperadas**:
  - Throughput: 500-600 mensagens/minuto (8-10 msg/s).
  - P95 latency < 200ms.
  - Error rate < 0.5%.
- **Script**: `load-tests/02-baseline.js`
- **Aprendizado**: Latência real do sistema, capacidade base sem estresse.

**Fase 2: Validação de Conceitos** (Essencial)

**Test Case 3: Spike Test - Absorção de Picos**
- **Objetivo**: Validar que Kafka absorve picos sem perda (Seção 7.1).
- **Configuração**: Ramp 5→50 VUs em 30s, manter 1 min, drop para 5.
- **Endpoint**: `POST /v1/messages`
- **Métricas esperadas**:
  - Sistema não retorna 5xx durante spike.
  - Consumer lag aumenta temporariamente mas se recupera.
  - P99 latency < 500ms durante pico.
- **Script**: `load-tests/03-spike.js`
- **Aprendizado**: Store-and-forward funciona, sistema é resiliente a picos.

**Test Case 4: Arquivos Pequenos**
- **Objetivo**: Validar upload de arquivos sob carga.
- **Configuração**: 10 VUs, 3 minutos, arquivos de 100KB-1MB.
- **Endpoint**: `POST /v1/files` (multipart upload).
- **Métricas esperadas**:
  - 50-100 uploads/minuto sustentáveis.
  - Latência de upload < 2 segundos (1MB).
  - Zero timeouts.
- **Script**: `load-tests/04-file-upload.js`
- **Aprendizado**: Streaming upload funciona, MinIO aguenta carga básica.

**Fase 3: Escalabilidade (Opcional, se houver tempo)**

**Test Case 5: Carga Crescente**
- **Objetivo**: Identificar o primeiro gargalo do sistema.
- **Configuração**: Ramp gradual de 10 VUs até 100 VUs (incrementos de 10 a cada minuto).
- **Endpoint**: `POST /v1/messages`
- **Métricas a observar**:
  - Throughput máximo sustentável antes de error rate > 1%.
  - Qual componente falha primeiro (API, Kafka, Cassandra, Worker)?
  - CPU/Memory de qual container chega a 80% primeiro?
- **Script**: `load-tests/05-stress.js`
- **Aprendizado**: Identificar gargalo arquitetural, entender limites.

**Test Case 6: Soak Test - Estabilidade**
- **Objetivo**: Validar ausência de memory leaks em longa duração.
- **Configuração**: 30 VUs, 15 minutos, ~300 req/min constante.
- **Endpoint**: `POST /v1/messages` + `GET /v1/messages` (mix 70/30).
- **Métricas esperadas**:
  - Latência não aumenta mais de 15% ao longo de 15 min.
  - Memory usage estável.
  - Zero crashes.
- **Script**: `load-tests/06-soak.js`
- **Aprendizado**: Sistema é estável ao longo do tempo.

#### 2.3. Coleta e Análise de Métricas (Simplificada)
- Configurar k6 para exportar métricas em JSON:
  ```bash
  k6 run --out json=results/baseline.json load-tests/02-baseline.js
  ```
- Criar script Python simples `scripts/analyze-k6-results.py` que:
  - Parse o JSON de resultados.
  - Calcula: throughput médio, P95 latency, error rate.
  - Gera relatório em texto simples (Markdown).
  - **Opcional**: Gráficos básicos com matplotlib (se necessário).
- Armazenar resultados em `scripts/load-tests/results/` com timestamp.

**Métricas Essenciais a Reportar**:
```markdown
## Test Case 2: Baseline Normal
- **Throughput**: 548 msg/min (9.13 msg/s)
- **P95 Latency**: 187ms
- **P99 Latency**: 243ms
- **Error Rate**: 0.12%
- **Duration**: 5 minutos
- **Total Requests**: 2,740
- **Failed Requests**: 3
```

---

### **3. Validação de Escalabilidade Horizontal (Seção 7 - Conceitos Fundamentais)**

**Justificativa Arquitetural**: A Seção 7 do esqueleto.md define mecanismos de escalabilidade que devem ser **demonstrados conceitualmente**, não necessariamente com carga massiva.

**Objetivo Pedagógico**: Demonstrar que adicionar recursos aumenta capacidade (conceito de escalabilidade horizontal), não atingir números de produção.

#### 3.1. Teste de Escalabilidade do Router Worker (Seção 7.2 e 7.3)

**Objetivo**: Validar que o particionamento do Kafka permite escalabilidade ao aumentar workers.

**Procedimento Simplificado**:

1. **Baseline (1 Worker)**:
   - Configurar `docker-compose.yml` com 1 router-worker.
   - Executar teste de carga moderado (20 VUs, 3 minutos).
   - Medir throughput (T1) e observar CPU/Memory.
   - **Exemplo esperado**: T1 = ~400 msg/min, CPU ~50%.
   
2. **Scale-out (2 Workers)**:
   - Executar: `docker-compose up --scale router-worker=2 -d`
   - Aguardar rebalancing do Kafka (logs devem mostrar partition assignment).
   - Executar mesmo teste de carga.
   - Medir throughput (T2).
   - **Meta Didática**: T2 >= 1.6 * T1 (eficiência ~80%, aceitável para POC).
   - **Observar**: Cada worker processa ~50% das mensagens (carga distribuída).

3. **Análise Qualitativa** (não apenas números):
   - Consultar métricas Prometheus: `messages_processed_total` por instância.
   - Verificar distribuição de carga entre workers.
   - **Pergunta reflexiva**: Por que não é exatamente 2x? (overhead de coordenação, rebalancing).
   
**Entregável**: 
- Gráfico simples comparando T1 vs T2.
- Screenshot dos logs mostrando rebalancing.
- Análise qualitativa: "Adicionar 1 worker aumentou throughput em 65%, demonstrando escalabilidade horizontal do Kafka."

#### 3.2. Teste de Escalabilidade da API (Seção 7.1 e 7.4)

**Objetivo**: Validar que API stateless pode ser replicada para aumentar capacidade.

**Procedimento Simplificado**:

1. **Baseline (1 API Instance)**:
   - Executar teste de carga (20 VUs, 2 minutos).
   - Medir throughput (A1) e latência (LA1).
   
2. **Scale-out (2 API Instances)**:
   - `docker-compose up --scale api-service=2 -d`
   - **Nota**: Requer load balancer (Nginx ou Docker Swarm mode).
   - Executar mesmo teste de carga.
   - Medir throughput (A2).
   - **Meta Didática**: A2 >= 1.7 * A1 (API é mais leve que worker).
   
3. **Validar Stateless**:
   - Enviar requisições e verificar nos logs que são distribuídas entre instâncias.
   - Confirmar que não há session affinity (cada requisição pode ir para API diferente).

**Entregável**: 
- Comparação A1 vs A2.
- Logs mostrando distribuição de requisições.
- **Conceito validado**: APIs stateless são facilmente escaláveis.

#### 3.3. Teste de Isolamento de Connectors (Seção 7.3)

**Objetivo**: Validar que connectors são independentes (falha em um não afeta outro).

**Procedimento Simplificado**:

1. Enviar 5 mensagens para WhatsApp, 5 para Instagram.
2. Derrubar connector do Instagram: `docker stop chat4alltijolim-connector-instagram-1`
3. Enviar mais 5 mensagens para cada canal.
4. **Observar**:
   - WhatsApp continua processando normalmente.
   - Mensagens do Instagram ficam pendentes (store-and-forward).
5. Reiniciar Instagram connector: mensagens pendentes são processadas.

**Entregável**: 
- Logs demonstrando isolamento.
- Screenshot de mensagens pendentes no Cassandra.
- **Conceito validado**: Isolamento de falhas (Seção 7.8).

---

### **4. Validação de Tolerância a Falhas (Seção 7.6, 7.7, 7.8) - Conceitos Essenciais**

**Justificativa Arquitetural**: A Seção 7 define mecanismos de resiliência que devem ser **demonstrados conceitualmente**.

**Objetivo Pedagógico**: Provar que os conceitos de sistemas distribuídos funcionam, não criar sistema de produção.

#### 4.1. Teste de Failover do Router Worker (Seção 7.6 - Failover Automático)

**Objetivo**: Validar que o sistema se recupera automaticamente da falha de um worker sem perda de mensagens.

**Procedimento Simplificado**:

1. Configurar 2 instâncias de router-worker.
2. Iniciar teste de carga leve contínuo (10 VUs, 5 minutos, ~100 msg/min).
3. Após 1 minuto de teste estável:
   ```bash
   docker stop chat4alltijolim-router-worker-1
   ```
4. **Observar**:
   - Logs do Kafka: `Revoking previously assigned partitions` e `Adding newly assigned partitions`.
   - Consumer lag aumenta temporariamente (spike).
   - Segundo worker assume as partitions do worker caído.
   - Sistema continua funcionando (zero 5xx na API).
5. Após 1 minuto, reiniciar worker:
   ```bash
   docker start chat4alltijolim-router-worker-1
   ```
6. **Validar**: Rebalancing acontece, sistema volta ao normal.

**Métricas Chave**:
- Tempo de recuperação: < 30 segundos (aceitável para POC).
- Zero message loss (validar via contagem de message_id no Cassandra).
- Spike temporário no consumer lag (gráfico no Grafana).

**Entregável**: 
- Log do rebalancing (texto).
- Screenshot do Grafana mostrando spike e recuperação no consumer lag.
- Confirmação: contagem de mensagens antes/depois = sem perda.

#### 4.2. Teste de Health Checks (Seção 7.7 - Detecção de Falhas)

**Objetivo**: Validar que health checks detectam falhas.

**Implementação Básica**:
- Adicionar health check em `docker-compose.yml`:
  ```yaml
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
    interval: 30s
    timeout: 5s
    retries: 2
  ```
- Endpoint `/health` retorna 200 se serviço está operacional.

**Teste**:
1. Verificar status: `docker-compose ps` (todos devem estar `healthy`).
2. Simular falha: parar Kafka container.
3. Aguardar health check falhar (~60s: 30s interval * 2 retries).
4. Verificar: `docker ps` mostra status `(unhealthy)` para API.
5. Reiniciar Kafka: health volta para `healthy`.

**Entregável**: 
- Screenshot do `docker ps` mostrando `(unhealthy)`.
- Logs do Docker mostrando health check failures.
- **Conceito validado**: Detecção automática de falhas.

#### 4.3. Teste de Circuit Breaker (Seção 7.8 - Isolamento de Falhas Externas)

**Objetivo**: Validar que falhas em APIs externas não sobrecarregam o sistema.

**Implementação Simplificada**:
- Adicionar lógica básica de circuit breaker em `WhatsAppConnector.java`:
  ```java
  private int consecutiveFailures = 0;
  private boolean circuitOpen = false;
  
  if (circuitOpen) {
      log.warn("Circuit breaker OPEN, skipping send");
      return; // Não tenta enviar
  }
  
  try {
      sendToWhatsApp(message);
      consecutiveFailures = 0; // Reset on success
  } catch (Exception e) {
      consecutiveFailures++;
      if (consecutiveFailures >= 3) {
          circuitOpen = true;
          log.error("Circuit breaker OPENED after 3 failures");
      }
  }
  ```

**Teste**:
1. Configurar connector para simular falhas (retornar erro).
2. Enviar 5 mensagens via API para WhatsApp.
3. **Observar**:
   - Primeiras 3 mensagens: tentam envio e falham.
   - Após 3 falhas: circuit breaker abre.
   - Mensagens 4-5: rejeitadas imediatamente (não tentam API).
   - Mensagens ficam em estado `PENDING` no Cassandra.
4. Corrigir connector (remover falha simulada).
5. Circuit breaker eventualmente fecha (retry logic).

**Entregável**: 
- Logs mostrando circuit breaker abrindo.
- Query no Cassandra mostrando mensagens `PENDING`.
- **Conceito validado**: Isolamento de falhas externas.

#### 4.4. Teste de Store-and-Forward (Seção 7.9)

**Objetivo**: Validar que mensagens para destinatários offline não são perdidas.

**Procedimento**:
1. Derrubar connector do Instagram: `docker stop connector-instagram`.
2. Enviar mensagem para `instagram:@usuario_offline` via API.
3. **Validar**:
   - API retorna `202 Accepted` (mensagem aceita).
   - Router Worker tenta processar, detecta connector offline.
   - Mensagem salva em Cassandra com status `PENDING`.
4. Reiniciar connector: `docker start connector-instagram`.
5. Router Worker retenta entrega (polling ou trigger manual).
6. Mensagem muda para `DELIVERED`.

**Query Cassandra**:
```sql
SELECT message_id, recipient_id, status, timestamp 
FROM messages 
WHERE status = 'PENDING' 
ALLOW FILTERING;
```

**Entregável**: 
- Log do fluxo completo.
- Query mostrando evolução: `PENDING` → `DELIVERED`.
- **Conceito validado**: Store-and-forward garante entrega eventual.

---

### **5. Health Checks e Heartbeats (Seção 7.7)**

**Justificativa Arquitetural**: A Seção 7.7 define heartbeats e health checks como essenciais para detecção rápida de falhas.

#### 5.1. Implementar Endpoints de Health Check

**api-service** (`GET /health`):
```json
{
  "status": "UP",
  "components": {
    "kafka": {"status": "UP", "latency_ms": 5},
    "cassandra": {"status": "UP", "latency_ms": 12}
  },
  "timestamp": "2025-11-26T10:30:45Z"
}
```

**router-worker** (`GET /health` na porta 8082):
```json
{
  "status": "UP",
  "consumer_lag": 234,
  "messages_processed_last_minute": 1543,
  "timestamp": "2025-11-26T10:30:45Z"
}
```

**connectors** (`GET /health`):
```json
{
  "status": "UP",
  "channel": "whatsapp",
  "circuit_breaker": "CLOSED",
  "last_successful_send": "2025-11-26T10:29:12Z"
}
```

#### 5.2. Integrar Health Checks no Docker Compose

Adicionar `healthcheck:` section em todos os serviços do `docker-compose.yml`:
```yaml
api-service:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
    interval: 30s
    timeout: 10s
    retries: 3
```

#### 5.3. Implementar Logs de Heartbeat

Em cada worker, adicionar log periódico (a cada 30 segundos):
```
[HEARTBEAT] service=router-worker instance_id=worker-1 status=healthy messages_processed=1543 consumer_lag=234 uptime_seconds=3456
```

Criar script `scripts/monitor-heartbeats.sh` que:
- Faz tail dos logs de todos os workers.
- Detecta se algum worker não enviou heartbeat nos últimos 60s (indica falha silenciosa).
- Alerta em caso de anomalia.

---

### **6. Relatório Técnico Final (Simplificado e Focado)**

**Objetivo**: Documentar a arquitetura implementada, decisões tomadas e aprendizados sobre sistemas distribuídos.

**Estrutura do Relatório** (10-15 páginas):

#### 1. Introdução (1 página)
- Contextualização do Chat4All.
- Requisitos críticos da Seção 1.1 do esqueleto.md (adaptados para escopo didático).
- Objetivos das 3 entregas.

#### 2. Arquitetura Implementada (2-3 páginas)
- Revisão da Seção 2 do esqueleto.md (Componentes).
- Diagrama de componentes atualizado (incluindo Prometheus/Grafana).
- Diagrama de sequência simplificado (fluxo de 1 mensagem).
- Mapeamento: componente → código-fonte (qual classe/arquivo).
- Referências aos ADRs (001-004).

#### 3. Decisões Técnicas (1-2 páginas)
- Revisão da Seção 5 do esqueleto.md:
  - **Por que Kafka?** Event-driven, alta throughput, replay capability.
  - **Por que Cassandra?** Write-heavy workload, horizontal scaling.
  - **Por que MinIO?** S3-compatible, streaming upload, presigned URLs.
  - **Connectors independentes:** Plugin architecture, isolamento de falhas.
  - **At-least-once + deduplicação:** Garantia de entrega com idempotência.

#### 4. Padrões Arquiteturais (1 página)
- Event-Driven Architecture (6.1): Kafka como backbone.
- Microsserviços (6.2): Isolamento e independência.
- Pub/Sub (6.3): Desacoplamento produtor/consumidor.
- Plugin Architecture (6.4): Extensibilidade de canais.

#### 5. Testes de Carga e Resultados (2-3 páginas)
- Metodologia: k6, cenários progressivos.
- Resultados dos test cases essenciais (tabelas simples):
  - **Warmup**: 50 msg/min, latência base.
  - **Baseline**: 500 msg/min, P95 < 200ms.
  - **Spike**: Sistema absorveu pico sem falhas.
  - **Files**: Upload de 1MB < 2s.
- Screenshots dos dashboards Grafana (1-2 capturas).
- Identificação de gargalos observados.
- **Comparação realista**: Meta didática vs. resultados alcançados.

#### 6. Escalabilidade Horizontal (1-2 páginas)
- Resultados dos testes de scaling:
  - **1 Worker → 2 Workers**: Throughput aumentou X%.
  - **1 API → 2 APIs**: Throughput aumentou Y%.
- Gráfico simples: throughput vs. número de instâncias.
- Análise qualitativa: "Por que não é exatamente 2x?"
- Logs demonstrando distribuição de carga.

#### 7. Tolerância a Falhas (1-2 páginas)
- Resultados dos testes de failover:
  - **Worker crash**: Kafka rebalancing, recuperação em <30s.
  - **Health checks**: Detecção automática de falhas.
  - **Circuit breaker**: Logs mostrando abertura após 3 falhas.
  - **Store-and-forward**: Mensagens pendentes entregues após reconexão.
- Screenshots de logs e queries Cassandra.

#### 8. Observabilidade (1 página)
- Stack implementada: Prometheus + Grafana.
- Métricas essenciais expostas (lista):
  - `http_requests_total`, `http_request_duration_seconds`.
  - `messages_consumed_total`, `kafka_consumer_lag`.
  - `messages_sent_total{channel}`.
- Screenshots dos dashboards (System Overview, Component Health).
- Logging estruturado: formato, correlation_id.

#### 9. Limitações e Aprendizados (1 página)
- **Limitações conhecidas**:
  - Cassandra single-node (sem HA real).
  - Connectors são mocks (não APIs reais).
  - Testes em ambiente local (não cloud).
  - Carga moderada (didática, não produção).
- **Aprendizados sobre sistemas distribuídos**:
  - Kafka garante ordem por partition.
  - Escalabilidade horizontal tem overhead (não é linear).
  - Observabilidade é essencial para diagnóstico.
  - Circuit breakers protegem de cascading failures.
  - Store-and-forward garante durabilidade.

#### 10. Conclusão (0.5 página)
- Síntese dos resultados.
- Validação dos requisitos didáticos (checklist adaptado).
- Conceitos de sistemas distribuídos demonstrados com sucesso.

#### Apêndices (opcional, não conta nas 15 páginas)
- **Apêndice A**: Comandos para reproduzir testes.
- **Apêndice B**: Configurações (`docker-compose.yml`, `prometheus.yml`).
- **Apêndice C**: Logs selecionados (exemplos).
- **Apêndice D**: Scripts de teste (snippets relevantes).

**Formato**: PDF, fonte 11pt, espaçamento 1.5, margens normais.

---

### **7. Demonstração Prática (Simplificada)**

**Objetivo**: Demonstração ao vivo do sistema completo com observabilidade básica em tempo real.

#### 7.1. Script de Demonstração Automatizado

Criar `scripts/demo-entrega3.sh` que executa sequência de 8 minutos:

```bash
#!/bin/bash
set -e

echo "=== DEMO ENTREGA 3: Chat4All - Observabilidade e Escalabilidade ==="

# 1. Iniciar stack completa
echo "[1/6] Iniciando stack completa..."
docker-compose up -d
sleep 45  # Aguardar inicialização

# 2. Verificar saúde de todos os serviços
echo "[2/6] Verificando health checks..."
./scripts/test-infrastructure.sh

# 3. Abrir Grafana
echo "[3/6] Abrindo Grafana (http://localhost:3000)..."
echo "Usuário: admin | Senha: admin"
xdg-open http://localhost:3000 2>/dev/null || open http://localhost:3000 || echo "Abra manualmente: http://localhost:3000"

# 4. Executar teste de carga baseline em background
echo "[4/6] Executando teste de carga (3 minutos, 20 VUs)..."
echo ">>> Observe o Dashboard 'System Overview' no Grafana <<<"
k6 run scripts/load-tests/02-baseline.js > /tmp/k6-baseline.log 2>&1 &
K6_PID=$!
sleep 120  # Aguardar 2 minutos de teste

# 5. Demonstrar failover
echo "[5/6] Demonstrando failover: Derrubando 1 router-worker..."
docker stop chat4alltijolim-router-worker-1
echo ">>> Observe no Grafana: consumer lag aumenta temporariamente <<<"
sleep 45

echo "Reiniciando worker..."
docker start chat4alltijolim-router-worker-1
echo ">>> Observe no Grafana: consumer lag volta ao normal <<<"
sleep 30

# 6. Aguardar teste finalizar
echo "[6/6] Aguardando teste de carga finalizar..."
wait $K6_PID || true

echo ""
echo "=== DEMO CONCLUÍDA ==="
echo "Resultados:"
echo "  - Grafana: http://localhost:3000"
echo "  - Logs k6: /tmp/k6-baseline.log"
echo "  - Containers: docker-compose ps"
echo ""
echo "Para análise detalhada, consulte os dashboards no Grafana."
```

**Duração**: 8 minutos
**Conceitos demonstrados**: Observabilidade, carga, failover, recuperação.

#### 7.2. Checklist de Demonstração Manual

Para apresentação em aula/defesa:

**Preparação (antes da apresentação)**:
1. ✅ Stack rodando: `docker-compose up -d`
2. ✅ Grafana acessível: http://localhost:3000
3. ✅ Dados no Cassandra: verificar com queries básicas
4. ✅ Arquivos no MinIO: verificar console http://localhost:9001

**Durante a apresentação (15 minutos)**:

**Parte 1: Arquitetura (3 min)**
1. Mostrar diagrama de componentes.
2. Explicar fluxo de 1 mensagem (API → Kafka → Worker → Connector).
3. Destacar: event-driven, stateless, microservices.

**Parte 2: Sistema Funcionando (4 min)**
4. Abrir Grafana Dashboard "System Overview".
5. Executar script simples:
   ```bash
   ./cli/chat4all-cli.py
   # Autenticar + enviar 5 mensagens
   ```
6. Mostrar no Grafana: métricas em tempo real (messages/sec, latency).
7. Mostrar logs: `docker-compose logs -f router-worker | grep "Message processed"`

**Parte 3: Escalabilidade (4 min)**
8. Mostrar métricas baseline (1 worker).
9. Escalar: `docker-compose up --scale router-worker=2 -d`
10. Aguardar rebalancing (~20s).
11. Mostrar no Grafana: distribuição de carga entre 2 workers.
12. Explicar conceito: horizontal scaling.

**Parte 4: Tolerância a Falhas (4 min)**
13. Derrubar 1 worker: `docker stop chat4alltijolim-router-worker-1`
14. Mostrar no Grafana: spike no consumer lag.
15. Explicar: Kafka rebalancing, failover automático.
16. Reiniciar worker: `docker start chat4alltijolim-router-worker-1`
17. Mostrar recuperação no Grafana.

**Conclusão (1 min)**
18. Resumir conceitos demonstrados:
    - Event-driven architecture funciona.
    - Escalabilidade horizontal comprovada.
    - Failover automático garante resiliência.
    - Observabilidade permite diagnóstico em tempo real.

---

**Entregas esperadas (Escopo Realista):**

- **Código-fonte** (4-6h de implementação):
  - Stack de observabilidade básica (Prometheus + Grafana) configurada.
  - Endpoints `/metrics` implementados em serviços principais (API, Router).
  - 2 dashboards Grafana essenciais (JSON exportado).
  - Health checks básicos implementados.
  - Circuit breaker simples implementado em 1 connector (demonstração).
  
- **Scripts de teste** (2-3h):
  - 4-6 scripts de load testing (k6) progressivos.
  - Script Python simples de análise (`analyze-k6-results.py`).
  - Script de demonstração (`demo-entrega3.sh`).
  
- **Resultados de testes** (automático, gerado pelos scripts):
  - Logs de execução dos test cases essenciais.
  - Arquivos JSON com métricas (k6 output).
  - Tabelas Markdown com summary (throughput, latency, error rate).
  - Screenshots dos dashboards Grafana (4-6 capturas essenciais).
  - 1-2 gráficos comparativos (scaling, failover).

- **Documentação** (3-4h):
  - **Relatório Técnico Final** (10-15 páginas, formato PDF).
  - **ADR 005**: Circuit Breakers (1 página).
  - **ADR 006**: Estratégia de Observabilidade (1 página).
  - **README atualizado** com seção de Observabilidade e Testes de Carga.

- **Evidências de Validação** (Metas Didáticas):
  - Comprovação de throughput sustentado de 500-1000 msg/min (log do k6).
  - Comprovação de P95 latency < 200ms em carga normal (gráfico).
  - Comprovação de scaling: 2 workers → +60-80% throughput (logs).
  - Comprovação de recovery time < 30s após failover (log de rebalancing).
  - Comprovação de zero message loss durante failover (query Cassandra).

---

**Critérios de Aceitação (Adaptados para Contexto Didático):**

### Performance (Seção 1.1 - Metas Realistas)
- ✅ Throughput sustentado ≥ 500 mensagens/minuto (8-10 msg/s) em carga normal.
- ✅ P95 latency < 200ms para `POST /v1/messages` sem contenção.
- ✅ P99 latency < 500ms durante picos moderados.
- ✅ Error rate < 1% durante testes de carga (tolerância para ambiente local).
- ✅ Arquivos de até 100MB são transferidos com sucesso (demonstração).

### Escalabilidade (Seção 7.1-7.4 - Validação Conceitual)
- ✅ 2x workers → throughput aumenta 60-80% (eficiência aceitável para POC).
- ✅ API stateless: múltiplas instâncias demonstram load balancing.
- ✅ Kafka consumer lag < 100 mensagens durante operação normal (escala local).
- ✅ CPU usage < 80% por container durante carga sustentada.
- ✅ Logs demonstram distribuição de carga entre instâncias.

### Tolerância a Falhas (Seção 7.6-7.9 - Demonstração de Conceitos)
- ✅ Recovery time < 30s após falha de worker (rebalancing Kafka).
- ✅ Zero message loss durante failover (validar via contagem message_id).
- ✅ Circuit breaker abre após 3-5 falhas consecutivas (demonstração).
- ✅ Store-and-forward: mensagens PENDING são entregues quando connector volta.
- ✅ Health checks detectam falhas em < 60s (intervalo de 30s × 2 retries).

### Observabilidade (Seção 2.4 - Stack Funcional)
- ✅ Prometheus coletando métricas de serviços principais (API, Router).
- ✅ 2 dashboards Grafana essenciais funcionais e atualizando em tempo real.
- ✅ Logs estruturados com timestamps e service name.
- ✅ Métricas básicas disponíveis: throughput, latency P95, error rate.
- ✅ Screenshots demonstram dashboards em ação durante testes.

---

**Referências da Arquitetura:**

Este plano de entrega implementa e valida **conceitos fundamentais**:
- **esqueleto.md - Seção 1.1**: Requisitos Críticos (adaptados para escopo didático)
- **esqueleto.md - Seção 2.4**: Observabilidade básica (Prometheus + Grafana)
- **esqueleto.md - Seção 5**: Decisões Técnicas (Kafka, Cassandra, MinIO, Connectors)
- **esqueleto.md - Seção 6**: Padrões Arquiteturais (EDA, Microservices, Pub/Sub)
- **esqueleto.md - Seção 7**: Mecanismos de Escalabilidade e Tolerância (demonstração conceitual)

**Foco Pedagógico**: Demonstrar que os conceitos de sistemas distribuídos funcionam, não atingir métricas de produção.

