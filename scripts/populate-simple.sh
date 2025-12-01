#!/bin/bash
# Script de Carga Simplificada - Chat4All
# Popula mensagens diretamente (sem precisar criar conversações)

set -e

echo "🚀 Chat4All - Script de Carga Inicial"
echo "======================================"
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Verificar API
echo "📡 Verificando API Service..."
if ! curl -s http://localhost:8080/actuator/health > /dev/null 2>&1; then
    echo -e "${RED}❌ API Service não está respondendo${NC}"
    exit 1
fi
echo -e "${GREEN}✅ API Service online${NC}"
echo ""

# ============================================
# ETAPA 1: AUTENTICAR
# ============================================
echo "🔐 ETAPA 1: Autenticando usuários..."
echo "-----------------------------------"

TOKEN_A=$(curl -s -X POST http://localhost:8080/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username":"user_a","password":"pass_a"}' | jq -r '.access_token')

if [ -z "$TOKEN_A" ] || [ "$TOKEN_A" = "null" ]; then
    echo -e "${RED}❌ Falha ao obter token do user_a${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Token user_a obtido${NC}"
echo "   Token: ${TOKEN_A:0:30}..."

TOKEN_B=$(curl -s -X POST http://localhost:8080/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username":"user_b","password":"pass_b"}' | jq -r '.access_token')

echo -e "${GREEN}✅ Token user_b obtido${NC}"
echo ""

# ============================================
# ETAPA 2: ENVIAR MENSAGENS
# ============================================
echo "📨 ETAPA 2: Enviando mensagens..."
echo "---------------------------------"

# IDs de conversação (gerados para agrupar mensagens)
CONV_ID_1="conv_$(uuidgen | tr '[:upper:]' '[:lower:]')"
CONV_ID_2="conv_$(uuidgen | tr '[:upper:]' '[:lower:]')"

echo "Conversação 1 ID: $CONV_ID_1"
echo "Conversação 2 ID: $CONV_ID_2"
echo ""

# Mensagem 1: user_a -> WhatsApp
echo "Enviando mensagem 1 (user_a -> WhatsApp)..."
MSG1_RESPONSE=$(curl -s -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d '{
    "conversation_id": "'$CONV_ID_1'",
    "recipient_id": "whatsapp:+5511999999999",
    "content": "Olá! Esta é a primeira mensagem de teste do Chat4All."
  }')

MSG_ID_1=$(echo "$MSG1_RESPONSE" | jq -r '.message_id // .messageId // empty')
echo -e "${GREEN}✅ Mensagem 1 enviada${NC}"
[ -n "$MSG_ID_1" ] && echo "   ID: $MSG_ID_1"

# Mensagem 2: user_a -> Instagram
echo "Enviando mensagem 2 (user_a -> Instagram)..."
curl -s -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d '{
    "conversation_id": "'$CONV_ID_1'",
    "recipient_id": "instagram:@maria_silva",
    "content": "Oi Maria! Como você está? Mensagem via Instagram."
  }' > /dev/null
echo -e "${GREEN}✅ Mensagem 2 enviada${NC}"

# Mensagem 3: user_b responde via WhatsApp
echo "Enviando mensagem 3 (user_b -> WhatsApp)..."
curl -s -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_B" \
  -d '{
    "conversation_id": "'$CONV_ID_1'",
    "recipient_id": "whatsapp:+5511988888888",
    "content": "Oi! Recebi sua mensagem. Obrigado pelo contato!"
  }' > /dev/null
echo -e "${GREEN}✅ Mensagem 3 enviada${NC}"

# Mensagem 4: user_a -> Instagram (conversação 2)
echo "Enviando mensagem 4 (user_a -> Instagram)..."
curl -s -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d '{
    "conversation_id": "'$CONV_ID_2'",
    "recipient_id": "instagram:@joao_santos",
    "content": "João, segue a informação que você pediu!"
  }' > /dev/null
echo -e "${GREEN}✅ Mensagem 4 enviada${NC}"

# Mensagem 5: user_b -> WhatsApp (conversação 2)
echo "Enviando mensagem 5 (user_b -> WhatsApp)..."
curl -s -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_B" \
  -d '{
    "conversation_id": "'$CONV_ID_2'",
    "recipient_id": "whatsapp:+5511977777777",
    "content": "Perfeito! Recebi tudo. Muito obrigado!"
  }' > /dev/null
echo -e "${GREEN}✅ Mensagem 5 enviada${NC}"

# Mensagem 6: user_a -> WhatsApp
echo "Enviando mensagem 6 (user_a -> WhatsApp)..."
curl -s -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d '{
    "conversation_id": "'$CONV_ID_1'",
    "recipient_id": "whatsapp:+5511966666666",
    "content": "Testando persistência no Cassandra! 🚀"
  }' > /dev/null
echo -e "${GREEN}✅ Mensagem 6 enviada${NC}"

# Mensagem 7: user_b -> Instagram
echo "Enviando mensagem 7 (user_b -> Instagram)..."
curl -s -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_B" \
  -d '{
    "conversation_id": "'$CONV_ID_2'",
    "recipient_id": "instagram:@ana_costa",
    "content": "Ana, validando sistema distribuído!"
  }' > /dev/null
echo -e "${GREEN}✅ Mensagem 7 enviada${NC}"

echo ""
echo -e "${YELLOW}⏳ Aguardando 15 segundos para os connectors processarem...${NC}"
sleep 15

# ============================================
# SUMÁRIO FINAL
# ============================================
echo ""
echo "✅ CARGA INICIAL CONCLUÍDA!"
echo "=========================================="
echo ""
echo "📊 SUMÁRIO DOS DADOS CRIADOS:"
echo ""
echo "📨 Mensagens: 7"
echo "   - 4 via WhatsApp"
echo "   - 3 via Instagram"
echo "   - 2 conversações ($CONV_ID_1, $CONV_ID_2)"
echo ""
echo "=========================================="
echo ""
echo "🔍 VALIDAR NO CASSANDRA:"
echo ""
echo "1. Conectar:"
echo "   docker exec -it chat4all-cassandra cqlsh"
echo ""
echo "2. Contar mensagens:"
echo "   SELECT COUNT(*) FROM chat4all.messages;"
echo "   # Esperado: 7"
echo ""
echo "3. Listar mensagens:"
echo "   SELECT message_id, content, status FROM chat4all.messages LIMIT 10;"
echo ""
echo "4. Ver mensagens de uma conversação:"
echo "   SELECT message_id, content, status, sent_at"
echo "   FROM chat4all.messages"
echo "   WHERE conversation_id = '$CONV_ID_1';"
echo ""
echo "5. Contar mensagens por status:"
echo "   SELECT status, COUNT(*) as total"
echo "   FROM chat4all.messages"
echo "   GROUP BY status ALLOW FILTERING;"
echo "   # Esperado: Status 'READ' com 7 mensagens"
echo ""
echo "=========================================="
echo ""
echo "🔧 VERIFICAR PROCESSAMENTO:"
echo "   docker-compose logs connector-whatsapp | tail -30"
echo "   docker-compose logs connector-instagram | tail -30"
echo ""
echo -e "${GREEN}✨ Script concluído com sucesso!${NC}"
echo ""
echo "💡 Dica: Se COUNT retornar 0, aguarde mais 10s e tente novamente."
echo "   Os connectors podem estar processando ainda."
