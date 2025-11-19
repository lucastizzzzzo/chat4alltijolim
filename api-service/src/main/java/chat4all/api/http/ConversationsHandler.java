package chat4all.api.http;

import chat4all.api.auth.JwtAuthenticator;
import chat4all.api.auth.JwtAuthenticationException;
import chat4all.api.cassandra.CassandraMessageRepository;
import chat4all.api.util.JsonParser;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * ConversationsHandler - HTTP Handler for GET /v1/conversations/{id}/messages
 * 
 * PROPÓSITO EDUCACIONAL: RESTful API + Pagination Pattern
 * ==================
 * 
 * ENDPOINT: GET /v1/conversations/{conversation_id}/messages
 * 
 * QUERY PARAMETERS:
 * - limit: Máximo de mensagens (default: 50, max: 100)
 * - offset: Quantas mensagens pular (default: 0)
 * 
 * EXEMPLO:
 * ```
 * GET /v1/conversations/conv_abc/messages?limit=20&offset=0
 * Authorization: Bearer eyJ...
 * ```
 * 
 * RESPONSE (200 OK):
 * ```json
 * {
 *   "conversation_id": "conv_abc",
 *   "messages": [
 *     {
 *       "message_id": "msg_123",
 *       "sender_id": "user_a",
 *       "content": "Hello!",
 *       "timestamp": 1700000000000,
 *       "status": "DELIVERED"
 *     }
 *   ],
 *   "pagination": {
 *     "limit": 20,
 *     "offset": 0,
 *     "returned": 15
 *   }
 * }
 * ```
 * 
 * PAGINATION STRATEGY:
 * - Limit/Offset (simples, didático)
 * - Cliente: incrementar offset para próxima página
 * - Exemplo: page 1 (offset=0), page 2 (offset=50), page 3 (offset=100)
 * 
 * AUTENTICAÇÃO:
 * - Requer JWT válido (Authorization: Bearer <token>)
 * - Retorna 401 se token ausente/inválido
 * 
 * @author Chat4All Educational Project
 */
public class ConversationsHandler implements HttpHandler {
    
    private final CassandraMessageRepository repository;
    private final JwtAuthenticator authenticator;
    
    public ConversationsHandler(CassandraMessageRepository repository, JwtAuthenticator authenticator) {
        this.repository = repository;
        this.authenticator = authenticator;
    }
    
    /**
     * Handles GET /v1/conversations/{id}/messages
     * 
     * FLUXO:
     * 1. Validar HTTP method (GET)
     * 2. Autenticar JWT token
     * 3. Extrair conversation_id do path
     * 4. Parsear query params (limit, offset)
     * 5. Query Cassandra
     * 6. Retornar JSON com mensagens + metadata pagination
     * 
     * ERROR HANDLING:
     * - 401: Token ausente/inválido
     * - 400: conversation_id inválido
     * - 404: Conversação não encontrada (simplificação: sempre retorna 200 com array vazio)
     * - 500: Erro interno
     * 
     * @param exchange HTTP request/response
     * @throws IOException if I/O error occurs
     */
    @Override
    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        
        // 1. Validar HTTP method
        if (!"GET".equals(method)) {
            sendErrorResponse(exchange, 405, "Method not allowed. Use GET.");
            return;
        }
        
        try {
            // 2. AUTHENTICATION - Extrair e validar JWT token
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
            
            // 3. Extrair conversation_id do path
            // Path format: /v1/conversations/{conversation_id}/messages
            String path = exchange.getRequestURI().getPath();
            String[] pathParts = path.split("/");
            
            if (pathParts.length < 4) {
                sendErrorResponse(exchange, 400, "Invalid path. Expected: /v1/conversations/{id}/messages");
                return;
            }
            
            String conversationId = pathParts[3]; // Index 3 = conversation_id
            
            if (conversationId == null || conversationId.trim().isEmpty()) {
                sendErrorResponse(exchange, 400, "conversation_id cannot be empty");
                return;
            }
            
            // 4. Parsear query parameters
            String query = exchange.getRequestURI().getQuery();
            int limit = 50; // default
            int offset = 0; // default
            
            if (query != null) {
                Map<String, String> queryParams = parseQueryParams(query);
                
                if (queryParams.containsKey("limit")) {
                    try {
                        limit = Integer.parseInt(queryParams.get("limit"));
                    } catch (NumberFormatException e) {
                        sendErrorResponse(exchange, 400, "Invalid limit parameter. Must be a number.");
                        return;
                    }
                }
                
                if (queryParams.containsKey("offset")) {
                    try {
                        offset = Integer.parseInt(queryParams.get("offset"));
                    } catch (NumberFormatException e) {
                        sendErrorResponse(exchange, 400, "Invalid offset parameter. Must be a number.");
                        return;
                    }
                }
            }
            
            // 5. Query Cassandra
            List<Map<String, Object>> messages = repository.getMessages(conversationId, limit, offset);
            
            // 6. Build response
            Map<String, Object> response = new HashMap<>();
            response.put("conversation_id", conversationId);
            response.put("messages", messages);
            
            // Pagination metadata
            Map<String, Object> pagination = new HashMap<>();
            pagination.put("limit", limit);
            pagination.put("offset", offset);
            pagination.put("returned", messages.size());
            response.put("pagination", pagination);
            
            String responseJson = JsonParser.toJson(response);
            sendResponse(exchange, 200, responseJson);
            
        } catch (IllegalArgumentException e) {
            sendErrorResponse(exchange, 400, e.getMessage());
            
        } catch (RuntimeException e) {
            System.err.println("Error in ConversationsHandler: " + e.getMessage());
            sendErrorResponse(exchange, 500, "Internal server error");
        }
    }
    
    /**
     * Parseia query string em Map
     * 
     * EXEMPLO:
     * "limit=20&offset=10" → {limit: "20", offset: "10"}
     * 
     * @param query Query string (sem '?')
     * @return Map com parâmetros
     */
    private Map<String, String> parseQueryParams(String query) {
        Map<String, String> params = new HashMap<>();
        
        if (query == null || query.isEmpty()) {
            return params;
        }
        
        String[] pairs = query.split("&");
        for (String pair : pairs) {
            String[] keyValue = pair.split("=");
            if (keyValue.length == 2) {
                params.put(keyValue[0], keyValue[1]);
            }
        }
        
        return params;
    }
    
    /**
     * Envia HTTP response
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
     * Envia HTTP error response
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
