/**
 * Test Case 3: Spike Test - Absorção de Picos
 * 
 * OBJETIVO: Validar que Kafka absorve picos sem perda (Store-and-Forward)
 * CONFIGURAÇÃO: Ramp 5→50 VUs em 30s, manter 1 min, drop para 5
 * 
 * MÉTRICAS ESPERADAS:
 * - Sistema não retorna 5xx durante spike
 * - Consumer lag aumenta temporariamente mas se recupera
 * - P99 latency < 500ms durante pico
 * 
 * EDUCATIONAL NOTE:
 * Este teste demonstra o padrão Store-and-Forward:
 * - API aceita mensagens rapidamente (202 Accepted)
 * - Kafka armazena em buffer
 * - Workers processam assincronamente
 * - Consumer lag é temporário, não perda de dados
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';
import { getAuthHeaders, API_URL } from './common/auth.js';

// Custom metrics
const errorRate = new Rate('errors');
const messageLatency = new Trend('message_latency');
const serverErrors = new Rate('server_errors');

// Test configuration
export const options = {
    stages: [
        { duration: '30s', target: 5 },   // Warm up to 5 VUs
        { duration: '30s', target: 50 },  // Spike to 50 VUs
        { duration: '1m', target: 50 },   // Hold spike for 1 minute
        { duration: '30s', target: 5 },   // Ramp down to 5 VUs
        { duration: '1m', target: 5 },    // Recovery period
    ],
    thresholds: {
        'http_req_duration': ['p(99)<500'], // 99% of requests should be below 500ms
        'server_errors': ['rate<0.01'],     // 5xx errors should be below 1%
        'http_req_failed': ['rate<0.02'],   // Total failures should be below 2%
    },
};

// Setup
export function setup() {
    console.log('🔧 Setup: Authenticating test user...');
    const headers = getAuthHeaders('user_a', 'pass_a');
    console.log('✓ Authentication successful');
    console.log('');
    console.log('========================================');
    console.log('  Spike Test Starting');
    console.log('========================================');
    console.log('Configuration: 5→50→5 VUs');
    console.log('Objective: Validate store-and-forward');
    console.log('Watch Grafana: Consumer lag spike & recovery');
    console.log('========================================');
    console.log('');
    return { headers };
}

// Main test function
export default function(data) {
    const { headers } = data;
    
    // Prepare message payload
    const payload = JSON.stringify({
        conversation_id: `conv-spike-${__VU % 20}`, // 20 conversations
        sender_id: 'user_a',
        content: `Spike test: VU ${__VU}, iteration ${__ITER}`,
    });
    
    // Send message
    const startTime = Date.now();
    const response = http.post(`${API_URL}/v1/messages`, payload, { headers });
    const duration = Date.now() - startTime;
    
    // Record metrics
    messageLatency.add(duration);
    errorRate.add(response.status !== 202);
    serverErrors.add(response.status >= 500);
    
    // Validate response
    check(response, {
        'status is 202': (r) => r.status === 202,
        'not 5xx error': (r) => r.status < 500,
        'has message_id': (r) => {
            try {
                const body = JSON.parse(r.body);
                return body.message_id && body.message_id.length > 0;
            } catch {
                return false;
            }
        },
    });
    
    // Minimal sleep during spike (aggressive load)
    sleep(0.5 + Math.random() * 0.5);
}

// Teardown
export function teardown(data) {
    console.log('');
    console.log('========================================');
    console.log('  Spike Test Complete');
    console.log('========================================');
    console.log('VALIDATION CHECKLIST:');
    console.log('  [  ] No 5xx errors during spike');
    console.log('  [  ] Consumer lag increased during spike');
    console.log('  [  ] Consumer lag recovered after spike');
    console.log('  [  ] Zero message loss (check Cassandra)');
    console.log('');
    console.log('Check Grafana Dashboard: Component Health');
    console.log('  - Consumer Lag graph should show spike & recovery');
    console.log('========================================');
}
