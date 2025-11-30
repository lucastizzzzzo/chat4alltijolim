# Tasks: Observability & Load Testing (Entrega 3)

**Specification**: 003-observability-testing  
**Total Tasks**: 100  
**Estimated Time**: 26-38 hours (team of 3-4 students)  
**Approach**: Progressive - Start simple, scale gradually

---

## Phase 1: Prometheus + Grafana Setup (10 tasks, 4-6h)

### T301: Add Prometheus service to docker-compose.yml
**Description**: Add Prometheus container configuration  
**Details**:
```yaml
prometheus:
  image: prom/prometheus:latest
  container_name: chat4all-prometheus
  ports:
    - "9090:9090"
  volumes:
    - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--storage.tsdb.retention.time=7d'
  networks:
    - chat4all-network
```
**Acceptance**: `docker-compose up prometheus` starts without errors

---

### T302: Create monitoring/prometheus.yml configuration
**Description**: Define Prometheus scrape configuration  
**Details**:
```yaml
global:
  scrape_interval: 30s  # Educational: 30s is sufficient
  evaluation_interval: 30s

scrape_configs:
  - job_name: 'api-service'
    static_configs:
      - targets: ['api-service:8080']
  
  - job_name: 'router-worker'
    static_configs:
      - targets: ['router-worker:8082']
  
  - job_name: 'connector-whatsapp'
    static_configs:
      - targets: ['connector-whatsapp:8083']
  
  - job_name: 'connector-instagram'
    static_configs:
      - targets: ['connector-instagram:8084']
```
**Acceptance**: Prometheus UI at http://localhost:9090 shows all targets

---

### T303: Add Grafana service to docker-compose.yml
**Description**: Add Grafana container with provisioning  
**Details**:
```yaml
grafana:
  image: grafana/grafana:latest
  container_name: chat4all-grafana
  ports:
    - "3000:3000"
  environment:
    - GF_SECURITY_ADMIN_USER=admin
    - GF_SECURITY_ADMIN_PASSWORD=admin
    - GF_USERS_ALLOW_SIGN_UP=false
  volumes:
    - ./monitoring/grafana/provisioning:/etc/grafana/provisioning
    - ./monitoring/grafana/dashboards:/var/lib/grafana/dashboards
  depends_on:
    - prometheus
  networks:
    - chat4all-network
```
**Acceptance**: Grafana accessible at http://localhost:3000 (admin/admin)

---

### T304: Create Grafana datasource provisioning
**Description**: Auto-configure Prometheus as datasource  
**File**: `monitoring/grafana/provisioning/datasources/prometheus.yml`  
**Details**:
```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
```
**Acceptance**: Grafana shows Prometheus datasource as "Connected"

---

### T305: Create Grafana dashboard provisioning config
**Description**: Auto-load dashboards on startup  
**File**: `monitoring/grafana/provisioning/dashboards/default.yml`  
**Details**:
```yaml
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: 'Chat4All'
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
```
**Acceptance**: Dashboards folder created in Grafana UI

---

### T306: Update .gitignore for monitoring data
**Description**: Ignore Grafana/Prometheus runtime data  
**Details**: Add to `.gitignore`:
```
monitoring/prometheus/data/
monitoring/grafana/data/
*.log
```
**Acceptance**: Git status shows no unwanted files

---

### T307: Test Prometheus metrics scraping
**Description**: Validate Prometheus can reach all targets  
**Steps**:
1. Start stack: `docker-compose up -d`
2. Open http://localhost:9090/targets
3. Verify all targets show "UP" status
**Acceptance**: All 4 services (API, Router, 2 Connectors) reachable

---

### T308: Add health check endpoints (preparation)
**Description**: Document what `/metrics` endpoint should return  
**Format**: Prometheus text format
```
# TYPE http_requests_total counter
http_requests_total{method="POST",path="/v1/messages",status="202"} 42

# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{method="POST",path="/v1/messages",le="0.1"} 35
http_request_duration_seconds_bucket{method="POST",path="/v1/messages",le="0.5"} 40
http_request_duration_seconds_sum{method="POST",path="/v1/messages"} 8.5
http_request_duration_seconds_count{method="POST",path="/v1/messages"} 42
```
**Acceptance**: Format documented in README

---

### T309: Create monitoring README
**Description**: Document observability stack usage  
**File**: `monitoring/README.md`  
**Sections**:
- Stack overview (Prometheus + Grafana)
- How to access dashboards
- Metrics exposed by each service
- Troubleshooting
**Acceptance**: README explains how to use monitoring tools

---

### T310: Test observability stack end-to-end
**Description**: Smoke test all components  
**Steps**:
1. `docker-compose down && docker-compose up -d`
2. Wait 60s for initialization
3. Verify Prometheus: http://localhost:9090
4. Verify Grafana: http://localhost:3000
5. Check logs: `docker-compose logs prometheus grafana`
**Acceptance**: Stack running, no errors in logs

---

## Phase 2: Metrics Instrumentation (15 tasks, 4-6h)

### T311: Implement MetricsRegistry utility (shared module)
**Description**: Create utility for metrics collection  
**File**: `shared/src/main/java/chat4all/shared/metrics/MetricsRegistry.java`  
**Details**:
```java
public class MetricsRegistry {
    private final Map<String, Counter> counters = new ConcurrentHashMap<>();
    private final Map<String, Histogram> histograms = new ConcurrentHashMap<>();
    
    public void incrementCounter(String name, String... labels) { ... }
    public void recordHistogram(String name, double value, String... labels) { ... }
    public String exportPrometheusFormat() { ... }
}
```
**Acceptance**: Utility compiles and has basic tests

---

### T312: Add /metrics endpoint to API Service
**Description**: Expose metrics via HTTP  
**File**: `api-service/src/main/java/chat4all/api/http/MetricsHandler.java`  
**Details**:
```java
public class MetricsHandler implements HttpHandler {
    @Override
    public void handle(HttpExchange exchange) {
        String metrics = MetricsRegistry.getInstance().exportPrometheusFormat();
        exchange.sendResponseHeaders(200, metrics.length());
        exchange.getResponseBody().write(metrics.getBytes());
    }
}
```
**Route**: `GET /metrics`  
**Acceptance**: `curl http://localhost:8080/metrics` returns Prometheus format

---

### T313: Instrument API: http_requests_total counter
**Description**: Count all HTTP requests by method, path, status  
**Location**: `MessagesHandler.java`, `FilesHandler.java`, etc.  
**Code**:
```java
MetricsRegistry.getInstance().incrementCounter(
    "http_requests_total",
    "method=" + method,
    "path=" + path,
    "status=" + statusCode
);
```
**Acceptance**: Counter increments visible in /metrics

---

### T314: Instrument API: http_request_duration_seconds histogram
**Description**: Record request latency  
**Code**:
```java
long startTime = System.nanoTime();
// ... handle request ...
long durationMs = (System.nanoTime() - startTime) / 1_000_000;
MetricsRegistry.getInstance().recordHistogram(
    "http_request_duration_seconds",
    durationMs / 1000.0,
    "method=" + method,
    "path=" + path
);
```
**Buckets**: 0.01, 0.05, 0.1, 0.2, 0.5, 1.0, 2.0 seconds  
**Acceptance**: P95 latency calculable from histogram

---

### T315: Instrument API: messages_accepted_total counter
**Description**: Count messages accepted by API  
**Location**: `MessagesHandler.java` after Kafka publish success  
**Acceptance**: Counter matches Kafka producer metrics

---

### T316: Instrument API: kafka_publish_duration_seconds histogram
**Description**: Time to publish to Kafka  
**Acceptance**: Histogram shows Kafka producer latency

---

### T317: Add /metrics endpoint to Router Worker
**Description**: Expose metrics on port 8082  
**File**: `router-worker/src/main/java/chat4all/worker/MetricsServer.java`  
**Details**: Simple HTTP server on port 8082 returning metrics  
**Acceptance**: `curl http://localhost:8082/metrics` works

---

### T318: Instrument Router: messages_consumed_total counter
**Description**: Count messages consumed from Kafka  
**Location**: `RouterWorker.java` in consume() method  
**Labels**: topic, partition  
**Acceptance**: Counter increments per message

---

### T319: Instrument Router: messages_processed_total counter
**Description**: Count messages processed by status  
**Labels**: status (SENT, DELIVERED, FAILED)  
**Acceptance**: Total processed = sum of all statuses

---

### T320: Instrument Router: kafka_consumer_lag gauge
**Description**: Track consumer lag per partition  
**Details**: Query Kafka consumer API for lag  
**Acceptance**: Lag metric matches Kafka console output

---

### T321: Instrument Router: processing_duration_seconds histogram
**Description**: Time to process one message (consume → persist → send)  
**Acceptance**: P95 processing time visible

---

### T322: Add /metrics to Connector (WhatsApp)
**Description**: Expose metrics on port 8083  
**File**: `connector-whatsapp/src/main/java/chat4all/connector/whatsapp/MetricsServer.java`  
**Acceptance**: `curl http://localhost:8083/metrics` works

---

### T323: Instrument Connector: messages_sent_total counter
**Description**: Count messages sent to external API  
**Labels**: channel (whatsapp), status (success/failed)  
**Acceptance**: Success + Failed = Total consumed

---

### T324: Instrument Connector: connector_api_duration_seconds histogram
**Description**: Time to call external API (simulated)  
**Acceptance**: Histogram shows ~200-500ms (mock delay)

---

### T325: Instrument Connector: circuit_breaker_state gauge
**Description**: Circuit breaker status (0=closed, 1=open, 0.5=half_open)  
**Acceptance**: State changes visible when circuit breaker triggers

---

## Phase 3: Grafana Dashboards (10 tasks, 3-4h)

### T326: Create Dashboard 1 JSON skeleton
**Description**: Create base dashboard structure  
**File**: `monitoring/grafana/dashboards/system-overview.json`  
**Details**: Grafana JSON format with empty panels  
**Acceptance**: Dashboard imports without errors

---

### T327: Dashboard 1 - Panel: Messages per Second
**Description**: Graph showing total message throughput  
**Query**: `rate(http_requests_total{path="/v1/messages"}[1m])`  
**Type**: Time series graph  
**Acceptance**: Graph shows real-time msg/s during test

---

### T328: Dashboard 1 - Panel: API Latency (P95)
**Description**: Graph showing P95 request latency  
**Query**: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`  
**Type**: Time series graph  
**Unit**: seconds  
**Acceptance**: Latency spikes visible during load

---

### T329: Dashboard 1 - Panel: Error Rate
**Description**: Gauge showing % of failed requests  
**Query**: `(rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])) * 100`  
**Type**: Gauge (0-100%)  
**Thresholds**: Green < 1%, Yellow 1-5%, Red > 5%  
**Acceptance**: Gauge updates in real-time

---

### T330: Dashboard 1 - Panel: Total Messages Processed
**Description**: Counter showing total messages  
**Query**: `sum(http_requests_total{path="/v1/messages"})`  
**Type**: Stat panel  
**Acceptance**: Number increases during test

---

### T331: Create Dashboard 2 JSON skeleton
**Description**: Component Health dashboard  
**File**: `monitoring/grafana/dashboards/component-health.json`  
**Acceptance**: Dashboard imports without errors

---

### T332: Dashboard 2 - Panel: Messages Published vs Consumed
**Description**: Compare producer and consumer rates  
**Queries**:
- Published: `rate(messages_accepted_total[1m])`
- Consumed: `rate(messages_consumed_total[1m])`  
**Type**: Time series (2 lines)  
**Acceptance**: Lines overlap when system is balanced

---

### T333: Dashboard 2 - Panel: Consumer Lag
**Description**: Show Kafka consumer lag  
**Query**: `kafka_consumer_lag`  
**Type**: Time series  
**Threshold**: Alert if > 100 (local testing)  
**Acceptance**: Lag spikes visible during failover

---

### T334: Dashboard 2 - Panel: Processing Time
**Description**: Average message processing duration  
**Query**: `rate(processing_duration_seconds_sum[5m]) / rate(processing_duration_seconds_count[5m])`  
**Type**: Gauge  
**Unit**: seconds  
**Acceptance**: Shows ~0.05-0.2s typical processing time

---

### T335: Export and document dashboards
**Description**: Export JSONs and create usage guide  
**Steps**:
1. Export Dashboard 1 JSON
2. Export Dashboard 2 JSON
3. Add screenshots to docs/
4. Update monitoring/README.md with dashboard descriptions
**Acceptance**: Dashboards can be imported from JSON files

---

## Phase 4: Load Testing Scripts (15 tasks, 4-6h)

### T336: Install k6 and verify installation
**Description**: Install k6 load testing tool  
**Commands**:
```bash
# Ubuntu/Debian
sudo apt install k6

# macOS
brew install k6

# Verify
k6 version
```
**Acceptance**: `k6 version` shows installed version

---

### T337: Create load testing directory structure
**Description**: Set up scripts/load-tests/ directory  
**Structure**:
```
scripts/load-tests/
├── 01-warmup.js
├── 02-baseline.js
├── 03-spike.js
├── 04-file-upload.js
├── 05-stress.js (optional)
├── 06-soak.js (optional)
├── common/
│   └── config.js
└── results/
```
**Acceptance**: Directory structure created

---

### T338: Create common k6 configuration
**Description**: Shared config for all tests  
**File**: `scripts/load-tests/common/config.js`  
**Details**:
```javascript
export const API_URL = __ENV.API_URL || 'http://localhost:8080';
export const JWT_TOKEN = authenticate(); // Get token once

export function authenticate() {
    const res = http.post(`${API_URL}/v1/auth/login`, JSON.stringify({
        user_id: 'user_a'
    }), { headers: { 'Content-Type': 'application/json' } });
    return res.json('token');
}
```
**Acceptance**: Config exports API_URL and JWT_TOKEN

---

### T339: Test Case 1 - Warmup (5 VUs, 2 min)
**Description**: Validate system works under minimal load  
**File**: `scripts/load-tests/01-warmup.js`  
**Config**:
```javascript
export let options = {
    vus: 5,
    duration: '2m',
    thresholds: {
        http_req_duration: ['p(95)<100'], // Expect <100ms without load
        http_req_failed: ['rate<0.01'],   // <1% errors
    }
};
```
**Payload**: 100-byte text message  
**Acceptance**: Test passes with 0% errors

---

### T340: Test Case 2 - Baseline (20 VUs, 5 min)
**Description**: Measure normal load performance  
**File**: `scripts/load-tests/02-baseline.js`  
**Config**:
```javascript
export let options = {
    vus: 20,
    duration: '5m',
    thresholds: {
        http_req_duration: ['p(95)<200'], // P95 < 200ms
        http_req_failed: ['rate<0.01'],   // <1% errors
    }
};
```
**Expected Throughput**: 500-600 msg/min  
**Acceptance**: Achieves target throughput with P95 < 200ms

---

### T341: Test Case 3 - Spike (ramp 5→50 VUs)
**Description**: Validate system absorbs traffic burst  
**File**: `scripts/load-tests/03-spike.js`  
**Config**:
```javascript
export let options = {
    stages: [
        { duration: '30s', target: 5 },   // Normal
        { duration: '30s', target: 50 },  // Spike
        { duration: '1m', target: 50 },   // Sustain
        { duration: '30s', target: 5 },   // Recovery
    ],
    thresholds: {
        http_req_failed: ['rate<0.05'],   // <5% errors during spike
    }
};
```
**Acceptance**: System doesn't crash, errors < 5%

---

### T342: Test Case 4 - File Upload (10 VUs, 3 min)
**Description**: Test file upload under load  
**File**: `scripts/load-tests/04-file-upload.js`  
**Details**: Upload 100KB-1MB files  
**Thresholds**:
- Upload duration < 2s for 1MB file
- Error rate < 1%
**Acceptance**: Files uploaded successfully without timeouts

---

### T343: (Optional) Test Case 5 - Stress (gradual ramp)
**Description**: Identify first bottleneck  
**File**: `scripts/load-tests/05-stress.js`  
**Config**: Ramp from 10 to 100 VUs in increments of 10 every minute  
**Acceptance**: Identifies component that fails first

---

### T344: (Optional) Test Case 6 - Soak (30 VUs, 15 min)
**Description**: Validate stability over time  
**File**: `scripts/load-tests/06-soak.js`  
**Mix**: 70% POST /v1/messages, 30% GET /v1/messages  
**Acceptance**: Latency doesn't degrade > 15% over time

---

### T345: Add test execution instructions
**Description**: Document how to run tests  
**File**: `scripts/load-tests/README.md`  
**Sections**:
- Prerequisites (k6 installed, stack running)
- How to run each test case
- How to interpret results
- Troubleshooting
**Acceptance**: README explains test execution

---

### T346: Create test execution wrapper script
**Description**: Script to run all tests sequentially  
**File**: `scripts/load-tests/run-all-tests.sh`  
**Details**:
```bash
#!/bin/bash
echo "Running Load Tests..."
k6 run 01-warmup.js --out json=results/warmup.json
k6 run 02-baseline.js --out json=results/baseline.json
k6 run 03-spike.js --out json=results/spike.json
k6 run 04-file-upload.js --out json=results/file-upload.json
echo "Tests complete. Check results/ directory."
```
**Acceptance**: Script runs all tests and saves results

---

### T347: Test k6 script execution
**Description**: Validate all scripts run successfully  
**Steps**:
1. Start stack: `docker-compose up -d`
2. Run warmup: `k6 run 01-warmup.js`
3. Check output for errors
**Acceptance**: All test scripts execute without syntax errors

---

### T348: Configure k6 output formats
**Description**: Save results in JSON for analysis  
**Command**: `k6 run script.js --out json=results/test.json`  
**Acceptance**: JSON file contains metrics data

---

### T349: Create sample k6 output for documentation
**Description**: Run one test and save output as example  
**File**: `scripts/load-tests/results/baseline-sample.json`  
**Acceptance**: Sample output demonstrates expected format

---

### T350: Document expected metrics for each test
**Description**: Define success criteria for each test case  
**File**: Add to `scripts/load-tests/README.md`  
**Example**:
```markdown
## Test Case 2: Baseline
**Expected Results**:
- Throughput: 500-600 msg/min
- P95 latency: < 200ms
- P99 latency: < 500ms
- Error rate: < 1%
```
**Acceptance**: Success criteria documented for all tests

---

## Phase 5: Results Analysis (10 tasks, 2-3h)

### T351: Create Python analysis script skeleton
**Description**: Set up analysis script  
**File**: `scripts/analyze-k6-results.py`  
**Structure**:
```python
import json
import sys

def parse_k6_json(filename):
    """Parse k6 JSON output"""
    pass

def calculate_metrics(data):
    """Calculate throughput, latency, errors"""
    pass

def generate_markdown_report(metrics):
    """Generate Markdown report"""
    pass

if __name__ == '__main__':
    # ...
```
**Acceptance**: Script runs without errors

---

### T352: Implement k6 JSON parsing
**Description**: Read and parse k6 output  
**Details**: Extract http_req_duration, http_req_failed metrics  
**Acceptance**: Parser extracts all metrics from JSON

---

### T353: Calculate throughput from k6 data
**Description**: Compute messages/minute  
**Formula**: `total_requests / (duration_seconds / 60)`  
**Acceptance**: Throughput matches k6 summary output

---

### T354: Calculate latency percentiles (P95, P99)
**Description**: Compute percentiles from histogram data  
**Acceptance**: P95/P99 within 5% of k6 output

---

### T355: Calculate error rate
**Description**: Compute % of failed requests  
**Formula**: `(failed_requests / total_requests) * 100`  
**Acceptance**: Error rate matches k6 output

---

### T356: Generate Markdown report template
**Description**: Create report format  
**Template**:
```markdown
# Load Test Results: {test_name}

**Date**: {date}
**Duration**: {duration}
**Virtual Users**: {vus}

## Metrics
- **Throughput**: {throughput} msg/min
- **P95 Latency**: {p95}ms
- **P99 Latency**: {p99}ms
- **Error Rate**: {error_rate}%

## Pass/Fail
- Throughput: {pass/fail} (target: {target})
- P95 Latency: {pass/fail} (target: < 200ms)
- Error Rate: {pass/fail} (target: < 1%)
```
**Acceptance**: Template generates valid Markdown

---

### T357: (Optional) Generate charts with matplotlib
**Description**: Create latency/throughput charts  
**Libraries**: matplotlib, numpy  
**Charts**:
- Latency over time (line chart)
- Throughput over time (line chart)
**Acceptance**: PNG files generated in results/

---

### T358: Run analysis script on all test results
**Description**: Generate reports for all tests  
**Command**: `python3 scripts/analyze-k6-results.py scripts/load-tests/results/*.json`  
**Output**: Markdown files in results/ directory  
**Acceptance**: Reports generated for all tests

---

### T359: Capture Grafana screenshots during tests
**Description**: Take screenshots of dashboards under load  
**Timing**: During baseline and spike tests  
**Files**: Save to `docs/screenshots/grafana-*.png`  
**Acceptance**: Screenshots show real-time metrics

---

### T360: Create summary comparison table
**Description**: Compare all test results in one table  
**File**: `scripts/load-tests/results/SUMMARY.md`  
**Format**:
```markdown
| Test | Throughput | P95 Latency | Error Rate | Pass |
|------|------------|-------------|------------|------|
| Warmup | 50 msg/min | 85ms | 0% | ✅ |
| Baseline | 548 msg/min | 187ms | 0.12% | ✅ |
| Spike | varies | 423ms | 2.3% | ✅ |
```
**Acceptance**: Summary table created

---

## Phase 6: Scalability Validation (10 tasks, 2-3h)

### T361: Measure baseline with 1 router-worker
**Description**: Establish baseline performance  
**Steps**:
1. Ensure 1 worker: `docker-compose up -d router-worker`
2. Run baseline test: `k6 run 02-baseline.js`
3. Record throughput T1 and CPU usage
**Acceptance**: Baseline metrics documented

---

### T362: Scale to 2 router-workers
**Description**: Add second worker instance  
**Command**: `docker-compose up --scale router-worker=2 -d`  
**Wait**: 30s for Kafka rebalancing  
**Acceptance**: `docker-compose ps` shows 2 router-worker containers

---

### T363: Verify Kafka rebalancing in logs
**Description**: Confirm partition reassignment  
**Command**: `docker-compose logs router-worker | grep -i "partition"`  
**Expected**: Logs show "Revoking" and "Adding" partitions  
**Acceptance**: Both workers assigned partitions

---

### T364: Run baseline test with 2 workers
**Description**: Measure scaled performance  
**Steps**:
1. Run same baseline test: `k6 run 02-baseline.js`
2. Record throughput T2
**Expected**: T2 >= 1.6 * T1 (60-80% efficiency)  
**Acceptance**: Throughput increased

---

### T365: Compare throughput: 1 worker vs 2 workers
**Description**: Calculate scaling efficiency  
**Formula**: `efficiency = (T2 / T1) / 2 * 100%`  
**Target**: 60-80% efficiency (acceptable for POC)  
**Acceptance**: Efficiency calculated and documented

---

### T366: Query Prometheus for load distribution
**Description**: Verify messages distributed between workers  
**Query**: `messages_processed_total` by instance  
**Acceptance**: Both workers show similar message counts

---

### T367: (Optional) Scale API Service to 2 instances
**Description**: Test API horizontal scaling  
**Note**: Requires load balancer (Nginx) or Docker Swarm mode  
**Command**: `docker-compose up --scale api-service=2 -d`  
**Acceptance**: 2 API instances running

---

### T368: (Optional) Measure API scaling efficiency
**Description**: Compare throughput with 1 vs 2 API instances  
**Expected**: 70-90% efficiency (API is lighter than worker)  
**Acceptance**: Efficiency documented

---

### T369: Document scaling results
**Description**: Create scaling analysis document  
**File**: `docs/SCALING_RESULTS.md`  
**Sections**:
- Baseline (1 worker)
- Scaled (2 workers)
- Efficiency calculation
- Load distribution evidence (Prometheus screenshots)
- Analysis: why not exactly 2x? (overhead, rebalancing)
**Acceptance**: Document explains scaling behavior

---

### T370: Create scaling comparison chart
**Description**: Visual comparison of scaling  
**Format**: Simple bar chart (can be ASCII art or PNG)  
**Data**: Throughput with 1, 2 workers  
**Acceptance**: Chart clearly shows scaling effect

---

## Phase 7: Fault Tolerance Tests (15 tasks, 3-4h)

### T371: Implement basic health check endpoint
**Description**: Add /health to API Service  
**File**: `api-service/src/main/java/chat4all/api/http/HealthCheckHandler.java`  
**Response**:
```json
{
  "status": "UP",
  "timestamp": 1700000000000,
  "checks": {
    "kafka": "UP",
    "cassandra": "UP"
  }
}
```
**Acceptance**: `curl http://localhost:8080/health` returns 200

---

### T372: Add health checks to docker-compose.yml
**Description**: Configure Docker health checks  
**Example**:
```yaml
api-service:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
    interval: 30s
    timeout: 5s
    retries: 2
    start_period: 40s
```
**Acceptance**: `docker-compose ps` shows health status

---

### T373: Test health check failure detection
**Description**: Simulate unhealthy service  
**Steps**:
1. Stop Kafka: `docker stop chat4alltijolim-kafka-1`
2. Wait for health check to fail (~60s)
3. Verify: `docker ps` shows "(unhealthy)"
4. Restart Kafka: `docker start chat4alltijolim-kafka-1`
**Acceptance**: Unhealthy status detected

---

### T374: Configure worker failover test environment
**Description**: Set up 2 router-workers for failover test  
**Command**: `docker-compose up --scale router-worker=2 -d`  
**Acceptance**: 2 workers running and consuming messages

---

### T375: Start load during failover test
**Description**: Run continuous load while testing failover  
**Command**: `k6 run --stage "5m:10" 02-baseline.js &`  
**Note**: Lightweight load (10 VUs) for observation  
**Acceptance**: Load test running in background

---

### T376: Trigger worker failure
**Description**: Stop 1 worker during load test  
**Command**: `docker stop chat4alltijolim-router-worker-1`  
**Time**: After 1 minute of stable test  
**Acceptance**: Worker container stopped

---

### T377: Observe Kafka rebalancing
**Description**: Monitor logs for partition reassignment  
**Command**: `docker-compose logs -f router-worker-2 | grep -i "rebalance"`  
**Expected**: Logs show rebalancing within 10-30s  
**Acceptance**: Rebalancing observed and logged

---

### T378: Measure recovery time
**Description**: Time from failure to recovery  
**Measurement**: Timestamp of stop → timestamp of rebalancing complete  
**Target**: < 30 seconds  
**Acceptance**: Recovery time documented

---

### T379: Verify zero message loss
**Description**: Count messages before/after failover  
**Query**:
```sql
SELECT COUNT(*) FROM chat4all.messages WHERE timestamp > {test_start};
```
**Expected**: Count matches k6 successful requests  
**Acceptance**: Zero messages lost

---

### T380: Restart failed worker
**Description**: Simulate worker recovery  
**Command**: `docker start chat4alltijolim-router-worker-1`  
**Wait**: 30s for rebalancing  
**Acceptance**: Worker rejoins consumer group

---

### T381: Implement simple circuit breaker in connector
**Description**: Add counter-based circuit breaker  
**File**: `connector-whatsapp/src/main/java/chat4all/connector/whatsapp/CircuitBreaker.java`  
**Logic**:
```java
private int consecutiveFailures = 0;
private boolean isOpen = false;

public boolean shouldAttempt() {
    if (isOpen) return false;
    return true;
}

public void recordSuccess() {
    consecutiveFailures = 0;
}

public void recordFailure() {
    consecutiveFailures++;
    if (consecutiveFailures >= 3) {
        isOpen = true;
        log.error("Circuit breaker OPENED");
    }
}
```
**Acceptance**: Circuit breaker compiles

---

### T382: Test circuit breaker opens after failures
**Description**: Simulate connector failures  
**Steps**:
1. Configure connector to fail (return error)
2. Send 5 messages to WhatsApp
3. Observe logs: first 3 attempts, then circuit opens
4. Verify messages 4-5 not attempted
**Acceptance**: Circuit breaker opens after 3 failures

---

### T383: Implement store-and-forward for PENDING messages
**Description**: Mark messages PENDING when connector offline  
**Logic**: If connector fails, save message with status PENDING  
**Acceptance**: PENDING messages visible in Cassandra

---

### T384: Test store-and-forward delivery
**Description**: Validate PENDING → DELIVERED transition  
**Steps**:
1. Stop connector: `docker stop connector-instagram`
2. Send message to Instagram recipient
3. Verify status PENDING in database
4. Restart connector: `docker start connector-instagram`
5. Wait for retry/poll mechanism
6. Verify status changed to DELIVERED
**Acceptance**: Message eventually delivered

---

### T385: Document all fault tolerance tests
**Description**: Create test report  
**File**: `docs/FAULT_TOLERANCE_TESTS.md`  
**Sections**:
- Health checks validation
- Worker failover test results (logs, recovery time)
- Zero message loss verification (SQL query)
- Circuit breaker demonstration (logs)
- Store-and-forward test (status transitions)
**Acceptance**: All tests documented with evidence

---

## Phase 8: Documentation (15 tasks, 4-6h)

### T386: Create ADR 005: Circuit Breakers
**Description**: Document circuit breaker decision  
**File**: `docs/adr/005-circuit-breakers.md`  
**Template**:
```markdown
# ADR 005: Circuit Breakers in Connectors

## Status
Accepted

## Context
External APIs can fail, causing connector retry storms...

## Decision
Implement simple counter-based circuit breaker...

## Consequences
Positive: Protects system from cascading failures
Negative: May skip messages temporarily (mitigated by store-and-forward)
```
**Length**: 1 page  
**Acceptance**: ADR merged to docs/adr/

---

### T387: Create ADR 006: Observability Strategy
**Description**: Document monitoring architecture  
**File**: `docs/adr/006-observability-strategy.md`  
**Sections**:
- Context: Need for runtime visibility
- Decision: Prometheus + Grafana (industry standard)
- Alternatives considered: ELK, Datadog (too complex for POC)
- Consequences: 2 dashboards sufficient for educational demo
**Length**: 1 page  
**Acceptance**: ADR merged

---

### T388: Start Technical Report structure
**Description**: Create report outline  
**File**: `docs/RELATORIO_TECNICO_ENTREGA3.md`  
**Sections** (10-15 pages):
1. Introdução
2. Arquitetura Implementada
3. Decisões Técnicas
4. Padrões Arquiteturais
5. Testes de Carga e Resultados
6. Escalabilidade Horizontal
7. Tolerância a Falhas
8. Observabilidade
9. Limitações e Aprendizados
10. Conclusão
**Acceptance**: Outline created with section headers

---

### T389: Write report Section 1: Introdução (1 page)
**Description**: Context and objectives  
**Content**:
- Chat4All overview
- Entregas 1-2 recap
- Entrega 3 objectives: observability, load testing, scalability
- Adapted requirements (realistic targets)
**Acceptance**: Section complete, 1 page

---

### T390: Write report Section 2: Arquitetura (2-3 pages)
**Description**: Document architecture with diagrams  
**Content**:
- Component diagram (updated with Prometheus/Grafana)
- Sequence diagram (message flow)
- Mapping: component → source code
- References to ADRs
**Acceptance**: Section complete with diagrams

---

### T391: Write report Section 3: Decisões Técnicas (1-2 pages)
**Description**: Justify technology choices  
**Content**:
- Why Kafka? (event-driven, durability)
- Why Cassandra? (write-heavy, horizontal scaling)
- Why MinIO? (S3-compatible, streaming)
- Why Prometheus + Grafana? (industry standard, open source)
**Acceptance**: Section complete with rationale

---

### T392: Write report Section 5: Testes de Carga (2-3 pages)
**Description**: Document load test results  
**Content**:
- Methodology (k6, progressive approach)
- Test case results (table with throughput, latency, errors)
- Grafana screenshots (2-3 captures)
- Analysis: bottlenecks identified
- Comparison: realistic targets vs. achieved
**Acceptance**: Section complete with evidence

---

### T393: Write report Section 6: Escalabilidade (1-2 pages)
**Description**: Document scaling results  
**Content**:
- 1 worker baseline (T1)
- 2 workers scaled (T2)
- Efficiency calculation (60-80%)
- Prometheus screenshots (load distribution)
- Qualitative analysis: "Why not exactly 2x?"
**Acceptance**: Section complete with charts

---

### T394: Write report Section 7: Tolerância a Falhas (1-2 pages)
**Description**: Document fault tolerance tests  
**Content**:
- Worker failover (logs, recovery time < 30s)
- Zero message loss (SQL query proof)
- Circuit breaker (logs showing state transitions)
- Store-and-forward (PENDING → DELIVERED)
**Acceptance**: Section complete with logs

---

### T395: Write report Section 9: Limitações e Aprendizados (1 page)
**Description**: Critical reflection  
**Content**:
**Limitações**:
- Single-node Cassandra (no true HA)
- Mock connectors (not real APIs)
- Local environment (not cloud)
- Moderate load (educational, not production)

**Aprendizados**:
- Kafka guarantees ordering per partition
- Horizontal scaling has overhead (not linear)
- Observability is essential for diagnosis
- Circuit breakers prevent cascading failures
**Acceptance**: Section demonstrates critical thinking

---

### T396: Write report Section 10: Conclusão (0.5 page)
**Description**: Summary and final thoughts  
**Content**:
- Objectives achieved
- Distributed systems concepts validated
- Realistic targets met
- System ready for demo
**Acceptance**: Section concisely summarizes report

---

### T397: Add Observability section to README.md
**Description**: Update main README  
**File**: `README.md`  
**New Section**:
```markdown
## Observability

### Metrics & Dashboards
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)

### Dashboards
1. **System Overview**: Messages/sec, latency, errors
2. **Component Health**: Consumer lag, processing time

### Running Load Tests
```bash
cd scripts/load-tests
k6 run 02-baseline.js
```
See `scripts/load-tests/README.md` for details.
```
**Acceptance**: README updated

---

### T398: Create demo script: demo-entrega3.sh
**Description**: Automated demo for presentation  
**File**: `scripts/demo-entrega3.sh`  
**Steps**:
1. Start stack
2. Check health
3. Open Grafana
4. Run baseline test (background)
5. Trigger failover (stop worker)
6. Show recovery
7. Restart worker
**Duration**: 8 minutes  
**Acceptance**: Script runs successfully

---

### T399: Create demo checklist for manual presentation
**Description**: Guide for live demo  
**File**: `docs/DEMO_CHECKLIST.md`  
**Sections**:
- Preparation (before presentation)
- Part 1: Architecture overview (3 min)
- Part 2: System functioning (4 min)
- Part 3: Scalability (4 min)
- Part 4: Fault tolerance (4 min)
- Conclusion (1 min)
**Total**: 15 minutes  
**Acceptance**: Checklist complete

---

### T400: Final review and quality check
**Description**: Verify all deliverables complete  
**Checklist**:
- [ ] Prometheus + Grafana running
- [ ] All services expose /metrics
- [ ] 2 dashboards functional
- [ ] 4-6 load test scripts working
- [ ] Test results analyzed (Markdown reports)
- [ ] Scaling evidence documented
- [ ] Fault tolerance tests documented
- [ ] 2 ADRs written
- [ ] Technical report complete (10-15 pages)
- [ ] README updated
- [ ] Demo script works
**Acceptance**: All items checked, ready for submission

---

## Summary

**Total Tasks**: 100  
**Total Estimated Time**: 26-38 hours  
**Team Size**: 3-4 students  
**Per Person**: 7-10 hours over 2 weeks

### Task Distribution by Priority

**High Priority (Core Deliverables)**: 80 tasks
- Phases 1-4: Observability + Load Testing (50 tasks)
- Phases 6-7: Scalability + Fault Tolerance (25 tasks)
- Phase 8: Documentation (15 tasks, minus optional charts)

**Medium Priority (Enhanced)**: 15 tasks
- Analysis charts (matplotlib)
- API scaling tests
- Detailed performance analysis

**Optional (Time Permitting)**: 5 tasks
- Test Case 5: Stress test
- Test Case 6: Soak test
- Advanced dashboard features

### Recommended Approach

**Week 1** (Focus on Implementation):
- Days 1-2: Phases 1-2 (Prometheus + Metrics)
- Days 3-4: Phase 3-4 (Dashboards + Load Tests)
- Days 5-6: Phase 5 (Results Analysis)

**Week 2** (Focus on Validation & Documentation):
- Days 1-2: Phases 6-7 (Scaling + Fault Tolerance)
- Days 3-5: Phase 8 (Documentation)
- Day 6: Final review + demo practice

---

**Status**: Ready for implementation  
**Last Updated**: November 2025  
**Next Step**: Begin Phase 1 (T301-T310)
