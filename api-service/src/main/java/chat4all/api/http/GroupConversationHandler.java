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
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * GroupConversationHandler - Gerencia conversas em grupo
 * 
 * Endpoints:
 * - POST /v1/groups - Criar grupo
 * - GET /v1/groups/{id} - Obter detalhes do grupo
 * - POST /v1/groups/{id}/members - Adicionar membro
 * - DELETE /v1/groups/{id}/members/{user_id} - Remover membro
 * - PUT /v1/groups/{id}/admins/{user_id} - Promover a admin
 * 
 * CONCEITOS EDUCACIONAIS:
 * 
 * 1. GRUPO vs CONVERSA 1:1:
 *    - Grupo: N participantes (3+), admins, permissões
 *    - 1:1: 2 participantes, sem hierarquia
 *    - Grupos usam tabela separada para metadados
 * 
 * 2. PERMISSÕES:
 *    - Admin: pode adicionar/remover membros, promover outros admins
 *    - Membro: pode apenas enviar/receber mensagens
 *    - Criador do grupo é admin automaticamente
 * 
 * 3. ESCALABILIDADE:
 *    - member_ids como LIST (denormalizado) - rápido para ler
 *    - Limite de 256 membros (configurável)
 *    - Para >256, migrar para tabela separada group_members
 * 
 * 4. MENSAGENS DE GRUPO:
 *    - Usa mesma tabela messages (conversation_id = group_id)
 *    - Connector envia para TODOS os membros do grupo
 *    - Status individual por membro (delivered/read tracking)
 */
public class GroupConversationHandler implements HttpHandler {
    
    private final CqlSession session;
    private final JwtAuthenticator jwtAuthenticator;
    private PreparedStatement insertGroupStatement;
    private PreparedStatement selectGroupStatement;
    private PreparedStatement updateMembersStatement;
    private PreparedStatement updateAdminsStatement;
    
    private static final int MAX_GROUP_MEMBERS = 256;
    
    public GroupConversationHandler(CqlSession session, JwtAuthenticator jwtAuthenticator) {
        if (session == null || jwtAuthenticator == null) {
            throw new IllegalArgumentException("Dependencies cannot be null");
        }
        this.session = session;
        this.jwtAuthenticator = jwtAuthenticator;
        prepareStatements();
    }
    
    private void prepareStatements() {
        insertGroupStatement = session.prepare(
            "INSERT INTO chat4all.group_conversations " +
            "(group_id, name, description, member_ids, admin_ids, max_members, created_at, created_by) " +
            "VALUES (?, ?, ?, ?, ?, ?, toTimestamp(now()), ?)"
        );
        
        selectGroupStatement = session.prepare(
            "SELECT group_id, name, description, member_ids, admin_ids, max_members, created_at, created_by " +
            "FROM chat4all.group_conversations WHERE group_id = ?"
        );
        
        updateMembersStatement = session.prepare(
            "UPDATE chat4all.group_conversations SET member_ids = ? WHERE group_id = ?"
        );
        
        updateAdminsStatement = session.prepare(
            "UPDATE chat4all.group_conversations SET admin_ids = ? WHERE group_id = ?"
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
            if ("POST".equals(method) && path.equals("/v1/groups")) {
                handleCreateGroup(exchange, userId);
            } else if ("GET".equals(method) && path.matches("/v1/groups/[^/]+")) {
                handleGetGroup(exchange, path);
            } else if ("POST".equals(method) && path.matches("/v1/groups/[^/]+/members")) {
                handleAddMember(exchange, userId, path);
            } else if ("DELETE".equals(method) && path.matches("/v1/groups/[^/]+/members/[^/]+")) {
                handleRemoveMember(exchange, userId, path);
            } else if ("PUT".equals(method) && path.matches("/v1/groups/[^/]+/admins/[^/]+")) {
                handlePromoteAdmin(exchange, userId, path);
            } else {
                sendErrorResponse(exchange, 404, "Not found");
            }
        } catch (Exception e) {
            System.err.println("❌ Error handling group request: " + e.getMessage());
            e.printStackTrace();
            sendErrorResponse(exchange, 500, "Internal server error");
        }
    }
    
    /**
     * POST /v1/groups
     * Body: {"name": "Equipe Projeto", "description": "Grupo do projeto final", "initial_members": ["user2", "user3"]}
     */
    private void handleCreateGroup(HttpExchange exchange, String userId) throws IOException {
        InputStream requestBody = exchange.getRequestBody();
        String bodyString = new String(requestBody.readAllBytes(), StandardCharsets.UTF_8);
        
        if (bodyString == null || bodyString.trim().isEmpty()) {
            sendErrorResponse(exchange, 400, "Request body cannot be empty");
            return;
        }
        
        Map<String, Object> request = JsonParser.parseRequest(bodyString);
        String name = (String) request.get("name");
        String description = (String) request.get("description");
        List<?> initialMembersRaw = (List<?>) request.get("initial_members");
        
        // Validação
        if (name == null || name.trim().isEmpty()) {
            sendErrorResponse(exchange, 400, "Missing required field: name");
            return;
        }
        
        if (name.length() > 100) {
            sendErrorResponse(exchange, 400, "Group name too long (max 100 chars)");
            return;
        }
        
        // Membros iniciais + criador
        List<String> memberIds = new ArrayList<>();
        memberIds.add(userId); // Criador sempre é membro
        
        if (initialMembersRaw != null) {
            for (Object member : initialMembersRaw) {
                String memberId = member.toString();
                if (!memberIds.contains(memberId)) {
                    memberIds.add(memberId);
                }
            }
        }
        
        if (memberIds.size() > MAX_GROUP_MEMBERS) {
            sendErrorResponse(exchange, 400, "Too many members (max " + MAX_GROUP_MEMBERS + ")");
            return;
        }
        
        // Admins: apenas criador inicialmente
        List<String> adminIds = new ArrayList<>();
        adminIds.add(userId);
        
        // Gerar group_id
        String groupId = "group_" + UUID.randomUUID().toString();
        
        // Inserir no banco
        session.execute(insertGroupStatement.bind(
            groupId,
            name,
            description != null ? description : "",
            memberIds,
            adminIds,
            MAX_GROUP_MEMBERS,
            userId
        ));
        
        String responseJson = String.format(
            "{\"group_id\":\"%s\",\"name\":\"%s\",\"description\":\"%s\",\"members\":%d,\"created_at\":\"%s\"}",
            escapeJson(groupId),
            escapeJson(name),
            escapeJson(description != null ? description : ""),
            memberIds.size(),
            Instant.now().toString()
        );
        
        System.out.println("✅ Group created: " + groupId + " (" + name + ") by " + userId);
        sendResponse(exchange, 201, responseJson);
    }
    
    /**
     * GET /v1/groups/{id}
     */
    private void handleGetGroup(HttpExchange exchange, String path) throws IOException {
        String groupId = path.substring("/v1/groups/".length());
        
        ResultSet result = session.execute(selectGroupStatement.bind(groupId));
        Row row = result.one();
        
        if (row == null) {
            sendErrorResponse(exchange, 404, "Group not found");
            return;
        }
        
        List<String> memberIds = row.getList("member_ids", String.class);
        List<String> adminIds = row.getList("admin_ids", String.class);
        
        String membersJson = "[\"" + String.join("\",\"", memberIds) + "\"]";
        String adminsJson = "[\"" + String.join("\",\"", adminIds) + "\"]";
        
        String responseJson = String.format(
            "{\"group_id\":\"%s\",\"name\":\"%s\",\"description\":\"%s\"," +
            "\"members\":%s,\"admins\":%s,\"max_members\":%d,\"created_by\":\"%s\",\"created_at\":\"%s\"}",
            escapeJson(row.getString("group_id")),
            escapeJson(row.getString("name")),
            escapeJson(row.getString("description")),
            membersJson,
            adminsJson,
            row.getInt("max_members"),
            escapeJson(row.getString("created_by")),
            row.getInstant("created_at") != null ? row.getInstant("created_at").toString() : "null"
        );
        
        sendResponse(exchange, 200, responseJson);
    }
    
    /**
     * POST /v1/groups/{id}/members
     * Body: {"user_id": "user123"}
     */
    private void handleAddMember(HttpExchange exchange, String userId, String path) throws IOException {
        String groupId = path.split("/")[3];
        
        // Verificar se usuário é admin
        if (!isAdmin(groupId, userId)) {
            sendErrorResponse(exchange, 403, "Only admins can add members");
            return;
        }
        
        InputStream requestBody = exchange.getRequestBody();
        String bodyString = new String(requestBody.readAllBytes(), StandardCharsets.UTF_8);
        Map<String, String> request = JsonParser.parseObject(bodyString);
        String newMemberId = request.get("user_id");
        
        if (newMemberId == null || newMemberId.trim().isEmpty()) {
            sendErrorResponse(exchange, 400, "Missing required field: user_id");
            return;
        }
        
        // Buscar membros atuais
        ResultSet result = session.execute(selectGroupStatement.bind(groupId));
        Row row = result.one();
        
        if (row == null) {
            sendErrorResponse(exchange, 404, "Group not found");
            return;
        }
        
        List<String> memberIds = new ArrayList<>(row.getList("member_ids", String.class));
        
        if (memberIds.contains(newMemberId)) {
            sendErrorResponse(exchange, 409, "User already in group");
            return;
        }
        
        if (memberIds.size() >= MAX_GROUP_MEMBERS) {
            sendErrorResponse(exchange, 400, "Group is full");
            return;
        }
        
        // Adicionar membro
        memberIds.add(newMemberId);
        session.execute(updateMembersStatement.bind(memberIds, groupId));
        
        String responseJson = String.format(
            "{\"message\":\"Member added\",\"group_id\":\"%s\",\"user_id\":\"%s\",\"total_members\":%d}",
            escapeJson(groupId),
            escapeJson(newMemberId),
            memberIds.size()
        );
        
        System.out.println("✅ Member added to group " + groupId + ": " + newMemberId);
        sendResponse(exchange, 200, responseJson);
    }
    
    /**
     * DELETE /v1/groups/{id}/members/{user_id}
     */
    private void handleRemoveMember(HttpExchange exchange, String userId, String path) throws IOException {
        String[] parts = path.split("/");
        String groupId = parts[3];
        String targetUserId = parts[5];
        
        // Verificar se usuário é admin
        if (!isAdmin(groupId, userId)) {
            sendErrorResponse(exchange, 403, "Only admins can remove members");
            return;
        }
        
        // Buscar membros e admins atuais
        ResultSet result = session.execute(selectGroupStatement.bind(groupId));
        Row row = result.one();
        
        if (row == null) {
            sendErrorResponse(exchange, 404, "Group not found");
            return;
        }
        
        List<String> memberIds = new ArrayList<>(row.getList("member_ids", String.class));
        List<String> adminIds = new ArrayList<>(row.getList("admin_ids", String.class));
        
        if (!memberIds.contains(targetUserId)) {
            sendErrorResponse(exchange, 404, "User not in group");
            return;
        }
        
        // Não pode remover o criador
        if (targetUserId.equals(row.getString("created_by"))) {
            sendErrorResponse(exchange, 403, "Cannot remove group creator");
            return;
        }
        
        // Remover de membros e admins
        memberIds.remove(targetUserId);
        adminIds.remove(targetUserId);
        
        session.execute(updateMembersStatement.bind(memberIds, groupId));
        session.execute(updateAdminsStatement.bind(adminIds, groupId));
        
        String responseJson = String.format(
            "{\"message\":\"Member removed\",\"group_id\":\"%s\",\"user_id\":\"%s\"}",
            escapeJson(groupId),
            escapeJson(targetUserId)
        );
        
        System.out.println("✅ Member removed from group " + groupId + ": " + targetUserId);
        sendResponse(exchange, 200, responseJson);
    }
    
    /**
     * PUT /v1/groups/{id}/admins/{user_id}
     */
    private void handlePromoteAdmin(HttpExchange exchange, String userId, String path) throws IOException {
        String[] parts = path.split("/");
        String groupId = parts[3];
        String targetUserId = parts[5];
        
        // Verificar se usuário é admin
        if (!isAdmin(groupId, userId)) {
            sendErrorResponse(exchange, 403, "Only admins can promote members");
            return;
        }
        
        // Buscar admins atuais
        ResultSet result = session.execute(selectGroupStatement.bind(groupId));
        Row row = result.one();
        
        if (row == null) {
            sendErrorResponse(exchange, 404, "Group not found");
            return;
        }
        
        List<String> memberIds = row.getList("member_ids", String.class);
        List<String> adminIds = new ArrayList<>(row.getList("admin_ids", String.class));
        
        if (!memberIds.contains(targetUserId)) {
            sendErrorResponse(exchange, 404, "User not in group");
            return;
        }
        
        if (adminIds.contains(targetUserId)) {
            sendErrorResponse(exchange, 409, "User already is admin");
            return;
        }
        
        // Promover a admin
        adminIds.add(targetUserId);
        session.execute(updateAdminsStatement.bind(adminIds, groupId));
        
        String responseJson = String.format(
            "{\"message\":\"User promoted to admin\",\"group_id\":\"%s\",\"user_id\":\"%s\"}",
            escapeJson(groupId),
            escapeJson(targetUserId)
        );
        
        System.out.println("✅ User promoted to admin in group " + groupId + ": " + targetUserId);
        sendResponse(exchange, 200, responseJson);
    }
    
    private boolean isAdmin(String groupId, String userId) {
        ResultSet result = session.execute(selectGroupStatement.bind(groupId));
        Row row = result.one();
        if (row == null) return false;
        
        List<String> adminIds = row.getList("admin_ids", String.class);
        return adminIds != null && adminIds.contains(userId);
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
