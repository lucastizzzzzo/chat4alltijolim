package chat4all.api.messages;

import chat4all.api.util.ValidationException;
import java.util.Map;

/**
 * MessageValidator - Validates message payloads before Kafka publishing
 * 
 * EDUCATIONAL PURPOSE: Input Validation and Error Handling
 * ==================
 * 
 * WHY VALIDATE AT API LAYER?
 * 1. **Fail Fast**: Catch errors before expensive operations (Kafka publish, DB write)
 * 2. **Clear Errors**: Provide specific error messages to clients
 * 3. **Data Integrity**: Ensure only well-formed data enters the system
 * 4. **Security**: Prevent malformed/malicious data injection
 * 
 * VALIDATION RULES:
 * - conversation_id: Required, non-empty string
 * - sender_id: Required, non-empty string (extracted from JWT in production)
 * - content: Required, non-empty, max 10KB (10240 bytes)
 * 
 * BOUNDARY CONDITIONS:
 * - Empty strings are invalid
 * - Null values are invalid
 * - Content at exactly 10KB is valid (10241+ bytes invalid)
 * 
 * EDUCATIONAL NOTE ON SIZE LIMITS:
 * Why 10KB for text messages?
 * - Kafka default max message size: 1MB
 * - 10KB allows ~100 messages per batch without hitting limits
 * - Typical text message: 100-500 bytes (10KB is generous)
 * - Files/images should use separate upload endpoint
 * 
 * @author Chat4All Educational Project
 */
public class MessageValidator {
    
    /**
     * Maximum content size in bytes (10KB)
     * 
     * EDUCATIONAL NOTE: Why bytes, not characters?
     * - UTF-8 encoding: Some characters take 1-4 bytes
     * - Example: "café" = 5 characters but 6 bytes (é = 2 bytes)
     * - Network/storage care about bytes, not character count
     */
    private static final int MAX_CONTENT_SIZE_BYTES = 10 * 1024; // 10KB
    
    /**
     * Validates a message payload
     * 
     * VALIDATION SEQUENCE:
     * 1. Check conversation_id exists and non-empty
     * 2. Check sender_id exists and non-empty
     * 3. Check content exists, non-empty, and within size limit
     * 
     * DESIGN DECISION: Validate in order of "cheapest to check first"
     * - Null checks are faster than string length checks
     * - String length checks are faster than byte length checks
     * 
     * @param message Message payload from API request
     * @throws ValidationException if validation fails with specific error message
     */
    public void validate(Map<String, Object> message) throws ValidationException {
        // 1. Validate conversation_id
        validateConversationId(message);
        
        // 2. Validate sender_id
        validateSenderId(message);
        
        // 3. Validate content
        validateContent(message);
    }
    
    /**
     * Validates conversation_id field
     * 
     * RULES:
     * - Must be present in map
     * - Must not be null
     * - Must not be empty string
     * - Must not be blank (only whitespace)
     * 
     * @param message Message payload
     * @throws ValidationException if validation fails
     */
    private void validateConversationId(Map<String, Object> message) throws ValidationException {
        if (!message.containsKey("conversation_id")) {
            throw new ValidationException("conversation_id is required");
        }
        
        Object conversationId = message.get("conversation_id");
        
        if (conversationId == null) {
            throw new ValidationException("conversation_id is required");
        }
        
        if (!(conversationId instanceof String)) {
            throw new ValidationException("conversation_id must be a string");
        }
        
        String conversationIdStr = (String) conversationId;
        
        if (conversationIdStr.trim().isEmpty()) {
            throw new ValidationException("conversation_id cannot be empty");
        }
    }
    
    /**
     * Validates sender_id field
     * 
     * RULES:
     * - Must be present in map
     * - Must not be null
     * - Must not be empty string
     * 
     * PRODUCTION NOTE: In real system, sender_id comes from JWT token,
     * not from request body (prevents impersonation).
     * For Phase 1 simplicity, we accept it from body.
     * 
     * @param message Message payload
     * @throws ValidationException if validation fails
     */
    private void validateSenderId(Map<String, Object> message) throws ValidationException {
        if (!message.containsKey("sender_id")) {
            throw new ValidationException("sender_id is required");
        }
        
        Object senderId = message.get("sender_id");
        
        if (senderId == null) {
            throw new ValidationException("sender_id is required");
        }
        
        if (!(senderId instanceof String)) {
            throw new ValidationException("sender_id must be a string");
        }
        
        String senderIdStr = (String) senderId;
        
        if (senderIdStr.trim().isEmpty()) {
            throw new ValidationException("sender_id cannot be empty");
        }
    }
    
    /**
     * Validates content field
     * 
     * RULES:
     * - Must be present in map
     * - Must not be null
     * - Must not be empty string
     * - Must not exceed 10KB (10240 bytes) when encoded as UTF-8
     * 
     * EDUCATIONAL NOTE: Why check bytes, not string length?
     * 
     * Example: "Hello" = 5 characters, 5 bytes
     * Example: "Olá" = 3 characters, 4 bytes (á = 2 bytes in UTF-8)
     * Example: "你好" = 2 characters, 6 bytes (each Chinese char = 3 bytes)
     * 
     * Network protocols (HTTP, Kafka) operate on bytes, not characters.
     * 
     * @param message Message payload
     * @throws ValidationException if validation fails
     */
    private void validateContent(Map<String, Object> message) throws ValidationException {
        if (!message.containsKey("content")) {
            throw new ValidationException("content is required");
        }
        
        Object content = message.get("content");
        
        if (content == null) {
            throw new ValidationException("content is required");
        }
        
        if (!(content instanceof String)) {
            throw new ValidationException("content must be a string");
        }
        
        String contentStr = (String) content;
        
        if (contentStr.trim().isEmpty()) {
            throw new ValidationException("content cannot be empty");
        }
        
        // Size validation: Convert string to bytes and check size
        // EDUCATIONAL NOTE: Why getBytes("UTF-8")?
        // - Default encoding varies by platform (Windows-1252, ISO-8859-1, etc.)
        // - UTF-8 is universal standard for web/network communication
        // - Explicit encoding prevents platform-dependent bugs
        byte[] contentBytes = contentStr.getBytes(java.nio.charset.StandardCharsets.UTF_8);
        
        if (contentBytes.length > MAX_CONTENT_SIZE_BYTES) {
            throw new ValidationException(
                String.format("content too large (max %d bytes, got %d bytes)", 
                    MAX_CONTENT_SIZE_BYTES, contentBytes.length)
            );
        }
    }
}
