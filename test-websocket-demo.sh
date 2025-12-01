#!/bin/bash
# Script para demonstrar WebSocket notifications
# Abre duas janelas CLI side-by-side

echo "🚀 Teste WebSocket - Chat4All"
echo ""
echo "📝 INSTRUÇÕES:"
echo ""
echo "Terminal 1 (ALICE - este terminal):"
echo "  1. Registrar: alice / senha123"
echo "  2. Login: alice / senha123"
echo "  3. Ativar notificações (opção 12)"
echo "  4. AGUARDAR mensagem de Bob..."
echo ""
echo "Terminal 2 (BOB - abrir outro terminal):"
echo "  cd /home/tizzo/chat4alltijolim/cli"
echo "  python3 chat4all-cli.py"
echo "  1. Registrar: bob / senha123"
echo "  2. Login: bob / senha123"
echo "  3. Criar conversa: nome=teste, participantes=alice,bob"
echo "  4. Enviar mensagem para alice"
echo ""
echo "🎯 RESULTADO: Alice receberá notificação INSTANTÂNEA (<100ms)!"
echo ""
read -p "Pressione ENTER para iniciar CLI de Alice..."

cd /home/tizzo/chat4alltijolim/cli
python3 chat4all-cli.py
