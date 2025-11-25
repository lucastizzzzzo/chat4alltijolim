package chat4all.api.http;

import chat4all.api.auth.JwtAuthenticator;
import chat4all.api.auth.JwtAuthenticationException;
import chat4all.api.kafka.MessageProducer;
import chat4all.api.messages.MessageValidator;
import chat4all.api.repository.FileRepository;
import chat4all.api.util.JsonParser;
import chat4all.api.util.ValidationException;
import chat4all.shared.FileEvent;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * MessagesHandler - HTTP Handler for POST /v1/messages
 * 
 * EDUCATIONAL PURPOSE: RESTful API Design + Async Processing
 * ==================
 * 
 * ENDPOINT: POST /v1/messages
 * 
 * REQUEST:
 * ```json
 * {
 *   "conversation_id": "conv_abc123",
 *   "sender_id": "user_alice",
 *   "content": "Hello, world!"
 * }
 * ```
 * 
 * RESPONSE (202 Accepted):
 * ```json
 * {
 *   "message_id": "msg_xyz789",
 *   "status": "ACCEPTED",
 *   "conversation_id": "conv_abc123"
 * }
 * ```
 * 
 * FLOW:
 * 1. Parse JSON request body
 * 2. Validate message fields (MessageValidator)
 * 3. Generate unique message_id (UUID)
 * 4. Publish to Kafka topic "messages"
 * 5. Return 202 Accepted (async processing)
 * 
 * WHY 202 ACCEPTED (not 200 OK)?
 * - Message is queued, not yet delivered
 * - Worker will process async (might take seconds/minutes)
 * - 202 signals "accepted for processing" (RESTful semantics)
 * 
 * EDUCATIONAL NOTE ON HTTP STATUS CODES:
 * - 200 OK: Request completed successfully
 * - 201 Created: Resource created (e.g., POST /users)
 * - 202 Accepted: Request accepted, processing async
 * - 400 Bad Request: Validation error
 * - 401 Unauthorized: Missing/invalid auth
 * - 500 Internal Error: Server error
 * 
 * @author Chat4All Educational Project
 */
public class MessagesHandler implements HttpHandler {
    
    private final MessageValidator validator;
    private final MessageProducer producer;
    private final JwtAuthenticator authenticator;
    private final FileRepository fileRepository; // Phase 2: File attachment validation
    
    /**
     * Creates MessagesHandler
     * 
     * DEPENDENCY INJECTION:
     * - validator: Injected for testability (can mock in tests)
     * - producer: Injected for testability (can use test Kafka)
     * - authenticator: JWT validator for authentication
     * - fileRepository: File metadata lookup (Phase 2)
     * 
     * @param validator Message validator
     * @param producer Kafka producer
     * @param authenticator JWT authenticator
     * @param fileRepository File repository (Phase 2)
     */
    public MessagesHandler(MessageValidator validator, MessageProducer producer, JwtAuthenticator authenticator, FileRepository fileRepository) {
        this.validator = validator;
        this.producer = producer;
        this.authenticator = authenticator;
        this.fileRepository = fileRepository;
    }
    
    /**
     * Handles POST /v1/messages
     * 
     * FLOW:
     * 1. Validate HTTP method (must be POST)
     * 2. Read and parse request body
     * 3. Validate message fields
     * 4. Generate message_id
     * 5. Build Kafka message event
     * 6. Publish to Kafka (async)
     * 7. Return 202 Accepted
     * 
     * ERROR HANDLING:
     * - ValidationException → 400 Bad Request
     * - IOException → 500 Internal Error
     * - Other exceptions → 500 Internal Error
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
            // 2. AUTHENTICATION - Extract and validate JWT token
            String authHeader = exchange.getRequestHeaders().getFirst("Authorization");
            
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                sendErrorResponse(exchange, 401, "Missing or invalid Authorization header. Expected: Bearer <token>");
                return;
            }
            
            String token = authHeader.substring(7); // Remove "Bearer " prefix
            
            String authenticatedUserId;
            try {
                authenticatedUserId = authenticator.validateToken(token);
            } catch (JwtAuthenticationException e) {
                sendErrorResponse(exchange, 401, "Authentication failed: " + e.getMessage());
                return;
            }
            
            // 3. Read request body
            InputStream requestBody = exchange.getRequestBody();
            String bodyString = new String(requestBody.readAllBytes(), StandardCharsets.UTF_8);
            
            if (bodyString.trim().isEmpty()) {
                sendErrorResponse(exchange, 400, "Request body cannot be empty");
                return;
            }
            
            // 4. Parse JSON
            Map<String, Object> messageData = JsonParser.parseRequest(bodyString);
            
            // 5. Verify sender_id matches authenticated user
            String senderIdFromPayload = (String) messageData.get("sender_id");
            if (senderIdFromPayload != null && !senderIdFromPayload.equals(authenticatedUserId)) {
                sendErrorResponse(exchange, 403, "Forbidden: sender_id must match authenticated user");
                return;
            }
            
            // If sender_id not provided, use authenticated user
            if (senderIdFromPayload == null) {
                messageData.put("sender_id", authenticatedUserId);
            }
            
            // 6. Validate message
            validator.validate(messageData);
            
            // 7. Phase 2: Handle file attachments (accept file_id with or without type="file")
            String fileId = (String) messageData.get("file_id");
            Map<String, String> fileMetadata = null;
            
            if (fileId != null && !fileId.trim().isEmpty()) {
                // Validate file exists in database
                java.util.Optional<FileEvent> fileEvent = fileRepository.findById(fileId);
                if (!fileEvent.isPresent()) {
                    sendErrorResponse(exchange, 400, "File not found: " + fileId);
                    return;
                }
                
                // Extract file metadata for quick access (denormalization)
                FileEvent file = fileEvent.get();
                fileMetadata = new HashMap<>();
                fileMetadata.put("filename", file.getFilename());
                fileMetadata.put("size_bytes", String.valueOf(file.getSizeBytes()));
                fileMetadata.put("mimetype", file.getMimetype());
                fileMetadata.put("checksum", file.getChecksum());
                
                System.out.println("[MessagesHandler] File attachment: " + fileId + " (" + file.getFilename() + ")");
            }
            
            // 8. Generate message_id (UUID v4 - random)
            String messageId = "msg_" + UUID.randomUUID().toString().replace("-", "");
            
            // 9. Build Kafka event payload
            Map<String, Object> kafkaEvent = new HashMap<>();
            kafkaEvent.put("message_id", messageId);
            kafkaEvent.put("conversation_id", messageData.get("conversation_id"));
            kafkaEvent.put("sender_id", messageData.get("sender_id"));
            
            // Phase 5: Add recipient_id if provided (for external connector routing)
            if (messageData.containsKey("recipient_id")) {
                kafkaEvent.put("recipient_id", messageData.get("recipient_id"));
            }
            
            kafkaEvent.put("content", messageData.get("content"));
            kafkaEvent.put("timestamp", System.currentTimeMillis());
            kafkaEvent.put("event_type", "MESSAGE_SENT");
            
            // Phase 2: Include file attachment if present
            if (fileId != null) {
                kafkaEvent.put("file_id", fileId);
                if (fileMetadata != null) {
                    kafkaEvent.put("file_metadata", fileMetadata);
                }
            }
            
            String kafkaEventJson = JsonParser.toJson(kafkaEvent);
            
            // 9. Publish to Kafka (async)
            String conversationId = (String) messageData.get("conversation_id");
            producer.publish(conversationId, kafkaEventJson);
            
            // 10. Return 202 Accepted
            Map<String, Object> response = new HashMap<>();
            response.put("message_id", messageId);
            response.put("status", "ACCEPTED");
            response.put("conversation_id", conversationId);
            
            String responseJson = JsonParser.toJson(response);
            sendResponse(exchange, 202, responseJson);
            
        } catch (ValidationException e) {
            // Validation error → 400 Bad Request
            sendErrorResponse(exchange, 400, e.getMessage());
            
        } catch (IOException e) {
            // I/O error → 500 Internal Error
            sendErrorResponse(exchange, 500, "Internal server error: I/O error");
            
        } catch (Exception e) {
            // Unexpected error → 500 Internal Error
            sendErrorResponse(exchange, 500, "Internal server error");
        }
    }
    
    /**
     * Sends HTTP response
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
     * Sends HTTP error response
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
