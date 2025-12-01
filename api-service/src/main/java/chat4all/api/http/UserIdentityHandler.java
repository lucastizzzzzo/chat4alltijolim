package chat4all.api.http;

import chat4all.api.auth.JwtAuthenticator;
import chat4all.api.util.JsonParser;
import com.datastax.oss.driver.api.core.CqlSession;
import com.datastax.oss.driver.api.core.cql.PreparedStatement;
import com.datastax.oss.driver.api.core.cql.ResultSet;
import com.datastax.oss.driver.api.core.cql.Row;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * UserIdentityHandler - Gerencia identidades de usuários (WhatsApp/Instagram)
 * 
 * Endpoints:
 * - POST /v1/users/identities - Vincular WhatsApp ou Instagram
 * - GET /v1/users/identities - Listar identidades do usuário
 * - DELETE /v1/users/identities/{platform}/{value} - Desvincular identidade
 * 
 * CONCEITOS EDUCACIONAIS:
 * 
 * 1. IDENTIDADE FEDERADA:
 *    - Um usuário pode ter múltiplas identidades (WhatsApp, Instagram, email)
 *    - Cada plataforma tem seu próprio formato de identificador
 *    - Sistema mapeia identidades externas → user_id interno
 * 
 * 2. FORMATOS DE IDENTIDADE:
 *    - WhatsApp: E.164 phone format (+5562996991812)
 *    - Instagram: Handle format (@username)
 *    - Validação de formato antes de armazenar
 * 
 * 3. CASOS DE USO:
 *    - Buscar user_id ao receber mensagem de número desconhecido
 *    - Enviar mensagem para WhatsApp/Instagram do usuário
 *    - Listar todos os canais de comunicação do usuário
 * 
 * 4. SEGURANÇA:
 *    - Verificação opcional (SMS/webhook) - não implementado aqui
 *    - Autenticação JWT obrigatória para vincular
 *    - Usuário só pode gerenciar suas próprias identidades
 */
public class UserIdentityHandler implements HttpHandler {
    
    private final CqlSession session;
    private final JwtAuthenticator jwtAuthenticator;
    private PreparedStatement insertIdentityStatement;
    private PreparedStatement selectIdentitiesStatement;
    private PreparedStatement selectByIdentityStatement;
    private PreparedStatement deleteIdentityStatement;
    
    // Regex para validação
    private static final Pattern WHATSAPP_PATTERN = Pattern.compile("^\\+[1-9]\\d{1,14}$"); // E.164 format
    private static final Pattern INSTAGRAM_PATTERN = Pattern.compile("^@[a-zA-Z0-9._]{1,30}$");
    
    public UserIdentityHandler(CqlSession session, JwtAuthenticator jwtAuthenticator) {
        if (session == null || jwtAuthenticator == null) {
            throw new IllegalArgumentException("Dependencies cannot be null");
        }
        this.session = session;
        this.jwtAuthenticator = jwtAuthenticator;
        prepareStatements();
    }
    
    private void prepareStatements() {
        insertIdentityStatement = session.prepare(
            "INSERT INTO chat4all.user_identities (user_id, platform, identity_value, verified, linked_at) " +
            "VALUES (?, ?, ?, ?, toTimestamp(now()))"
        );
        
        selectIdentitiesStatement = session.prepare(
            "SELECT platform, identity_value, verified, linked_at FROM chat4all.user_identities " +
            "WHERE user_id = ?"
        );
        
        selectByIdentityStatement = session.prepare(
            "SELECT user_id, verified FROM chat4all.user_identities " +
            "WHERE identity_value = ? ALLOW FILTERING"
        );
        
        deleteIdentityStatement = session.prepare(
            "DELETE FROM chat4all.user_identities " +
            "WHERE user_id = ? AND platform = ? AND identity_value = ?"
        );
    }
    
    @Override
    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        String path = exchange.getRequestURI().getPath();
        
        // Autenticação obrigatória
        String authHeader = exchange.getRequestHeaders().getFirst("Authorization");
        
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            sendErrorResponse(exchange, 401, "Unauthorized: missing or invalid JWT token");
            return;
        }
        
        String token = authHeader.substring(7); // Remove "Bearer " prefix
        String userId = null;
        try {
            userId = jwtAuthenticator.validateToken(token);
        } catch (Exception e) {
            sendErrorResponse(exchange, 401, "Unauthorized: " + e.getMessage());
            return;
        }
        
        try {
            if ("POST".equals(method) && path.equals("/v1/users/identities")) {
                handleLinkIdentity(exchange, userId);
            } else if ("GET".equals(method) && path.equals("/v1/users/identities")) {
                handleListIdentities(exchange, userId);
            } else if ("DELETE".equals(method) && path.startsWith("/v1/users/identities/")) {
                handleUnlinkIdentity(exchange, userId, path);
            } else {
                sendErrorResponse(exchange, 404, "Not found");
            }
        } catch (Exception e) {
            System.err.println("❌ Error handling identity request: " + e.getMessage());
            e.printStackTrace();
            sendErrorResponse(exchange, 500, "Internal server error");
        }
    }
    
    /**
     * POST /v1/users/identities
     * Body: {"platform": "whatsapp", "value": "+5562996991812"}
     */
    private void handleLinkIdentity(HttpExchange exchange, String userId) throws IOException {
        InputStream requestBody = exchange.getRequestBody();
        String bodyString = new String(requestBody.readAllBytes(), StandardCharsets.UTF_8);
        
        if (bodyString == null || bodyString.trim().isEmpty()) {
            sendErrorResponse(exchange, 400, "Request body cannot be empty");
            return;
        }
        
        Map<String, String> request = JsonParser.parseObject(bodyString);
        String platform = request.get("platform");
        String value = request.get("value");
        
        // Validação de campos
        if (platform == null || platform.trim().isEmpty()) {
            sendErrorResponse(exchange, 400, "Missing required field: platform");
            return;
        }
        
        if (value == null || value.trim().isEmpty()) {
            sendErrorResponse(exchange, 400, "Missing required field: value");
            return;
        }
        
        platform = platform.toLowerCase();
        
        // Validação de plataforma
        if (!platform.equals("whatsapp") && !platform.equals("instagram")) {
            sendErrorResponse(exchange, 400, "Invalid platform. Must be 'whatsapp' or 'instagram'");
            return;
        }
        
        // Validação de formato
        if (platform.equals("whatsapp") && !WHATSAPP_PATTERN.matcher(value).matches()) {
            sendErrorResponse(exchange, 400, 
                "Invalid WhatsApp format. Use E.164 format: +[country][number]");
            return;
        }
        
        if (platform.equals("instagram") && !INSTAGRAM_PATTERN.matcher(value).matches()) {
            sendErrorResponse(exchange, 400, 
                "Invalid Instagram format. Use: @username (1-30 chars)");
            return;
        }
        
        // Verificar se identidade já está em uso
        ResultSet existingCheck = session.execute(selectByIdentityStatement.bind(value));
        Row existing = existingCheck.one();
        if (existing != null && !existing.getString("user_id").equals(userId)) {
            sendErrorResponse(exchange, 409, 
                "Identity already linked to another user");
            return;
        }
        
        // Inserir identidade
        session.execute(insertIdentityStatement.bind(
            userId,
            platform,
            value,
            false  // não verificado por padrão
        ));
        
        String responseJson = String.format(
            "{\"user_id\":\"%s\",\"platform\":\"%s\",\"value\":\"%s\",\"verified\":false,\"linked_at\":\"%s\"}",
            escapeJson(userId),
            escapeJson(platform),
            escapeJson(value),
            Instant.now().toString()
        );
        
        System.out.println("✅ Identity linked: " + platform + " = " + value + " (user: " + userId + ")");
        sendResponse(exchange, 201, responseJson);
    }
    
    /**
     * GET /v1/users/identities
     */
    private void handleListIdentities(HttpExchange exchange, String userId) throws IOException {
        ResultSet results = session.execute(selectIdentitiesStatement.bind(userId));
        
        List<String> identitiesJson = new ArrayList<>();
        for (Row row : results) {
            String identityJson = String.format(
                "{\"platform\":\"%s\",\"value\":\"%s\",\"verified\":%s,\"linked_at\":\"%s\"}",
                escapeJson(row.getString("platform")),
                escapeJson(row.getString("identity_value")),
                row.getBoolean("verified"),
                row.getInstant("linked_at") != null ? row.getInstant("linked_at").toString() : "null"
            );
            identitiesJson.add(identityJson);
        }
        
        String responseJson = "{\"identities\":[" + String.join(",", identitiesJson) + "]}";
        sendResponse(exchange, 200, responseJson);
    }
    
    /**
     * DELETE /v1/users/identities/{platform}/{value}
     * Exemplo: DELETE /v1/users/identities/whatsapp/+5562996991812
     */
    private void handleUnlinkIdentity(HttpExchange exchange, String userId, String path) throws IOException {
        // Parse: /v1/users/identities/{platform}/{value}
        String[] parts = path.split("/");
        if (parts.length < 5) {
            sendErrorResponse(exchange, 400, "Invalid path format");
            return;
        }
        
        String platform = parts[4];
        String value = parts.length > 5 ? String.join("/", java.util.Arrays.copyOfRange(parts, 5, parts.length)) : "";
        
        if (value.isEmpty()) {
            sendErrorResponse(exchange, 400, "Missing identity value in path");
            return;
        }
        
        // Decodificar URL encoding (+ virou espaço)
        value = java.net.URLDecoder.decode(value, StandardCharsets.UTF_8);
        
        session.execute(deleteIdentityStatement.bind(userId, platform, value));
        
        String responseJson = String.format(
            "{\"message\":\"Identity unlinked\",\"platform\":\"%s\",\"value\":\"%s\"}",
            escapeJson(platform),
            escapeJson(value)
        );
        
        System.out.println("✅ Identity unlinked: " + platform + " = " + value + " (user: " + userId + ")");
        sendResponse(exchange, 200, responseJson);
    }
    
    private String escapeJson(String input) {
        if (input == null) return "";
        return input.replace("\\", "\\\\")
                   .replace("\"", "\\\"")
                   .replace("\n", "\\n")
                   .replace("\r", "\\r");
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
        String errorJson = String.format("{\"error\":\"%s\"}", escapeJson(message));
        sendResponse(exchange, statusCode, errorJson);
    }
}
