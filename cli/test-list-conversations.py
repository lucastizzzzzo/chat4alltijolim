#!/usr/bin/env python3
"""Script de teste para listar conversas"""

import requests

API_URL = "http://localhost:8080"

# 1. Autenticar
auth_response = requests.post(
    f"{API_URL}/auth/token",
    json={"username": "lucastizzo", "password": "pass"},
    timeout=10
)

if auth_response.status_code != 200:
    print(f"❌ Falha na autenticação: {auth_response.status_code}")
    print(auth_response.text)
    exit(1)

token = auth_response.json()['access_token']
print(f"✓ Autenticado - Token: {token[:20]}...")

# Extrair user_id do token JWT
import base64
import json

parts = token.split('.')
payload = base64.urlsafe_b64decode(parts[1] + '==')  # Add padding
payload_data = json.loads(payload)
user_id = payload_data['sub']
print(f"✓ User ID: {user_id}")

# 2. Listar conversas
conversations_response = requests.get(
    f"{API_URL}/v1/users/{user_id}/conversations",
    headers={"Authorization": f"Bearer {token}"},
    timeout=10
)

if conversations_response.status_code != 200:
    print(f"❌ Erro ao buscar conversas: {conversations_response.status_code}")
    print(conversations_response.text)
    exit(1)

data = conversations_response.json()
print(f"\n✓ {data['count']} conversa(s) encontrada(s):\n")

for conv in data['conversations']:
    print(f"  • {conv['conversation_id']}")
    print(f"    Tipo: {conv['type']}")
    print(f"    Membros: {', '.join(conv['participant_ids'])}")
    print()

print("✅ Teste concluído com sucesso!")
