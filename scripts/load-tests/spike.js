/**
 * k6 Load Test - Spike Test
 * 
 * Purpose: Validate system behavior under sudden traffic spikes
 * 
 * Profile:
 * - Duration: 2 minutes
 * - Spike Pattern: 0 → 1000 RPS in 1 minute → hold 30s → drop
 * - Request Type: POST /v1/messages
 * 
 * Success Criteria:
 * - System remains available during spike
 * - Error rate < 5% during spike
 * - Recovery time < 30s after spike
 * 
 * Usage:
 *   k6 run scripts/load-tests/spike.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '10s', target: 0 },     // Start at 0
    { duration: '50s', target: 1000 },  // Spike to 1000 RPS
    { duration: '30s', target: 1000 },  // Hold at 1000 RPS
    { duration: '30s', target: 0 },     // Drop back to 0
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500'],  // Allow higher latency during spike
    'errors': ['rate<0.05'],             // Error rate < 5%
  },
};

const BASE_URL = __ENV.API_URL || 'http://localhost:8080';

export default function () {
  const payload = JSON.stringify({
    sender_id: `spike_user_${__VU}`,
    recipient_id: `recipient_${Math.floor(Math.random() * 1000)}`,
    content: `Spike test message from VU ${__VU} iteration ${__ITER}`,
    timestamp: new Date().toISOString(),
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer spike-test-token',
    },
  };

  const res = http.post(`${BASE_URL}/v1/messages`, payload, params);
  
  errorRate.add(res.status !== 200);

  check(res, {
    'status is 200 or 429': (r) => r.status === 200 || r.status === 429,  // Accept rate limiting
    'response time < 1s': (r) => r.timings.duration < 1000,
  });

  sleep(0.1);  // Minimal think time for spike
}
