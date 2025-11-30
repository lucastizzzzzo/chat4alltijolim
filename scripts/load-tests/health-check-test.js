/**
 * Health Check Load Test
 * 
 * Simple test to validate infrastructure is handling load
 * Tests the /health endpoint which doesn't require authentication
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '30s', target: 50 },   // Ramp up to 50 VUs
    { duration: '1m', target: 50 },    // Stay at 50 VUs
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<100'], // 95% of requests must complete below 100ms
    'http_req_failed': ['rate<0.01'],   // Less than 1% errors
    'errors': ['rate<0.01'],            // Less than 1% errors
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
  // Test health endpoint
  const healthRes = http.get(`${BASE_URL}/health`);
  
  const healthCheck = check(healthRes, {
    'health status is 200': (r) => r.status === 200,
    'health response < 100ms': (r) => r.timings.duration < 100,
  });
  
  errorRate.add(!healthCheck);
  
  // Small sleep to simulate realistic usage
  sleep(0.1);
}

export function handleSummary(data) {
  const summary = {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
  };
  
  return summary;
}

function textSummary(data, options = {}) {
  const indent = options.indent || '';
  const enableColors = options.enableColors !== false;
  
  let summary = '\n';
  
  if (enableColors) {
    summary += '\x1b[36m'; // Cyan
  }
  
  summary += `${indent}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
  summary += `${indent}    HEALTH CHECK LOAD TEST - SUMMARY\n`;
  summary += `${indent}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
  
  if (enableColors) {
    summary += '\x1b[0m'; // Reset
  }
  
  // Metrics
  const metrics = data.metrics;
  
  // HTTP Requests
  if (metrics.http_reqs) {
    summary += `\n${indent}HTTP Requests:\n`;
    summary += `${indent}  Total: ${metrics.http_reqs.values.count}\n`;
    summary += `${indent}  Rate: ${(metrics.http_reqs.values.rate || 0).toFixed(2)}/s\n`;
  }
  
  // Request Duration
  if (metrics.http_req_duration) {
    const dur = metrics.http_req_duration.values;
    summary += `\n${indent}Response Time:\n`;
    summary += `${indent}  Avg: ${(dur.avg || 0).toFixed(2)}ms\n`;
    summary += `${indent}  Min: ${(dur.min || 0).toFixed(2)}ms\n`;
    summary += `${indent}  Max: ${(dur.max || 0).toFixed(2)}ms\n`;
    summary += `${indent}  p50: ${(dur['p(50)'] || 0).toFixed(2)}ms\n`;
    summary += `${indent}  p90: ${(dur['p(90)'] || 0).toFixed(2)}ms\n`;
    summary += `${indent}  p95: ${(dur['p(95)'] || 0).toFixed(2)}ms\n`;
    summary += `${indent}  p99: ${(dur['p(99)'] || 0).toFixed(2)}ms\n`;
  }
  
  // Failures
  if (metrics.http_req_failed) {
    const failed = metrics.http_req_failed.values;
    const failRate = ((failed.rate || 0) * 100).toFixed(2);
    summary += `\n${indent}Failures:\n`;
    summary += `${indent}  Rate: ${failRate}%\n`;
    summary += `${indent}  Total: ${failed.passes || 0}/${metrics.http_reqs.values.count}\n`;
  }
  
  // Checks
  if (metrics.checks) {
    const checks = metrics.checks.values;
    const passRate = ((checks.rate || 0) * 100).toFixed(2);
    summary += `\n${indent}Checks:\n`;
    summary += `${indent}  Pass Rate: ${passRate}%\n`;
    summary += `${indent}  Passed: ${checks.passes || 0}/${checks.passes + checks.fails || 0}\n`;
  }
  
  // VUs
  if (metrics.vus) {
    summary += `\n${indent}Virtual Users:\n`;
    summary += `${indent}  Min: ${metrics.vus.values.min || 0}\n`;
    summary += `${indent}  Max: ${metrics.vus.values.max || 0}\n`;
  }
  
  // Data transferred
  if (metrics.data_received && metrics.data_sent) {
    const received = (metrics.data_received.values.count / 1024).toFixed(2);
    const sent = (metrics.data_sent.values.count / 1024).toFixed(2);
    summary += `\n${indent}Data Transfer:\n`;
    summary += `${indent}  Received: ${received} KB\n`;
    summary += `${indent}  Sent: ${sent} KB\n`;
  }
  
  summary += `\n${indent}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
  
  // Threshold results
  if (data.thresholds) {
    summary += `\n${indent}Threshold Results:\n`;
    for (const [name, result] of Object.entries(data.thresholds)) {
      const status = result.ok ? '✓' : '✗';
      const color = result.ok ? (enableColors ? '\x1b[32m' : '') : (enableColors ? '\x1b[31m' : '');
      const reset = enableColors ? '\x1b[0m' : '';
      summary += `${indent}  ${color}${status}${reset} ${name}\n`;
    }
  }
  
  summary += '\n';
  return summary;
}
