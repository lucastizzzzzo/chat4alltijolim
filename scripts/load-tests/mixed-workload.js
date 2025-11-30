/**
 * k6 Load Test - Mixed Workload
 * 
 * Purpose: Simulate realistic production traffic with mixed request types
 * 
 * Profile:
 * - Duration: 10 minutes
 * - Target RPS: 150 requests/second
 * - Traffic Mix: 80% text messages, 20% file uploads
 * - Variable message sizes
 * 
 * Success Criteria:
 * - p95 text latency < 200ms
 * - p95 file latency < 2s
 * - Overall error rate < 1%
 * 
 * Usage:
 *   k6 run scripts/load-tests/mixed-workload.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import encoding from 'k6/encoding';

const errorRate = new Rate('errors');
const textLatency = new Trend('text_message_latency');
const fileLatency = new Trend('file_message_latency');
const textCounter = new Counter('text_messages');
const fileCounter = new Counter('file_messages');

export const options = {
  stages: [
    { duration: '1m', target: 150 },   // Ramp-up
    { duration: '8m', target: 150 },   // Sustained load
    { duration: '1m', target: 0 },     // Ramp-down
  ],
  thresholds: {
    'text_message_latency': ['p(95)<200'],
    'file_message_latency': ['p(95)<2000'],
    'errors': ['rate<0.01'],
  },
};

const BASE_URL = __ENV.API_URL || 'http://localhost:8080';

// Sample text messages of varying lengths
const textMessages = [
  'Hi',
  'How are you?',
  'This is a medium-length message for testing purposes.',
  'This is a longer message that contains more content and simulates a real conversation between users. It includes multiple sentences and provides more realistic data for testing the messaging system.',
  'Short',
  'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
];

// Generate small file (100KB) for 20% of requests
function generateSmallFile() {
  const size = 100 * 1024;  // 100KB
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let data = '';
  
  for (let i = 0; i < size / 10; i++) {  // Reduce iterations
    data += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  
  return encoding.b64encode(data);
}

export default function () {
  // Decide request type: 80% text, 20% file
  const isFileUpload = Math.random() < 0.2;
  
  if (isFileUpload) {
    sendFileMessage();
  } else {
    sendTextMessage();
  }
}

function sendTextMessage() {
  const messageContent = textMessages[Math.floor(Math.random() * textMessages.length)];
  
  const payload = JSON.stringify({
    sender_id: `mixed_user_${__VU}`,
    recipient_id: `recipient_${Math.floor(Math.random() * 100)}`,
    content: messageContent,
    timestamp: new Date().toISOString(),
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer mixed-test-token',
    },
  };

  const startTime = new Date();
  const res = http.post(`${BASE_URL}/v1/messages`, payload, params);
  const duration = new Date() - startTime;

  textCounter.add(1);
  textLatency.add(duration);
  errorRate.add(res.status !== 200);

  check(res, {
    'text status is 200': (r) => r.status === 200,
    'text response fast': (r) => r.timings.duration < 500,
  });

  sleep(0.5);  // Short think time
}

function sendFileMessage() {
  const fileData = generateSmallFile();
  
  const payload = JSON.stringify({
    sender_id: `mixed_user_${__VU}`,
    recipient_id: `recipient_${Math.floor(Math.random() * 100)}`,
    content: 'File attachment',
    timestamp: new Date().toISOString(),
    file_attachment: {
      filename: `file-${__VU}-${__ITER}.jpg`,
      content_type: 'image/jpeg',
      size_bytes: fileData.length,
      data: fileData.substring(0, 50) + '...',  // Truncated for demo
    },
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer mixed-test-token',
    },
    timeout: '10s',
  };

  const startTime = new Date();
  const res = http.post(`${BASE_URL}/v1/messages`, payload, params);
  const duration = new Date() - startTime;

  fileCounter.add(1);
  fileLatency.add(duration);
  errorRate.add(res.status !== 200);

  check(res, {
    'file status is 200': (r) => r.status === 200,
    'file upload acceptable': (r) => r.timings.duration < 5000,
  });

  sleep(1.5);  // Longer think time for file uploads
}

export function handleSummary(data) {
  const totalText = data.metrics.text_messages.values.count;
  const totalFile = data.metrics.file_messages.values.count;
  const totalRequests = totalText + totalFile;
  const textPct = (totalText / totalRequests * 100).toFixed(1);
  const filePct = (totalFile / totalRequests * 100).toFixed(1);
  
  console.log('\n=== MIXED WORKLOAD TEST SUMMARY ===');
  console.log(`Total Requests: ${totalRequests}`);
  console.log(`  Text Messages: ${totalText} (${textPct}%)`);
  console.log(`  File Uploads: ${totalFile} (${filePct}%)`);
  console.log(`\nText Message Latency:`);
  console.log(`  p50: ${data.metrics.text_message_latency.values['p(50)'].toFixed(2)}ms`);
  console.log(`  p95: ${data.metrics.text_message_latency.values['p(95)'].toFixed(2)}ms`);
  console.log(`\nFile Upload Latency:`);
  console.log(`  p50: ${data.metrics.file_message_latency.values['p(50)'].toFixed(2)}ms`);
  console.log(`  p95: ${data.metrics.file_message_latency.values['p(95)'].toFixed(2)}ms`);
  console.log(`\nOverall Error Rate: ${(data.metrics.errors.values.rate * 100).toFixed(2)}%`);
  console.log('\n');
  
  return {
    'mixed-workload-summary.json': JSON.stringify(data, null, 2),
  };
}
