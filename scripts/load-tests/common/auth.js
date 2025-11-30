/**
 * Common authentication utilities for k6 load tests
 * 
 * PURPOSE: Centralize JWT token generation for all test scenarios
 * USAGE: import { getAuthToken } from './common/auth.js';
 */

import http from 'k6/http';

const API_BASE_URL = __ENV.API_BASE_URL || 'http://localhost:8080';

/**
 * Get JWT authentication token
 * 
 * @param {string} username - Username for authentication
 * @param {string} password - Password for authentication
 * @returns {string} JWT token
 */
export function getAuthToken(username = 'user_a', password = 'pass_a') {
    const authResponse = http.post(
        `${API_BASE_URL}/auth/token`,
        JSON.stringify({ username, password }),
        {
            headers: { 'Content-Type': 'application/json' },
        }
    );
    
    if (authResponse.status !== 200) {
        throw new Error(`Authentication failed: ${authResponse.status} ${authResponse.body}`);
    }
    
    const authData = JSON.parse(authResponse.body);
    return authData.access_token;
}

/**
 * Get authorization header with JWT token
 * 
 * @param {string} username - Username for authentication
 * @param {string} password - Password for authentication
 * @returns {object} Headers object with Authorization
 */
export function getAuthHeaders(username = 'user_a', password = 'pass_a') {
    const token = getAuthToken(username, password);
    return {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
    };
}

export const API_URL = API_BASE_URL;
