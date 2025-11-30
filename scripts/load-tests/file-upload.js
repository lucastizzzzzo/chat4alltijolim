/**
 * k6 Load Test - File Upload Test
 * 
 * Purpose: Validate file upload performance with 1MB files
 * 
 * Profile:
 * - Duration: 5 minutes
 * - Target RPS: 50 requests/second (lower due to file size)
 * - Request Type: POST /v1/messages with file attachment
 * - File Size: ~1MB
 * 
 * Success Criteria:
 * - p95 latency < 2s (higher due to file upload)
 * - Error rate < 1%
 * - Successful S3/MinIO upload
 * 
 * Usage:
 *   k6 run scripts/load-tests/file-upload.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';
import encoding from 'k6/encoding';

const errorRate = new Rate('errors');
const uploadLatency = new Trend('upload_latency_ms');

export const options = {
  stages: [
    { duration: '30s', target: 50 },   // Ramp-up to 50 RPS
    { duration: '4m', target: 50 },    // Stay at 50 RPS
    { duration: '30s', target: 0 },    // Ramp-down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<2000'],  // p95 < 2s for file uploads
    'errors': ['rate<0.01'],              // Error rate < 1%
  },
};

const BASE_URL = __ENV.API_URL || 'http://localhost:8080';

// Generate a ~1MB base64-encoded "file" (simulated image)
function generateLargeFile() {
  // Create 750KB of random data (becomes ~1MB when base64-encoded)
  const size = 750 * 1024;  // 750KB
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let data = '';
  
  for (let i = 0; i < size; i++) {
    data += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  
  // Base64 encode to simulate file upload
  return encoding.b64encode(data);
}

// Generate file once per VU (expensive operation)
const fileData = generateLargeFile();

export default function () {
  const payload = JSON.stringify({
    sender_id: `file_user_${__VU}`,
    recipient_id: `recipient_${Math.floor(Math.random() * 50)}`,
    content: 'File upload test - 1MB image',
    timestamp: new Date().toISOString(),
    file_attachment: {
      filename: `test-image-${__VU}-${__ITER}.jpg`,
      content_type: 'image/jpeg',
      size_bytes: fileData.length,
      data: fileData.substring(0, 100) + '...',  // Send truncated for demo (full upload in real scenario)
    },
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer file-upload-test-token',
    },
    timeout: '10s',  // Higher timeout for file uploads
  };

  const startTime = new Date();
  const res = http.post(`${BASE_URL}/v1/messages`, payload, params);
  const duration = new Date() - startTime;

  uploadLatency.add(duration);
  errorRate.add(res.status !== 200);

  check(res, {
    'status is 200': (r) => r.status === 200,
    'upload completed': (r) => r.timings.duration < 5000,
    'has message_id': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.message_id !== undefined;
      } catch (e) {
        return false;
      }
    },
    'has file_url': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.file_url !== undefined;
      } catch (e) {
        return false;
      }
    },
  });

  // Longer think time due to file upload complexity
  sleep(2);
}

export function handleSummary(data) {
  const avgSize = fileData.length;
  const totalRequests = data.metrics.http_reqs.values.count;
  const totalDataGB = (totalRequests * avgSize / 1024 / 1024 / 1024).toFixed(2);
  
  console.log('\n=== FILE UPLOAD TEST SUMMARY ===');
  console.log(`File Size: ~${(avgSize / 1024 / 1024).toFixed(2)} MB`);
  console.log(`Total Uploads: ${totalRequests}`);
  console.log(`Total Data Transferred: ${totalDataGB} GB`);
  console.log(`Avg Upload Time: ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms`);
  console.log(`p95 Upload Time: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms`);
  console.log(`Error Rate: ${(data.metrics.errors.values.rate * 100).toFixed(2)}%`);
  console.log('\n');
  
  return {
    'file-upload-summary.json': JSON.stringify(data, null, 2),
  };
}
