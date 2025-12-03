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
 * UserConversationsHandler - HTTP Handler for GET /v1/users/{user_id}/conversations
 * 
 * PROPÓSITO EDUCACIONAL: List User Conversations
 * ==================
 * 
 * ENDPOINT: GET /v1/users/{user_id}/conversations
 * 
 * EXEMPLO:
 * ```
 * GET /v1/users/03a6418c-790c-4606-b8c9-3de3a0458fcb/conversations
 * Authorization: Bearer eyJ...
 * ```
 * 
 * RESPONSE (200 OK):
 * ```json
 * {
 *   "user_id": "03a6418c-790c-4606-b8c9-3de3a0458fcb",
 *   "conversations": [
 *     {
 *       "conversation_id": "conv_festa_de_ano_novo_1764721674",
 *       "type": "private",
 *       "participant_ids": ["user_a", "instagram:@joaolucas"],
 *       "created_at": 1764721674000
 *     }
 *   ],
 *   "count": 1
 * }
 * ```
 * 
 * AUTENTICAÇÃO:
 * - Requer JWT válido (Authorization: Bearer <token>)
 * - Retorna 401 se token ausente/inválido
 * 
 * @author Chat4All Educational Project
 */
public class UserConversationsHandler implements HttpHandler {
    
    private final CassandraMessageRepository repository;
    private final JwtAuthenticator authenticator;
    
    public UserConversationsHandler(CassandraMessageRepository repository, JwtAuthenticator authenticator) {
        this.repository = repository;
        this.authenticator = authenticator;
    }
    
    @Override
    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        
        // Validar HTTP method
        if (!"GET".equals(method)) {
            sendErrorResponse(exchange, 405, "Method not allowed. Use GET.");
            return;
        }
        
        try {
            // AUTHENTICATION - Extrair e validar JWT token
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
            
            // Extrair user_id do path
            // Path format: /v1/users/{user_id}/conversations
            String path = exchange.getRequestURI().getPath();
            String[] pathParts = path.split("/");
            
            if (pathParts.length < 4) {
                sendErrorResponse(exchange, 400, "Invalid path. Expected: /v1/users/{user_id}/conversations");
                return;
            }
            
            String userId = pathParts[3]; // Index 3 = user_id
            
            if (userId == null || userId.trim().isEmpty()) {
                sendErrorResponse(exchange, 400, "user_id cannot be empty");
                return;
            }
            
            // Query Cassandra
            List<Map<String, Object>> conversations = repository.getConversationsByUser(userId);
            
            // Build response
            Map<String, Object> response = new HashMap<>();
            response.put("user_id", userId);
            response.put("conversations", conversations);
            response.put("count", conversations.size());
            
            String responseJson = JsonParser.toJson(response);
            sendResponse(exchange, 200, responseJson);
            
        } catch (IllegalArgumentException e) {
            sendErrorResponse(exchange, 400, e.getMessage());
            
        } catch (RuntimeException e) {
            System.err.println("Error in UserConversationsHandler: " + e.getMessage());
            sendErrorResponse(exchange, 500, "Internal server error");
        }
    }
    
    private void sendResponse(HttpExchange exchange, int statusCode, String body) throws IOException {
        byte[] responseBytes = body.getBytes(StandardCharsets.UTF_8);
        
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(statusCode, responseBytes.length);
        
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(responseBytes);
        }
    }
    
    private void sendErrorResponse(HttpExchange exchange, int statusCode, String message) throws IOException {
        String errorJson = String.format("{\"error\":\"%s\"}", message);
        sendResponse(exchange, statusCode, errorJson);
    }
}
