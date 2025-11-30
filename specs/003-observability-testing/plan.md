# Implementation Plan: Observability & Load Testing

**Specification**: 003-observability-testing  
**Scope**: Educational - Concept Demonstration  
**Timeline**: 2 weeks (Week 7-8)  
**Team**: 3-4 students  
**Effort**: 26-38 hours total (7-10h per person)

---

## Quick Start Guide

### Prerequisites
- ✅ Entrega 1 complete (basic messaging)
- ✅ Entrega 2 complete (files, connectors, status lifecycle)
- 🔧 Install k6: `sudo apt install k6` or `brew install k6`
- 🔧 Python 3 with matplotlib (optional for charts)

### Getting Started
```bash
# 1. Create monitoring directory structure
mkdir -p monitoring/grafana/{provisioning/datasources,provisioning/dashboards,dashboards}
mkdir -p scripts/load-tests/{common,results}

# 2. Start with Phase 1: Prometheus setup
# Follow tasks T301-T310

# 3. Verify stack
docker-compose up -d
curl http://localhost:9090  # Prometheus
curl http://localhost:3000  # Grafana (admin/admin)
```

---

## Implementation Phases Overview

### 📊 Phase 1: Prometheus + Grafana (T301-T310) - 4-6h
**Goal**: Observability stack running  
**Key Tasks**:
- Add services to docker-compose.yml
- Create prometheus.yml config
- Configure Grafana datasource
- Verify metrics scraping

**Success**: Grafana shows "Prometheus Connected"

---

### 📈 Phase 2: Metrics Instrumentation (T311-T325) - 4-6h
**Goal**: All services expose /metrics  
**Key Tasks**:
- Create MetricsRegistry utility
- Add /metrics endpoint to API (port 8080)
- Add /metrics endpoint to Router (port 8082)
- Add /metrics endpoint to Connectors (ports 8083/8084)
- Instrument key operations (counters, histograms)

**Success**: `curl http://localhost:8080/metrics` returns Prometheus format

---

### 📉 Phase 3: Grafana Dashboards (T326-T335) - 3-4h
**Goal**: 2 essential dashboards functional  
**Key Tasks**:
- Dashboard 1: System Overview (msg/sec, latency, errors)
- Dashboard 2: Component Health (lag, processing time)
- Export dashboard JSONs
- Document usage

**Success**: Dashboards update in real-time during tests

---

### 🔥 Phase 4: Load Testing Scripts (T336-T350) - 4-6h
**Goal**: 4-6 k6 test cases ready  
**Key Tasks**:
- Install k6 and create directory structure
- Test Case 1: Warmup (5 VUs, 2 min)
- Test Case 2: Baseline (20 VUs, 5 min) - **Most important**
- Test Case 3: Spike (ramp 5→50 VUs)
- Test Case 4: File Upload (10 VUs, 100KB files)
- Optional: Stress + Soak tests

**Success**: All tests execute without errors

---

### 📊 Phase 5: Results Analysis (T351-T360) - 2-3h
**Goal**: Test results analyzed and documented  
**Key Tasks**:
- Create Python script to parse k6 JSON
- Calculate throughput, P95/P99 latency, error rate
- Generate Markdown reports
- Capture Grafana screenshots
- Optional: Generate charts with matplotlib

**Success**: Reports in Markdown format with metrics

---

### 🔁 Phase 6: Scalability Validation (T361-T370) - 2-3h
**Goal**: Demonstrate horizontal scaling  
**Key Tasks**:
- Measure baseline (1 worker) → T1
- Scale to 2 workers: `docker-compose up --scale router-worker=2 -d`
- Measure scaled (2 workers) → T2
- Calculate efficiency: (T2/T1)/2 * 100%
- Verify load distribution in Prometheus

**Success**: T2 >= 1.6 * T1 (60-80% efficiency)

---

### 🛡️ Phase 7: Fault Tolerance Tests (T371-T385) - 3-4h
**Goal**: Validate resilience concepts  
**Key Tasks**:
- Implement health checks (docker-compose)
- Test worker failover (stop/start container)
- Observe Kafka rebalancing (< 30s recovery)
- Verify zero message loss (Cassandra query)
- Implement simple circuit breaker (3-5 failures)
- Test store-and-forward (PENDING → DELIVERED)

**Success**: All fault tolerance concepts demonstrated with logs

---

### 📝 Phase 8: Documentation (T386-T400) - 4-6h
**Goal**: Complete technical documentation  
**Key Tasks**:
- ADR 005: Circuit Breakers (1 page)
- ADR 006: Observability Strategy (1 page)
- Technical Report (10-15 pages):
  - Introduction, Architecture, Decisions
  - Load Tests, Scalability, Fault Tolerance
  - Observability, Limitations, Learnings
- Update README.md
- Create demo script (demo-entrega3.sh)

**Success**: Report complete, ready for submission

---

## Week-by-Week Breakdown

### Week 1: Implementation (Days 1-6)

**Day 1-2: Observability Stack** (Phases 1-2)
- Student A: Prometheus + Grafana setup (T301-T310)
- Student B: Metrics in API Service (T311-T316)
- Student C: Metrics in Router Worker (T317-T321)
- Student D: Metrics in Connectors (T322-T325)

**Day 3-4: Dashboards + Tests** (Phases 3-4)
- Student A+B: Grafana dashboards (T326-T335)
- Student C+D: k6 test scripts (T336-T345)
- All: Test execution and debugging

**Day 5-6: Analysis** (Phase 5)
- Student A: Python analysis script (T351-T356)
- Student B: Run all tests, collect results (T357-T360)
- Student C+D: Grafana screenshots, preliminary docs

---

### Week 2: Validation & Documentation (Days 1-6)

**Day 1-2: Validation** (Phases 6-7)
- Student A+B: Scalability tests (T361-T370)
- Student C+D: Fault tolerance tests (T371-T385)
- All: Collect evidence (logs, queries, screenshots)

**Day 3-5: Documentation** (Phase 8)
- Student A: ADRs + report sections 1-4 (T386-T391)
- Student B: Report sections 5-7 (T392-T394)
- Student C: Report sections 8-10 + README (T395-T397)
- Student D: Demo script + checklist (T398-T399)

**Day 6: Final Review**
- All: Task T400 (quality check)
- All: Practice demo presentation
- All: Final adjustments

---

## Critical Path (Minimum Viable Delivery)

If time is limited, focus on these **60 essential tasks**:

### Must Have (Core Requirements)
1. **Observability** (20 tasks):
   - T301-T310: Prometheus + Grafana
   - T311-T320: Basic metrics (API + Router only)
   - T326-T330: Dashboard 1 only

2. **Load Testing** (15 tasks):
   - T336-T342: Setup + Warmup + Baseline + Spike tests
   - T351-T355: Basic analysis (no charts)

3. **Scalability** (8 tasks):
   - T361-T366: 1 vs 2 workers comparison
   - T369: Documentation

4. **Fault Tolerance** (10 tasks):
   - T371-T380: Health checks + worker failover
   - T385: Documentation

5. **Documentation** (7 tasks):
   - T386-T387: 2 ADRs
   - T388-T396: Technical report (simplified)
   - T400: Final review

**Total Critical Path**: 60 tasks = 18-24 hours

---

## Success Metrics (Realistic Targets)

### Performance
- ✅ Throughput: **500-1000 msg/min** (not 10 million!)
- ✅ P95 Latency: **< 200ms** under normal load
- ✅ Error Rate: **< 1%** during tests

### Scalability
- ✅ 2x workers → **+60-80% throughput**
- ✅ Consumer lag < 100 messages
- ✅ Load distribution visible in metrics

### Fault Tolerance
- ✅ Recovery time: **< 30 seconds**
- ✅ Zero message loss (verified)
- ✅ Circuit breaker opens after 3-5 failures
- ✅ Store-and-forward works

### Observability
- ✅ Prometheus collecting metrics
- ✅ 2 dashboards functional
- ✅ Screenshots captured

---

## Common Pitfalls & Solutions

### Issue: k6 not available
**Solution**: Use Docker k6:
```bash
docker run --network=host -v $PWD:/scripts grafana/k6 run /scripts/02-baseline.js
```

### Issue: Grafana dashboards complex
**Solution**: Focus on System Overview only (Dashboard 1)

### Issue: Load tests overwhelm system
**Solution**: Start with 5 VUs, increase gradually. Use local metrics, not production targets.

### Issue: Circuit breaker too complex
**Solution**: Simple counter (3 consecutive failures → open). No timeout/half-open needed for POC.

### Issue: Time constraint
**Solution**: Follow Critical Path (60 tasks). Skip optional tasks (stress test, soak test, charts).

---

## Deliverables Checklist

### Code
- [ ] `monitoring/prometheus.yml` configured
- [ ] `monitoring/grafana/` with datasource + dashboards
- [ ] `/metrics` endpoints in all services
- [ ] `scripts/load-tests/*.js` (minimum 4 tests)
- [ ] `scripts/analyze-k6-results.py`
- [ ] Circuit breaker in 1 connector
- [ ] Health checks in docker-compose.yml

### Documentation
- [ ] `docs/adr/005-circuit-breakers.md`
- [ ] `docs/adr/006-observability-strategy.md`
- [ ] `docs/RELATORIO_TECNICO_ENTREGA3.md` (10-15 pages)
- [ ] `docs/SCALING_RESULTS.md`
- [ ] `docs/FAULT_TOLERANCE_TESTS.md`
- [ ] `monitoring/README.md`
- [ ] `scripts/load-tests/README.md`
- [ ] `README.md` updated

### Results
- [ ] `scripts/load-tests/results/*.json` (k6 output)
- [ ] `scripts/load-tests/results/*.md` (analysis reports)
- [ ] `scripts/load-tests/results/SUMMARY.md` (comparison table)
- [ ] `docs/screenshots/grafana-*.png` (4-6 captures)
- [ ] `docs/screenshots/logs-*.txt` (failover, rebalancing)

### Demo
- [ ] `scripts/demo-entrega3.sh` functional
- [ ] `docs/DEMO_CHECKLIST.md` for presentation

---

## Getting Help

### Resources
- **Prometheus Docs**: https://prometheus.io/docs/prometheus/latest/querying/basics/
- **Grafana Dashboards**: https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/
- **k6 Examples**: https://k6.io/docs/examples/
- **Circuit Breaker**: https://martinfowler.com/bliki/CircuitBreaker.html

### Debugging
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job, health}'

# Check metrics from service
curl http://localhost:8080/metrics

# Verify Kafka consumer lag
docker-compose exec kafka kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group router-worker-group --describe

# Check container health
docker-compose ps
docker inspect chat4alltijolim-api-service-1 | jq '.[0].State.Health'
```

---

## Final Tips

1. **Start Simple**: Get Prometheus + Grafana running first, then add metrics incrementally.

2. **Test Early**: Run k6 tests as soon as you have basic metrics to catch issues early.

3. **Focus on Concepts**: Demonstrate that patterns work, not achieve high numbers.

4. **Document as You Go**: Take screenshots and save logs immediately after tests.

5. **Iterate**: First make it work, then make it better. Don't optimize prematurely.

6. **Communication**: Daily sync (10 min) to track progress and unblock issues.

7. **Commit Often**: Commit after each completed task for easy rollback.

---

**Status**: Ready to begin  
**Start Date**: [Fill in]  
**Target Completion**: [Fill in]  
**Team Members**: [Fill in]

**Next Step**: Execute Phase 1, Task T301 (Add Prometheus to docker-compose.yml)

Good luck! 🚀
