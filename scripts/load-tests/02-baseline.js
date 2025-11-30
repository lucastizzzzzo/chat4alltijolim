/**
 * Test Case 2: Baseline Normal - Carga Sustentada
 * 
 * OBJETIVO: Medir throughput e latência em uso "normal"
 * CONFIGURAÇÃO: 20 VUs, 5 minutos, ~500 req/min
 * 
 * MÉTRICAS ESPERADAS:
 * - Throughput: 500-600 mensagens/minuto (8-10 msg/s)
 * - P95 latency < 200ms
 * - Error rate < 0.5%
 * 
 * EDUCATIONAL NOTE:
 * Este é o teste MAIS IMPORTANTE da Entrega 3.
 * Estabelece a capacidade real do sistema em condições normais de operação.
 * Use este teste para comparar antes/depois de otimizações.
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import { getAuthHeaders, API_URL } from './common/auth.js';

// Custom metrics
const errorRate = new Rate('errors');
const messageLatency = new Trend('message_latency');
const messagesAccepted = new Counter('messages_accepted');
const messagesRejected = new Counter('messages_rejected');

// Test configuration
export const options = {
    vus: 20,
    duration: '5m',
    thresholds: {
        'http_req_duration': ['p(95)<200'], // 95% of requests should be below 200ms
        'http_req_duration': ['p(99)<500'], // 99% of requests should be below 500ms
        'errors': ['rate<0.005'],            // Error rate should be below 0.5%
        'http_req_failed': ['rate<0.005'],   // Failed requests should be below 0.5%
    },
};

// Setup: authenticate
export function setup() {
    console.log('🔧 Setup: Authenticating test user...');
    const headers = getAuthHeaders('user_a', 'pass_a');
    console.log('✓ Authentication successful');
    console.log('');
    console.log('========================================');
    console.log('  Baseline Test Starting');
    console.log('========================================');
    console.log('Configuration: 20 VUs, 5 minutes');
    console.log('Target: ~500 msg/min (8-10 msg/s)');
    console.log('P95 latency target: < 200ms');
    console.log('========================================');
    console.log('');
    return { headers };
}

// Main test function
export default function(data) {
    const { headers } = data;
    
    // Prepare message payload
    const payload = JSON.stringify({
        conversation_id: `conv-baseline-${__VU % 10}`, // Distribute across 10 conversations
        sender_id: 'user_a',
        content: `Baseline test message from VU ${__VU}, iteration ${__ITER}`,
    });
    
    // Send message
    const startTime = Date.now();
    const response = http.post(`${API_URL}/v1/messages`, payload, { headers });
    const duration = Date.now() - startTime;
    
    // Record metrics
    messageLatency.add(duration);
    
    // Check response
    const isSuccess = response.status === 202;
    errorRate.add(!isSuccess);
    
    if (isSuccess) {
        messagesAccepted.add(1);
    } else {
        messagesRejected.add(1);
    }
    
    // Validate response
    check(response, {
        'status is 202': (r) => r.status === 202,
        'has message_id': (r) => {
            try {
                const body = JSON.parse(r.body);
                return body.message_id && body.message_id.length > 0;
            } catch {
                return false;
            }
        },
        'response time < 300ms': (r) => duration < 300,
    });
    
    // Sleep 1-2 seconds between requests
    // 20 VUs * ~1.5s sleep = ~13 req/s = ~780 req/min ≈ 500-800 msg/min
    sleep(1 + Math.random());
}

// Teardown: print summary
export function teardown(data) {
    console.log('');
    console.log('========================================');
    console.log('  Baseline Test Complete');
    console.log('========================================');
    console.log('EXPECTED:');
    console.log('  Throughput: 500-600 msg/min');
    console.log('  P95 latency: < 200ms');
    console.log('  Error rate: < 0.5%');
    console.log('');
    console.log('NEXT STEPS:');
    console.log('  1. Check Grafana dashboards');
    console.log('  2. Compare with targets');
    console.log('  3. Export results: k6 run --out json=results/baseline.json 02-baseline.js');
    console.log('========================================');
}
