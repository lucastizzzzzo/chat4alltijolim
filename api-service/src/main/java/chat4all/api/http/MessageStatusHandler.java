package chat4all.api.http;

import chat4all.api.auth.JwtAuthenticator;
import chat4all.api.auth.JwtAuthenticationException;
import chat4all.api.cassandra.CassandraMessageRepository;
import chat4all.shared.MessageStatus;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

/**
 * MessageStatusHandler - Mark messages as READ
 * 
 * PROPÓSITO EDUCACIONAL: RESTful State Updates + Idempotency
 * ==================
 * 
 * ENDPOINT: POST /v1/messages/{message_id}/read
 * 
 * PURPOSE:
 * - Allow clients to mark messages as read
 * - Validates state transitions (DELIVERED → READ only)
 * - Idempotent (calling twice has same effect as once)
 * - Records read_at timestamp for analytics
 * 
 * STATE MACHINE VALIDATION:
 * ```
 * Current     Target      Result
 * ─────────────────────────────────
 * SENT     →  READ    =   400 (invalid)
 * DELIVERED → READ    =   200 (valid)
 * READ     →  READ    =   200 (idempotent)
 * ```
 * 
 * EXAMPLE REQUEST:
 * ```
 * POST /v1/messages/msg_abc123/read
 * Authorization: Bearer eyJ...
 * ```
 * 
 * RESPONSE (200 OK):
 * ```json
 * {
 *   "message_id": "msg_abc123",
 *   "status": "READ",
 *   "read_at": 1700000000000
 * }
 * ```
 * 
 * ERROR (400 Bad Request):
 * ```json
 * {
 *   "error": "Invalid transition: SENT → READ (message must be DELIVERED first)"
 * }
 * ```
 * 
 * WHY IDEMPOTENT?
 * - Network retries: client might send same request twice
 * - User action: user might click "mark as read" multiple times
 * - Same outcome regardless of how many times called
 * 
 * REAL-WORLD EXAMPLE:
 * - WhatsApp blue checkmarks: marking as read multiple times is safe
 * - Email "mark as read": clicking twice doesn't break anything
 * 
 * @author Chat4All Educational Project
 */
public class MessageStatusHandler implements HttpHandler {
    
    private final CassandraMessageRepository repository;
    private final JwtAuthenticator authenticator;
    
    /**
     * Constructor
     * 
     * @param repository Cassandra repository for status updates
     * @param authenticator JWT authenticator
     */
    public MessageStatusHandler(CassandraMessageRepository repository, JwtAuthenticator authenticator) {
        this.repository = repository;
        this.authenticator = authenticator;
    }
    
    /**
     * Handle POST /v1/messages/{message_id}/read
     * 
     * FLOW:
     * 1. Validate HTTP method (POST only)
     * 2. Authenticate JWT token
     * 3. Extract message_id from path
     * 4. Query current status from Cassandra
     * 5. Validate transition using MessageStatus.isValidTransition()
     * 6. If valid, update to READ and set read_at timestamp
     * 7. Return success or error response
     * 
     * @param exchange HTTP request/response
     * @throws IOException if I/O error occurs
     */
    @Override
    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        
        // 1. Validate HTTP method
        if (!"POST".equals(method)) {
            sendErrorResponse(exchange, 405, "Method not allowed. Use POST.");
            return;
        }
        
        try {
            // 2. AUTHENTICATION - Validate JWT token
            String authHeader = exchange.getRequestHeaders().getFirst("Authorization");
            
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                sendErrorResponse(exchange, 401, "Missing or invalid Authorization header");
                return;
            }
            
            String token = authHeader.substring(7);
            
            try {
                authenticator.validateToken(token);
            } catch (JwtAuthenticationException e) {
                sendErrorResponse(exchange, 401, "Authentication failed: " + e.getMessage());
                return;
            }
            
            // 3. Extract message_id from path
            // Path format: /v1/messages/{message_id}/read
            String path = exchange.getRequestURI().getPath();
            String[] pathParts = path.split("/");
            
            if (pathParts.length < 4) {
                sendErrorResponse(exchange, 400, "Invalid path. Expected: /v1/messages/{message_id}/read");
                return;
            }
            
            String messageId = pathParts[3]; // Index 3 = message_id
            
            if (messageId == null || messageId.trim().isEmpty()) {
                sendErrorResponse(exchange, 400, "message_id cannot be empty");
                return;
            }
            
            // 4. Query current status from database
            Map<String, Object> message = repository.getMessageById(messageId);
            
            if (message == null) {
                sendErrorResponse(exchange, 404, "Message not found: " + messageId);
                return;
            }
            
            String currentStatusStr = (String) message.get("status");
            MessageStatus currentStatus = MessageStatus.fromString(currentStatusStr);
            MessageStatus targetStatus = MessageStatus.READ;
            
            // 5. Validate transition
            if (!MessageStatus.isValidTransition(currentStatus, targetStatus)) {
                sendErrorResponse(exchange, 400, 
                    "Invalid transition: " + currentStatus + " → " + targetStatus + 
                    " (message must be DELIVERED first)");
                return;
            }
            
            // 6. Update to READ (or confirm already READ - idempotent)
            long readAt;
            
            if (currentStatus == MessageStatus.READ) {
                // Already READ - return existing read_at (idempotent)
                Instant readAtInstant = (Instant) message.get("read_at");
                readAt = readAtInstant != null ? readAtInstant.toEpochMilli() : System.currentTimeMillis();
                
                System.out.println("✓ Message already READ (idempotent): " + messageId);
                
            } else {
                // Update to READ
                readAt = System.currentTimeMillis();
                repository.updateMessageStatus(messageId, MessageStatus.READ.getValue(), readAt);
                
                System.out.println("✓ Marked as READ: " + messageId);
            }
            
            // 7. Build success response
            Map<String, Object> response = new HashMap<>();
            response.put("message_id", messageId);
            response.put("status", "READ");
            response.put("read_at", readAt);
            
            String responseJson = toJson(response);
            sendResponse(exchange, 200, responseJson);
            
        } catch (IllegalArgumentException e) {
            sendErrorResponse(exchange, 400, e.getMessage());
            
        } catch (RuntimeException e) {
            System.err.println("Error in MessageStatusHandler: " + e.getMessage());
            e.printStackTrace();
            sendErrorResponse(exchange, 500, "Internal server error");
        }
    }
    
    /**
     * Convert map to JSON string (manual for educational purposes)
     * 
     * @param map Data to convert
     * @return JSON string
     */
    private String toJson(Map<String, Object> map) {
        StringBuilder json = new StringBuilder("{");
        boolean first = true;
        
        for (Map.Entry<String, Object> entry : map.entrySet()) {
            if (!first) {
                json.append(",");
            }
            first = false;
            
            json.append("\"").append(entry.getKey()).append("\":");
            
            Object value = entry.getValue();
            if (value instanceof String) {
                json.append("\"").append(value).append("\"");
            } else {
                json.append(value);
            }
        }
        
        json.append("}");
        return json.toString();
    }
    
    /**
     * Send HTTP response
     * 
     * @param exchange HTTP exchange
     * @param statusCode HTTP status code
     * @param body Response body (JSON string)
     * @throws IOException if I/O error occurs
     */
    private void sendResponse(HttpExchange exchange, int statusCode, String body) throws IOException {
        byte[] responseBytes = body.getBytes(StandardCharsets.UTF_8);
        
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(statusCode, responseBytes.length);
        
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(responseBytes);
        }
    }
    
    /**
     * Send HTTP error response
     * 
     * @param exchange HTTP exchange
     * @param statusCode HTTP status code
     * @param message Error message
     * @throws IOException if I/O error occurs
     */
    private void sendErrorResponse(HttpExchange exchange, int statusCode, String message) throws IOException {
        String errorJson = String.format("{\"error\":\"%s\"}", message);
        sendResponse(exchange, statusCode, errorJson);
    }
}
