#!/bin/bash

# Demo Simplificado: Troca de Mensagens entre João (user_a) e Maria (user_b)
# Mostra timestamps e status das mensagens

API_URL="http://localhost:8082"
CONV_ID="conv_demo_$(date +%s)"

echo "=========================================================="
echo "  📱 Conversação: João e Maria"
echo "=========================================================="
echo "Conversation ID: $CONV_ID"
echo ""

# Autenticar João
echo "→ Autenticando João (user_a)..."
JOAO_TOKEN=$(curl -s $API_URL/auth/token -H "Content-Type: application/json" -d '{"username":"user_a","password":"pass_a"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
echo "✓ João autenticado"
echo ""

# Autenticar Maria
echo "→ Autenticando Maria (user_b)..."
MARIA_TOKEN=$(curl -s $API_URL/auth/token -H "Content-Type: application/json" -d '{"username":"user_b","password":"pass_b"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
echo "✓ Maria autenticada"
echo ""

# João envia 3 mensagens
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "👨 João enviando mensagens..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

curl -s $API_URL/v1/messages \
  -H "Authorization: Bearer $JOAO_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"conversation_id\":\"$CONV_ID\",\"sender_id\":\"user_a\",\"content\":\"Oi Maria, tudo bem?\"}"
echo ""
echo "✓ Mensagem 1 enviada: \"Oi Maria, tudo bem?\""
sleep 1

curl -s $API_URL/v1/messages \
  -H "Authorization: Bearer $JOAO_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"conversation_id\":\"$CONV_ID\",\"sender_id\":\"user_a\",\"content\":\"Podemos conversar sobre o projeto?\"}"
echo ""
echo "✓ Mensagem 2 enviada: \"Podemos conversar sobre o projeto?\""
sleep 1

curl -s $API_URL/v1/messages \
  -H "Authorization: Bearer $JOAO_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"conversation_id\":\"$CONV_ID\",\"sender_id\":\"user_a\",\"content\":\"Que tal às 15h?\"}"
echo ""
echo "✓ Mensagem 3 enviada: \"Que tal às 15h?\""
echo ""

# Aguardar processamento
echo "⏳ Aguardando Worker processar (12 segundos)..."
sleep 12
echo ""

# Maria envia 3 mensagens
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "👩 Maria respondendo..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

curl -s $API_URL/v1/messages \
  -H "Authorization: Bearer $MARIA_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"conversation_id\":\"$CONV_ID\",\"sender_id\":\"user_b\",\"content\":\"Oi João! Tudo ótimo, e você?\"}"
echo ""
echo "✓ Mensagem 4 enviada: \"Oi João! Tudo ótimo, e você?\""
sleep 1

curl -s $API_URL/v1/messages \
  -H "Authorization: Bearer $MARIA_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"conversation_id\":\"$CONV_ID\",\"sender_id\":\"user_b\",\"content\":\"Claro! Que horas funciona melhor?\"}"
echo ""
echo "✓ Mensagem 5 enviada: \"Claro! Que horas funciona melhor?\""
sleep 1

curl -s $API_URL/v1/messages \
  -H "Authorization: Bearer $MARIA_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"conversation_id\":\"$CONV_ID\",\"sender_id\":\"user_b\",\"content\":\"Perfeito! Te mando o link às 14h50.\"}"
echo ""
echo "✓ Mensagem 6 enviada: \"Perfeito! Te mando o link às 14h50.\""
echo ""

# Aguardar processamento final
echo "⏳ Aguardando processamento final (12 segundos)..."
sleep 12
echo ""

# Visualizar histórico completo
echo "=========================================================="
echo "  📖 HISTÓRICO DA CONVERSAÇÃO"
echo "=========================================================="
echo ""

curl -s "$API_URL/v1/conversations/$CONV_ID/messages?limit=20" \
  -H "Authorization: Bearer $JOAO_TOKEN" | python3 -c "
import sys, json
from datetime import datetime

try:
    data = json.load(sys.stdin)
    messages = data.get('messages', [])
    conv_id = data.get('conversation_id', 'N/A')
    pagination = data.get('pagination', {})
    
    print(f'Conversação: {conv_id}')
    print(f'Total de mensagens retornadas: {pagination.get(\"returned\", 0)}')
    print()
    print('─' * 90)
    print(f'{\"#\":<4} {\"Remetente\":<12} {\"Timestamp\":<20} {\"Status\":<12} {\"Conteúdo\":<30}')
    print('─' * 90)
    
    for i, msg in enumerate(messages, 1):
        sender = msg.get('sender_id', 'unknown')
        content = msg.get('content', '')[:40]
        timestamp_ms = msg.get('timestamp', 0)
        status = msg.get('status', 'UNKNOWN')
        msg_id = msg.get('message_id', 'N/A')[:15]
        
        # Converter timestamp
        if timestamp_ms:
            dt = datetime.fromtimestamp(timestamp_ms / 1000.0)
            time_str = dt.strftime('%H:%M:%S.%f')[:-3]
        else:
            time_str = 'N/A'
        
        # Emoji
        emoji = '👨' if sender == 'user_a' else '👩'
        sender_name = 'João' if sender == 'user_a' else 'Maria'
        
        print(f'{i:<4} {emoji} {sender_name:<10} {time_str:<20} {status:<12} {content}')
    
    print('─' * 90)
    print()
    
    # Estatísticas
    joao_msgs = sum(1 for m in messages if m.get('sender_id') == 'user_a')
    maria_msgs = sum(1 for m in messages if m.get('sender_id') == 'user_b')
    delivered = sum(1 for m in messages if m.get('status') == 'DELIVERED')
    
    print('📊 Estatísticas:')
    print(f'   • Mensagens de João: {joao_msgs}')
    print(f'   • Mensagens de Maria: {maria_msgs}')
    print(f'   • Total: {len(messages)}')
    print(f'   • Status DELIVERED: {delivered}/{len(messages)}')
    
except Exception as e:
    print(f'Erro: {e}', file=sys.stderr)
    import traceback
    traceback.print_exc()
"

echo ""
echo "=========================================================="
echo "✅ Demo completa!"
echo "=========================================================="
