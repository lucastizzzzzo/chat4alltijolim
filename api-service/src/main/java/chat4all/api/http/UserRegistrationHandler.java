package chat4all.api.http;

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
import java.util.Map;
import java.util.UUID;
import java.util.regex.Pattern;
import java.time.Instant;

/**
 * UserRegistrationHandler - Endpoint de registro de usuários HTTP
 * 
 * Implementa o endpoint POST /auth/register para criar novos usuários.
 * 
 * CONCEITOS EDUCACIONAIS:
 * 
 * 1. REGISTRO DE USUÁRIOS:
 *    - Validação de campos obrigatórios (username, password, email)
 *    - Verificação de unicidade (username e email únicos)
 *    - Geração de user_id (UUID v4)
 *    - Persistência no Cassandra
 * 
 * 2. VALIDAÇÕES:
 *    - Username: 3-50 caracteres, alfanumérico + underscore
 *    - Password: mínimo 6 caracteres
 *    - Email: formato válido (regex simples)
 *    - Unicidade: username e email devem ser únicos no sistema
 * 
 * 3. SEGURANÇA:
 *    - ⚠️ Passwords em plain text (TEMPORÁRIO - apenas demonstração)
 *    - ✅ Em produção: usar BCrypt.hashpw(password, BCrypt.gensalt())
 *    - ✅ Validação de entrada contra injection
 *    - ✅ Rate limiting recomendado (prevenir spam)
 * 
 * 4. CÓDIGOS HTTP:
 *    - 201 Created: Usuário criado com sucesso
 *    - 400 Bad Request: Campos inválidos ou faltando
 *    - 409 Conflict: Username ou email já existe
 *    - 405 Method Not Allowed: Método diferente de POST
 *    - 500 Internal Server Error: Erro no banco
 * 
 * FORMATO REQUEST:
 * ```
 * POST /auth/register HTTP/1.1
 * Content-Type: application/json
 * 
 * {
 *   "username": "lucas",
 *   "password": "senha123",
 *   "email": "lucas@example.com"
 * }
 * ```
 * 
 * FORMATO RESPONSE (201 Created):
 * ```
 * {
 *   "user_id": "uuid-aqui",
 *   "username": "lucas",
 *   "email": "lucas@example.com",
 *   "created_at": "2024-11-30T10:30:45Z"
 * }
 * ```
 */
public class UserRegistrationHandler implements HttpHandler {
    
    private final CqlSession session;
    private PreparedStatement insertUserStatement;
    private PreparedStatement checkUsernameStatement;
    private PreparedStatement checkEmailStatement;
    
    // Regex simples para validação
    private static final Pattern USERNAME_PATTERN = Pattern.compile("^[a-zA-Z0-9_]{3,50}$");
    private static final Pattern EMAIL_PATTERN = Pattern.compile("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$");
    
    /**
     * Construtor do UserRegistrationHandler.
     * 
     * @param session Sessão Cassandra (injetada)
     */
    public UserRegistrationHandler(CqlSession session) {
        if (session == null) {
            throw new IllegalArgumentException("CqlSession cannot be null");
        }
        this.session = session;
        prepareStatements();
    }
    
    /**
     * Prepara statements Cassandra para reutilização.
     * Melhora performance evitando parse repetido.
     */
    private void prepareStatements() {
        // Criar tabela se não existir (provisório - deveria estar em schema.cql)
        session.execute("""
            CREATE TABLE IF NOT EXISTS chat4all.users (
                user_id UUID PRIMARY KEY,
                username TEXT,
                password TEXT,
                email TEXT,
                created_at TIMESTAMP
            )
        """);
        
        // Índices para consultas por username e email
        session.execute("CREATE INDEX IF NOT EXISTS users_username_idx ON chat4all.users (username)");
        session.execute("CREATE INDEX IF NOT EXISTS users_email_idx ON chat4all.users (email)");
        
        // Prepared statements
        insertUserStatement = session.prepare(
            "INSERT INTO chat4all.users (user_id, username, password, email) " +
            "VALUES (?, ?, ?, ?)"
        );
        
        checkUsernameStatement = session.prepare(
            "SELECT user_id FROM chat4all.users WHERE username = ? ALLOW FILTERING"
        );
        
        checkEmailStatement = session.prepare(
            "SELECT user_id FROM chat4all.users WHERE email = ? ALLOW FILTERING"
        );
    }
    
    @Override
    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        
        // 1. Validação de método HTTP
        if (!"POST".equals(method)) {
            sendErrorResponse(exchange, 405, "Method not allowed. Use POST.");
            return;
        }
        
        try {
            // 2. Leitura e parse do body
            InputStream requestBody = exchange.getRequestBody();
            String bodyString = new String(requestBody.readAllBytes(), StandardCharsets.UTF_8);
            
            if (bodyString == null || bodyString.trim().isEmpty()) {
                sendErrorResponse(exchange, 400, "Request body cannot be empty");
                return;
            }
            
            Map<String, String> userRequest = JsonParser.parseObject(bodyString);
            
            // 3. Extração de campos
            String username = userRequest.get("username");
            String password = userRequest.get("password");
            String email = userRequest.get("email");
            
            // 4. Validação de campos obrigatórios
            if (username == null || username.trim().isEmpty()) {
                sendErrorResponse(exchange, 400, "Missing required field: username");
                return;
            }
            
            if (password == null || password.trim().isEmpty()) {
                sendErrorResponse(exchange, 400, "Missing required field: password");
                return;
            }
            
            if (email == null || email.trim().isEmpty()) {
                sendErrorResponse(exchange, 400, "Missing required field: email");
                return;
            }
            
            // 5. Validação de formato
            if (!USERNAME_PATTERN.matcher(username).matches()) {
                sendErrorResponse(exchange, 400, 
                    "Invalid username format. Use 3-50 alphanumeric characters or underscore.");
                return;
            }
            
            if (password.length() < 6) {
                sendErrorResponse(exchange, 400, 
                    "Password too short. Minimum 6 characters required.");
                return;
            }
            
            if (!EMAIL_PATTERN.matcher(email).matches()) {
                sendErrorResponse(exchange, 400, 
                    "Invalid email format.");
                return;
            }
            
            // 6. Verificar unicidade de username
            ResultSet usernameCheck = session.execute(checkUsernameStatement.bind(username));
            Row existingUser = usernameCheck.one();
            if (existingUser != null) {
                sendErrorResponse(exchange, 409, "Username already exists");
                return;
            }
            
            // 7. Verificar unicidade de email
            ResultSet emailCheck = session.execute(checkEmailStatement.bind(email));
            Row existingEmail = emailCheck.one();
            if (existingEmail != null) {
                sendErrorResponse(exchange, 409, "Email already registered");
                return;
            }
            
            // 8. Gerar user_id (UUID v4 convertido para String)
            String userId = UUID.randomUUID().toString();
            
            // 9. Inserir no banco
            // ⚠️ ATENÇÃO: Password em plain text - EM PRODUÇÃO usar BCrypt!
            // String hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());
            session.execute(insertUserStatement.bind(
                userId,
                username,
                password, // ⚠️ Plain text - trocar por hash em produção
                email
            ));
            
            // 10. Resposta de sucesso (201 Created)
            String timestamp = Instant.now().toString();
            String responseJson = String.format(
                "{\"user_id\":\"%s\",\"username\":\"%s\",\"email\":\"%s\",\"created_at\":\"%s\"}",
                userId,
                escapeJson(username),
                escapeJson(email),
                timestamp
            );
            
            System.out.println("✅ User registered: " + username + " (id: " + userId + ")");
            sendResponse(exchange, 201, responseJson);
            
        } catch (Exception e) {
            System.err.println("❌ Error registering user: " + e.getMessage());
            e.printStackTrace();
            sendErrorResponse(exchange, 500, "Internal server error");
        }
    }
    
    /**
     * Escapa caracteres especiais para JSON.
     */
    private String escapeJson(String input) {
        if (input == null) return "";
        return input.replace("\\", "\\\\")
                   .replace("\"", "\\\"")
                   .replace("\n", "\\n")
                   .replace("\r", "\\r");
    }
    
    /**
     * Envia resposta HTTP de sucesso.
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
     * Envia resposta HTTP de erro.
     */
    private void sendErrorResponse(HttpExchange exchange, int statusCode, String message) throws IOException {
        String errorJson = String.format("{\"error\":\"%s\"}", escapeJson(message));
        sendResponse(exchange, statusCode, errorJson);
    }
}
