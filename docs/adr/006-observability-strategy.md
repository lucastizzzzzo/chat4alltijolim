# ADR 006: Observability Strategy with Prometheus and Grafana

**Status:** Accepted  
**Date:** 2024-11-27  
**Deciders:** Architecture Team  
**Context:** Entrega 3 - Observability and Performance Validation

---

## Context and Problem Statement

A distributed messaging system with multiple microservices (API Service, Router Workers, Connectors) processing asynchronous events requires comprehensive observability to:

- **Monitor performance:** Track throughput, latency, error rates in real-time
- **Debug issues:** Identify bottlenecks and failures across services
- **Validate scalability:** Measure impact of adding instances
- **Ensure reliability:** Detect degradation before user impact
- **Support operations:** Enable data-driven capacity planning

**Question:** How do we implement effective observability across all services with minimal overhead and maximum educational value?

---

## Decision Drivers

1. **Educational Value:** Demonstrate industry-standard observability practices
2. **Low Overhead:** < 5% performance impact on message processing
3. **Real-Time Visibility:** Metrics available within 15-30 seconds
4. **Multi-Service Support:** Monitor all components from single interface
5. **Production-Ready:** Use tools employed in real-world systems
6. **Minimal Dependencies:** Avoid heavy APM solutions (Datadog, New Relic)
7. **Open Source:** Free and self-hosted
8. **Integration Ease:** Native support for Java/Kafka ecosystem

---

## Considered Options

### Option 1: Prometheus + Grafana (Chosen)

**Pros:**
- ✅ Industry standard for metrics collection
- ✅ Pull-based model (services expose `/metrics`, Prometheus scrapes)
- ✅ Excellent Grafana integration (official data source)
- ✅ PromQL for powerful querying
- ✅ Lightweight (< 1% CPU overhead per service)
- ✅ Native Java support via Micrometer
- ✅ Self-contained (no external SaaS dependencies)

**Cons:**
- ⚠️ No distributed tracing (would need Jaeger/Zipkin)
- ⚠️ Dashboard configuration requires JSON
- ⚠️ PromQL learning curve

### Option 2: ELK Stack (Elasticsearch, Logstash, Kibana)

**Pros:**
- Rich log aggregation and search
- Powerful full-text queries
- Historical analysis

**Cons:**
- ❌ Heavy resource usage (2GB+ RAM for Elasticsearch)
- ❌ Complex setup and maintenance
- ❌ Overkill for metrics (better for logs)
- ❌ Higher latency (batch processing)
- ❌ Not ideal for real-time dashboards

### Option 3: Application Performance Monitoring (APM) SaaS

**Options:** Datadog, New Relic, Dynatrace

**Pros:**
- Rich feature set (tracing, profiling, alerting)
- Zero infrastructure management
- Professional dashboards

**Cons:**
- ❌ **Requires external account/API keys**
- ❌ Cost (free tiers limited)
- ❌ Data leaves local environment
- ❌ Not educational (black box)
- ❌ Overkill for project scope

### Option 4: Custom Metrics Logging

**Pros:**
- No dependencies
- Full control

**Cons:**
- ❌ Reinventing the wheel
- ❌ No visualization
- ❌ Manual aggregation required
- ❌ Not scalable
- ❌ No educational value (non-standard)

---

## Decision Outcome

**Chosen option:** **Prometheus + Grafana**

### Architecture Overview

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ API Service  │     │Router Worker │     │  Connectors  │
│   :8080      │     │   :8082      │     │ :8083, :8084 │
└───────┬──────┘     └───────┬──────┘     └───────┬──────┘
        │                    │                    │
        │  GET /actuator/prometheus              │
        │  (Micrometer exposition)               │
        │                    │                    │
        └────────────────────┴────────────────────┘
                             │
                    ┌────────▼─────────┐
                    │   Prometheus     │  Scrape every 15s
                    │     :9090        │  Store time-series
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │     Grafana      │  Visualize metrics
                    │     :3000        │  Dashboards + alerts
                    └──────────────────┘
```

### Metrics Collection Flow

1. **Service Instrumentation (Micrometer)**
   - Java applications expose metrics at `/actuator/prometheus`
   - Micrometer formats metrics in Prometheus exposition format
   - Zero code changes needed (annotation-based)

2. **Scraping (Prometheus)**
   - Polls each service every 15 seconds (configurable)
   - Stores time-series data in local TSDB
   - Retention: 15 days (configurable)

3. **Visualization (Grafana)**
   - Queries Prometheus via PromQL
   - Auto-provisioned dashboards (JSON in `monitoring/grafana/dashboards/`)
   - Refresh interval: 5 seconds

---

## Implementation Details

### 1. Micrometer Integration (Java Services)

**Dependency (`pom.xml`):**
```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
    <version>1.11.0</version>
</dependency>
```

**Metrics Registry (`MetricsRegistry.java`):**
```java
public class MetricsRegistry {
    private static final PrometheusMeterRegistry registry = 
        new PrometheusMeterRegistry(PrometheusConfig.DEFAULT);
    
    // HTTP Server metrics
    public static final Counter messagesAccepted = Counter.builder("messages_accepted_total")
        .description("Total messages accepted by API")
        .register(registry);
    
    // Kafka publish duration
    public static final Timer kafkaPublishDuration = Timer.builder("kafka_publish_duration_seconds")
        .description("Time to publish message to Kafka")
        .register(registry);
}
```

**Exposition Endpoint:**
```java
server.createContext("/actuator/prometheus", exchange -> {
    String metrics = MetricsRegistry.getInstance().scrape();
    exchange.sendResponseHeaders(200, metrics.length());
    exchange.getResponseBody().write(metrics.getBytes());
    exchange.close();
});
```

### 2. Prometheus Configuration

**`monitoring/prometheus.yml`:**
```yaml
global:
  scrape_interval: 15s  # Scrape every 15 seconds
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'api-service'
    static_configs:
      - targets: ['api-service:8080']
    metrics_path: '/actuator/prometheus'

  - job_name: 'router-worker'
    static_configs:
      - targets: ['router-worker:8082']
    metrics_path: '/actuator/prometheus'

  - job_name: 'connector-whatsapp'
    static_configs:
      - targets: ['connector-whatsapp:8083']
    metrics_path: '/actuator/prometheus'

  - job_name: 'connector-instagram'
    static_configs:
      - targets: ['connector-instagram:8084']
    metrics_path: '/actuator/prometheus'
```

### 3. Grafana Dashboards

**Auto-Provisioned Dashboards:**
- `overview.json` - System-wide health (all services)
- `api-service.json` - HTTP requests, latency, throughput
- `router-worker.json` - Kafka consumer lag, processing time
- `connectors.json` - Channel-specific delivery metrics

**Example Panel (API Service Throughput):**
```json
{
  "title": "Messages per Minute",
  "targets": [{
    "expr": "rate(messages_accepted_total[1m]) * 60",
    "legendFormat": "{{instance}}"
  }],
  "yAxis": {
    "format": "msg/min"
  }
}
```

---

## Key Metrics Tracked

### API Service (`api-service:8080/actuator/prometheus`)

```prometheus
# HTTP Requests
http_requests_total{method="POST",endpoint="/messages",status="202"} 15234
http_request_duration_seconds{method="POST",endpoint="/messages",quantile="0.95"} 0.0024

# Message Processing
messages_accepted_total 15234
messages_rejected_total{reason="validation_error"} 47

# File Uploads
files_uploaded_total 342
file_upload_size_bytes{quantile="0.95"} 524288

# Kafka Publishing
kafka_publish_duration_seconds{topic="messages",quantile="0.99"} 0.0032

# JVM Metrics (automatic)
jvm_memory_used_bytes{area="heap"} 134217728
jvm_gc_pause_seconds_count{gc="G1 Young Generation"} 23
```

### Router Worker (`router-worker:8082/actuator/prometheus`)

```prometheus
# Kafka Consumer
messages_processed_total{topic="messages"} 15187
kafka_consumer_lag{topic="messages",partition="0"} 0

# Message Routing
messages_routed_total{channel="whatsapp"} 8942
messages_routed_total{channel="instagram"} 6245

# Processing Time
message_processing_duration_seconds{quantile="0.95"} 0.0015

# Status Updates
status_updates_published_total{status="SENT"} 15187
```

### Connectors (`connector-*:808*/actuator/prometheus`)

```prometheus
# Message Delivery
messages_sent_total{channel="whatsapp",status="success"} 8893
messages_sent_total{channel="whatsapp",status="failed"} 49

# API Call Duration (simulated)
connector_api_duration_seconds{channel="whatsapp",quantile="0.99"} 0.485

# Circuit Breaker (future)
circuit_breaker_state{name="whatsapp-api"} 0  # 0=closed, 1=open, 2=half-open
```

---

## Query Examples (PromQL)

### 1. Messages Per Second (All Services)
```promql
sum(rate(messages_accepted_total[1m]))
```

### 2. P95 Latency by Endpoint
```promql
histogram_quantile(0.95, 
  rate(http_request_duration_seconds_bucket[5m])
)
```

### 3. Error Rate Percentage
```promql
(
  sum(rate(messages_rejected_total[5m])) 
  / 
  sum(rate(http_requests_total[5m]))
) * 100
```

### 4. Kafka Consumer Lag (Max)
```promql
max(kafka_consumer_lag) by (topic, partition)
```

### 5. Memory Usage Trend
```promql
jvm_memory_used_bytes{area="heap"} / 1024 / 1024
```

---

## Load Testing Integration

### k6 Metrics Collection

Load tests (`scripts/load-tests/*.js`) complement observability:

1. **Client-Side Metrics (k6):**
   - Request latency from client perspective
   - HTTP status codes
   - Iteration duration

2. **Server-Side Metrics (Prometheus):**
   - Internal processing time
   - Kafka lag
   - JVM health

**Correlation:**
```bash
# Run load test
k6 run --duration 5m scripts/load-tests/02-baseline.js

# Query Prometheus during test
curl 'http://localhost:9090/api/v1/query?query=rate(messages_accepted_total[1m])'

# View in Grafana dashboard at http://localhost:3000
```

---

## Consequences

### Positive

✅ **Real-Time Visibility:** See throughput, latency, errors within 15 seconds  
✅ **Multi-Service View:** All components in single Grafana dashboard  
✅ **Low Overhead:** < 1% CPU, ~100MB RAM for Prometheus  
✅ **Production Skills:** Same tools used in industry  
✅ **Extensible:** Easy to add new metrics (Counter, Timer, Gauge)  
✅ **Historical Analysis:** Query trends over 15 days  
✅ **Load Test Validation:** Compare k6 results with server-side metrics  

### Negative

⚠️ **Setup Complexity:** Requires Prometheus + Grafana containers  
⚠️ **Dashboard Maintenance:** JSON configuration for custom panels  
⚠️ **No Distributed Tracing:** Can't follow single request across services (would need Zipkin)  
⚠️ **PromQL Learning:** Query language has learning curve  

### Neutral

📊 **Dashboards Manual:** JSON provisioning (not drag-and-drop)  
🔧 **Retention Management:** Disk space grows with metrics (15 days = ~500MB)  

---

## Future Enhancements

### Phase 1: Alerts (Prometheus Alertmanager)
```yaml
groups:
  - name: chat4all_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(messages_rejected_total[5m]) / rate(http_requests_total[5m]) > 0.05
        for: 2m
        annotations:
          summary: "Error rate above 5% for 2 minutes"
```

### Phase 2: Distributed Tracing (Jaeger)
- Trace message flow: API → Kafka → Router → Connector
- Identify latency hotspots per request

### Phase 3: Log Aggregation (Loki)
- Complement metrics with structured logs
- Grafana Loki integrates seamlessly

---

## Validation Results (Entrega 3)

### Load Test Baseline (20 VUs, 5 min)
```
Throughput: 753 msg/min (12.55 msg/s) ✅
P95 Latency: 2.39ms ✅
P99 Latency: 4.85ms ✅
Error Rate: 0.00% ✅
```

**Prometheus Confirmation:**
```promql
# Server-side throughput matched k6 client-side
rate(messages_accepted_total[1m]) * 60 = 753 msg/min ✅

# No rejected messages
sum(messages_rejected_total) = 0 ✅
```

### Scalability Test (1 vs 2 Workers)
```
1 Worker: 746 msg/min
2 Workers: 744 msg/min (no improvement)

# Prometheus revealed bottleneck
rate(http_requests_total{job="api-service"}[1m]) ← saturated
kafka_consumer_lag{job="router-worker"} = 0 ← workers idle
```

**Conclusion:** Grafana dashboards confirmed API Service is bottleneck (not workers).

---

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Dashboards](https://grafana.com/docs/grafana/latest/dashboards/)
- [Micrometer Metrics](https://micrometer.io/docs)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
- [SRE Book - Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/)

---

## Related ADRs

- [ADR 001: No Frameworks Constraint](001-no-frameworks.md) - Why Micrometer fits
- [ADR 005: Circuit Breaker Pattern](005-circuit-breaker-pattern.md) - Metrics integration
- [Docs: OBSERVABILITY.md](../OBSERVABILITY.md) - Usage guide
