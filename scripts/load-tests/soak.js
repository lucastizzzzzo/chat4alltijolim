/**
 * k6 Load Test - Soak Test (Endurance Test)
 * 
 * Purpose: Validate system stability under sustained load over time
 * Detects memory leaks, resource exhaustion, connection pool issues
 * 
 * Profile:
 * - Duration: 30 minutes
 * - Target RPS: 200 requests/second (steady)
 * - Request Type: POST /v1/messages
 * 
 * Success Criteria:
 * - No performance degradation over time
 * - Stable memory usage (check via Grafana)
 * - No connection leaks
 * - Error rate remains < 1%
 * 
 * Usage:
 *   k6 run scripts/load-tests/soak.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('errors');
const latencyTrend = new Trend('latency_ms');

export const options = {
  stages: [
    { duration: '2m', target: 200 },   // Ramp-up to 200 RPS
    { duration: '26m', target: 200 },  // Stay at 200 RPS for 26 minutes
    { duration: '2m', target: 0 },     // Ramp-down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<200', 'p(99)<500'],  // Latency must stay stable
    'errors': ['rate<0.01'],                          // Error rate < 1%
    'http_req_failed': ['rate<0.01'],                 // Failed requests < 1%
  },
};

const BASE_URL = __ENV.API_URL || 'http://localhost:8080';

const messages = [
  'Soak test message - endurance testing',
  'Long-running load validation',
  'Memory leak detection in progress',
  'Connection pool stability check',
  'Sustained load - 30 minutes',
];

export default function () {
  const messageContent = messages[Math.floor(Math.random() * messages.length)];
  
  const payload = JSON.stringify({
    sender_id: `soak_user_${__VU}`,
    recipient_id: `recipient_${Math.floor(Math.random() * 200)}`,
    content: `${messageContent} - VU ${__VU} - Iter ${__ITER}`,
    timestamp: new Date().toISOString(),
    metadata: {
      test_type: 'soak',
      duration_minutes: 30,
      target_rps: 200,
    },
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer soak-test-token',
    },
  };

  const startTime = new Date();
  const res = http.post(`${BASE_URL}/v1/messages`, payload, params);
  const duration = new Date() - startTime;

  latencyTrend.add(duration);
  errorRate.add(res.status !== 200);

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time stable': (r) => r.timings.duration < 500,  // No degradation
    'valid response': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.message_id !== undefined;
      } catch (e) {
        return false;
      }
    },
  });

  // Steady think time
  sleep(1);
}

export function handleSummary(data) {
  console.log('\n=== SOAK TEST STABILITY ANALYSIS ===');
  console.log(`Total Duration: ${data.state.testRunDurationMs / 1000 / 60} minutes`);
  console.log(`Requests: ${data.metrics.http_reqs.values.count}`);
  console.log(`Avg RPS: ${data.metrics.http_reqs.values.rate.toFixed(2)}`);
  console.log(`Error Rate: ${(data.metrics.http_req_failed.values.rate * 100).toFixed(4)}%`);
  console.log(`\nLatency Percentiles:`);
  console.log(`  p50: ${data.metrics.http_req_duration.values['p(50)'].toFixed(2)}ms`);
  console.log(`  p95: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms`);
  console.log(`  p99: ${data.metrics.http_req_duration.values['p(99)'].toFixed(2)}ms`);
  console.log(`\n⚠️  Check Grafana for memory/CPU trends over time\n`);
  
  return {
    'soak-summary.json': JSON.stringify(data, null, 2),
  };
}
