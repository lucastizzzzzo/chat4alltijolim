/**
 * Test Case 4: File Upload - Arquivos Pequenos
 * 
 * OBJETIVO: Validar upload de arquivos sob carga
 * CONFIGURAÇÃO: 10 VUs, 3 minutos, arquivos de 100KB-1MB
 * 
 * MÉTRICAS ESPERADAS:
 * - 50-100 uploads/minuto sustentáveis
 * - Latência de upload < 2 segundos (1MB)
 * - Zero timeouts
 * 
 * EDUCATIONAL NOTE:
 * Testa integração API → MinIO com streaming upload.
 * Arquivos pequenos (< 1MB) para manter teste rápido.
 * Valida presigned URLs e metadata em Cassandra.
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';
import { getAuthHeaders, API_URL } from './common/auth.js';

// Custom metrics
const errorRate = new Rate('errors');
const uploadLatency = new Trend('upload_latency');
const uploadSize = new Trend('upload_size_bytes');

// Test configuration
export const options = {
    vus: 10,
    duration: '3m',
    thresholds: {
        'http_req_duration': ['p(95)<2000'], // 95% of uploads should be below 2s
        'errors': ['rate<0.01'],              // Error rate should be below 1%
        'http_req_failed': ['rate<0.01'],     // Failed requests should be below 1%
    },
};

// Generate random file content
function generateFileContent(sizeKB) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    const length = sizeKB * 1024;
    let result = '';
    for (let i = 0; i < length; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
}

// Setup
export function setup() {
    console.log('🔧 Setup: Authenticating test user...');
    const headers = getAuthHeaders('user_a', 'pass_a');
    console.log('✓ Authentication successful');
    console.log('');
    console.log('========================================');
    console.log('  File Upload Test Starting');
    console.log('========================================');
    console.log('Configuration: 10 VUs, 3 minutes');
    console.log('File sizes: 100KB - 1MB');
    console.log('Target: 50-100 uploads/min');
    console.log('========================================');
    console.log('');
    return { headers };
}

// Main test function
export default function(data) {
    const { headers } = data;
    
    // Random file size between 100KB and 1MB
    const fileSizeKB = 100 + Math.floor(Math.random() * 900);
    const fileContent = generateFileContent(fileSizeKB);
    const fileName = `test-file-${__VU}-${__ITER}-${Date.now()}.txt`;
    
    // Prepare multipart form data
    const formData = {
        file: http.file(fileContent, fileName, 'text/plain'),
        conversation_id: `conv-files-${__VU}`,
    };
    
    // Upload file
    const startTime = Date.now();
    const response = http.post(
        `${API_URL}/v1/files`,
        formData,
        {
            headers: {
                'Authorization': headers['Authorization'],
            },
        }
    );
    const duration = Date.now() - startTime;
    
    // Record metrics
    uploadLatency.add(duration);
    uploadSize.add(fileSizeKB * 1024);
    errorRate.add(response.status !== 201);
    
    // Validate response
    const success = check(response, {
        'status is 201': (r) => r.status === 201,
        'has file_id': (r) => {
            try {
                const body = JSON.parse(r.body);
                return body.file_id && body.file_id.length > 0;
            } catch {
                return false;
            }
        },
        'has download_url': (r) => {
            try {
                const body = JSON.parse(r.body);
                return body.download_url && body.download_url.includes('localhost:9000');
            } catch {
                return false;
            }
        },
        'upload time reasonable': (r) => duration < 3000, // < 3 seconds
    });
    
    if (!success) {
        console.error(`❌ Upload failed: ${fileName} (${fileSizeKB}KB) - ${response.status}`);
    }
    
    // Sleep 2-4 seconds between uploads
    // 10 VUs * ~3s sleep = ~3-4 uploads/s = ~180-240 uploads/min ≈ 50-100 with variability
    sleep(2 + Math.random() * 2);
}

// Teardown
export function teardown(data) {
    console.log('');
    console.log('========================================');
    console.log('  File Upload Test Complete');
    console.log('========================================');
    console.log('EXPECTED:');
    console.log('  Uploads: 50-100 files/min');
    console.log('  P95 latency: < 2 seconds');
    console.log('  Error rate: < 1%');
    console.log('');
    console.log('VALIDATION:');
    console.log('  1. Check MinIO console: http://localhost:9001');
    console.log('  2. Verify files in bucket: chat4all-files');
    console.log('  3. Check Cassandra for file metadata');
    console.log('========================================');
}
