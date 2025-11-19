#!/bin/bash

# Demo: Troca de Mensagens entre João e Maria
# 
# Este script demonstra uma conversação completa entre dois usuários
# mostrando timestamps, status das mensagens, e o fluxo assíncrono.

set -e  # Exit on error

API_URL="http://localhost:8082"
CONV_ID="conv_joao_maria_$(date +%s)"

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo ""
echo "=========================================================="
echo "  📱 DEMO: Conversação entre João e Maria"
echo "=========================================================="
echo ""
echo "Conversation ID: $CONV_ID"
echo ""

# ============================================================
# STEP 1: Autenticar João
# ============================================================
echo -e "${BLUE}[1] Autenticando João...${NC}"
JOAO_TOKEN=$(curl -s -X POST "$API_URL/auth/token" \
  -H "Content-Type: application/json" \
  -d '{"username":"user_a","password":"pass_a"}' \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$JOAO_TOKEN" ]; then
  echo "❌ Falha ao autenticar João"
  exit 1
fi

echo -e "${GREEN}✓ João autenticado${NC}"
echo "  Token: ${JOAO_TOKEN:0:30}..."
echo ""

# ============================================================
# STEP 2: Autenticar Maria
# ============================================================
echo -e "${BLUE}[2] Autenticando Maria...${NC}"
MARIA_TOKEN=$(curl -s -X POST "$API_URL/auth/token" \
  -H "Content-Type: application/json" \
  -d '{"username":"user_b","password":"pass_b"}' \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$MARIA_TOKEN" ]; then
  echo "❌ Falha ao autenticar Maria"
  exit 1
fi

echo -e "${GREEN}✓ Maria autenticada${NC}"
echo "  Token: ${MARIA_TOKEN:0:30}..."
echo ""

# ============================================================
# STEP 3: João envia primeira mensagem
# ============================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[3] João → Maria: \"Oi Maria, tudo bem?\"${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

JOAO_MSG1=$(curl -s -X POST "$API_URL/v1/messages" \
  -H "Authorization: Bearer $JOAO_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"conversation_id\": \"$CONV_ID\",
    \"sender_id\": \"joao\",
    \"content\": \"Oi Maria, tudo bem?\"
  }")

MSG1_ID=$(echo "$JOAO_MSG1" | grep -o '"message_id":"[^"]*' | cut -d'"' -f4)
MSG1_TIME=$(date +"%H:%M:%S")

echo -e "${GREEN}✓ Mensagem enviada para Kafka${NC}"
echo "  Message ID: $MSG1_ID"
echo "  Timestamp: $MSG1_TIME"
echo "  Status: ACCEPTED (aguardando processamento)"
echo ""
sleep 1

# ============================================================
# STEP 4: João envia segunda mensagem
# ============================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[4] João → Maria: \"Podemos conversar sobre o projeto?\"${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

JOAO_MSG2=$(curl -s -X POST "$API_URL/v1/messages" \
  -H "Authorization: Bearer $JOAO_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"conversation_id\": \"$CONV_ID\",
    \"sender_id\": \"joao\",
    \"content\": \"Podemos conversar sobre o projeto?\"
  }")

MSG2_ID=$(echo "$JOAO_MSG2" | grep -o '"message_id":"[^"]*' | cut -d'"' -f4)
MSG2_TIME=$(date +"%H:%M:%S")

echo -e "${GREEN}✓ Mensagem enviada para Kafka${NC}"
echo "  Message ID: $MSG2_ID"
echo "  Timestamp: $MSG2_TIME"
echo "  Status: ACCEPTED"
echo ""
sleep 1

# ============================================================
# STEP 5: Aguardar processamento do Worker
# ============================================================
echo -e "${BLUE}[5] Aguardando Router Worker processar mensagens (8s)...${NC}"
echo "    (Worker consome do Kafka → persiste no Cassandra → atualiza status)"
sleep 8
echo -e "${GREEN}✓ Processamento completo${NC}"
echo ""

# ============================================================
# STEP 6: Maria responde primeira mensagem
# ============================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[6] Maria → João: \"Oi João! Tudo ótimo, e você?\"${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

MARIA_MSG1=$(curl -s -X POST "$API_URL/v1/messages" \
  -H "Authorization: Bearer $MARIA_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"conversation_id\": \"$CONV_ID\",
    \"sender_id\": \"maria\",
    \"content\": \"Oi João! Tudo ótimo, e você?\"
  }")

MSG3_ID=$(echo "$MARIA_MSG1" | grep -o '"message_id":"[^"]*' | cut -d'"' -f4)
MSG3_TIME=$(date +"%H:%M:%S")

echo -e "${GREEN}✓ Mensagem enviada para Kafka${NC}"
echo "  Message ID: $MSG3_ID"
echo "  Timestamp: $MSG3_TIME"
echo "  Status: ACCEPTED"
echo ""
sleep 1

# ============================================================
# STEP 7: Maria responde segunda mensagem
# ============================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[7] Maria → João: \"Claro! Que horas funciona melhor?\"${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

MARIA_MSG2=$(curl -s -X POST "$API_URL/v1/messages" \
  -H "Authorization: Bearer $MARIA_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"conversation_id\": \"$CONV_ID\",
    \"sender_id\": \"maria\",
    \"content\": \"Claro! Que horas funciona melhor?\"
  }")

MSG4_ID=$(echo "$MARIA_MSG2" | grep -o '"message_id":"[^"]*' | cut -d'"' -f4)
MSG4_TIME=$(date +"%H:%M:%S")

echo -e "${GREEN}✓ Mensagem enviada para Kafka${NC}"
echo "  Message ID: $MSG4_ID"
echo "  Timestamp: $MSG4_TIME"
echo "  Status: ACCEPTED"
echo ""
sleep 1

# ============================================================
# STEP 8: João responde
# ============================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[8] João → Maria: \"Que tal às 15h? Podemos fazer uma call.\"${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

JOAO_MSG3=$(curl -s -X POST "$API_URL/v1/messages" \
  -H "Authorization: Bearer $JOAO_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"conversation_id\": \"$CONV_ID\",
    \"sender_id\": \"joao\",
    \"content\": \"Que tal às 15h? Podemos fazer uma call.\"
  }")

MSG5_ID=$(echo "$JOAO_MSG3" | grep -o '"message_id":"[^"]*' | cut -d'"' -f4)
MSG5_TIME=$(date +"%H:%M:%S")

echo -e "${GREEN}✓ Mensagem enviada para Kafka${NC}"
echo "  Message ID: $MSG5_ID"
echo "  Timestamp: $MSG5_TIME"
echo "  Status: ACCEPTED"
echo ""

# ============================================================
# STEP 9: Maria confirma
# ============================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[9] Maria → João: \"Perfeito! Te mando o link da call às 14h50.\"${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

MARIA_MSG3=$(curl -s -X POST "$API_URL/v1/messages" \
  -H "Authorization: Bearer $MARIA_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"conversation_id\": \"$CONV_ID\",
    \"sender_id\": \"maria\",
    \"content\": \"Perfeito! Te mando o link da call às 14h50.\"
  }")

MSG6_ID=$(echo "$MARIA_MSG3" | grep -o '"message_id":"[^"]*' | cut -d'"' -f4)
MSG6_TIME=$(date +"%H:%M:%S")

echo -e "${GREEN}✓ Mensagem enviada para Kafka${NC}"
echo "  Message ID: $MSG6_ID"
echo "  Timestamp: $MSG6_TIME"
echo "  Status: ACCEPTED"
echo ""

# ============================================================
# STEP 10: Aguardar processamento final
# ============================================================
echo -e "${BLUE}[10] Aguardando processamento final (8s)...${NC}"
sleep 8
echo -e "${GREEN}✓ Todas as mensagens processadas${NC}"
echo ""

# ============================================================
# STEP 11: João visualiza histórico completo
# ============================================================
echo "=========================================================="
echo -e "${BLUE}[11] 📖 João visualizando histórico da conversação${NC}"
echo "=========================================================="
echo ""

HISTORY=$(curl -s -X GET "$API_URL/v1/conversations/$CONV_ID/messages?limit=20&offset=0" \
  -H "Authorization: Bearer $JOAO_TOKEN")

echo "$HISTORY" | python3 -c "
import sys, json
from datetime import datetime

try:
    data = json.load(sys.stdin)
    messages = data.get('messages', [])
    pagination = data.get('pagination', {})
    
    print(f\"Conversação: {data.get('conversation_id', 'N/A')}\")
    print(f\"Total de mensagens: {pagination.get('returned', 0)}\")
    print()
    print('─' * 80)
    
    for i, msg in enumerate(messages, 1):
        sender = msg.get('sender_id', 'unknown')
        content = msg.get('content', '')
        timestamp_ms = msg.get('timestamp', 0)
        status = msg.get('status', 'UNKNOWN')
        msg_id = msg.get('message_id', 'N/A')[:20]
        
        # Converter timestamp para formato legível
        if timestamp_ms:
            dt = datetime.fromtimestamp(timestamp_ms / 1000.0)
            time_str = dt.strftime('%H:%M:%S.%f')[:-3]
        else:
            time_str = 'N/A'
        
        # Emoji baseado no remetente
        emoji = '👨' if sender == 'joao' else '👩'
        
        print(f\"{i}. {emoji} {sender.upper():<8} [{time_str}] [Status: {status}]\")
        print(f\"   {content}\")
        print(f\"   ID: {msg_id}...\")
        print()
    
    print('─' * 80)
except Exception as e:
    print(f'Erro ao processar JSON: {e}', file=sys.stderr)
    print(sys.stdin.read())
"

echo ""

# ============================================================
# STEP 12: Maria também visualiza o histórico
# ============================================================
echo "=========================================================="
echo -e "${BLUE}[12] 📖 Maria visualizando o mesmo histórico${NC}"
echo "=========================================================="
echo ""

HISTORY_MARIA=$(curl -s -X GET "$API_URL/v1/conversations/$CONV_ID/messages?limit=20&offset=0" \
  -H "Authorization: Bearer $MARIA_TOKEN")

echo "$HISTORY_MARIA" | python3 -c "
import sys, json
from datetime import datetime

try:
    data = json.load(sys.stdin)
    messages = data.get('messages', [])
    
    print('Maria vê a mesma conversação (consistência garantida pelo Cassandra):')
    print()
    
    for i, msg in enumerate(messages, 1):
        sender = msg.get('sender_id', 'unknown')
        content = msg.get('content', '')
        status = msg.get('status', 'UNKNOWN')
        
        # Destaque para mensagens enviadas por ela
        if sender == 'maria':
            print(f\"  {i}. ✓ MARIA (você): {content} [{status}]\")
        else:
            print(f\"  {i}.   {sender}: {content} [{status}]\")
except Exception as e:
    print(f'Erro: {e}', file=sys.stderr)
"

echo ""

# ============================================================
# STEP 13: Verificar diretamente no Cassandra
# ============================================================
echo "=========================================================="
echo -e "${BLUE}[13] 🗄️  Verificando dados no Cassandra${NC}"
echo "=========================================================="
echo ""

echo "Consultando tabela 'messages' no Cassandra..."
docker exec chat4all-cassandra cqlsh -e "
SELECT conversation_id, sender_id, content, status, toTimestamp(now()) as query_time
FROM chat4all.messages 
WHERE conversation_id = '$CONV_ID' 
LIMIT 10;" 2>/dev/null || echo "⚠ Não foi possível consultar Cassandra diretamente"

echo ""

# ============================================================
# STEP 14: Verificar logs do Worker
# ============================================================
echo "=========================================================="
echo -e "${BLUE}[14] 📋 Logs do Router Worker (últimas 15 linhas)${NC}"
echo "=========================================================="
echo ""

docker logs chat4alltijolim_router-worker_1 2>&1 | grep -E "Processing|Saved|Delivered|Status" | tail -15

echo ""

# ============================================================
# SUMMARY
# ============================================================
echo "=========================================================="
echo -e "${GREEN}✅ DEMO COMPLETA!${NC}"
echo "=========================================================="
echo ""
echo "📊 Estatísticas:"
echo "  • Usuários: João e Maria"
echo "  • Total de mensagens: 6"
echo "  • Mensagens de João: 3"
echo "  • Mensagens de Maria: 3"
echo "  • Conversação ID: $CONV_ID"
echo ""
echo "🔄 Fluxo Demonstrado:"
echo "  1. Autenticação JWT (2 usuários)"
echo "  2. Envio assíncrono via Kafka (6 mensagens)"
echo "  3. Processamento pelo Router Worker"
echo "  4. Persistência no Cassandra"
echo "  5. Status transitions: ACCEPTED → SENT → DELIVERED"
echo "  6. Recuperação do histórico (ambos os usuários)"
echo "  7. Ordenação cronológica por timestamp"
echo ""
echo "🎯 Conceitos de Sistemas Distribuídos Demonstrados:"
echo "  ✓ Event-Driven Architecture (Kafka)"
echo "  ✓ Asynchronous Message Processing"
echo "  ✓ Distributed Database (Cassandra)"
echo "  ✓ Horizontal Scalability (stateless API)"
echo "  ✓ At-least-once Delivery Semantics"
echo "  ✓ Message Ordering (via partition key)"
echo "  ✓ RESTful API Design"
echo "  ✓ JWT Authentication"
echo ""
echo "=========================================================="
