package chat4all.api.http;

import chat4all.api.auth.TokenGenerator;
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

/**
 * AuthHandler - Endpoint de autenticação HTTP
 * 
 * Implementa o endpoint POST /auth/token para gerar tokens JWT.
 * 
 * CONCEITOS EDUCACIONAIS:
 * 
 * 1. AUTENTICAÇÃO vs AUTORIZAÇÃO:
 *    - Autenticação: "Quem é você?" → Validar username/password, gerar token
 *    - Autorização: "O que você pode fazer?" → Validar token, verificar permissões
 *    - Este handler faz AUTENTICAÇÃO (fase 1)
 * 
 * 2. AUTENTICAÇÃO STATELESS:
 *    - Servidor NÃO guarda sessão (sem cookies, sem cache)
 *    - Cliente envia credenciais → Servidor retorna token
 *    - Cliente guarda token → Envia token em cada request (Authorization: Bearer <token>)
 *    - Servidor valida token → Extrai user_id
 *    - BENEFÍCIO: Escalabilidade horizontal (qualquer servidor pode validar token)
 * 
 * 3. HARDCODED USERS (temporário - apenas para demonstração):
 *    - Em produção, usuários viriam do banco de dados (Cassandra)
 *    - Passwords seriam hashados com bcrypt/argon2 (NUNCA plain text!)
 *    - Aqui usamos Map.of() para fins didáticos
 * 
 * 4. CÓDIGOS HTTP:
 *    - 200 OK: Credenciais válidas → Token gerado
 *    - 400 Bad Request: Username ou password faltando
 *    - 401 Unauthorized: Credenciais inválidas ou usuário não existe
 *    - 405 Method Not Allowed: Método diferente de POST
 * 
 * 5. FORMATO DE RESPOSTA (RFC 6749 - OAuth 2.0):
 *    ```json
 *    {
 *      "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
 *      "token_type": "Bearer",
 *      "expires_in": 3600
 *    }
 *    ```
 *    - access_token: JWT gerado
 *    - token_type: "Bearer" (indica que token deve ser enviado no header Authorization: Bearer <token>)
 *    - expires_in: Tempo de expiração em segundos (3600 = 1 hora)
 * 
 * 6. COMO CLIENTE USA O TOKEN:
 *    ```bash
 *    # 1. Obter token
 *    curl -X POST http://localhost:8080/auth/token \
 *      -H "Content-Type: application/json" \
 *      -d '{"username":"user_a","password":"pass_a"}'
 *    
 *    # Resposta: {"access_token":"eyJ...","token_type":"Bearer","expires_in":3600}
 *    
 *    # 2. Usar token em requests protegidos
 *    curl -X POST http://localhost:8080/api/messages \
 *      -H "Authorization: Bearer eyJ..." \
 *      -H "Content-Type: application/json" \
 *      -d '{"from":"alice","to":"bob","body":"Hello!"}'
 *    ```
 * 
 * 7. SEGURANÇA:
 *    - ✅ HTTPS obrigatório em produção (previne token theft)
 *    - ✅ Short expiration time (1 hora) → Reduz janela de ataque se token vazar
 *    - ✅ Validação de entrada → Previne injection
 *    - ❌ Passwords em plain text → TROCAR por bcrypt em produção
 *    - ❌ Hardcoded users → TROCAR por Cassandra em produção
 *    - ❌ Sem rate limiting → ADICIONAR para prevenir brute force
 * 
 * USO:
 * ```java
 * TokenGenerator generator = new TokenGenerator("my-secret");
 * AuthHandler handler = new AuthHandler(generator);
 * server.createContext("/auth/token", handler);
 * ```
 */
public class AuthHandler implements HttpHandler {
    
    /**
     * Gerador de tokens JWT.
     * Injetado via construtor (Dependency Injection para testabilidade).
     */
    private final TokenGenerator tokenGenerator;
    
    /**
     * Sessão Cassandra para buscar usuários do banco.
     */
    private final com.datastax.oss.driver.api.core.CqlSession session;
    private final com.datastax.oss.driver.api.core.cql.PreparedStatement selectUserStatement;
    
    /**
     * Usuários válidos (HARDCODED - fallback para compatibilidade).
     */
    private static final Map<String, String> FALLBACK_USERS = Map.of(
        "user_a", "pass_a",
        "user_b", "pass_b",
        "user_c", "pass_c"
    );
    
    /**
     * Construtor do AuthHandler.
     * 
     * @param tokenGenerator Gerador de tokens JWT (injetado para testabilidade)
     * @param session Sessão Cassandra para buscar usuários
     */
    public AuthHandler(TokenGenerator tokenGenerator, com.datastax.oss.driver.api.core.CqlSession session) {
        if (tokenGenerator == null) {
            throw new IllegalArgumentException("TokenGenerator cannot be null");
        }
        this.tokenGenerator = tokenGenerator;
        this.session = session;
        
        if (session != null) {
            this.selectUserStatement = session.prepare(
                "SELECT user_id, password FROM chat4all.users WHERE username = ? ALLOW FILTERING"
            );
        } else {
            this.selectUserStatement = null;
        }
    }
    
    /**
     * Processa requisições HTTP no endpoint /auth/token.
     * 
     * FLUXO:
     * 1. Valida método HTTP (deve ser POST)
     * 2. Lê e parseia body JSON (username, password)
     * 3. Valida campos obrigatórios
     * 4. Verifica credenciais contra VALID_USERS
     * 5. Gera token JWT se válido
     * 6. Retorna resposta JSON com token
     * 
     * FORMATO REQUEST:
     * ```
     * POST /auth/token HTTP/1.1
     * Content-Type: application/json
     * 
     * {
     *   "username": "user_a",
     *   "password": "pass_a"
     * }
     * ```
     * 
     * FORMATO RESPONSE (200 OK):
     * ```
     * HTTP/1.1 200 OK
     * Content-Type: application/json
     * 
     * {
     *   "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
     *   "token_type": "Bearer",
     *   "expires_in": 3600
     * }
     * ```
     * 
     * FORMATO RESPONSE (401 Unauthorized):
     * ```
     * HTTP/1.1 401 Unauthorized
     * Content-Type: application/json
     * 
     * {
     *   "error": "Invalid credentials"
     * }
     * ```
     * 
     * @param exchange Objeto HttpExchange do servidor HTTP
     * @throws IOException se houver erro de I/O
     */
    @Override
    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        
        // 1. Validação de método HTTP
        if (!"POST".equals(method)) {
            sendErrorResponse(exchange, 405, "Method not allowed. Use POST.");
            return;
        }
        
        try {
            // 2. Leitura do body
            InputStream requestBody = exchange.getRequestBody();
            String bodyString = new String(requestBody.readAllBytes(), StandardCharsets.UTF_8);
            
            // Validação: body não pode ser vazio
            if (bodyString == null || bodyString.trim().isEmpty()) {
                sendErrorResponse(exchange, 400, "Request body cannot be empty");
                return;
            }
            
            // 3. Parse JSON
            Map<String, String> credentials = JsonParser.parseObject(bodyString);
            
            // 4. Validação de campos obrigatórios
            String username = credentials.get("username");
            String password = credentials.get("password");
            
            if (username == null || username.trim().isEmpty()) {
                sendErrorResponse(exchange, 400, "Missing required field: username");
                return;
            }
            
            if (password == null || password.trim().isEmpty()) {
                sendErrorResponse(exchange, 400, "Missing required field: password");
                return;
            }
            
            // 5. Verificação de credenciais
            // Consulta o banco de dados primeiro
            // Em produção: usar BCrypt.checkpw(password, passwordHash) para comparação segura
            
            String userId = null;
            boolean authenticated = false;
            
            try {
                // Tenta autenticar via banco de dados
                ResultSet result = session.execute(selectUserStatement.bind(username));
                Row user = result.one();
                
                if (user != null) {
                    // Usuário encontrado no banco
                    String storedPassword = user.getString("password");
                    userId = user.getString("user_id");
                    
                    // NOTA: Em produção, usar BCrypt.checkpw(password, storedPassword)
                    // Aqui estamos usando comparação direta apenas para fins educacionais
                    if (password.equals(storedPassword)) {
                        authenticated = true;
                    }
                }
            } catch (Exception dbException) {
                // Log do erro de banco (não expor ao usuário)
                // Continua para tentar fallback de usuários hardcoded
            }
            
            // Fallback para usuários hardcoded (mantém compatibilidade com user_a, user_b, user_c)
            if (!authenticated) {
                if (FALLBACK_USERS.containsKey(username) && FALLBACK_USERS.get(username).equals(password)) {
                    userId = username; // Para usuários hardcoded, username = userId
                    authenticated = true;
                }
            }
            
            // Se não autenticou nem via banco nem via fallback
            if (!authenticated) {
                // Log: Authentication failed - invalid credentials
                sendErrorResponse(exchange, 401, "Invalid credentials");
                return;
            }
            
            // 6. Geração de token JWT
            String token = tokenGenerator.generateToken(userId);
            
            // 7. Resposta de sucesso (formato OAuth 2.0 RFC 6749)
            String responseJson = String.format(
                "{\"access_token\":\"%s\",\"token_type\":\"Bearer\",\"expires_in\":3600}",
                token
            );
            
            // Log: Token generated successfully
            sendResponse(exchange, 200, responseJson);
            
        } catch (Exception e) {
            // Log do erro: Error processing authentication request
            
            // Retorna erro genérico (não expor detalhes internos)
            sendErrorResponse(exchange, 500, "Internal server error");
        }
    }
    
    /**
     * Envia resposta HTTP de sucesso.
     * 
     * @param exchange HttpExchange
     * @param statusCode Código HTTP (200, 201, etc.)
     * @param body Corpo da resposta (JSON)
     * @throws IOException se houver erro de I/O
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
     * 
     * @param exchange HttpExchange
     * @param statusCode Código HTTP (400, 401, 405, 500)
     * @param message Mensagem de erro
     * @throws IOException se houver erro de I/O
     */
    private void sendErrorResponse(HttpExchange exchange, int statusCode, String message) throws IOException {
        String errorJson = String.format("{\"error\":\"%s\"}", message);
        sendResponse(exchange, statusCode, errorJson);
    }
}
