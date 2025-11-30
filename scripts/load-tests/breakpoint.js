/**
 * k6 Load Test - Breakpoint Test
 * 
 * Purpose: Find the absolute maximum RPS the system can handle
 * 
 * Profile:
 * - Duration: Variable (until system breaks)
 * - Load Pattern: Aggressive ramp-up until failure
 * - Target: Find breaking point
 * 
 * Success Criteria:
 * - Identify maximum sustainable RPS
 * - Document failure mode (timeouts, errors, crashes)
 * - Measure recovery time
 * 
 * Usage:
 *   k6 run scripts/load-tests/breakpoint.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate } from 'k6/metrics';

const requestCount = new Counter('requests_total');
const errorCount = new Counter('errors_total');
const errorRate = new Rate('error_rate');

export const options = {
  stages: [
    { duration: '30s', target: 100 },
    { duration: '30s', target: 200 },
    { duration: '30s', target: 300 },
    { duration: '30s', target: 400 },
    { duration: '30s', target: 500 },
    { duration: '30s', target: 600 },
    { duration: '30s', target: 700 },
    { duration: '30s', target: 800 },
    { duration: '30s', target: 900 },
    { duration: '30s', target: 1000 },
    { duration: '30s', target: 1200 },
    { duration: '30s', target: 1500 },
    { duration: '30s', target: 2000 },
  ],
  thresholds: {
    // No thresholds - we want to see where it breaks
  },
};

const BASE_URL = __ENV.API_URL || 'http://localhost:8080';

export default function () {
  const payload = JSON.stringify({
    sender_id: `breakpoint_user_${__VU}`,
    recipient_id: `recipient_${Math.floor(Math.random() * 1000)}`,
    content: `Breakpoint test - Finding max RPS - VU ${__VU}`,
    timestamp: new Date().toISOString(),
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer breakpoint-test-token',
    },
    timeout: '10s',  // 10 second timeout
  };

  requestCount.add(1);
  
  const res = http.post(`${BASE_URL}/v1/messages`, payload, params);
  
  const success = res.status === 200;
  if (!success) {
    errorCount.add(1);
  }
  errorRate.add(!success);

  check(res, {
    'status is 200': (r) => r.status === 200,
  });

  // Minimal think time
  sleep(0.01);
}

export function handleSummary(data) {
  const totalRequests = data.metrics.requests_total.values.count;
  const totalErrors = data.metrics.errors_total.values.count;
  const errorPct = (totalErrors / totalRequests * 100).toFixed(2);
  const maxRPS = data.metrics.http_reqs.values.rate.toFixed(2);
  
  console.log('\n=== BREAKPOINT TEST RESULTS ===');
  console.log(`Total Requests: ${totalRequests}`);
  console.log(`Total Errors: ${totalErrors} (${errorPct}%)`);
  console.log(`Max Achieved RPS: ${maxRPS}`);
  console.log(`\nLatency at Peak:`);
  console.log(`  p50: ${data.metrics.http_req_duration.values['p(50)'].toFixed(2)}ms`);
  console.log(`  p95: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms`);
  console.log(`  p99: ${data.metrics.http_req_duration.values['p(99)'].toFixed(2)}ms`);
  console.log(`  max: ${data.metrics.http_req_duration.values.max.toFixed(2)}ms`);
  console.log(`\n⚠️  Recommendation: Set max RPS to ${(maxRPS * 0.7).toFixed(0)} (70% of peak)\n`);
  
  return {
    'breakpoint-summary.json': JSON.stringify(data, null, 2),
  };
}
