/**
 * k6 Load Test - Baseline Performance
 * 
 * Purpose: Establish baseline performance metrics under normal load
 * 
 * Profile:
 * - Duration: 5 minutes
 * - Target RPS: 100 requests/second
 * - Request Type: POST /v1/messages (text messages)
 * 
 * Success Criteria:
 * - p95 latency < 200ms
 * - Error rate < 1%
 * - Consumer lag < 1000
 * 
 * Usage:
 *   k6 run --out json=baseline-results.json scripts/load-tests/baseline.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const messageLatency = new Trend('message_latency');

// Test configuration
export const options = {
  stages: [
    { duration: '30s', target: 100 },  // Ramp-up to 100 RPS
    { duration: '4m', target: 100 },   // Stay at 100 RPS
    { duration: '30s', target: 0 },    // Ramp-down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<200'],  // 95% of requests must complete within 200ms
    'errors': ['rate<0.01'],             // Error rate must be below 1%
    'http_req_failed': ['rate<0.01'],    // Failed requests must be below 1%
  },
};

// Base URL (configurable via environment variable)
const BASE_URL = __ENV.API_URL || 'http://localhost:8080';

// Sample message content
const messages = [
  'Hello, how are you?',
  'This is a test message',
  'Baseline load testing in progress',
  'Chat4All system validation',
  'Metrics collection active',
];

export default function () {
  // Generate random message
  const messageContent = messages[Math.floor(Math.random() * messages.length)];
  
  // Create request payload
  const payload = JSON.stringify({
    sender_id: `user_${__VU}_${__ITER}`,
    recipient_id: `recipient_${Math.floor(Math.random() * 100)}`,
    content: messageContent,
    timestamp: new Date().toISOString(),
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer test-token-baseline',
    },
  };

  // Send request
  const startTime = new Date();
  const res = http.post(`${BASE_URL}/v1/messages`, payload, params);
  const duration = new Date() - startTime;

  // Record metrics
  messageLatency.add(duration);
  errorRate.add(res.status !== 200);

  // Validate response
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200,
    'has message_id': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.message_id !== undefined;
      } catch (e) {
        return false;
      }
    },
  });

  // Think time (1 second between requests per VU)
  sleep(1);
}

export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'baseline-summary.json': JSON.stringify(data, null, 2),
  };
}

// Helper function for summary
function textSummary(data, options) {
  const indent = options.indent || '';
  const colors = options.enableColors || false;
  
  let summary = '\n\n';
  summary += indent + '='.repeat(60) + '\n';
  summary += indent + 'BASELINE TEST SUMMARY\n';
  summary += indent + '='.repeat(60) + '\n\n';
  
  summary += indent + `Total Requests: ${data.metrics.http_reqs.values.count}\n`;
  summary += indent + `Request Rate: ${data.metrics.http_reqs.values.rate.toFixed(2)} req/s\n`;
  summary += indent + `Failed Requests: ${data.metrics.http_req_failed.values.rate.toFixed(4) * 100}%\n\n`;
  
  summary += indent + 'Latency:\n';
  summary += indent + `  p50: ${data.metrics.http_req_duration.values['p(50)'].toFixed(2)}ms\n`;
  summary += indent + `  p95: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms\n`;
  summary += indent + `  p99: ${data.metrics.http_req_duration.values['p(99)'].toFixed(2)}ms\n`;
  summary += indent + `  max: ${data.metrics.http_req_duration.values.max.toFixed(2)}ms\n\n`;
  
  summary += indent + '='.repeat(60) + '\n\n';
  
  return summary;
}
