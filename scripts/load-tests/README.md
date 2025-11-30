# Load Testing Scripts - Chat4All

**Purpose**: Progressive load testing to validate distributed systems concepts

## Prerequisites

```bash
# Install k6
sudo apt install k6  # Ubuntu/Debian
brew install k6      # macOS

# Or use Docker
docker pull grafana/k6
```

## Test Cases

### 1. Warmup Test (`01-warmup.js`)
**Objective**: Validate system works without errors  
**Config**: 5 VUs, 2 minutes, ~50 msg/min  
**Expected**: P95 < 100ms, 0% errors

```bash
k6 run scripts/load-tests/01-warmup.js
```

### 2. Baseline Test (`02-baseline.js`) ⭐ MOST IMPORTANT
**Objective**: Measure normal throughput and latency  
**Config**: 20 VUs, 5 minutes, ~500 msg/min  
**Expected**: P95 < 200ms, <0.5% errors

```bash
k6 run scripts/load-tests/02-baseline.js

# Export results
k6 run --out json=scripts/load-tests/results/baseline.json scripts/load-tests/02-baseline.js
```

### 3. Spike Test (`03-spike.js`)
**Objective**: Validate store-and-forward pattern  
**Config**: Ramp 5→50→5 VUs over 3.5 minutes  
**Expected**: No 5xx errors, consumer lag recovers

```bash
k6 run scripts/load-tests/03-spike.js

# Watch Grafana dashboard during test
open http://localhost:3000
```

### 4. File Upload Test (`04-file-upload.js`)
**Objective**: Validate file upload under load  
**Config**: 10 VUs, 3 minutes, 100KB-1MB files  
**Expected**: 50-100 uploads/min, P95 < 2s

```bash
k6 run scripts/load-tests/04-file-upload.js
```

## Usage

### Run single test
```bash
cd /home/tizzo/chat4alltijolim
k6 run scripts/load-tests/02-baseline.js
```

### Run with custom API URL
```bash
API_BASE_URL=http://api.example.com:8080 k6 run scripts/load-tests/02-baseline.js
```

### Export results to JSON
```bash
k6 run --out json=results/baseline-$(date +%Y%m%d-%H%M%S).json scripts/load-tests/02-baseline.js
```

### Run all tests sequentially
```bash
#!/bin/bash
echo "Running all load tests..."
k6 run scripts/load-tests/01-warmup.js
sleep 30
k6 run --out json=results/baseline.json scripts/load-tests/02-baseline.js
sleep 30
k6 run scripts/load-tests/03-spike.js
sleep 30
k6 run scripts/load-tests/04-file-upload.js
echo "All tests complete!"
```

## Interpreting Results

### Key Metrics
- **http_req_duration**: Request latency (P50, P95, P99)
- **http_req_failed**: Failed request rate
- **http_reqs**: Total requests per second
- **iterations**: Completed iterations per VU

### Success Criteria
```
✓ http_req_duration....: avg=125ms min=45ms med=98ms max=456ms p(95)=187ms
✓ http_req_failed......: 0.12% ✓ 3 ✗ 2737
✓ http_reqs............: 2740  9.13/s
✓ iterations...........: 2740  9.13/s
```

### Common Issues

**Problem**: `Connection refused`  
**Solution**: Ensure services are running: `docker-compose up -d`

**Problem**: `Authentication failed`  
**Solution**: Check JWT_SECRET in docker-compose.yml matches

**Problem**: High error rate (>5%)  
**Solution**: Reduce VUs or increase duration (system may be overloaded)

## Grafana Integration

While tests run, monitor in real-time:

1. Open Grafana: http://localhost:3000
2. Navigate to "System Overview" dashboard
3. Observe:
   - Messages/sec increasing
   - Latency P95 staying below threshold
   - Error rate remaining low

## Results Analysis

After test completion:

```bash
# Parse JSON results
python3 scripts/analyze-k6-results.py results/baseline.json

# Generate report
python3 scripts/analyze-k6-results.py results/baseline.json > results/baseline-report.md
```

## Educational Notes

### Warmup Test
- Establishes baseline behavior
- Validates all components are working
- Sets latency expectations

### Baseline Test
- Most important for comparing before/after optimizations
- Realistic "normal" load
- Used to calculate system capacity

### Spike Test
- Demonstrates event-driven architecture benefit
- Shows Kafka absorbing traffic bursts
- Validates store-and-forward pattern

### File Upload Test
- Different workload (larger payloads)
- Tests MinIO integration
- Validates streaming upload

## Next Steps

1. ✅ Run warmup test to validate setup
2. ✅ Run baseline test and capture results
3. ✅ Open Grafana to see real-time metrics
4. ✅ Run spike test to observe consumer lag
5. ✅ Analyze results and document in technical report
6. ✅ Compare 1 vs 2 workers (scalability)
7. ✅ Capture screenshots for deliverables

**Good luck with your load testing!** 🚀
