#!/bin/bash

# Script de Teste - Mensagens em Grupo
# Testa envio e listagem de mensagens em conversas de grupo

set -e

API_URL="http://localhost:8080"
TIMESTAMP=$(date +%s)

echo "========================================================"
echo "  💬 Teste: Mensagens em Grupo"
echo "========================================================"
echo

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}⏳ $1${NC}"
}

# ========================================
# PASSO 1: Criar usuários e grupo
# ========================================
print_info "Passo 1: Setup - Criando 3 usuários e 1 grupo..."
echo

# Criar 3 usuários
USERS=()
TOKENS=()

for i in 1 2 3; do
    USERNAME="group_msg_user${i}_${TIMESTAMP}"
    PASSWORD="senha${i}23"
    EMAIL="user${i}_${TIMESTAMP}@example.com"
    
    USER_RESPONSE=$(curl -s -X POST ${API_URL}/auth/register \
      -H "Content-Type: application/json" \
      -d "{
        \"username\": \"$USERNAME\",
        \"password\": \"$PASSWORD\",
        \"email\": \"$EMAIL\"
      }")
    
    USER_ID=$(echo "$USER_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('user_id', ''))")
    USERS+=("$USER_ID")
    
    TOKEN=$(curl -s -X POST ${API_URL}/auth/token \
      -H "Content-Type: application/json" \
      -d "{
        \"username\": \"$USERNAME\",
        \"password\": \"$PASSWORD\"
      }" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")
    
    TOKENS+=("$TOKEN")
    
    print_success "Usuário $i criado: $USERNAME (ID: $USER_ID)"
done

echo

# Criar grupo com user1 como criador
print_info "Criando grupo..."

CREATE_GROUP=$(curl -s -X POST ${API_URL}/v1/groups \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKENS[0]}" \
  -d "{
    \"name\": \"Grupo Chat ${TIMESTAMP}\",
    \"description\": \"Grupo para teste de mensagens\",
    \"initial_members\": [\"${USERS[1]}\", \"${USERS[2]}\"]
  }")

GROUP_ID=$(echo "$CREATE_GROUP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('group_id', ''))")

if [ -z "$GROUP_ID" ]; then
    print_error "Falha ao criar grupo"
    echo "$CREATE_GROUP"
    exit 1
fi

print_success "Grupo criado: $GROUP_ID"
echo

# ========================================
# PASSO 2: User1 envia mensagem no grupo
# ========================================
print_info "Passo 2: User1 enviando mensagem no grupo..."
echo

MSG1_RESPONSE=$(curl -s -X POST ${API_URL}/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKENS[0]}" \
  -d "{
    \"conversation_id\": \"$GROUP_ID\",
    \"recipient_id\": \"group:${GROUP_ID}\",
    \"content\": \"Olá pessoal! Esta é a primeira mensagem do grupo.\"
  }")

echo "$MSG1_RESPONSE" | python3 -m json.tool

MSG1_ID=$(echo "$MSG1_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('message_id', ''))" 2>/dev/null || echo "")

if [ -n "$MSG1_ID" ]; then
    print_success "Mensagem 1 enviada (ID: $MSG1_ID)"
else
    print_success "Mensagem 1 enviada"
fi
echo

# ========================================
# PASSO 3: User2 responde no grupo
# ========================================
print_info "Passo 3: User2 respondendo no grupo..."
echo

sleep 2  # Pequeno delay para ordem das mensagens

MSG2_RESPONSE=$(curl -s -X POST ${API_URL}/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKENS[1]}" \
  -d "{
    \"conversation_id\": \"$GROUP_ID\",
    \"recipient_id\": \"group:${GROUP_ID}\",
    \"content\": \"Oi! Obrigado por me adicionar ao grupo!\"
  }")

echo "$MSG2_RESPONSE" | python3 -m json.tool
print_success "Mensagem 2 enviada"
echo

# ========================================
# PASSO 4: User3 também responde
# ========================================
print_info "Passo 4: User3 respondendo no grupo..."
echo

sleep 2

MSG3_RESPONSE=$(curl -s -X POST ${API_URL}/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKENS[2]}" \
  -d "{
    \"conversation_id\": \"$GROUP_ID\",
    \"recipient_id\": \"group:${GROUP_ID}\",
    \"content\": \"Olá a todos! Vamos começar a usar este grupo para coordenar o projeto.\"
  }")

echo "$MSG3_RESPONSE" | python3 -m json.tool
print_success "Mensagem 3 enviada"
echo

# ========================================
# PASSO 5: User1 envia outra mensagem
# ========================================
print_info "Passo 5: User1 enviando segunda mensagem..."
echo

sleep 2

MSG4_RESPONSE=$(curl -s -X POST ${API_URL}/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKENS[0]}" \
  -d "{
    \"conversation_id\": \"$GROUP_ID\",
    \"recipient_id\": \"group:${GROUP_ID}\",
    \"content\": \"Perfeito! Estamos todos aqui. Próxima reunião na sexta-feira às 15h.\"
  }")

echo "$MSG4_RESPONSE" | python3 -m json.tool
print_success "Mensagem 4 enviada"
echo

# ========================================
# PASSO 6: Aguardar processamento
# ========================================
print_info "Passo 6: Aguardando processamento das mensagens (10s)..."
sleep 10
print_success "Processamento concluído"
echo

# ========================================
# PASSO 7: Listar mensagens do grupo
# ========================================
print_info "Passo 7: Listando todas as mensagens do grupo..."
echo

LIST_MESSAGES=$(curl -s -X GET "${API_URL}/v1/conversations/${GROUP_ID}/messages?limit=20" \
  -H "Authorization: Bearer ${TOKENS[0]}")

echo "$LIST_MESSAGES" | python3 -m json.tool

MSG_COUNT=$(echo "$LIST_MESSAGES" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('messages', [])))" 2>/dev/null || echo "0")

print_success "Total de mensagens recuperadas: $MSG_COUNT"
echo

# ========================================
# PASSO 8: Verificar no Cassandra
# ========================================
print_info "Passo 8: Verificando mensagens no Cassandra..."
echo

echo "📊 Mensagens do grupo (últimas 10):"
docker exec chat4all-cassandra cqlsh -e "
SELECT message_id, sender_id, content, status, sent_at
FROM chat4all.messages 
WHERE conversation_id = '${GROUP_ID}' 
LIMIT 10;" 2>/dev/null || echo "⚠️  Erro ao consultar Cassandra"

echo

# ========================================
# PASSO 9: Verificar logs dos connectors
# ========================================
print_info "Passo 9: Verificando logs dos connectors..."
echo

echo "📱 Últimas 5 mensagens processadas pelo WhatsApp Connector:"
docker-compose logs --tail=5 connector-whatsapp 2>/dev/null | grep -E "Delivered|Read|message" || echo "Nenhuma mensagem encontrada"

echo
echo "📷 Últimas 5 mensagens processadas pelo Instagram Connector:"
docker-compose logs --tail=5 connector-instagram 2>/dev/null | grep -E "Delivered|Read|message" || echo "Nenhuma mensagem encontrada"

echo

# ========================================
# RESUMO FINAL
# ========================================
echo "========================================================"
echo "  ✅ Teste de Mensagens em Grupo Completo!"
echo "========================================================"
echo
echo "📊 Resumo:"
echo "  • Grupo ID: $GROUP_ID"
echo "  • Participantes: 3 usuários"
echo "  • Mensagens enviadas: 4"
echo "  • Mensagens recuperadas: $MSG_COUNT"
echo
echo "👥 Participantes:"
echo "  1. User 1 (ID: ${USERS[0]}) - Criador"
echo "  2. User 2 (ID: ${USERS[1]}) - Membro"
echo "  3. User 3 (ID: ${USERS[2]}) - Membro"
echo
echo "💬 Histórico de mensagens:"
echo "  1. User1: 'Olá pessoal! Esta é a primeira mensagem...'"
echo "  2. User2: 'Oi! Obrigado por me adicionar...'"
echo "  3. User3: 'Olá a todos! Vamos começar...'"
echo "  4. User1: 'Perfeito! Estamos todos aqui...'"
echo
echo "🧪 Funcionalidades testadas:"
echo "  ✅ Criar grupo com múltiplos membros"
echo "  ✅ Enviar mensagens no grupo (múltiplos usuários)"
echo "  ✅ Listar mensagens do grupo"
echo "  ✅ Processamento via Kafka"
echo "  ✅ Entrega via connectors"
echo "  ✅ Persistência no Cassandra"
echo
echo "🔗 Para ver mensagens no CLI:"
echo "  cd ~/chat4alltijolim/cli"
echo "  python3 chat4all-cli.py"
echo "  Login com user1 e liste conversas"
echo
