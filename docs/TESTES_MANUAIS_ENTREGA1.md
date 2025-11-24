# Guia de Testes Manuais - Entrega 1
## Chat4All: Sistema de Mensagens Básico

**Objetivo**: Validar manualmente todas as funcionalidades da Entrega 1  
**Tempo estimado**: 15-20 minutos  
**Pré-requisitos**: Docker e Docker Compose instalados

---

## 📋 Checklist de Testes

- [ ] 1. Iniciar o sistema
- [ ] 2. Verificar saúde dos serviços
- [ ] 3. Autenticação JWT
- [ ] 4. Enviar mensagem (POST)
- [ ] 5. Buscar mensagens (GET)
- [ ] 6. Validar persistência no Cassandra
- [ ] 7. Verificar logs do Router Worker
- [ ] 8. Testar paginação
- [ ] 9. Testar autenticação inválida
- [ ] 10. Demonstração completa (conversa entre 2 usuários)

---

## 🚀 Passo 1: Iniciar o Sistema

### 1.1. Subir todos os containers

```bash
cd /home/tizzo/chat4alltijolim
docker-compose up -d
```

**Saída esperada**:
```
Creating network "chat4alltijolim_chat4all-network" done
Creating chat4all-zookeeper ... done
Creating chat4all-cassandra ... done
Creating chat4all-kafka ... done
Creating chat4all-cassandra-init ... done
Creating chat4all-api-service ... done
Creating chat4all-router-worker ... done
```

### 1.2. Aguardar inicialização (60-90 segundos)

```bash
# Monitorar logs
docker-compose logs -f api-service router-worker
```

**Aguarde até ver**:
```
[API] HTTP server started on port 8080
[Router] Kafka consumer ready, subscribed to topic: messages
```

Pressione `Ctrl+C` para sair dos logs.

---

## ✅ Passo 2: Verificar Saúde dos Serviços

### 2.1. Verificar status dos containers

```bash
docker-compose ps
```

**Saída esperada** (todos com status "Up"):
```
NAME                        STATUS              PORTS
chat4all-api-service        Up 2 minutes        0.0.0.0:8082->8080/tcp
chat4all-cassandra          Up 2 minutes        7000-7001/tcp, 7199/tcp, 9042/tcp, 9160/tcp
chat4all-kafka              Up 2 minutes        9092/tcp
chat4all-router-worker      Up 2 minutes        
chat4all-zookeeper          Up 2 minutes        2181/tcp, 2888/tcp, 3888/tcp
```

### 2.2. Testar endpoint de health

```bash
curl http://localhost:8082/health
```

**Saída esperada**:
```json
{"status":"UP"}
```

✅ **Resultado**: Sistema está funcionando!

---

## 🔐 Passo 3: Autenticação JWT

### 3.1. Obter token JWT

```bash
curl -X POST http://localhost:8082/auth/token \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user_a",
    "password": "pass_a"
  }' | jq
```

**Saída esperada**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyX2EiLCJpYXQiOjE3MDA3NTE4NDUsImV4cCI6MTcwMDc1NTQ0NX0.abc123...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

### 3.2. Salvar token em variável

```bash
TOKEN=$(curl -s -X POST http://localhost:8082/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username":"user_a","password":"pass_a"}' \
  | jq -r '.access_token')

echo "Token obtido: $TOKEN"
```

### 3.3. Testar autenticação inválida

```bash
# Sem token
curl -X POST http://localhost:8082/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"conversation_id":"conv_test","sender_id":"user_a","content":"teste"}'
```

**Saída esperada**:
```json
{"error":"Missing Authorization header"}
```

```bash
# Token inválido
curl -X POST http://localhost:8082/v1/messages \
  -H "Authorization: Bearer token_invalido" \
  -H "Content-Type: application/json" \
  -d '{"conversation_id":"conv_test","sender_id":"user_a","content":"teste"}'
```

**Saída esperada**:
```json
{"error":"Invalid token"}
```

✅ **Resultado**: Autenticação está protegendo os endpoints!

---

## 📤 Passo 4: Enviar Mensagem (POST)

### 4.1. Enviar primeira mensagem

```bash
curl -X POST http://localhost:8082/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "conv_manual_test_001",
    "sender_id": "user_a",
    "content": "Olá! Esta é a primeira mensagem de teste manual."
  }' | jq
```

**Saída esperada**:
```json
{
  "message_id": "msg_550e8400e29b41d4a716446655440000",
  "status": "SENT",
  "timestamp": 1700751845123
}
```

### 4.2. Enviar mais mensagens

```bash
# Mensagem 2
curl -X POST http://localhost:8082/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "conv_manual_test_001",
    "sender_id": "user_a",
    "content": "Esta é a segunda mensagem!"
  }' | jq

# Mensagem 3
curl -X POST http://localhost:8082/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "conv_manual_test_001",
    "sender_id": "user_b",
    "content": "Resposta do user_b: Mensagem recebida!"
  }' | jq
```

### 4.3. Verificar validação de campos obrigatórios

```bash
# Sem conversation_id
curl -X POST http://localhost:8082/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "sender_id": "user_a",
    "content": "teste"
  }' | jq
```

**Saída esperada**:
```json
{"error":"Missing required field: conversation_id"}
```

```bash
# Conteúdo vazio
curl -X POST http://localhost:8082/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "conv_test",
    "sender_id": "user_a",
    "content": ""
  }' | jq
```

**Saída esperada**:
```json
{"error":"content cannot be empty"}
```

✅ **Resultado**: Validação de campos está funcionando!

---

## 📥 Passo 5: Buscar Mensagens (GET)

### 5.1. Aguardar processamento do Router Worker

```bash
echo "Aguardando Router Worker processar mensagens (5 segundos)..."
sleep 5
```

### 5.2. Buscar todas as mensagens da conversa

```bash
curl -X GET "http://localhost:8082/v1/conversations/conv_manual_test_001/messages?limit=50&offset=0" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Saída esperada**:
```json
{
  "conversation_id": "conv_manual_test_001",
  "messages": [
    {
      "message_id": "msg_550e8400e29b41d4a716446655440000",
      "sender_id": "user_a",
      "content": "Olá! Esta é a primeira mensagem de teste manual.",
      "timestamp": 1700751845123,
      "status": "DELIVERED"
    },
    {
      "message_id": "msg_7c9e6679f433471ca852690783e4e2e0",
      "sender_id": "user_a",
      "content": "Esta é a segunda mensagem!",
      "timestamp": 1700751846234,
      "status": "DELIVERED"
    },
    {
      "message_id": "msg_a1b2c3d4e5f6789012345678901234ab",
      "sender_id": "user_b",
      "content": "Resposta do user_b: Mensagem recebida!",
      "timestamp": 1700751847345,
      "status": "DELIVERED"
    }
  ],
  "pagination": {
    "limit": 50,
    "offset": 0,
    "returned": 3
  }
}
```

✅ **Resultado**: Mensagens foram persistidas e estão sendo recuperadas!

---

## 🗄️ Passo 6: Validar Persistência no Cassandra

### 6.1. Acessar Cassandra CQL Shell

```bash
docker-compose exec cassandra cqlsh
```

### 6.2. Consultar tabela de mensagens

```sql
USE chat4all;

SELECT message_id, conversation_id, sender_id, content, status, timestamp 
FROM messages 
WHERE conversation_id = 'conv_manual_test_001' 
LIMIT 10;
```

**Saída esperada**:
```
 message_id                       | conversation_id      | sender_id | content                                              | status    | timestamp
----------------------------------+----------------------+-----------+------------------------------------------------------+-----------+---------------
 msg_550e8400e29b41d4a716446655  | conv_manual_test_001 | user_a    | Olá! Esta é a primeira mensagem de teste manual.    | DELIVERED | 1700751845123
 msg_7c9e6679f433471ca852690783  | conv_manual_test_001 | user_a    | Esta é a segunda mensagem!                           | DELIVERED | 1700751846234
 msg_a1b2c3d4e5f6789012345678901 | conv_manual_test_001 | user_b    | Resposta do user_b: Mensagem recebida!              | DELIVERED | 1700751847345

(3 rows)
```

### 6.3. Verificar ordenação por timestamp

```sql
SELECT sender_id, content, timestamp 
FROM messages 
WHERE conversation_id = 'conv_manual_test_001' 
ORDER BY timestamp ASC;
```

**Observação**: Mensagens devem aparecer na ordem cronológica.

### 6.4. Sair do Cassandra

```sql
exit
```

✅ **Resultado**: Dados persistidos corretamente no Cassandra!

---

## 📋 Passo 7: Verificar Logs do Router Worker

### 7.1. Ver logs do Router Worker

```bash
docker-compose logs router-worker | tail -30
```

**Saída esperada**:
```
[Router] Message received from Kafka: msg_550e8400e29b41d4a716446655440000
[Router] Processing message for conversation: conv_manual_test_001
[Router] Persisting to Cassandra...
[Router] Message persisted successfully
[Router] Transitioning status: SENT → DELIVERED
[Router] Status updated in Cassandra
[Router] Kafka offset committed

[Router] Message received from Kafka: msg_7c9e6679f433471ca852690783e4e2e0
[Router] Processing message for conversation: conv_manual_test_001
[Router] Persisting to Cassandra...
[Router] Message persisted successfully
[Router] Transitioning status: SENT → DELIVERED
[Router] Status updated in Cassandra
[Router] Kafka offset committed
```

✅ **Resultado**: Router Worker está processando mensagens corretamente!

---

## 📄 Passo 8: Testar Paginação

### 8.1. Criar 10 mensagens para teste de paginação

```bash
for i in {1..10}; do
  curl -s -X POST http://localhost:8082/v1/messages \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"conversation_id\": \"conv_pagination_test\",
      \"sender_id\": \"user_a\",
      \"content\": \"Mensagem número $i para teste de paginação\"
    }" > /dev/null
  echo "Mensagem $i enviada"
done
```

### 8.2. Aguardar processamento

```bash
sleep 5
```

### 8.3. Buscar primeira página (limit=3)

```bash
curl -X GET "http://localhost:8082/v1/conversations/conv_pagination_test/messages?limit=3&offset=0" \
  -H "Authorization: Bearer $TOKEN" | jq '.messages | length'
```

**Saída esperada**: `3`

### 8.4. Buscar segunda página (offset=3)

```bash
curl -X GET "http://localhost:8082/v1/conversations/conv_pagination_test/messages?limit=3&offset=3" \
  -H "Authorization: Bearer $TOKEN" | jq '.messages | length'
```

**Saída esperada**: `3`

### 8.5. Verificar metadata de paginação

```bash
curl -X GET "http://localhost:8082/v1/conversations/conv_pagination_test/messages?limit=5&offset=0" \
  -H "Authorization: Bearer $TOKEN" | jq '.pagination'
```

**Saída esperada**:
```json
{
  "limit": 5,
  "offset": 0,
  "returned": 5
}
```

✅ **Resultado**: Paginação está funcionando corretamente!

---

## 🔍 Passo 9: Verificar Kafka

### 9.1. Listar tópicos Kafka

```bash
docker-compose exec kafka kafka-topics --list --bootstrap-server localhost:9092
```

**Saída esperada**:
```
__consumer_offsets
messages
```

### 9.2. Ver mensagens no tópico

```bash
docker-compose exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic messages \
  --from-beginning \
  --max-messages 3
```

**Saída esperada** (formato JSON):
```json
{"message_id":"msg_550e8400","conversation_id":"conv_manual_test_001","sender_id":"user_a","content":"Olá! Esta é a primeira mensagem de teste manual.","timestamp":1700751845123,"status":"SENT"}
{"message_id":"msg_7c9e6679","conversation_id":"conv_manual_test_001","sender_id":"user_a","content":"Esta é a segunda mensagem!","timestamp":1700751846234,"status":"SENT"}
{"message_id":"msg_a1b2c3d4","conversation_id":"conv_manual_test_001","sender_id":"user_b","content":"Resposta do user_b: Mensagem recebida!","timestamp":1700751847345,"status":"SENT"}
```

### 9.3. Verificar consumer group

```bash
docker-compose exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group router-worker-group \
  --describe
```

**Saída esperada**:
```
GROUP                 TOPIC     PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG
router-worker-group   messages  0          5               5               0
router-worker-group   messages  1          4               4               0
router-worker-group   messages  2          4               4               0
```

**Observação**: `LAG` deve ser 0 (todas as mensagens processadas).

✅ **Resultado**: Kafka está funcionando e Router Worker está consumindo!

---

## 🎭 Passo 10: Demonstração Completa (Conversa entre João e Maria)

### 10.1. Executar script de demonstração

```bash
./scripts/demo-simple.sh
```

**Saída esperada**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📱 Chat4All - Demonstração Interativa
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/6] Autenticando usuários...
✓ João autenticado
✓ Maria autenticada

[2/6] João envia 3 mensagens...
✓ Mensagem 1: "Oi Maria, tudo bem?"
✓ Mensagem 2: "Podemos conversar sobre o projeto?"
✓ Mensagem 3: "Que tal às 15h?"

[3/6] Aguardando processamento (5s)...
⏳ Router Worker processando...

[4/6] Maria envia 3 respostas...
✓ Mensagem 1: "Oi João! Tudo ótimo, e você?"
✓ Mensagem 2: "Claro! Que horas funciona melhor?"
✓ Mensagem 3: "Perfeito! Te mando o link às 14h50."

[5/6] Aguardando processamento (5s)...
⏳ Router Worker processando...

[6/6] Recuperando histórico da conversa...

📖 HISTÓRICO DA CONVERSAÇÃO
──────────────────────────────────────────────────────────────────
#    Remetente    Timestamp            Status       Conteúdo
──────────────────────────────────────────────────────────────────
1    👨 João       14:30:45.123         DELIVERED    Oi Maria, tudo bem?
2    👨 João       14:30:46.234         DELIVERED    Podemos conversar sobre o projeto?
3    👨 João       14:30:47.345         DELIVERED    Que tal às 15h?
4    👩 Maria      14:30:52.456         DELIVERED    Oi João! Tudo ótimo, e você?
5    👩 Maria      14:30:53.567         DELIVERED    Claro! Que horas funciona melhor?
6    👩 Maria      14:30:54.678         DELIVERED    Perfeito! Te mando o link às 14h50.
──────────────────────────────────────────────────────────────────

📊 Estatísticas:
   • Mensagens de João: 3
   • Mensagens de Maria: 3
   • Total: 6
   • Status DELIVERED: 6/6 (100%)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✅ Demonstração concluída com sucesso!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

✅ **Resultado**: Sistema completo funcionando end-to-end!

---

## 🧪 Testes Automatizados (Opcional)

### Executar todos os testes E2E

```bash
# Teste básico (POST + Worker + Cassandra)
./scripts/test-end-to-end.sh

# Teste GET com paginação
./scripts/test-get-messages.sh

# Teste de autenticação
./scripts/test-auth-messages.sh
```

**Saída esperada para cada**:
```
✅ ALL TESTS PASSED!
```

---

## 📊 Resumo dos Testes

### Funcionalidades Validadas

| # | Funcionalidade | Status | Método |
|---|----------------|--------|--------|
| 1 | Inicialização do sistema | ✅ | docker-compose ps |
| 2 | Health check | ✅ | GET /health |
| 3 | Autenticação JWT | ✅ | POST /auth/token |
| 4 | Validação de token | ✅ | Headers Authorization |
| 5 | Enviar mensagem | ✅ | POST /v1/messages |
| 6 | Validação de campos | ✅ | Campos obrigatórios |
| 7 | Buscar mensagens | ✅ | GET /v1/conversations/{id}/messages |
| 8 | Paginação | ✅ | Query params limit/offset |
| 9 | Persistência Cassandra | ✅ | cqlsh queries |
| 10 | Router Worker (Kafka) | ✅ | Logs e consumer groups |
| 11 | Status SENT → DELIVERED | ✅ | Transição automática |
| 12 | Ordenação cronológica | ✅ | Timestamp ASC |

### Componentes Testados

- ✅ **API Service**: REST endpoints, autenticação, validação
- ✅ **Kafka**: Producer (API), Consumer (Router), Topics, Partições
- ✅ **Router Worker**: Processamento assíncrono, persistência, status
- ✅ **Cassandra**: Schema, queries, ordenação, deduplicação
- ✅ **Docker Compose**: Orquestração, networking, volumes

---

## 🐛 Troubleshooting

### Problema: Containers não iniciam

```bash
# Verificar logs
docker-compose logs cassandra kafka

# Reiniciar
docker-compose restart

# Ou remover e recriar
docker-compose down
docker-compose up -d
```

### Problema: "Connection refused" ao acessar API

```bash
# Verificar porta
docker-compose ps api-service

# Deve mostrar: 0.0.0.0:8082->8080/tcp
# Usar: http://localhost:8082 (não 8080!)
```

### Problema: Mensagens não aparecem no GET

```bash
# Aguardar mais tempo (Router Worker pode estar processando)
sleep 10

# Verificar logs do Router Worker
docker-compose logs router-worker

# Verificar LAG do consumer group
docker-compose exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group router-worker-group \
  --describe
```

### Problema: Token JWT expirado

```bash
# Gerar novo token
TOKEN=$(curl -s -X POST http://localhost:8082/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username":"user_a","password":"pass_a"}' \
  | jq -r '.access_token')
```

---

## 🎯 Checklist Final de Validação

Marque cada item após testar:

- [ ] ✅ Sistema inicia sem erros
- [ ] ✅ Health check retorna "UP"
- [ ] ✅ JWT token é gerado corretamente
- [ ] ✅ POST /v1/messages aceita mensagens válidas
- [ ] ✅ POST /v1/messages rejeita mensagens inválidas
- [ ] ✅ GET /v1/conversations/{id}/messages retorna mensagens
- [ ] ✅ Paginação funciona (limit/offset)
- [ ] ✅ Mensagens persistem no Cassandra
- [ ] ✅ Router Worker processa mensagens
- [ ] ✅ Status muda de SENT → DELIVERED
- [ ] ✅ Kafka consumer não tem LAG
- [ ] ✅ Demo completa executa sem erros

---

## 📝 Notas para Apresentação

### Pontos a destacar:

1. **Arquitetura Event-Driven**: API → Kafka → Router Worker → Cassandra
2. **Autenticação**: JWT com HS256, expiração de 1h
3. **Escalabilidade**: API stateless, Kafka com 3 partições
4. **Persistência**: Cassandra com partition key = conversation_id
5. **Assíncrono**: POST retorna imediatamente, processamento em background
6. **Idempotência**: INSERT IF NOT EXISTS no Cassandra
7. **Observabilidade**: Logs estruturados, Kafka consumer groups

### Demonstrar:

1. POST → Kafka (instantâneo)
2. Router Worker logs (processamento)
3. GET → Cassandra (dados persistidos)
4. Paginação (múltiplas páginas)
5. Validação de campos (erros 400)
6. Autenticação (erros 401)

---

## 🚀 Próximos Passos

Após validar a Entrega 1, você pode:

1. **Parar o sistema**:
   ```bash
   docker-compose down
   ```

2. **Limpar dados** (opcional):
   ```bash
   docker-compose down -v  # Remove volumes
   ```

3. **Continuar para Entrega 2**:
   - File upload/download (MinIO)
   - Multi-platform connectors (WhatsApp, Instagram)
   - Status lifecycle (READ receipts)

---

**Chat4All - Educational Project**  
**Guia de Testes Manuais - Entrega 1**  
**Versão**: 1.0  
**Data**: Novembro 2025
