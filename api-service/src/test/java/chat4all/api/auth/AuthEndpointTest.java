package chat4all.api.auth;

import chat4all.api.http.AuthHandler;
import com.datastax.oss.driver.api.core.CqlSession;
import com.datastax.oss.driver.api.core.cql.PreparedStatement;
import com.datastax.oss.driver.api.core.cql.ResultSet;
import com.datastax.oss.driver.api.core.cql.BoundStatement;
import com.sun.net.httpserver.HttpExchange;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.mockito.Mockito;
import static org.assertj.core.api.Assertions.*;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URI;

/**
 * AuthEndpointTest - Integration Tests for POST /auth/token
 * 
 * EDUCATIONAL PURPOSE: Test-First Development (TDD)
 * ==================
 * Tests authentication endpoint BEFORE implementing AuthHandler.java
 * 
 * ENDPOINT SPECIFICATION:
 * - URL: POST /auth/token
 * - Request: {"username":"user_a","password":"pass_a"}
 * - Response 200: {"access_token":"eyJ...","token_type":"Bearer","expires_in":3600}
 * - Response 401: {"error":"Unauthorized","message":"Invalid credentials"}
 * 
 * HARDCODED TEST USERS (Phase 1 simplification):
 * - user_a / pass_a
 * - user_b / pass_b
 * 
 * @author Chat4All Educational Project
 */
public class AuthEndpointTest {
    
    private AuthHandler authHandler;
    private static final String TEST_SECRET = "test-secret-key-for-junit";
    
    @BeforeEach
    public void setUp() {
        TokenGenerator tokenGenerator = new TokenGenerator(TEST_SECRET);
        
        // Mock CqlSession for testing (AuthHandler will use fallback hardcoded users when DB query fails)
        CqlSession mockSession = Mockito.mock(CqlSession.class);
        PreparedStatement mockPreparedStatement = Mockito.mock(PreparedStatement.class);
        BoundStatement mockBoundStatement = Mockito.mock(BoundStatement.class);
        ResultSet mockResultSet = Mockito.mock(ResultSet.class);
        
        // Setup mock to return empty results (so AuthHandler uses fallback hardcoded users)
        Mockito.when(mockSession.prepare(Mockito.anyString())).thenReturn(mockPreparedStatement);
        Mockito.when(mockPreparedStatement.bind(Mockito.any())).thenReturn(mockBoundStatement);
        Mockito.when(mockSession.execute(Mockito.any(BoundStatement.class))).thenReturn(mockResultSet);
        Mockito.when(mockResultSet.one()).thenReturn(null); // No user found in DB, use fallback
        
        authHandler = new AuthHandler(tokenGenerator, mockSession);
    }
    
    /**
     * Test: Valid credentials return JWT token
     * 
     * GIVEN: Valid username "user_a" and password "pass_a"
     * WHEN: POST /auth/token
     * THEN: HTTP 200 with JSON: {"access_token":"...","token_type":"Bearer","expires_in":3600}
     */
    @Test
    public void testValidCredentialsReturnToken() throws Exception {
        // Given
        String requestBody = "{\"username\":\"user_a\",\"password\":\"pass_a\"}";
        HttpExchange exchange = createMockHttpExchange("POST", "/auth/token", requestBody);
        
        // When
        authHandler.handle(exchange);
        
        // Then
        ByteArrayOutputStream responseBody = (ByteArrayOutputStream) exchange.getResponseBody();
        String response = responseBody.toString();
        
        assertThat(response).contains("\"access_token\":");
        assertThat(response).contains("\"token_type\":\"Bearer\"");
        assertThat(response).contains("\"expires_in\":3600");
        
        // Verify token structure (3 parts: header.payload.signature)
        String token = extractAccessToken(response);
        assertThat(token.split("\\.")).hasSize(3);
        
        // Verify status code was 200
        Mockito.verify(exchange).sendResponseHeaders(200, Mockito.anyLong());
    }
    
    /**
     * Test: Invalid credentials return 401 Unauthorized
     * 
     * GIVEN: Invalid password "wrong_password"
     * WHEN: POST /auth/token
     * THEN: HTTP 401 with JSON: {"error":"Unauthorized","message":"Invalid credentials"}
     */
    @Test
    public void testInvalidCredentialsReturn401() throws Exception {
        // Given
        String requestBody = "{\"username\":\"user_a\",\"password\":\"wrong_password\"}";
        HttpExchange exchange = createMockHttpExchange("POST", "/auth/token", requestBody);
        
        // When
        authHandler.handle(exchange);
        
        // Then
        ByteArrayOutputStream responseBody = (ByteArrayOutputStream) exchange.getResponseBody();
        String response = responseBody.toString();
        
        assertThat(response).contains("\"error\":\"Unauthorized\"");
        assertThat(response).contains("\"message\":\"Invalid credentials\"");
        
        // Verify status code was 401
        Mockito.verify(exchange).sendResponseHeaders(401, Mockito.anyLong());
    }
    
    /**
     * Test: Missing username returns 400 Bad Request
     * 
     * GIVEN: Request body with only password
     * WHEN: POST /auth/token
     * THEN: HTTP 400 with validation error
     */
    @Test
    public void testMissingUsernameReturns400() throws Exception {
        // Given
        String requestBody = "{\"password\":\"pass_a\"}";
        HttpExchange exchange = createMockHttpExchange("POST", "/auth/token", requestBody);
        
        // When
        authHandler.handle(exchange);
        
        // Then
        ByteArrayOutputStream responseBody = (ByteArrayOutputStream) exchange.getResponseBody();
        String response = responseBody.toString();
        
        assertThat(response).contains("\"error\":\"Validation failed\"");
        assertThat(response).contains("username");
        
        // Verify status code was 400
        Mockito.verify(exchange).sendResponseHeaders(400, Mockito.anyLong());
    }
    
    /**
     * Test: Missing password returns 400 Bad Request
     * 
     * GIVEN: Request body with only username
     * WHEN: POST /auth/token
     * THEN: HTTP 400 with validation error
     */
    @Test
    public void testMissingPasswordReturns400() throws Exception {
        // Given
        String requestBody = "{\"username\":\"user_a\"}";
        HttpExchange exchange = createMockHttpExchange("POST", "/auth/token", requestBody);
        
        // When
        authHandler.handle(exchange);
        
        // Then
        ByteArrayOutputStream responseBody = (ByteArrayOutputStream) exchange.getResponseBody();
        String response = responseBody.toString();
        
        assertThat(response).contains("\"error\":\"Validation failed\"");
        assertThat(response).contains("password");
        
        // Verify status code was 400
        Mockito.verify(exchange).sendResponseHeaders(400, Mockito.anyLong());
    }
    
    /**
     * Test: Empty request body returns 400 Bad Request
     * 
     * GIVEN: Empty request body
     * WHEN: POST /auth/token
     * THEN: HTTP 400 with error message
     */
    @Test
    public void testEmptyBodyReturns400() throws Exception {
        // Given
        String requestBody = "";
        HttpExchange exchange = createMockHttpExchange("POST", "/auth/token", requestBody);
        
        // When
        authHandler.handle(exchange);
        
        // Then
        ByteArrayOutputStream responseBody = (ByteArrayOutputStream) exchange.getResponseBody();
        String response = responseBody.toString();
        
        assertThat(response).contains("\"error\":");
        
        // Verify status code was 400
        Mockito.verify(exchange).sendResponseHeaders(400, Mockito.anyLong());
    }
    
    /**
     * Test: Non-existent user returns 401 Unauthorized
     * 
     * GIVEN: Username that doesn't exist in hardcoded users
     * WHEN: POST /auth/token
     * THEN: HTTP 401
     */
    @Test
    public void testNonExistentUserReturns401() throws Exception {
        // Given
        String requestBody = "{\"username\":\"user_nonexistent\",\"password\":\"any_password\"}";
        HttpExchange exchange = createMockHttpExchange("POST", "/auth/token", requestBody);
        
        // When
        authHandler.handle(exchange);
        
        // Then
        ByteArrayOutputStream responseBody = (ByteArrayOutputStream) exchange.getResponseBody();
        String response = responseBody.toString();
        
        assertThat(response).contains("\"error\":\"Unauthorized\"");
        
        // Verify status code was 401
        Mockito.verify(exchange).sendResponseHeaders(401, Mockito.anyLong());
    }
    
    /**
     * Test: GET method returns 405 Method Not Allowed
     * 
     * GIVEN: GET request to /auth/token
     * WHEN: Request is processed
     * THEN: HTTP 405 (only POST allowed)
     */
    @Test
    public void testGetMethodReturns405() throws Exception {
        // Given
        HttpExchange exchange = createMockHttpExchange("GET", "/auth/token", "");
        
        // When
        authHandler.handle(exchange);
        
        // Then
        // Verify status code was 405
        Mockito.verify(exchange).sendResponseHeaders(405, Mockito.anyLong());
    }
    
    /**
     * Test: Valid user_b credentials also work
     * 
     * GIVEN: Valid username "user_b" and password "pass_b"
     * WHEN: POST /auth/token
     * THEN: HTTP 200 with valid token
     */
    @Test
    public void testSecondUserCredentials() throws Exception {
        // Given
        String requestBody = "{\"username\":\"user_b\",\"password\":\"pass_b\"}";
        HttpExchange exchange = createMockHttpExchange("POST", "/auth/token", requestBody);
        
        // When
        authHandler.handle(exchange);
        
        // Then
        ByteArrayOutputStream responseBody = (ByteArrayOutputStream) exchange.getResponseBody();
        String response = responseBody.toString();
        
        assertThat(response).contains("\"access_token\":");
        assertThat(response).contains("\"token_type\":\"Bearer\"");
        
        // Verify status code was 200
        Mockito.verify(exchange).sendResponseHeaders(200, Mockito.anyLong());
    }
    
    // ==================
    // HELPER METHODS
    // ==================
    
    /**
     * Create mock HttpExchange for testing
     * 
     * EDUCATIONAL NOTE: Mockito allows us to simulate HTTP requests
     * without starting a real HTTP server. This speeds up tests.
     */
    private HttpExchange createMockHttpExchange(String method, String uri, String body) throws Exception {
        HttpExchange exchange = Mockito.mock(HttpExchange.class);
        
        // Mock request method (GET, POST, etc.)
        Mockito.when(exchange.getRequestMethod()).thenReturn(method);
        
        // Mock request URI
        Mockito.when(exchange.getRequestURI()).thenReturn(new URI(uri));
        
        // Mock request body
        InputStream requestBody = new ByteArrayInputStream(body.getBytes());
        Mockito.when(exchange.getRequestBody()).thenReturn(requestBody);
        
        // Mock response body
        ByteArrayOutputStream responseBody = new ByteArrayOutputStream();
        Mockito.when(exchange.getResponseBody()).thenReturn(responseBody);
        
        return exchange;
    }
    
    /**
     * Extract access_token value from JSON response
     * 
     * EXAMPLE: extractAccessToken('{"access_token":"abc123"}') -> "abc123"
     */
    private String extractAccessToken(String jsonResponse) {
        String pattern = "\"access_token\":\"";
        int startIndex = jsonResponse.indexOf(pattern);
        if (startIndex == -1) {
            throw new AssertionError("access_token not found in response: " + jsonResponse);
        }
        
        startIndex += pattern.length();
        int endIndex = jsonResponse.indexOf("\"", startIndex);
        
        return jsonResponse.substring(startIndex, endIndex);
    }
}
