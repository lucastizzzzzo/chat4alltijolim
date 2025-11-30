/**
 * Test Case 1: Warmup - Carga Mínima
 * 
 * OBJETIVO: Validar que o sistema funciona sem erros sob carga controlada
 * CONFIGURAÇÃO: 5 VUs, 2 minutos, ~50 req/min
 * 
 * MÉTRICAS ESPERADAS:
 * - Throughput: ~50 mensagens/minuto (baseline)
 * - P95 latency < 100ms (sem contenção)
 * - Error rate = 0% (sistema estável)
 * 
 * EDUCATIONAL NOTE:
 * Este teste estabelece o comportamento baseline do sistema.
 * Não é sobre carga, é sobre validar que tudo funciona corretamente.
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';
import { getAuthHeaders, API_URL } from './common/auth.js';

// Custom metrics
const errorRate = new Rate('errors');
const messageLatency = new Trend('message_latency');

// Test configuration
export const options = {
    vus: 5,
    duration: '2m',
    thresholds: {
        'http_req_duration': ['p(95)<100'], // 95% of requests should be below 100ms
        'errors': ['rate<0.01'],             // Error rate should be below 1%
        'http_req_failed': ['rate<0.01'],    // Failed requests should be below 1%
    },
};

// Setup: authenticate once per VU
export function setup() {
    console.log('🔧 Setup: Authenticating test user...');
    const headers = getAuthHeaders('user_a', 'pass_a');
    console.log('✓ Authentication successful');
    return { headers };
}

// Main test function (executed by each VU)
export default function(data) {
    const { headers } = data;
    
    // Prepare message payload (system generates message_id automatically)
    const payload = JSON.stringify({
        conversation_id: `conv-warmup-${__VU}`,
        sender_id: 'user_a',
        content: `Warmup test message from VU ${__VU}`,
    });
    
    // Send message
    const startTime = Date.now();
    const response = http.post(`${API_URL}/v1/messages`, payload, { headers });
    const duration = Date.now() - startTime;
    
    // Record metrics
    messageLatency.add(duration);
    errorRate.add(response.status !== 202);
    
    // Validate response
    const success = check(response, {
        'status is 202': (r) => r.status === 202,
        'has message_id': (r) => {
            try {
                const body = JSON.parse(r.body);
                return body.message_id && body.message_id.length > 0;
            } catch {
                return false;
            }
        },
        'response time < 200ms': (r) => duration < 200,
    });
    
    if (!success) {
        console.error(`❌ Request failed: ${response.status} ${response.body}`);
    }
    
    // Sleep 2-3 seconds between requests (simulates human behavior)
    // 5 VUs * ~2.5s sleep = ~2 req/s = ~120 req/min ≈ 50-100 msg/min
    sleep(2 + Math.random());
}

// Teardown: print summary
export function teardown(data) {
    console.log('');
    console.log('========================================');
    console.log('  Warmup Test Complete');
    console.log('========================================');
    console.log('Expected: ~50 msg/min, P95 < 100ms, 0% errors');
    console.log('Review detailed metrics above');
    console.log('========================================');
}
