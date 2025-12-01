#!/bin/bash

# Demo de Notificações em Tempo Real no CLI
# Este script demonstra o sistema de notificações push

set -e

API_URL="http://localhost:8080"
TIMESTAMP=$(date +%s)

echo "════════════════════════════════════════════════════════════"
echo "  🔔 Demo: Sistema de Notificações em Tempo Real"
echo "════════════════════════════════════════════════════════════"
echo ""

# ============================================================================
# ETAPA 1: Criar dois usuários (Alice e Bob)
# ============================================================================

echo "📝 Etapa 1: Criando usuários de teste..."
echo ""

# Registrar Alice
echo "⏳ Registrando Alice..."
ALICE_RESPONSE=$(curl -s -X POST "$API_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "alice_'$TIMESTAMP'",
    "password": "alice123",
    "email": "alice_'$TIMESTAMP'@example.com"
  }')

ALICE_ID=$(echo "$ALICE_RESPONSE" | jq -r '.user_id')

if [ "$ALICE_ID" != "null" ] && [ -n "$ALICE_ID" ]; then
    echo "✅ Alice registrada! ID: $ALICE_ID"
else
    echo "❌ Erro ao registrar Alice"
    exit 1
fi

# Login de Alice
ALICE_TOKEN=$(curl -s -X POST "$API_URL/auth/token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "alice_'$TIMESTAMP'",
    "password": "alice123"
  }' | jq -r '.access_token')

echo "   Token: ${ALICE_TOKEN:0:30}..."

# Registrar Bob
echo ""
echo "⏳ Registrando Bob..."
BOB_RESPONSE=$(curl -s -X POST "$API_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "bob_'$TIMESTAMP'",
    "password": "bob123",
    "email": "bob_'$TIMESTAMP'@example.com"
  }')

BOB_ID=$(echo "$BOB_RESPONSE" | jq -r '.user_id')

if [ "$BOB_ID" != "null" ] && [ -n "$BOB_ID" ]; then
    echo "✅ Bob registrado! ID: $BOB_ID"
else
    echo "❌ Erro ao registrar Bob"
    exit 1
fi

# Login de Bob
BOB_TOKEN=$(curl -s -X POST "$API_URL/auth/token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "bob_'$TIMESTAMP'",
    "password": "bob123"
  }' | jq -r '.access_token')

echo "   Token: ${BOB_TOKEN:0:30}..."

# ============================================================================
# ETAPA 2: Criar conversa
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════"
echo "💬 Etapa 2: Criando conversa entre Alice e Bob..."
echo "════════════════════════════════════════════════════════════"
echo ""

CONV_ID="demo_notifications_$TIMESTAMP"
echo "Conversation ID: $CONV_ID"

# ============================================================================
# ETAPA 3: Instruções para o usuário
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════"
echo "🎯 INSTRUÇÕES PARA TESTE"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "1️⃣  Abra um NOVO terminal e execute:"
echo ""
echo "    cd /home/tizzo/chat4alltijolim/cli"
echo "    python3 chat4all-cli.py"
echo ""
echo "2️⃣  No CLI, faça login como Alice:"
echo ""
echo "    Opção: 2 (Autenticar)"
echo "    Username: alice_$TIMESTAMP"
echo "    Password: alice123"
echo ""
echo "3️⃣  Ative as notificações:"
echo ""
echo "    Opção: 12 (Ativar notificações)"
echo ""
echo "4️⃣  Volte para este terminal e pressione ENTER"
echo "    (este script enviará mensagens do Bob para Alice)"
echo ""

read -p "Pressione ENTER quando Alice estiver com notificações ATIVAS..."

# ============================================================================
# ETAPA 4: Bob envia mensagens para Alice
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════"
echo "📨 Enviando mensagens do Bob para Alice..."
echo "════════════════════════════════════════════════════════════"
echo ""

# Mensagem 1
echo "⏳ Mensagem 1: Cumprimento..."
MSG1_RESPONSE=$(curl -s -X POST "$API_URL/v1/messages" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "'$CONV_ID'",
    "recipient_id": "user:'$ALICE_ID'",
    "content": "Olá Alice! Como você está? 👋"
  }')

MSG1_ID=$(echo "$MSG1_RESPONSE" | jq -r '.message_id')
echo "✅ Mensagem 1 enviada! ID: $MSG1_ID"
echo "   👀 Verifique o terminal do CLI - Alice deve ter recebido notificação!"
echo ""

sleep 5

# Mensagem 2
echo "⏳ Mensagem 2: Pergunta..."
MSG2_RESPONSE=$(curl -s -X POST "$API_URL/v1/messages" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "'$CONV_ID'",
    "recipient_id": "user:'$ALICE_ID'",
    "content": "Você viu a documentação do sistema de grupos? Ficou muito bom! 📚"
  }')

MSG2_ID=$(echo "$MSG2_RESPONSE" | jq -r '.message_id')
echo "✅ Mensagem 2 enviada! ID: $MSG2_ID"
echo "   👀 Nova notificação para Alice!"
echo ""

sleep 5

# Mensagem 3
echo "⏳ Mensagem 3: Convite..."
MSG3_RESPONSE=$(curl -s -X POST "$API_URL/v1/messages" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "'$CONV_ID'",
    "recipient_id": "user:'$ALICE_ID'",
    "content": "Vamos marcar uma reunião para discutir as próximas features? 🤝"
  }')

MSG3_ID=$(echo "$MSG3_RESPONSE" | jq -r '.message_id')
echo "✅ Mensagem 3 enviada! ID: $MSG3_ID"
echo "   👀 Mais uma notificação!"
echo ""

sleep 5

# Mensagem 4 com urgência
echo "⏳ Mensagem 4: Urgente..."
MSG4_RESPONSE=$(curl -s -X POST "$API_URL/v1/messages" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "'$CONV_ID'",
    "recipient_id": "user:'$ALICE_ID'",
    "content": "🚨 URGENTE: O servidor de produção está com 90% de uso de memória!"
  }')

MSG4_ID=$(echo "$MSG4_RESPONSE" | jq -r '.message_id')
echo "✅ Mensagem 4 enviada! ID: $MSG4_ID"
echo "   👀 Notificação urgente para Alice!"
echo ""

# ============================================================================
# ETAPA 5: Verificação
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ TESTE CONCLUÍDO"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "📊 Resumo:"
echo "   • 4 mensagens enviadas do Bob para Alice"
echo "   • Alice deve ter recebido 4 notificações no CLI"
echo "   • Cada notificação mostrou:"
echo "     - Nome da conversa"
echo "     - Remetente (Bob)"
echo "     - Conteúdo da mensagem"
echo "     - Horário"
echo ""
echo "🔍 Validações no CLI de Alice:"
echo ""
echo "   1. Verificar se as 4 notificações apareceram"
echo "   2. Verificar se o nome da conversa está correto"
echo "   3. Usar opção 7 para listar mensagens da conversa"
echo "   4. Conversation ID: $CONV_ID"
echo ""
echo "💡 Dicas:"
echo "   • Use Opção 12 novamente para desativar notificações"
echo "   • As notificações verificam novas mensagens a cada 3 segundos"
echo "   • Somente mensagens de outros usuários geram notificações"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  🎉 Demo Completo!"
echo "════════════════════════════════════════════════════════════"
