#!/bin/bash

# Script para testar registro de usuário com WhatsApp e Instagram
# Chat4All - Teste de Funcionalidade

set -e

API_URL="http://localhost:8080"

echo "========================================================"
echo "  🧪 Teste: Registro de Usuário com Identidades"
echo "========================================================"
echo

# Gerar dados únicos
TIMESTAMP=$(date +%s)
USERNAME="testuser_${TIMESTAMP}"
EMAIL="test${TIMESTAMP}@example.com"
PASSWORD="senha123"
WHATSAPP="+5562996991${TIMESTAMP: -3}"
INSTAGRAM="@user${TIMESTAMP}"

echo "📋 Dados do teste:"
echo "  Username: $USERNAME"
echo "  Email: $EMAIL"
echo "  WhatsApp: $WHATSAPP"
echo "  Instagram: $INSTAGRAM"
echo

# 1. Registrar usuário
echo "⏳ Passo 1: Registrando usuário..."
REGISTER_RESPONSE=$(curl -s -X POST ${API_URL}/auth/register \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$USERNAME\",
    \"password\": \"$PASSWORD\",
    \"email\": \"$EMAIL\"
  }")

echo "$REGISTER_RESPONSE" | python3 -m json.tool

USER_ID=$(echo "$REGISTER_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('user_id', ''))")

if [ -z "$USER_ID" ]; then
    echo "❌ Falha ao registrar usuário"
    exit 1
fi

echo "✅ Usuário registrado! ID: $USER_ID"
echo

# 2. Fazer login
echo "⏳ Passo 2: Fazendo login..."
LOGIN_RESPONSE=$(curl -s -X POST ${API_URL}/auth/token \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$USERNAME\",
    \"password\": \"$PASSWORD\"
  }")

echo "$LOGIN_RESPONSE" | python3 -m json.tool

TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))")

if [ -z "$TOKEN" ]; then
    echo "❌ Falha no login"
    exit 1
fi

echo "✅ Login realizado!"
echo "   Token: ${TOKEN:0:50}..."
echo

# 3. Vincular WhatsApp
echo "⏳ Passo 3: Vinculando WhatsApp..."
WHATSAPP_RESPONSE=$(curl -s -X POST ${API_URL}/v1/users/identities \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"platform\": \"whatsapp\",
    \"value\": \"$WHATSAPP\"
  }")

echo "$WHATSAPP_RESPONSE" | python3 -m json.tool

if echo "$WHATSAPP_RESPONSE" | grep -q "error"; then
    echo "❌ Falha ao vincular WhatsApp"
    echo "$WHATSAPP_RESPONSE"
else
    echo "✅ WhatsApp vinculado!"
fi
echo

# 4. Vincular Instagram
echo "⏳ Passo 4: Vinculando Instagram..."
INSTAGRAM_RESPONSE=$(curl -s -X POST ${API_URL}/v1/users/identities \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"platform\": \"instagram\",
    \"value\": \"$INSTAGRAM\"
  }")

echo "$INSTAGRAM_RESPONSE" | python3 -m json.tool

if echo "$INSTAGRAM_RESPONSE" | grep -q "error"; then
    echo "❌ Falha ao vincular Instagram"
    echo "$INSTAGRAM_RESPONSE"
else
    echo "✅ Instagram vinculado!"
fi
echo

# 5. Listar identidades
echo "⏳ Passo 5: Listando identidades vinculadas..."
IDENTITIES_RESPONSE=$(curl -s -X GET ${API_URL}/v1/users/identities \
  -H "Authorization: Bearer $TOKEN")

echo "$IDENTITIES_RESPONSE" | python3 -m json.tool

IDENTITY_COUNT=$(echo "$IDENTITIES_RESPONSE" | python3 -c "import sys, json; print(len(json.load(sys.stdin).get('identities', [])))")

echo
echo "✅ Total de identidades vinculadas: $IDENTITY_COUNT"
echo

# 6. Verificar no Cassandra
echo "⏳ Passo 6: Verificando dados no Cassandra..."
echo

echo "👤 Usuário na tabela users:"
docker exec chat4all-cassandra cqlsh -e "
SELECT user_id, username, email 
FROM chat4all.users 
WHERE username = '$USERNAME' 
ALLOW FILTERING;" 2>/dev/null || echo "Erro ao consultar users"

echo
echo "🔗 Identidades na tabela user_identities:"
docker exec chat4all-cassandra cqlsh -e "
SELECT platform, identity_value, verified 
FROM chat4all.user_identities 
WHERE user_id = '$USER_ID' 
ALLOW FILTERING;" 2>/dev/null || echo "Erro ao consultar identities"

echo
echo "========================================================"
echo "  ✅ Teste Completo!"
echo "========================================================"
echo
echo "📊 Resumo:"
echo "  • Usuário criado: $USERNAME"
echo "  • User ID: $USER_ID"
echo "  • Token gerado: ✓"
echo "  • WhatsApp vinculado: $WHATSAPP"
echo "  • Instagram vinculado: $INSTAGRAM"
echo "  • Total de identidades: $IDENTITY_COUNT"
echo
echo "🧪 Para testar no CLI:"
echo "  cd ~/chat4alltijolim/cli"
echo "  python3 chat4all-cli.py"
echo "  Opção 10: Ver identidades vinculadas"
echo
