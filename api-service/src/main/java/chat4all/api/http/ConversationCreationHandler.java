package chat4all.api.http;

import chat4all.api.auth.JwtAuthenticator;
import chat4all.api.auth.JwtAuthenticationException;
import chat4all.api.resolver.IdentityResolver;
import chat4all.api.util.JsonParser;
import com.datastax.oss.driver.api.core.CqlSession;
import com.datastax.oss.driver.api.core.cql.PreparedStatement;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * ConversationCreationHandler - Cria conversas e registra na tabela conversations_by_user
 * 
 * ENDPOINT: POST /v1/conversations/create
 * 
 * REQUEST:
 * {
 *   "conversation_id": "conv_festa_123",
 *   "name": "Festa de Ano Novo",
 *   "participant_ids": ["user_a", "user_b", "instagram:@joao"]
 * }
 * 
 * RESPONSE (201 Created):
 * {
 *   "conversation_id": "conv_festa_123",
 *   "status": "created"
 * }
 */
public class ConversationCreationHandler implements HttpHandler {
    
    private final CqlSession session;
    private final JwtAuthenticator authenticator;
    private final IdentityResolver identityResolver;
    private final PreparedStatement insertConversation;
    private final PreparedStatement insertConversationByUser;
    
    public ConversationCreationHandler(CqlSession session, JwtAuthenticator authenticator, IdentityResolver identityResolver) {
        this.session = session;
        this.authenticator = authenticator;
        this.identityResolver = identityResolver;
        
        // Inserir na tabela conversations
        this.insertConversation = session.prepare(
            "INSERT INTO chat4all.conversations (conversation_id, type, participant_ids, name, created_at) " +
            "VALUES (?, ?, ?, ?, ?)"
        );
        
        // Inserir na tabela conversations_by_user (denormalizada)
        this.insertConversationByUser = session.prepare(
            "INSERT INTO chat4all.conversations_by_user (user_id, conversation_id, type, participant_ids, name, created_at) " +
            "VALUES (?, ?, ?, ?, ?, ?)"
        );
        
        System.out.println("✓ ConversationCreationHandler initialized");
    }
    
    @Override
    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        
        if (!"POST".equals(method)) {
            sendErrorResponse(exchange, 405, "Method not allowed. Use POST.");
            return;
        }
        
        try {
            // Autenticação
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
            
            // Ler body
            InputStream requestBody = exchange.getRequestBody();
            String bodyString = new String(requestBody.readAllBytes(), StandardCharsets.UTF_8);
            
            if (bodyString.trim().isEmpty()) {
                sendErrorResponse(exchange, 400, "Request body cannot be empty");
                return;
            }
            
            // Parse JSON
            Map<String, Object> data = JsonParser.parseRequest(bodyString);
            
            String conversationId = (String) data.get("conversation_id");
            String name = (String) data.get("name"); // Nome da conversa (opcional)
            @SuppressWarnings("unchecked")
            List<String> participantIds = (List<String>) data.get("participant_ids");
            
            if (conversationId == null || conversationId.trim().isEmpty()) {
                sendErrorResponse(exchange, 400, "conversation_id is required");
                return;
            }
            
            if (participantIds == null || participantIds.isEmpty()) {
                sendErrorResponse(exchange, 400, "participant_ids is required and must not be empty");
                return;
            }
            
            String type = "private"; // Por padrão
            Instant now = Instant.now();
            
            // 1. Inserir na tabela conversations
            session.execute(insertConversation.bind(
                conversationId,
                type,
                participantIds,
                name,
                now
            ));
            
            System.out.println("[ConversationCreation] Created conversation: " + conversationId);
            
            // 2. Inserir na tabela conversations_by_user para cada participante
            // Resolver identidades externas (instagram:@..., whatsapp:+...) para user_ids
            List<String> resolvedUserIds = new ArrayList<>();
            for (String participantId : participantIds) {
                // Tentar resolver para user_id
                String userId = identityResolver.resolveToUserId(participantId);
                if (userId != null && !userId.equals(participantId)) {
                    // Foi resolvido para um user_id diferente
                    resolvedUserIds.add(userId);
                    System.out.println("[ConversationCreation] Resolved " + participantId + " → " + userId);
                } else if (!participantId.startsWith("whatsapp:") && !participantId.startsWith("instagram:")) {
                    // Já é um user_id interno (UUID)
                    resolvedUserIds.add(participantId);
                }
            }
            
            // Registrar conversa para cada user_id resolvido
            for (String userId : resolvedUserIds) {
                session.execute(insertConversationByUser.bind(
                    userId,
                    conversationId,
                    type,
                    participantIds,
                    name,
                    now
                ));
                System.out.println("[ConversationCreation] Registered for user: " + userId);
            }
            
            // Response
            String nameField = name != null ? ",\"name\":\"" + name + "\"" : "";
            String response = String.format(
                "{\"conversation_id\":\"%s\",\"status\":\"created\",\"participants\":%d%s}",
                conversationId,
                participantIds.size(),
                nameField
            );
            
            sendResponse(exchange, 201, response);
            
        } catch (Exception e) {
            System.err.println("[ConversationCreation] Error: " + e.getMessage());
            e.printStackTrace();
            sendErrorResponse(exchange, 500, "Internal server error: " + e.getMessage());
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
