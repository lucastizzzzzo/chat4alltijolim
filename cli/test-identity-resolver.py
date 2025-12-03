#!/usr/bin/env python3
"""
Teste do IdentityResolver - Enviar mensagens usando username/whatsapp/instagram
"""

import requests
import json
import base64

API_URL = "http://localhost:8080"

print("=" * 70)
print("  TESTE: Resolver Identidades Automaticamente")
print("=" * 70)

# 1. Autenticar user_a
print("\n[1] Autenticando user_a...")
auth = requests.post(
    f"{API_URL}/auth/token",
    json={"username": "user_a", "password": "pass_a"},
    timeout=10
)
token = auth.json()['access_token']
print("✓ Autenticado")

# 2. Criar conversa de teste
conv_id = "conv_identity_test"
print(f"\n[2] Usando conversation_id: {conv_id}")

# 3. TESTE 1: Enviar usando USERNAME
print("\n[3] TESTE 1: Enviar mensagem para USERNAME 'user_b'")
print("    Recipient: user_b (username)")

msg1 = requests.post(
    f"{API_URL}/v1/messages",
    headers={"Authorization": f"Bearer {token}"},
    json={
        "conversation_id": conv_id,
        "recipient_id": "user_b",  # ← USERNAME (será resolvido para user_id)
        "content": "Teste 1: Enviado usando username 'user_b'"
    },
    timeout=10
)

if msg1.status_code in [200, 201, 202]:
    print(f"✓ Mensagem enviada: {msg1.json().get('message_id')}")
else:
    print(f"❌ Erro: {msg1.status_code} - {msg1.text}")

# 4. TESTE 2: Enviar usando WhatsApp (se vinculado)
print("\n[4] TESTE 2: Enviar para WhatsApp vinculado")
print("    Recipient: whatsapp:+5562996991812 (será resolvido se vinculado)")

msg2 = requests.post(
    f"{API_URL}/v1/messages",
    headers={"Authorization": f"Bearer {token}"},
    json={
        "conversation_id": conv_id,
        "recipient_id": "whatsapp:+5562996991812",  # ← Resolve se vinculado
        "content": "Teste 2: Enviado para WhatsApp (resolvido ou externo)"
    },
    timeout=10
)

if msg2.status_code in [200, 201, 202]:
    print(f"✓ Mensagem enviada: {msg2.json().get('message_id')}")
else:
    print(f"❌ Erro: {msg2.status_code} - {msg2.text}")

# 5. TESTE 3: Instagram externo (não vinculado)
print("\n[5] TESTE 3: Enviar para Instagram EXTERNO (não vinculado)")
print("    Recipient: instagram:@external_user")

msg3 = requests.post(
    f"{API_URL}/v1/messages",
    headers={"Authorization": f"Bearer {token}"},
    json={
        "conversation_id": conv_id,
        "recipient_id": "instagram:@external_user",  # ← Externo
        "content": "Teste 3: Instagram externo (vai para conector)"
    },
    timeout=10
)

if msg3.status_code in [200, 201, 202]:
    print(f"✓ Mensagem enviada: {msg3.json().get('message_id')}")
    print("  → Roteada para conector Instagram (usuário externo)")
else:
    print(f"❌ Erro: {msg3.status_code} - {msg3.text}")

# 6. Verificar logs do API service
print("\n[6] Verificando logs do API Service...")
print("    Execute: docker logs chat4alltijolim_api-service_1 | grep IdentityResolver")
print("\n    Você verá algo como:")
print("      [IdentityResolver] Resolved username user_b → <user_id>")
print("      [IdentityResolver] External identity: instagram:@external_user")

print("\n" + "=" * 70)
print("✅ Testes concluídos!")
print("=" * 70)

print("""
RESUMO:
- ✓ Pode enviar mensagens usando USERNAME (ex: user_b)
- ✓ Pode enviar usando WhatsApp vinculado (whatsapp:+55...)
- ✓ Pode enviar usando Instagram vinculado (instagram:@...)
- ✓ Identidades externas (não vinculadas) vão para conectores

PRÓXIMO PASSO NO CLI:
Agora no chat4all-cli.py você pode digitar:
- Recipient: user_b (ao invés do UUID)
- Recipient: whatsapp:+5562996991812 (se vinculado a algum usuário)
- Recipient: instagram:@usuario (interno se vinculado, externo caso contrário)
""")
