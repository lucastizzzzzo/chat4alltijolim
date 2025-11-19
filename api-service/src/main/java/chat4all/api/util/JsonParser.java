package chat4all.api.util;

import java.util.HashMap;
import java.util.Map;

/**
 * JsonParser - Manual JSON Parsing for Educational Purposes
 * 
 * EDUCATIONAL PURPOSE:
 * ==================
 * This class implements MANUAL JSON PARSING to teach students the fundamentals of serialization.
 * 
 * WHY NOT USE JACKSON OR GSON?
 * 1. EDUCATIONAL TRANSPARENCY: Students see exactly how JSON is structured and parsed
 * 2. MINIMAL DEPENDENCIES: Aligns with Constitution Principle II (minimal external libraries)
 * 3. UNDERSTANDING SERIALIZATION: Students learn string manipulation, escaping, validation
 * 
 * PRODUCTION NOTE:
 * In real-world projects, use battle-tested libraries like Jackson or Gson.
 * This implementation is simplified and does not handle:
 * - Nested objects/arrays
 * - Unicode escape sequences (like \u0041 for 'A')
 * - Scientific notation (1.5e10)
 * - Edge cases (malformed JSON)
 * 
 * SUPPORTED FORMATS:
 * - Flat JSON objects: {"key":"value","number":42,"boolean":true}
 * - String values with basic escaping: \"Hello\nWorld\"
 * - Numeric values: integers and decimals
 * - Boolean values: true/false
 * - Null values: null
 * 
 * @author Chat4All Educational Project
 * @version 1.0.0
 */
public class JsonParser {
    
    /**
     * Parse a flat JSON object into a Map
     * 
     * ALIAS METHOD for better naming consistency.
     * 
     * @param json JSON string (flat object only)
     * @return Map of key-value pairs
     * @throws IllegalArgumentException if JSON is malformed
     */
    public static Map<String, String> parseObject(String json) {
        Map<String, Object> raw = parseRequest(json);
        Map<String, String> result = new HashMap<>();
        for (Map.Entry<String, Object> entry : raw.entrySet()) {
            Object value = entry.getValue();
            result.put(entry.getKey(), value != null ? value.toString() : null);
        }
        return result;
    }
    
    /**
     * Parse a flat JSON object into a Map
     * 
     * EXAMPLE INPUT:
     * {
     *   "conversation_id": "conv_abc123",
     *   "sender_id": "user_alice",
     *   "content": "Hello, world!"
     * }
     * 
     * EXAMPLE OUTPUT:
     * Map {
     *   "conversation_id" -> "conv_abc123",
     *   "sender_id" -> "user_alice",
     *   "content" -> "Hello, world!"
     * }
     * 
     * EDUCATIONAL NOTE: This method teaches students:
     * 1. String tokenization (splitting by delimiters)
     * 2. State machine parsing (inside quotes vs outside)
     * 3. Escape sequence handling (quote, backslash, newline, carriage return, tab)
     * 4. Type inference (string vs number vs boolean)
     * 
     * @param json JSON string (flat object only)
     * @return Map of key-value pairs
     * @throws IllegalArgumentException if JSON is malformed
     */
    public static Map<String, Object> parseRequest(String json) {
        if (json == null || json.trim().isEmpty()) {
            throw new IllegalArgumentException("JSON string cannot be null or empty");
        }
        
        json = json.trim();
        
        // Validate JSON structure: must start with { and end with }
        if (!json.startsWith("{") || !json.endsWith("}")) {
            throw new IllegalArgumentException("Invalid JSON: must start with { and end with }");
        }
        
        // Remove outer braces
        json = json.substring(1, json.length() - 1).trim();
        
        Map<String, Object> result = new HashMap<>();
        
        // Empty object: {}
        if (json.isEmpty()) {
            return result;
        }
        
        // Parse key-value pairs
        // State machine: iterate character by character to handle commas inside strings
        StringBuilder currentToken = new StringBuilder();
        boolean insideQuotes = false;
        boolean escapeNext = false;
        
        for (int i = 0; i < json.length(); i++) {
            char c = json.charAt(i);
            
            if (escapeNext) {
                // Handle escape sequences
                currentToken.append(c);
                escapeNext = false;
                continue;
            }
            
            if (c == '\\') {
                escapeNext = true;
                currentToken.append(c);
                continue;
            }
            
            if (c == '"') {
                insideQuotes = !insideQuotes;
                currentToken.append(c);
                continue;
            }
            
            if (c == ',' && !insideQuotes) {
                // End of key-value pair
                parseAndAddPair(currentToken.toString().trim(), result);
                currentToken.setLength(0); // Clear buffer
                continue;
            }
            
            currentToken.append(c);
        }
        
        // Parse last key-value pair (no trailing comma)
        if (currentToken.length() > 0) {
            parseAndAddPair(currentToken.toString().trim(), result);
        }
        
        return result;
    }
    
    /**
     * Parse a single key-value pair and add to map
     * 
     * EXAMPLES:
     * - "name":"Alice" -> key="name", value="Alice" (String)
     * - "age":30 -> key="age", value=30 (Integer)
     * - "active":true -> key="active", value=true (Boolean)
     * 
     * @param pair Key-value pair string
     * @param map Map to add parsed pair to
     */
    private static void parseAndAddPair(String pair, Map<String, Object> map) {
        // Find colon separator: "key":"value" or "key":123
        int colonIndex = findColonIndex(pair);
        if (colonIndex == -1) {
            throw new IllegalArgumentException("Invalid JSON pair (missing colon): " + pair);
        }
        
        // Extract key (remove surrounding quotes)
        String key = pair.substring(0, colonIndex).trim();
        if (key.startsWith("\"") && key.endsWith("\"")) {
            key = key.substring(1, key.length() - 1);
            key = unescapeJson(key);
        } else {
            throw new IllegalArgumentException("Invalid JSON key (must be quoted): " + key);
        }
        
        // Extract value
        String valueStr = pair.substring(colonIndex + 1).trim();
        Object value = parseValue(valueStr);
        
        map.put(key, value);
    }
    
    /**
     * Find the index of the colon separator (outside of quotes)
     * 
     * EXAMPLE: "name":"Alice:Bob" -> returns index of first : (not the one inside quotes)
     * 
     * @param pair Key-value pair string
     * @return Index of colon, or -1 if not found
     */
    private static int findColonIndex(String pair) {
        boolean insideQuotes = false;
        boolean escapeNext = false;
        
        for (int i = 0; i < pair.length(); i++) {
            char c = pair.charAt(i);
            
            if (escapeNext) {
                escapeNext = false;
                continue;
            }
            
            if (c == '\\') {
                escapeNext = true;
                continue;
            }
            
            if (c == '"') {
                insideQuotes = !insideQuotes;
                continue;
            }
            
            if (c == ':' && !insideQuotes) {
                return i;
            }
        }
        
        return -1;
    }
    
    /**
     * Parse a JSON value (string, number, boolean, or null)
     * 
     * TYPE INFERENCE:
     * - Starts/ends with ": String
     * - "true" or "false": Boolean
     * - "null": null
     * - Contains only digits/decimal point: Number (Long or Double)
     * 
     * @param valueStr Value string from JSON
     * @return Parsed value (String, Long, Double, Boolean, or null)
     */
    private static Object parseValue(String valueStr) {
        valueStr = valueStr.trim();
        
        // String value
        if (valueStr.startsWith("\"") && valueStr.endsWith("\"")) {
            String str = valueStr.substring(1, valueStr.length() - 1);
            return unescapeJson(str);
        }
        
        // Boolean value
        if ("true".equalsIgnoreCase(valueStr)) {
            return Boolean.TRUE;
        }
        if ("false".equalsIgnoreCase(valueStr)) {
            return Boolean.FALSE;
        }
        
        // Null value
        if ("null".equalsIgnoreCase(valueStr)) {
            return null;
        }
        
        // Numeric value (integer or decimal)
        try {
            if (valueStr.contains(".")) {
                return Double.parseDouble(valueStr);
            } else {
                return Long.parseLong(valueStr);
            }
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("Invalid JSON value: " + valueStr);
        }
    }
    
    /**
     * Convert a Map to JSON string
     * 
     * EXAMPLE INPUT:
     * Map {
     *   "status" -> "success",
     *   "message_id" -> "msg_abc123",
     *   "timestamp" -> 1705497600000L,
     *   "messages" -> List[Map{...}, Map{...}]
     * }
     * 
     * EXAMPLE OUTPUT:
     * {"status":"success","message_id":"msg_abc123","timestamp":1705497600000,"messages":[{...},{...}]}
     * 
     * SUPPORTS:
     * - Nested Maps
     * - Lists (arrays)
     * - Primitive types
     * 
     * @param data Map to serialize
     * @return JSON string
     */
    public static String toJson(Map<String, Object> data) {
        if (data == null || data.isEmpty()) {
            return "{}";
        }
        
        StringBuilder json = new StringBuilder();
        json.append("{");
        
        boolean first = true;
        for (Map.Entry<String, Object> entry : data.entrySet()) {
            if (!first) {
                json.append(",");
            }
            first = false;
            
            // Key (always string)
            json.append("\"").append(escapeJson(entry.getKey())).append("\":");
            
            // Value (type-dependent)
            json.append(toJsonValue(entry.getValue()));
        }
        
        json.append("}");
        return json.toString();
    }
    
    /**
     * Convert any value to JSON representation
     * 
     * Handles: String, Number, Boolean, null, List, Map
     * 
     * @param value Value to convert
     * @return JSON string representation
     */
    private static String toJsonValue(Object value) {
        if (value == null) {
            return "null";
        } else if (value instanceof String) {
            return "\"" + escapeJson((String) value) + "\"";
        } else if (value instanceof Boolean || value instanceof Number) {
            return value.toString();
        } else if (value instanceof java.util.List) {
            return toJsonArray((java.util.List<?>) value);
        } else if (value instanceof java.util.Map) {
            return toJson((java.util.Map<String, Object>) value);
        } else {
            // Fallback: convert to string
            return "\"" + escapeJson(value.toString()) + "\"";
        }
    }
    
    /**
     * Convert a List to JSON array
     * 
     * EXAMPLE:
     * List[Map{id:1}, Map{id:2}] -> [{\"id\":1},{\"id\":2}]
     * 
     * @param list List to serialize
     * @return JSON array string
     */
    private static String toJsonArray(java.util.List<?> list) {
        if (list == null || list.isEmpty()) {
            return "[]";
        }
        
        StringBuilder json = new StringBuilder();
        json.append("[");
        
        boolean first = true;
        for (Object item : list) {
            if (!first) {
                json.append(",");
            }
            first = false;
            
            json.append(toJsonValue(item));
        }
        
        json.append("]");
        return json.toString();
    }
    
    /**
     * Escape special JSON characters
     * 
     * ESCAPE SEQUENCES:
     * - Backslash (\) -> \\
     * - Double quote (") -> \"
     * - Newline (\n) -> \\n
     * - Carriage return (\r) -> \\r
     * - Tab (\t) -> \\t
     * 
     * EDUCATIONAL NOTE: Without escaping, the following message breaks JSON:
     * Message: He said: "Hello"
     * Broken JSON: {"content":"He said: "Hello""}
     * Fixed JSON: {"content":"He said: \"Hello\""}
     * 
     * @param str String to escape
     * @return Escaped string
     */
    private static String escapeJson(String str) {
        if (str == null) return "";
        return str.replace("\\", "\\\\")
                  .replace("\"", "\\\"")
                  .replace("\n", "\\n")
                  .replace("\r", "\\r")
                  .replace("\t", "\\t");
    }
    
    /**
     * Unescape JSON escape sequences
     * 
     * REVERSE PROCESS:
     * - \\ -> \
     * - \" -> "
     * - \\n -> \n (newline character)
     * - \\r -> \r (carriage return)
     * - \\t -> \t (tab character)
     * 
     * @param str Escaped string
     * @return Unescaped string
     */
    private static String unescapeJson(String str) {
        if (str == null) return "";
        
        StringBuilder result = new StringBuilder();
        boolean escapeNext = false;
        
        for (int i = 0; i < str.length(); i++) {
            char c = str.charAt(i);
            
            if (escapeNext) {
                switch (c) {
                    case 'n':
                        result.append('\n');
                        break;
                    case 'r':
                        result.append('\r');
                        break;
                    case 't':
                        result.append('\t');
                        break;
                    case '\\':
                        result.append('\\');
                        break;
                    case '"':
                        result.append('"');
                        break;
                    default:
                        // Unknown escape sequence, keep as-is
                        result.append('\\').append(c);
                }
                escapeNext = false;
            } else if (c == '\\') {
                escapeNext = true;
            } else {
                result.append(c);
            }
        }
        
        return result.toString();
    }
    
    /**
     * Get a string value from parsed JSON map
     * 
     * @param map Parsed JSON map
     * @param key Key to retrieve
     * @return String value, or null if not present
     * @throws ClassCastException if value is not a string
     */
    public static String getString(Map<String, Object> map, String key) {
        Object value = map.get(key);
        return value != null ? (String) value : null;
    }
    
    /**
     * Get a long value from parsed JSON map
     * 
     * @param map Parsed JSON map
     * @param key Key to retrieve
     * @return Long value, or null if not present
     * @throws ClassCastException if value is not a number
     */
    public static Long getLong(Map<String, Object> map, String key) {
        Object value = map.get(key);
        if (value == null) return null;
        if (value instanceof Long) return (Long) value;
        if (value instanceof Number) return ((Number) value).longValue();
        throw new ClassCastException("Value for key '" + key + "' is not a number");
    }
    
    /**
     * Get a boolean value from parsed JSON map
     * 
     * @param map Parsed JSON map
     * @param key Key to retrieve
     * @return Boolean value, or null if not present
     * @throws ClassCastException if value is not a boolean
     */
    public static Boolean getBoolean(Map<String, Object> map, String key) {
        Object value = map.get(key);
        return value != null ? (Boolean) value : null;
    }
}
