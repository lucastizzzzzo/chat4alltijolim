# 🧪 TDD (Test-Driven Development) - US3 Autenticação JWT

## 📚 O que é TDD?

**Test-Driven Development** (Desenvolvimento Orientado a Testes) é uma prática onde você:

1. **RED**: Escreve o teste ANTES do código → Teste FALHA (vermelho)
2. **GREEN**: Escreve código mínimo para fazer teste PASSAR (verde)
3. **REFACTOR**: Melhora o código mantendo testes verdes

### Por que TDD?

✅ **Especificação clara**: Teste define EXATAMENTE o comportamento esperado  
✅ **Confiança**: Se testes passam, código funciona  
✅ **Regressão**: Mudanças futuras não quebram funcionalidade  
✅ **Design**: Testes forçam código testável (baixo acoplamento)

---

## 🎯 US3: Autenticação JWT - Ciclo TDD

### Fase 1: 🔴 RED - Testes que FALHAM

#### ✅ T019: AuthEndpointTest.java
**Arquivo**: `api-service/src/test/java/chat4all/api/auth/AuthEndpointTest.java`

**Testes criados:**
- ✅ `testValidCredentialsReturnToken()` - POST /auth/token com credenciais válidas retorna JWT
- ✅ `testInvalidCredentialsReturn401()` - Credenciais inválidas retornam 401
- ✅ `testMissingUsernameReturns400()` - Username faltando retorna 400
- ✅ `testMissingPasswordReturns400()` - Password faltando retorna 400
- ✅ `testEmptyBodyReturns400()` - Body vazio retorna 400
- ✅ `testNonExistentUserReturns401()` - Usuário inexistente retorna 401
- ✅ `testGetMethodReturns405()` - GET não permitido, retorna 405
- ✅ `testSecondUserCredentials()` - user_b também funciona

**Total: 8 testes**

#### ✅ T020: JwtAuthenticatorTest.java
**Arquivo**: `api-service/src/test/java/chat4all/api/auth/JwtAuthenticatorTest.java`

**Testes criados:**
- ✅ `testValidateValidToken()` - Token válido retorna user ID
- ✅ `testValidateExpiredToken()` - Token expirado lança exceção
- ✅ `testValidateInvalidSignature()` - Assinatura inválida lança exceção
- ✅ `testValidateMalformedToken()` - Token malformado lança exceção
- ✅ `testValidateNullToken()` - Token null lança exceção
- ✅ `testValidateEmptyToken()` - Token vazio lança exceção
- ✅ `testValidateTamperedPayload()` - Payload adulterado lança exceção
- ✅ `testValidateTokenIsIdempotent()` - Validação múltipla retorna mesmo resultado

**Total: 8 testes**

#### ✅ T021: TokenGeneratorTest.java
**Arquivo**: `api-service/src/test/java/chat4all/api/auth/TokenGeneratorTest.java`

**Testes criados:**
- ✅ `testGenerateTokenWithUserId()` - Gera token com estrutura JWT (3 partes)
- ✅ `testTokenContainsClaims()` - Token contém claims: sub, iat, exp
- ✅ `testTokenExpiration()` - exp = iat + 3600 segundos (1 hora)
- ✅ `testGenerateTokenWithNullUserIdThrowsException()` - User ID null lança exceção
- ✅ `testGenerateTokenWithEmptyUserIdThrowsException()` - User ID vazio lança exceção
- ✅ `testSameUserIdGeneratesDifferentTokens()` - Timestamps diferentes = tokens diferentes

**Total: 6 testes**

---

### Fase 2: ✅ GREEN - Implementar até PASSAR

**Próximos passos (T023-T028):**

#### T023: TokenGenerator.java
```java
// api-service/src/main/java/chat4all/api/auth/TokenGenerator.java
public class TokenGenerator {
    private final String secret;
    private final int expirationSeconds;
    
    public String generateToken(String userId) {
        // Usar java-jwt (com.auth0:java-jwt)
        // Algorithm.HMAC256(secret)
        // .withSubject(userId)
        // .withIssuedAt(now)
        // .withExpiresAt(now + expirationSeconds)
    }
}
```

#### T024: JwtAuthenticator.java
```java
// api-service/src/main/java/chat4all/api/auth/JwtAuthenticator.java
public class JwtAuthenticator {
    private final String secret;
    
    public String validateToken(String token) {
        // JWT.require(Algorithm.HMAC256(secret))
        // .build()
        // .verify(token)
        // .getSubject() // Returns user_id
    }
}
```

#### T025: AuthHandler.java
```java
// api-service/src/main/java/chat4all/api/http/AuthHandler.java
public class AuthHandler implements HttpHandler {
    // Hardcoded users: user_a/pass_a, user_b/pass_b
    // Parse JSON request
    // Validate credentials
    // Generate JWT token
    // Return {"access_token":"...","token_type":"Bearer","expires_in":3600}
}
```

#### T026: HttpRequestHandler.java (Middleware)
```java
// Adicionar autenticação a todos os endpoints protegidos
// Extract Authorization: Bearer <token>
// Validate token
// Attach user_id to request context
// Return 401 if invalid
```

#### T027: Executar testes novamente
```bash
mvn test -Dtest=TokenGeneratorTest,JwtAuthenticatorTest,AuthEndpointTest
```

**Resultado esperado:** ✅ TODOS OS 22 TESTES PASSANDO

#### T028: Adicionar comentários educacionais
- Explicar estrutura JWT (header.payload.signature)
- Explicar HMAC-SHA256
- Explicar Base64URL encoding
- Explicar claims (sub, iat, exp)

---

### Fase 3: 🔧 REFACTOR - Melhorar código

- Extrair constantes (expiration time)
- Melhorar nomes de variáveis
- Adicionar logs estruturados
- Garantir que testes continuam verdes

---

## 🧪 Como Executar os Testes (Fase RED)

### Pré-requisito: Instalar Maven
```bash
sudo apt install maven
```

### Executar TODOS os testes de autenticação:
```bash
cd /home/tizzo/chat4alltijolim

# Compilar projeto
mvn clean compile

# Executar testes (vão FALHAR - fase RED)
mvn test -pl api-service -Dtest=TokenGeneratorTest
mvn test -pl api-service -Dtest=JwtAuthenticatorTest  
mvn test -pl api-service -Dtest=AuthEndpointTest
```

### Resultado esperado (Fase RED):
```
[ERROR] Failures:
[ERROR]   TokenGeneratorTest.testGenerateTokenWithUserId:36
      java.lang.ClassNotFoundException: chat4all.api.auth.TokenGenerator

[INFO] Tests run: 22, Failures: 22, Errors: 0, Skipped: 0
```

✅ **ISSO É BOM!** Testes falhando significa que estamos na fase RED corretamente.

---

## 📊 Status Atual

### ✅ Concluído (Fase RED):
- [X] T019: AuthEndpointTest.java (8 testes)
- [X] T020: JwtAuthenticatorTest.java (8 testes)
- [X] T021: TokenGeneratorTest.java (6 testes)
- [X] Mockito adicionado ao pom.xml
- [X] JwtAuthenticationException criada

**Total: 22 testes escritos**

### 🚧 Próximo (Fase GREEN):
- [ ] T022: Executar testes e verificar FALHAS
- [ ] T023: Implementar TokenGenerator.java
- [ ] T024: Implementar JwtAuthenticator.java
- [ ] T025: Implementar AuthHandler.java
- [ ] T026: Adicionar middleware de autenticação
- [ ] T027: Executar testes e verificar SUCESSOS
- [ ] T028: Adicionar comentários educacionais

---

## 🎓 Conceitos Educacionais Demonstrados

### 1. JWT (JSON Web Token)
**Estrutura:** `header.payload.signature`

- **Header**: `{"alg":"HS256","typ":"JWT"}` (algoritmo HMAC-SHA256)
- **Payload**: `{"sub":"user_alice","iat":1700000000,"exp":1700003600}` (claims)
- **Signature**: HMAC-SHA256(base64(header) + "." + base64(payload), secret)

### 2. HMAC-SHA256
**Hash-based Message Authentication Code** com SHA-256

- Combina hash criptográfico (SHA-256) com chave secreta
- Garante integridade: se payload muda, signature quebra
- Não é encriptação: payload é visível (Base64, não criptografia)

### 3. Base64URL Encoding
Variante do Base64 segura para URLs:
- Substitui `+` por `-`
- Substitui `/` por `_`
- Remove `=` padding

### 4. Claims JWT
- **sub** (subject): Identifica o usuário (user_id)
- **iat** (issued at): Timestamp de criação
- **exp** (expiration): Timestamp de expiração

### 5. Test Doubles (Mocks)
**Mockito** permite simular objetos sem implementação real:
```java
HttpExchange exchange = Mockito.mock(HttpExchange.class);
Mockito.when(exchange.getRequestMethod()).thenReturn("POST");
```

---

## 📚 Referências

- [JWT.io](https://jwt.io/) - Debugger JWT online
- [RFC 7519](https://tools.ietf.org/html/rfc7519) - Especificação JWT
- [java-jwt by Auth0](https://github.com/auth0/java-jwt) - Biblioteca usada
- [Test-Driven Development by Kent Beck](https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530) - Livro referência

---

**Data:** 2025-11-18  
**Fase TDD Atual:** 🔴 RED (testes escritos, implementação pendente)  
**Próximo Passo:** Executar testes e implementar TokenGenerator.java
