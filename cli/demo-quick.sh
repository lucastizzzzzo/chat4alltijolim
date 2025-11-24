#!/bin/bash
# Demo rápido do CLI funcionando

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  🚀 Chat4All CLI - Demo Rápido                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se API está rodando
echo "1️⃣  Verificando se API está online..."
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "   ✓ API respondendo em http://localhost:8080"
else
    echo "   ❌ API offline. Execute: docker-compose up -d"
    exit 1
fi

echo ""
echo "2️⃣  Testando autenticação..."
TOKEN=$(curl -s -X POST http://localhost:8080/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username":"user_a","password":"pass_a"}' \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)

if [ -n "$TOKEN" ]; then
    echo "   ✓ Autenticado como user_a"
    echo "   Token: ${TOKEN:0:20}..."
else
    echo "   ❌ Falha na autenticação"
    exit 1
fi

echo ""
echo "3️⃣  Enviando mensagem de teste..."
MSG_ID=$(curl -s -X POST http://localhost:8080/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "conv_cli_demo",
    "sender_id": "user_a",
    "recipient_id": "user_b",
    "content": "Teste do CLI! 🚀"
  }' | python3 -c "import sys, json; print(json.load(sys.stdin)['message_id'])" 2>/dev/null)

if [ -n "$MSG_ID" ]; then
    echo "   ✓ Mensagem enviada"
    echo "   Message ID: $MSG_ID"
else
    echo "   ❌ Falha ao enviar mensagem"
    exit 1
fi

echo ""
echo "4️⃣  Aguardando processamento (3 segundos)..."
sleep 3

echo ""
echo "5️⃣  Listando mensagens..."
MESSAGES=$(curl -s -X GET "http://localhost:8080/v1/conversations/conv_cli_demo/messages?limit=10&offset=0" \
  -H "Authorization: Bearer $TOKEN")

if echo "$MESSAGES" | python3 -c "import sys, json; msgs = json.load(sys.stdin)['messages']; print(f\"   ✓ {len(msgs)} mensagem(ns) encontrada(s)\"); [print(f\"      • {m['content']} (status: {m['status']})\") for m in msgs]" 2>/dev/null; then
    true
else
    echo "   ⚠  Aguarde mais tempo para processamento ou verifique os logs"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✅ Demo completo! Agora teste o CLI interativo:              ║"
echo "║                                                                 ║"
echo "║     ./cli/chat4all-cli.py                                      ║"
echo "║                                                                 ║"
echo "║  Login: user_a / pass_a  ou  user_b / pass_b                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
