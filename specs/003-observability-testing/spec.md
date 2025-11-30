# Specification 003: Observability & Load Testing

**Feature**: Observability Stack and Progressive Load Testing  
**Delivery**: Entrega 3 (Weeks 7-8)  
**Status**: 📋 Planning  
**Scope**: Educational - Concept Demonstration

---

## Overview

Implement **basic observability** (metrics + dashboards) and **progressive load testing** to validate distributed systems concepts: scalability, fault tolerance, and performance monitoring.

**Educational Focus**: Demonstrate that architectural concepts work, not achieve production metrics.

---

## Goals

### Primary Objectives
1. ✅ Implement Prometheus + Grafana stack (basic setup)
2. ✅ Create 2 essential dashboards for real-time monitoring
3. ✅ Execute progressive load tests (4-6 scenarios with k6)
4. ✅ Validate horizontal scalability (2x workers → +60-80% throughput)
5. ✅ Demonstrate fault tolerance (failover, circuit breaker, store-and-forward)
6. ✅ Produce technical report (10-15 pages) with learnings

### Non-Goals
- ❌ Production-grade observability (complex dashboards, alerting)
- ❌ High throughput targets (10^6 msg/min → 500-1000 msg/min realistic)
- ❌ Extensive performance optimization
- ❌ Cloud deployment (local Docker environment is sufficient)

---

## Success Criteria

### Performance (Realistic Targets)
- Sustained throughput: **500-1000 msg/min** (8-16 msg/s)
- P95 latency: **< 200ms** under normal load
- P99 latency: **< 500ms** during moderate spikes
- Error rate: **< 1%** during load tests (local environment tolerance)

### Scalability (Conceptual Validation)
- 2x workers → throughput increases **60-80%** (acceptable efficiency for POC)
- Kafka consumer lag: **< 100 messages** during normal operation
- Logs demonstrate load distribution between instances

### Fault Tolerance (Concept Demonstration)
- Recovery time: **< 30s** after worker failure (Kafka rebalancing)
- Zero message loss during failover (validate via message_id count)
- Circuit breaker opens after **3-5 consecutive failures**
- Store-and-forward: PENDING messages delivered when connector recovers

### Observability (Functional Stack)
- Prometheus collecting metrics from API + Router services
- 2 Grafana dashboards updating in real-time
- Screenshots demonstrate dashboards during tests
- Basic structured logging (timestamp, service name)

---

## Architecture Changes

### New Components

```
┌─────────────────────────────────────────────────────────┐
│                    Observability Stack                   │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────┐      ┌─────────────┐                  │
│  │ Prometheus  │──────│   Grafana   │                  │
│  │  (metrics)  │      │ (dashboards)│                  │
│  └──────┬──────┘      └─────────────┘                  │
│         │                                                │
│         │ scrape /metrics                               │
│         │                                                │
│  ┌──────▼──────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ API Service │  │Router Worker │  │  Connectors  │  │
│  │   :8080     │  │    :8082     │  │  :8083/8084  │  │
│  └─────────────┘  └──────────────┘  └──────────────┘  │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Metrics Endpoints

**API Service** (`GET /metrics`):
- `http_requests_total{method, path, status}`
- `http_request_duration_seconds{method, path}` (histogram)
- `messages_accepted_total`
- `kafka_publish_duration_seconds`

**Router Worker** (`GET /metrics` on port 8082):
- `messages_consumed_total{topic, partition}`
- `messages_processed_total{status}`
- `kafka_consumer_lag{topic, partition}`
- `processing_duration_seconds` (histogram)

**Connectors** (`GET /metrics`):
- `messages_sent_total{channel, status}`
- `connector_api_duration_seconds{channel}`
- `circuit_breaker_state{channel}` (0=closed, 1=open)

---

## Implementation Phases

### Phase 1: Prometheus + Grafana Setup (4-6h)
**Tasks**: T301-T310 (10 tasks)
- Add Prometheus + Grafana to docker-compose.yml
- Create monitoring/prometheus.yml configuration
- Configure Grafana datasource + provisioning
- Basic health checks

**Deliverable**: Observability stack running, Grafana accessible at :3000

---

### Phase 2: Metrics Instrumentation (4-6h)
**Tasks**: T311-T325 (15 tasks)
- Implement `/metrics` endpoint in API Service
- Implement `/metrics` endpoint in Router Worker
- Implement `/metrics` endpoint in Connectors
- Expose essential metrics (counters, histograms)
- Test metrics collection with Prometheus

**Deliverable**: All services exposing Prometheus-compatible metrics

---

### Phase 3: Grafana Dashboards (3-4h)
**Tasks**: T326-T335 (10 tasks)
- Dashboard 1: System Overview (messages/sec, latency, errors)
- Dashboard 2: Component Health (consumer lag, processing time, status)
- Export dashboard JSONs to monitoring/grafana/dashboards/
- Document dashboard usage

**Deliverable**: 2 functional dashboards updating in real-time

---

### Phase 4: Load Testing Scripts (4-6h)
**Tasks**: T336-T350 (15 tasks)
- Install k6 and create scripts/load-tests/ directory
- Test Case 1: Warmup (5 VUs, 2 min, ~50 msg/min)
- Test Case 2: Baseline (20 VUs, 5 min, ~500 msg/min)
- Test Case 3: Spike (ramp 5→50 VUs)
- Test Case 4: File Upload (10 VUs, 100KB-1MB files)
- Optional: Stress test (gradual ramp to identify bottleneck)
- Optional: Soak test (15 min stability)

**Deliverable**: 4-6 k6 scripts executing successfully

---

### Phase 5: Results Analysis (2-3h)
**Tasks**: T351-T360 (10 tasks)
- Create scripts/analyze-k6-results.py
- Parse k6 JSON output
- Generate Markdown reports with metrics
- Capture Grafana screenshots during tests
- Optional: Generate basic charts (matplotlib)

**Deliverable**: Test results in Markdown format + screenshots

---

### Phase 6: Scalability Validation (2-3h)
**Tasks**: T361-T370 (10 tasks)
- Test: 1 router-worker baseline
- Test: 2 router-workers scaled (docker-compose up --scale)
- Compare throughput (T1 vs T2)
- Validate load distribution (Prometheus metrics)
- Test: 2 API instances (optional, requires load balancer)

**Deliverable**: Evidence of horizontal scalability (logs + metrics)

---

### Phase 7: Fault Tolerance Tests (3-4h)
**Tasks**: T371-T385 (15 tasks)
- Implement basic health checks (docker-compose healthcheck)
- Test: Worker failover (stop/start container during load)
- Observe Kafka rebalancing in logs
- Validate zero message loss (Cassandra query)
- Implement simple circuit breaker in 1 connector
- Test: Circuit breaker opens after 3-5 failures
- Test: Store-and-forward (connector offline → PENDING → reconnect)

**Deliverable**: Logs demonstrating fault tolerance concepts

---

### Phase 8: Documentation (4-6h)
**Tasks**: T386-T400 (15 tasks)
- ADR 005: Circuit Breakers (1 page)
- ADR 006: Observability Strategy (1 page)
- Technical Report (10-15 pages):
  - Introduction (1 page)
  - Architecture (2-3 pages)
  - Technical Decisions (1-2 pages)
  - Architectural Patterns (1 page)
  - Load Test Results (2-3 pages)
  - Scalability (1-2 pages)
  - Fault Tolerance (1-2 pages)
  - Observability (1 page)
  - Limitations & Learnings (1 page)
  - Conclusion (0.5 page)
- Update README.md with observability section
- Create demo script: scripts/demo-entrega3.sh

**Deliverable**: Complete technical documentation

---

## Task Breakdown Summary

| Phase | Tasks | Est. Hours | Priority |
|-------|-------|------------|----------|
| 1. Prometheus + Grafana | T301-T310 | 4-6h | High |
| 2. Metrics Instrumentation | T311-T325 | 4-6h | High |
| 3. Grafana Dashboards | T326-T335 | 3-4h | High |
| 4. Load Testing Scripts | T336-T350 | 4-6h | High |
| 5. Results Analysis | T351-T360 | 2-3h | Medium |
| 6. Scalability Validation | T361-T370 | 2-3h | High |
| 7. Fault Tolerance Tests | T371-T385 | 3-4h | High |
| 8. Documentation | T386-T400 | 4-6h | High |
| **TOTAL** | **100 tasks** | **26-38h** | - |

**For a team of 3-4 students**: 7-10 hours per person over 2 weeks ✅

---

## Dependencies

### External Tools Required
- **k6** (load testing): https://k6.io/docs/getting-started/installation/
- **Python 3** (for analysis scripts): matplotlib, json (built-in)
- **Docker Compose** (already used)

### Internal Dependencies
- Entrega 1: ✅ Complete (basic messaging)
- Entrega 2: ✅ Complete (files, connectors, status lifecycle)
- All services must expose HTTP endpoints for metrics

---

## Testing Strategy

### Unit Tests
- Not applicable (observability is integration-focused)

### Integration Tests
- Prometheus scrapes metrics successfully from all services
- Grafana displays real-time data from Prometheus
- k6 scripts execute without errors
- Metrics update during load tests

### Manual Validation
- Visual inspection of Grafana dashboards during demo
- Log analysis for failover/rebalancing events
- Query Cassandra to confirm zero message loss
- Compare throughput before/after scaling

---

## Non-Functional Requirements

### Performance Targets (Realistic for POC)
- Metrics collection overhead: < 5% CPU increase
- Prometheus retention: 7 days (sufficient for educational demo)
- Grafana dashboard refresh: 5-10 seconds (acceptable latency)

### Usability
- Grafana dashboards must be self-explanatory (titles, units, descriptions)
- k6 scripts must have clear comments explaining test purpose
- README must include instructions to run load tests

### Maintainability
- Prometheus/Grafana configuration in version control
- Dashboard JSONs exported and versioned
- Test scripts follow consistent naming convention

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| k6 not available on student machines | High | Provide Docker-based k6 alternative |
| Grafana dashboards too complex | Medium | Focus on 2 essential dashboards only |
| Load tests overwhelm local environment | Medium | Start with low VUs (5-20), increase gradually |
| Circuit breaker implementation complex | Medium | Simple counter-based logic (3-5 failures) |
| Time constraint (38h total) | High | Mark optional tasks clearly (Phases 4-5) |

---

## Acceptance Criteria Checklist

### Observability
- [ ] Prometheus running and scraping metrics (30s interval)
- [ ] Grafana accessible at http://localhost:3000
- [ ] Dashboard 1 (System Overview) displays: msg/sec, latency, errors
- [ ] Dashboard 2 (Component Health) displays: consumer lag, processing time
- [ ] Screenshots captured during load tests

### Load Testing
- [ ] k6 installed and test scripts created (minimum 4 scenarios)
- [ ] Warmup test executes successfully (5 VUs, 2 min)
- [ ] Baseline test achieves 500+ msg/min with P95 < 200ms
- [ ] Spike test demonstrates Kafka absorbs traffic burst
- [ ] Results analyzed and documented in Markdown

### Scalability
- [ ] 1 worker baseline measured (throughput T1)
- [ ] 2 workers scaled, throughput measured (T2 >= 1.6 * T1)
- [ ] Logs demonstrate load distribution between workers
- [ ] Kafka rebalancing observed and documented

### Fault Tolerance
- [ ] Health checks implemented (docker-compose healthcheck)
- [ ] Worker failover test: recovery time < 30s
- [ ] Zero message loss validated (Cassandra query)
- [ ] Circuit breaker opens after 3-5 failures (logs)
- [ ] Store-and-forward: PENDING → DELIVERED transition

### Documentation
- [ ] ADR 005 (Circuit Breakers) written
- [ ] ADR 006 (Observability) written
- [ ] Technical report completed (10-15 pages)
- [ ] README updated with observability section
- [ ] Demo script (demo-entrega3.sh) functional

---

## References

- **Prometheus Documentation**: https://prometheus.io/docs/
- **Grafana Dashboards**: https://grafana.com/docs/grafana/latest/dashboards/
- **k6 Load Testing**: https://k6.io/docs/
- **Circuit Breaker Pattern**: https://martinfowler.com/bliki/CircuitBreaker.html
- **Kafka Consumer Groups**: https://kafka.apache.org/documentation/#consumergroups

---

**Educational Note**: This specification prioritizes **concept demonstration** over production metrics. Students should focus on understanding WHY these patterns work, not just achieving high numbers.

---

**Status**: Ready for task breakdown (tasks.md)
**Last Updated**: November 2025
