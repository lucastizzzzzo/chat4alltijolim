/**
 * k6 Load Test - Stress Test
 * 
 * Purpose: Find system breaking point by gradually increasing load
 * 
 * Profile:
 * - Duration: 10 minutes
 * - Load Pattern: Gradual increase from 0 to 500 RPS
 * - Request Type: POST /v1/messages
 * 
 * Success Criteria:
 * - Identify maximum sustainable RPS
 * - Observe degradation points (latency, errors)
 * - Validate graceful degradation
 * 
 * Usage:
 *   k6 run scripts/load-tests/stress.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const requestCount = new Counter('custom_requests');
const errorRate = new Rate('errors');
const latencyTrend = new Trend('latency_ms');

export const options = {
  stages: [
    { duration: '1m', target: 50 },    // Ramp to 50 RPS
    { duration: '1m', target: 100 },   // Ramp to 100 RPS
    { duration: '1m', target: 150 },   // Ramp to 150 RPS
    { duration: '1m', target: 200 },   // Ramp to 200 RPS
    { duration: '1m', target: 250 },   // Ramp to 250 RPS
    { duration: '1m', target: 300 },   // Ramp to 300 RPS
    { duration: '1m', target: 350 },   // Ramp to 350 RPS
    { duration: '1m', target: 400 },   // Ramp to 400 RPS
    { duration: '1m', target: 450 },   // Ramp to 450 RPS
    { duration: '1m', target: 500 },   // Ramp to 500 RPS
  ],
  thresholds: {
    'http_req_duration': ['p(99)<1000'],  // p99 < 1s
    'errors': ['rate<0.1'],               // Error rate < 10%
  },
};

const BASE_URL = __ENV.API_URL || 'http://localhost:8080';

export default function () {
  const payload = JSON.stringify({
    sender_id: `stress_user_${__VU}`,
    recipient_id: `recipient_${Math.floor(Math.random() * 500)}`,
    content: `Stress test - stage ${getCurrentStage()} - VU ${__VU}`,
    timestamp: new Date().toISOString(),
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer stress-test-token',
    },
  };

  const startTime = new Date();
  const res = http.post(`${BASE_URL}/v1/messages`, payload, params);
  const duration = new Date() - startTime;

  requestCount.add(1);
  latencyTrend.add(duration);
  errorRate.add(res.status !== 200);

  check(res, {
    'status is 200': (r) => r.status === 200,
    'latency acceptable': (r) => r.timings.duration < 1000,
  });

  sleep(0.5);
}

// Helper to determine current load stage
function getCurrentStage() {
  const elapsed = __ITER * 0.5;  // Approximate elapsed time
  if (elapsed < 60) return '50 RPS';
  if (elapsed < 120) return '100 RPS';
  if (elapsed < 180) return '150 RPS';
  if (elapsed < 240) return '200 RPS';
  if (elapsed < 300) return '250 RPS';
  if (elapsed < 360) return '300 RPS';
  if (elapsed < 420) return '350 RPS';
  if (elapsed < 480) return '400 RPS';
  if (elapsed < 540) return '450 RPS';
  return '500 RPS';
}
