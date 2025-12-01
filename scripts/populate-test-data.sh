#!/bin/bash
# Script de Carga Inicial - Chat4All
# Popula o sistema com dados de teste para validação de persistência

set -e  # Parar em caso de erro

echo "🚀 Chat4All - Script de Carga Inicial"
echo "======================================"
echo ""

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Verificar se API está rodando
echo "📡 Verificando API Service..."
if ! curl -s http://localhost:8080/actuator/health > /dev/null 2>&1; then
    echo -e "${RED}❌ API Service não está respondendo em http://localhost:8080${NC}"
    echo "Execute: docker-compose up -d"
    exit 1
fi
echo -e "${GREEN}✅ API Service está online${NC}"
echo ""

# ============================================
# ETAPA 1: CRIAR USUÁRIOS
# ============================================
echo "👥 ETAPA 1: Criando usuários..."
echo "--------------------------------"

# Criar user_a
echo "Criando user_a..."
USER_A_RESPONSE=$(curl -s -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user_a",
    "password": "pass_a",
    "email": "user_a@example.com"
  }')

if echo "$USER_A_RESPONSE" | grep -q "success\|userId"; then
    echo -e "${GREEN}✅ user_a criado com sucesso${NC}"
    USER_A_ID=$(echo "$USER_A_RESPONSE" | jq -r '.userId // .user_id // empty')
    echo "   ID: $USER_A_ID"
else
    echo -e "${YELLOW}⚠️  user_a pode já existir ou houve erro${NC}"
fi

# Criar user_b
echo "Criando user_b..."
USER_B_RESPONSE=$(curl -s -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user_b",
    "password": "pass_b",
    "email": "user_b@example.com"
  }')

if echo "$USER_B_RESPONSE" | grep -q "success\|userId"; then
    echo -e "${GREEN}✅ user_b criado com sucesso${NC}"
    USER_B_ID=$(echo "$USER_B_RESPONSE" | jq -r '.userId // .user_id // empty')
    echo "   ID: $USER_B_ID"
else
    echo -e "${YELLOW}⚠️  user_b pode já existir ou houve erro${NC}"
fi

# Criar user_c
echo "Criando user_c..."
curl -s -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user_c",
    "password": "pass_c",
    "email": "user_c@example.com"
  }' > /dev/null

echo -e "${GREEN}✅ user_c criado${NC}"
echo ""

# ============================================
# ETAPA 2: FAZER LOGIN (OBTER TOKENS)
# ============================================
echo "🔐 ETAPA 2: Autenticando usuários..."
echo "-----------------------------------"

TOKEN_A=$(curl -s -X POST http://localhost:8080/auth/token \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user_a",
    "password": "pass_a"
  }' | jq -r '.access_token // .token // empty')

if [ -z "$TOKEN_A" ] || [ "$TOKEN_A" = "null" ]; then
    echo -e "${RED}❌ Falha ao obter token do user_a${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Token user_a obtido${NC}"
echo "   Token: ${TOKEN_A:0:20}..."

TOKEN_B=$(curl -s -X POST http://localhost:8080/auth/token \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user_b",
    "password": "pass_b"
  }' | jq -r '.access_token // .token // empty')

echo -e "${GREEN}✅ Token user_b obtido${NC}"

TOKEN_C=$(curl -s -X POST http://localhost:8080/auth/token \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user_c",
    "password": "pass_c"
  }' | jq -r '.access_token // .token // empty')

echo -e "${GREEN}✅ Token user_c obtido${NC}"
echo ""

# ============================================
# ETAPA 3: CRIAR CONVERSAÇÕES
# ============================================
echo "💬 ETAPA 3: Criando conversações..."
echo "-----------------------------------"

# Conversação 1: user_a <-> user_b
CONV1_RESPONSE=$(curl -s -X POST http://localhost:8080/v1/conversations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d '{
    "participants": ["user_a", "user_b"]
  }')

CONV_ID_1=$(echo "$CONV1_RESPONSE" | jq -r '.conversationId // .conversation_id // empty')
if [ -n "$CONV_ID_1" ] && [ "$CONV_ID_1" != "null" ]; then
    echo -e "${GREEN}✅ Conversação 1 criada (user_a ↔ user_b)${NC}"
    echo "   ID: $CONV_ID_1"
else
    echo -e "${YELLOW}⚠️  Falha ao criar conversação 1${NC}"
    CONV_ID_1="test-conv-1"
fi

# Conversação 2: user_a <-> user_c
CONV2_RESPONSE=$(curl -s -X POST http://localhost:8080/v1/conversations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d '{
    "participants": ["user_a", "user_c"]
  }')

CONV_ID_2=$(echo "$CONV2_RESPONSE" | jq -r '.conversationId // .conversation_id // empty')
if [ -n "$CONV_ID_2" ] && [ "$CONV_ID_2" != "null" ]; then
    echo -e "${GREEN}✅ Conversação 2 criada (user_a ↔ user_c)${NC}"
    echo "   ID: $CONV_ID_2"
else
    echo -e "${YELLOW}⚠️  Falha ao criar conversação 2${NC}"
    CONV_ID_2="test-conv-2"
fi

echo ""

# ============================================
# ETAPA 4: ENVIAR MENSAGENS
# ============================================
echo "📨 ETAPA 4: Enviando mensagens..."
echo "---------------------------------"

# Mensagem 1: WhatsApp
echo "Enviando mensagem 1 (WhatsApp)..."
MSG1_RESPONSE=$(curl -s -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d '{
    "conversation_id": "'$CONV_ID_1'",
    "recipient_id": "whatsapp:+5511999999999",
    "content": "Olá! Esta é a primeira mensagem de teste do sistema Chat4All."
  }')

MSG_ID_1=$(echo "$MSG1_RESPONSE" | jq -r '.messageId // .message_id // empty')
echo -e "${GREEN}✅ Mensagem 1 enviada (WhatsApp)${NC}"
[ -n "$MSG_ID_1" ] && echo "   ID: $MSG_ID_1"

# Mensagem 2: Instagram
echo "Enviando mensagem 2 (Instagram)..."
MSG2_RESPONSE=$(curl -s -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d '{
    "conversation_id": "'$CONV_ID_1'",
    "recipient_id": "instagram:@maria_silva",
    "content": "Olá Maria! Como você está? Esta é uma mensagem via Instagram."
  }')

MSG_ID_2=$(echo "$MSG2_RESPONSE" | jq -r '.messageId // .message_id // empty')
echo -e "${GREEN}✅ Mensagem 2 enviada (Instagram)${NC}"

# Mensagem 3: WhatsApp (resposta)
echo "Enviando mensagem 3 (WhatsApp)..."
curl -s -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_B" \
  -d '{
    "conversation_id": "'$CONV_ID_1'",
    "recipient_id": "whatsapp:+5511988888888",
    "content": "Oi! Recebi sua mensagem. Obrigado pelo contato!"
  }' > /dev/null

echo -e "${GREEN}✅ Mensagem 3 enviada (resposta user_b)${NC}"

# Mensagem 4: Instagram (conversação 2)
echo "Enviando mensagem 4 (Instagram)..."
curl -s -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d '{
    "conversation_id": "'$CONV_ID_2'",
    "recipient_id": "instagram:@joao_santos",
    "content": "João, segue a informação que você pediu!"
  }' > /dev/null

echo -e "${GREEN}✅ Mensagem 4 enviada (Instagram)${NC}"

# Mensagem 5: WhatsApp (conversação 2)
echo "Enviando mensagem 5 (WhatsApp)..."
curl -s -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_C" \
  -d '{
    "conversation_id": "'$CONV_ID_2'",
    "recipient_id": "whatsapp:+5511977777777",
    "content": "Perfeito! Recebi tudo. Muito obrigado!"
  }' > /dev/null

echo -e "${GREEN}✅ Mensagem 5 enviada (resposta user_c)${NC}"

echo ""
echo -e "${YELLOW}⏳ Aguardando 10 segundos para os connectors processarem...${NC}"
sleep 10

# ============================================
# ETAPA 5: UPLOAD DE ARQUIVOS
# ============================================
echo ""
echo "📁 ETAPA 5: Fazendo upload de arquivos..."
echo "-----------------------------------------"

# Criar arquivo de teste 1MB
echo "Criando arquivo de teste (1MB)..."
dd if=/dev/urandom of=/tmp/chat4all_test_file.txt bs=1M count=1 2>/dev/null
echo -e "${GREEN}✅ Arquivo criado: /tmp/chat4all_test_file.txt${NC}"

# Upload arquivo 1
echo "Fazendo upload do arquivo 1..."
FILE1_RESPONSE=$(curl -s -X POST http://localhost:8080/v1/files \
  -H "Authorization: Bearer $TOKEN_A" \
  -F "file=@/tmp/chat4all_test_file.txt" \
  -F "conversation_id=$CONV_ID_1")

FILE_ID_1=$(echo "$FILE1_RESPONSE" | jq -r '.fileId // .file_id // empty')
if [ -n "$FILE_ID_1" ] && [ "$FILE_ID_1" != "null" ]; then
    echo -e "${GREEN}✅ Arquivo 1 uploaded${NC}"
    echo "   ID: $FILE_ID_1"
    echo "   Nome: chat4all_test_file.txt"
    echo "   Tamanho: 1MB"
else
    echo -e "${YELLOW}⚠️  Falha no upload do arquivo 1${NC}"
fi

# Criar arquivo pequeno (texto)
echo "Criando arquivo de texto..."
echo "Este é um documento importante do Chat4All.

Conteúdo:
- Relatório de testes
- Validação de persistência
- Integração com MinIO

Data: $(date)
" > /tmp/chat4all_documento.txt

# Upload arquivo 2
echo "Fazendo upload do arquivo 2..."
FILE2_RESPONSE=$(curl -s -X POST http://localhost:8080/v1/files \
  -H "Authorization: Bearer $TOKEN_A" \
  -F "file=@/tmp/chat4all_documento.txt" \
  -F "conversation_id=$CONV_ID_2")

FILE_ID_2=$(echo "$FILE2_RESPONSE" | jq -r '.fileId // .file_id // empty')
if [ -n "$FILE_ID_2" ] && [ "$FILE_ID_2" != "null" ]; then
    echo -e "${GREEN}✅ Arquivo 2 uploaded${NC}"
    echo "   ID: $FILE_ID_2"
    echo "   Nome: chat4all_documento.txt"
fi

# ============================================
# ETAPA 6: ENVIAR MENSAGENS COM ARQUIVOS
# ============================================
echo ""
echo "📎 ETAPA 6: Enviando mensagens com anexos..."
echo "--------------------------------------------"

if [ -n "$FILE_ID_1" ] && [ "$FILE_ID_1" != "null" ]; then
    echo "Enviando mensagem com arquivo 1 anexado..."
    curl -s -X POST http://localhost:8080/v1/messages \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN_A" \
      -d '{
        "conversation_id": "'$CONV_ID_1'",
        "recipient_id": "whatsapp:+5511999999999",
        "content": "Segue o arquivo que você solicitou.",
        "file_id": "'$FILE_ID_1'"
      }' > /dev/null
    
    echo -e "${GREEN}✅ Mensagem com arquivo 1 enviada${NC}"
fi

if [ -n "$FILE_ID_2" ] && [ "$FILE_ID_2" != "null" ]; then
    echo "Enviando mensagem com arquivo 2 anexado..."
    curl -s -X POST http://localhost:8080/v1/messages \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN_A" \
      -d '{
        "conversation_id": "'$CONV_ID_2'",
        "recipient_id": "instagram:@joao_santos",
        "content": "Documento anexado conforme combinado.",
        "file_id": "'$FILE_ID_2'"
      }' > /dev/null
    
    echo -e "${GREEN}✅ Mensagem com arquivo 2 enviada${NC}"
fi

echo ""
echo -e "${YELLOW}⏳ Aguardando 5 segundos para processamento final...${NC}"
sleep 5

# ============================================
# SUMÁRIO FINAL
# ============================================
echo ""
echo "✅ CARGA INICIAL CONCLUÍDA!"
echo "=========================================="
echo ""
echo "📊 SUMÁRIO DOS DADOS CRIADOS:"
echo ""
echo "👥 Usuários: 3"
echo "   - user_a (email: user_a@example.com)"
echo "   - user_b (email: user_b@example.com)"
echo "   - user_c (email: user_c@example.com)"
echo ""
echo "💬 Conversações: 2"
echo "   - Conversação 1: user_a ↔ user_b"
echo "   - Conversação 2: user_a ↔ user_c"
echo ""
echo "📨 Mensagens: 7"
echo "   - 4 via WhatsApp"
echo "   - 3 via Instagram"
echo ""
echo "📁 Arquivos: 2"
echo "   - chat4all_test_file.txt (1MB)"
echo "   - chat4all_documento.txt (~300 bytes)"
echo ""
echo "=========================================="
echo ""
echo "🔍 COMO VALIDAR NO CASSANDRA:"
echo ""
echo "1. Conectar no Cassandra:"
echo "   docker exec -it chat4all-cassandra cqlsh"
echo ""
echo "2. Executar queries de validação:"
echo ""
echo "   # Contar usuários"
echo "   SELECT COUNT(*) FROM chat4all.users;"
echo "   # Esperado: 3"
echo ""
echo "   # Listar usuários"
echo "   SELECT username, email FROM chat4all.users;"
echo ""
echo "   # Contar conversações"
echo "   SELECT COUNT(*) FROM chat4all.conversations;"
echo "   # Esperado: 2"
echo ""
echo "   # Contar mensagens"
echo "   SELECT COUNT(*) FROM chat4all.messages;"
echo "   # Esperado: 7"
echo ""
echo "   # Listar mensagens com status"
echo "   SELECT message_id, content, status, sent_at FROM chat4all.messages LIMIT 10;"
echo ""
echo "   # Contar arquivos"
echo "   SELECT COUNT(*) FROM chat4all.files;"
echo "   # Esperado: 2"
echo ""
echo "   # Listar arquivos"
echo "   SELECT file_id, filename, size_bytes FROM chat4all.files;"
echo ""
echo "=========================================="
echo ""
echo "📊 VERIFICAR MÉTRICAS:"
echo "   - Prometheus: http://localhost:9090"
echo "   - Grafana: http://localhost:3000 (admin/admin)"
echo "   - MinIO Console: http://localhost:9001 (minioadmin/minioadmin)"
echo ""
echo "🔧 VERIFICAR LOGS DOS CONNECTORS:"
echo "   docker-compose logs connector-whatsapp | tail -30"
echo "   docker-compose logs connector-instagram | tail -30"
echo ""
echo -e "${GREEN}✨ Script concluído com sucesso!${NC}"
