#!/usr/bin/env python3
"""
Script para testar notificações entre 2 usuários REAIS do sistema
Cenário: user_a envia mensagem para user_b (ambos usuários internos)
"""

import requests
import time
import json

API_URL = "http://localhost:8080"

print("=" * 70)
print("  TESTE DE NOTIFICAÇÕES - Usuários Reais")
print("=" * 70)

# 1. Autenticar user_a
print("\n[1] Autenticando user_a...")
auth_a = requests.post(
    f"{API_URL}/auth/token",
    json={"username": "user_a", "password": "pass_a"},
    timeout=10
)

if auth_a.status_code != 200:
    print(f"❌ Falha: {auth_a.status_code}")
    exit(1)

token_a = auth_a.json()['access_token']
print("✓ user_a autenticado")

# Extrair user_id do token
import base64
parts = token_a.split('.')
payload = base64.urlsafe_b64decode(parts[1] + '==')
user_id_a = json.loads(payload)['sub']
print(f"  User ID: {user_id_a}")

# 2. Autenticar user_b
print("\n[2] Autenticando user_b...")
auth_b = requests.post(
    f"{API_URL}/auth/token",
    json={"username": "user_b", "password": "pass_b"},
    timeout=10
)

if auth_b.status_code != 200:
    print(f"❌ Falha: {auth_b.status_code}")
    exit(1)

token_b = auth_b.json()['access_token']
print("✓ user_b autenticado")

parts = token_b.split('.')
payload = base64.urlsafe_b64decode(parts[1] + '==')
user_id_b = json.loads(payload)['sub']
print(f"  User ID: {user_id_b}")

# 3. Criar conversa (apenas memória - para demonstração)
conv_id = f"conv_test_notifications_{int(time.time())}"
print(f"\n[3] Usando conversation ID: {conv_id}")

# 4. user_a envia mensagem para user_b (user_id, não instagram:@...)
print(f"\n[4] user_a enviando mensagem para user_b...")
print(f"    Recipient: {user_id_b} (usuário interno!)")

message = requests.post(
    f"{API_URL}/v1/messages",
    headers={"Authorization": f"Bearer {token_a}"},
    json={
        "conversation_id": conv_id,
        "recipient_id": user_id_b,  # ← Destinatário é user_id, não instagram:@...
        "content": "Olá user_b! Esta é uma mensagem de teste de notificações."
    },
    timeout=10
)

if message.status_code not in [200, 201, 202]:
    print(f"❌ Erro ao enviar: {message.status_code}")
    print(message.text)
    exit(1)

msg_data = message.json()
msg_id = msg_data.get('message_id')
print(f"✓ Mensagem enviada: {msg_id}")
print(f"  Status: {msg_data.get('status')}")

# 5. Aguardar processamento
print("\n[5] Aguardando processamento (5s)...")
time.sleep(5)

# 6. Verificar se user_b recebe a mensagem
print(f"\n[6] Verificando mensagens de user_b...")
messages_b = requests.get(
    f"{API_URL}/v1/conversations/{conv_id}/messages",
    headers={"Authorization": f"Bearer {token_b}"},
    timeout=10
)

if messages_b.status_code == 200:
    data = messages_b.json()
    count = len(data.get('messages', []))
    print(f"✓ user_b vê {count} mensagem(s) na conversa")
    
    if count > 0:
        for msg in data['messages']:
            print(f"  • {msg.get('content')} (de: {msg.get('sender_id')[:10]}...)")
else:
    print(f"⚠ Não foi possível buscar mensagens: {messages_b.status_code}")

# 7. Instruções para testar WebSocket
print("\n" + "=" * 70)
print("  PRÓXIMO PASSO: Testar WebSocket em 2 terminais")
print("=" * 70)
print("""
Terminal 1 (user_b recebendo):
  $ cd cli && python3 chat4all-cli.py
  Opção 2: Autenticar com user_b / pass_b
  Opção 12: Ativar notificações
  (Aguardar conectado...)

Terminal 2 (user_a enviando):
  $ cd cli && python3 chat4all-cli.py
  Opção 2: Autenticar com user_a / pass_a
  Opção 5: Enviar mensagem
    - Conversation ID: {conv_id}
    - Recipient ID: {user_id_b}
    - Mensagem: Teste WebSocket!

Terminal 1 deve receber notificação em tempo real! 📲
""".format(conv_id=conv_id, user_id_b=user_id_b))

print("\n✅ Teste concluído!")
print(f"\nConversation ID para usar no CLI: {conv_id}")
print(f"user_b ID: {user_id_b}")
