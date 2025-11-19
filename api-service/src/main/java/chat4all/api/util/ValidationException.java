package chat4all.api.util;

/**
 * ValidationException - Custom Exception for Input Validation Errors
 * 
 * EDUCATIONAL PURPOSE:
 * ==================
 * This custom exception teaches students about EXPLICIT ERROR HANDLING in REST APIs.
 * 
 * WHY CUSTOM EXCEPTIONS?
 * 1. CLARITY: Distinguishes validation errors from system errors (NullPointerException)
 * 2. HTTP MAPPING: Validation errors -> 400 Bad Request, System errors -> 500 Internal Server Error
 * 3. CLIENT FEEDBACK: Provides specific error messages to API consumers
 * 
 * EXCEPTION HIERARCHY IN CHAT4ALL:
 * - Exception (root)
 *   - RuntimeException (unchecked)
 *     - ValidationException (THIS CLASS) -> 400 Bad Request
 *     - UnauthorizedException (future) -> 401 Unauthorized
 *   - IOException (checked) -> 500 Internal Server Error
 * 
 * WHEN TO THROW ValidationException:
 * - Empty/null required fields: "conversation_id is required"
 * - Invalid formats: "Invalid UUID format for message_id"
 * - Size limits: "Message content exceeds 10KB limit"
 * - Business rule violations: "User not a participant in conversation"
 * 
 * EDUCATIONAL NOTE: This is a RuntimeException (unchecked) so callers don't need
 * to declare "throws ValidationException". This is preferred for validation errors
 * because they represent programmer errors (invalid input), not recoverable conditions.
 * 
 * @author Chat4All Educational Project
 * @version 1.0.0
 */
public class ValidationException extends RuntimeException {
    
    /**
     * The field that failed validation (e.g., "conversation_id", "content")
     * 
     * EDUCATIONAL NOTE: This field enables structured error responses.
     * Instead of: {"error": "Validation failed"}
     * We return: {"error": "Validation failed", "field": "conversation_id", "message": "Cannot be empty"}
     * 
     * This helps API consumers identify exactly which field to fix.
     */
    private final String field;
    
    /**
     * Constructor with error message only
     * 
     * USE CASE: General validation errors without a specific field
     * 
     * EXAMPLE:
     * throw new ValidationException("Request body cannot be empty");
     * 
     * @param message Error message
     */
    public ValidationException(String message) {
        super(message);
        this.field = null;
    }
    
    /**
     * Constructor with field and error message
     * 
     * USE CASE: Field-specific validation errors
     * 
     * EXAMPLE:
     * throw new ValidationException("conversation_id", "Cannot be empty");
     * 
     * @param field Field name that failed validation
     * @param message Error message
     */
    public ValidationException(String field, String message) {
        super(message);
        this.field = field;
    }
    
    /**
     * Constructor with field, message, and cause
     * 
     * USE CASE: Validation errors caused by underlying exceptions
     * 
     * EXAMPLE:
     * try {
     *     UUID.fromString(messageId);
     * } catch (IllegalArgumentException e) {
     *     throw new ValidationException("message_id", "Invalid UUID format", e);
     * }
     * 
     * @param field Field name that failed validation
     * @param message Error message
     * @param cause Underlying exception
     */
    public ValidationException(String field, String message, Throwable cause) {
        super(message, cause);
        this.field = field;
    }
    
    /**
     * Get the field that failed validation
     * 
     * @return Field name, or null if not field-specific
     */
    public String getField() {
        return field;
    }
    
    /**
     * Check if this exception is field-specific
     * 
     * @return true if a field is associated with this error
     */
    public boolean hasField() {
        return field != null && !field.isEmpty();
    }
    
    /**
     * Generate a structured error response JSON
     * 
     * EXAMPLE OUTPUT (field-specific):
     * {
     *   "error": "Validation failed",
     *   "field": "conversation_id",
     *   "message": "Cannot be empty"
     * }
     * 
     * EXAMPLE OUTPUT (general):
     * {
     *   "error": "Validation failed",
     *   "message": "Request body cannot be empty"
     * }
     * 
     * @return JSON error response
     */
    public String toJsonError() {
        StringBuilder json = new StringBuilder();
        json.append("{");
        json.append("\"error\":\"Validation failed\"");
        
        if (hasField()) {
            json.append(",\"field\":\"").append(escapeJson(field)).append("\"");
        }
        
        json.append(",\"message\":\"").append(escapeJson(getMessage())).append("\"");
        json.append("}");
        
        return json.toString();
    }
    
    /**
     * Escape special JSON characters
     * 
     * @param str String to escape
     * @return Escaped string
     */
    private String escapeJson(String str) {
        if (str == null) return "";
        return str.replace("\\", "\\\\")
                  .replace("\"", "\\\"")
                  .replace("\n", "\\n")
                  .replace("\r", "\\r")
                  .replace("\t", "\\t");
    }
    
    /**
     * toString for logging
     * 
     * EXAMPLE: ValidationException: [field=conversation_id] Cannot be empty
     */
    @Override
    public String toString() {
        if (hasField()) {
            return "ValidationException: [field=" + field + "] " + getMessage();
        } else {
            return "ValidationException: " + getMessage();
        }
    }
}
