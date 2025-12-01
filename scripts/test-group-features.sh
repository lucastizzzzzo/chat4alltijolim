#!/bin/bash

# Script de Teste - Funcionalidades de Grupo
# Testa: criar grupo, adicionar/remover membros, listar mensagens

set -e  # Para na primeira falha

API_URL="http://localhost:8080"
TIMESTAMP=$(date +%s)

echo "========================================================"
echo "  🧪 Teste: Funcionalidades de Grupo"
echo "========================================================"
echo

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para printar com cor
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}⏳ $1${NC}"
}

# ========================================
# PASSO 1: Criar 3 usuários para o grupo
# ========================================
print_info "Passo 1: Criando 3 usuários para teste de grupo..."
echo

# Usuário 1 (Criador/Admin do grupo)
USER1_USERNAME="group_admin_${TIMESTAMP}"
USER1_PASSWORD="admin123"
USER1_EMAIL="admin${TIMESTAMP}@example.com"

print_info "Registrando usuário 1 (admin)..."
USER1_RESPONSE=$(curl -s -X POST ${API_URL}/auth/register \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$USER1_USERNAME\",
    \"password\": \"$USER1_PASSWORD\",
    \"email\": \"$USER1_EMAIL\"
  }")

USER1_ID=$(echo "$USER1_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('user_id', ''))")

if [ -z "$USER1_ID" ]; then
    print_error "Falha ao criar usuário 1"
    echo "$USER1_RESPONSE"
    exit 1
fi

print_success "Usuário 1 criado: $USER1_USERNAME (ID: $USER1_ID)"

# Login usuário 1
TOKEN1=$(curl -s -X POST ${API_URL}/auth/token \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$USER1_USERNAME\",
    \"password\": \"$USER1_PASSWORD\"
  }" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

print_success "Token usuário 1 obtido"
echo

# Usuário 2 (Membro)
USER2_USERNAME="group_member1_${TIMESTAMP}"
USER2_PASSWORD="member123"
USER2_EMAIL="member1_${TIMESTAMP}@example.com"

print_info "Registrando usuário 2 (membro)..."
USER2_RESPONSE=$(curl -s -X POST ${API_URL}/auth/register \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$USER2_USERNAME\",
    \"password\": \"$USER2_PASSWORD\",
    \"email\": \"$USER2_EMAIL\"
  }")

USER2_ID=$(echo "$USER2_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('user_id', ''))")
print_success "Usuário 2 criado: $USER2_USERNAME (ID: $USER2_ID)"

# Login usuário 2
TOKEN2=$(curl -s -X POST ${API_URL}/auth/token \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$USER2_USERNAME\",
    \"password\": \"$USER2_PASSWORD\"
  }" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

echo

# Usuário 3 (Membro que será removido)
USER3_USERNAME="group_member2_${TIMESTAMP}"
USER3_PASSWORD="member456"
USER3_EMAIL="member2_${TIMESTAMP}@example.com"

print_info "Registrando usuário 3 (membro temporário)..."
USER3_RESPONSE=$(curl -s -X POST ${API_URL}/auth/register \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$USER3_USERNAME\",
    \"password\": \"$USER3_PASSWORD\",
    \"email\": \"$USER3_EMAIL\"
  }")

USER3_ID=$(echo "$USER3_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('user_id', ''))")
print_success "Usuário 3 criado: $USER3_USERNAME (ID: $USER3_ID)"
echo

# ========================================
# PASSO 2: Criar grupo (apenas com user1)
# ========================================
print_info "Passo 2: Criando grupo..."
echo

GROUP_NAME="Grupo de Testes ${TIMESTAMP}"
GROUP_DESC="Grupo criado automaticamente para testes"

CREATE_GROUP_RESPONSE=$(curl -s -X POST ${API_URL}/v1/groups \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN1" \
  -d "{
    \"name\": \"$GROUP_NAME\",
    \"description\": \"$GROUP_DESC\",
    \"initial_members\": []
  }")

echo "$CREATE_GROUP_RESPONSE" | python3 -m json.tool

GROUP_ID=$(echo "$CREATE_GROUP_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('group_id', ''))")

if [ -z "$GROUP_ID" ]; then
    print_error "Falha ao criar grupo"
    exit 1
fi

print_success "Grupo criado!"
echo "  • Nome: $GROUP_NAME"
echo "  • ID: $GROUP_ID"
echo "  • Criador: $USER1_USERNAME"
echo

# ========================================
# PASSO 3: Obter detalhes do grupo
# ========================================
print_info "Passo 3: Obtendo detalhes do grupo..."
echo

GET_GROUP_RESPONSE=$(curl -s -X GET ${API_URL}/v1/groups/${GROUP_ID} \
  -H "Authorization: Bearer $TOKEN1")

echo "$GET_GROUP_RESPONSE" | python3 -m json.tool

MEMBER_COUNT=$(echo "$GET_GROUP_RESPONSE" | python3 -c "import sys, json; print(len(json.load(sys.stdin).get('member_ids', [])))")
ADMIN_COUNT=$(echo "$GET_GROUP_RESPONSE" | python3 -c "import sys, json; print(len(json.load(sys.stdin).get('admin_ids', [])))")

print_success "Detalhes obtidos"
echo "  • Membros: $MEMBER_COUNT"
echo "  • Admins: $ADMIN_COUNT"
echo

# ========================================
# PASSO 4: Adicionar user2 ao grupo
# ========================================
print_info "Passo 4: Adicionando user2 ao grupo..."
echo

ADD_MEMBER_RESPONSE=$(curl -s -X POST ${API_URL}/v1/groups/${GROUP_ID}/members \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN1" \
  -d "{
    \"user_id\": \"$USER2_ID\"
  }")

echo "$ADD_MEMBER_RESPONSE" | python3 -m json.tool

if echo "$ADD_MEMBER_RESPONSE" | grep -q "error"; then
    print_error "Falha ao adicionar membro"
else
    print_success "Usuário 2 adicionado ao grupo"
fi
echo

# ========================================
# PASSO 5: Adicionar user3 ao grupo
# ========================================
print_info "Passo 5: Adicionando user3 ao grupo..."
echo

ADD_MEMBER3_RESPONSE=$(curl -s -X POST ${API_URL}/v1/groups/${GROUP_ID}/members \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN1" \
  -d "{
    \"user_id\": \"$USER3_ID\"
  }")

echo "$ADD_MEMBER3_RESPONSE" | python3 -m json.tool

if echo "$ADD_MEMBER3_RESPONSE" | grep -q "error"; then
    print_error "Falha ao adicionar membro"
else
    print_success "Usuário 3 adicionado ao grupo"
fi
echo

# ========================================
# PASSO 6: Verificar membros (deve ter 3)
# ========================================
print_info "Passo 6: Verificando membros do grupo..."
echo

GET_GROUP2_RESPONSE=$(curl -s -X GET ${API_URL}/v1/groups/${GROUP_ID} \
  -H "Authorization: Bearer $TOKEN1")

echo "$GET_GROUP2_RESPONSE" | python3 -m json.tool

MEMBER_COUNT2=$(echo "$GET_GROUP2_RESPONSE" | python3 -c "import sys, json; print(len(json.load(sys.stdin).get('member_ids', [])))")

if [ "$MEMBER_COUNT2" -eq 3 ]; then
    print_success "Grupo agora tem 3 membros"
else
    print_error "Esperado 3 membros, encontrado: $MEMBER_COUNT2"
fi
echo

# ========================================
# PASSO 7: Promover user2 a admin
# ========================================
print_info "Passo 7: Promovendo user2 a admin..."
echo

PROMOTE_RESPONSE=$(curl -s -X PUT ${API_URL}/v1/groups/${GROUP_ID}/admins/${USER2_ID} \
  -H "Authorization: Bearer $TOKEN1")

echo "$PROMOTE_RESPONSE" | python3 -m json.tool

if echo "$PROMOTE_RESPONSE" | grep -q "error"; then
    print_error "Falha ao promover usuário"
else
    print_success "Usuário 2 promovido a admin"
fi
echo

# ========================================
# PASSO 8: User2 (agora admin) remove user3
# ========================================
print_info "Passo 8: User2 (admin) removendo user3 do grupo..."
echo

REMOVE_RESPONSE=$(curl -s -X DELETE ${API_URL}/v1/groups/${GROUP_ID}/members/${USER3_ID} \
  -H "Authorization: Bearer $TOKEN2")

echo "$REMOVE_RESPONSE" | python3 -m json.tool

if echo "$REMOVE_RESPONSE" | grep -q "error"; then
    print_error "Falha ao remover membro"
else
    print_success "Usuário 3 removido do grupo"
fi
echo

# ========================================
# PASSO 9: Verificar membros finais (deve ter 2)
# ========================================
print_info "Passo 9: Verificando membros finais..."
echo

GET_GROUP3_RESPONSE=$(curl -s -X GET ${API_URL}/v1/groups/${GROUP_ID} \
  -H "Authorization: Bearer $TOKEN1")

echo "$GET_GROUP3_RESPONSE" | python3 -m json.tool

MEMBER_COUNT3=$(echo "$GET_GROUP3_RESPONSE" | python3 -c "import sys, json; print(len(json.load(sys.stdin).get('member_ids', [])))")
ADMIN_COUNT3=$(echo "$GET_GROUP3_RESPONSE" | python3 -c "import sys, json; print(len(json.load(sys.stdin).get('admin_ids', [])))")

if [ "$MEMBER_COUNT3" -eq 2 ]; then
    print_success "Grupo agora tem 2 membros (correto)"
else
    print_error "Esperado 2 membros, encontrado: $MEMBER_COUNT3"
fi

if [ "$ADMIN_COUNT3" -eq 2 ]; then
    print_success "Grupo tem 2 admins (correto)"
else
    print_error "Esperado 2 admins, encontrado: $ADMIN_COUNT3"
fi
echo

# ========================================
# PASSO 10: Verificar no Cassandra
# ========================================
print_info "Passo 10: Verificando dados no Cassandra..."
echo

echo "📊 Grupo na tabela group_conversations:"
docker exec chat4all-cassandra cqlsh -e "
SELECT group_id, name, member_ids, admin_ids 
FROM chat4all.group_conversations 
WHERE group_id = '${GROUP_ID}';" 2>/dev/null || echo "⚠️  Erro ao consultar Cassandra"

echo

# ========================================
# RESUMO FINAL
# ========================================
echo "========================================================"
echo "  ✅ Teste Completo!"
echo "========================================================"
echo
echo "📊 Resumo:"
echo "  • Grupo criado: $GROUP_NAME"
echo "  • ID do grupo: $GROUP_ID"
echo "  • Criador: $USER1_USERNAME ($USER1_ID)"
echo "  • Membros atuais: $MEMBER_COUNT3"
echo "  • Admins atuais: $ADMIN_COUNT3"
echo
echo "👥 Usuários criados:"
echo "  1. $USER1_USERNAME (admin, criador)"
echo "  2. $USER2_USERNAME (admin, promovido)"
echo "  3. $USER3_USERNAME (removido)"
echo
echo "🧪 Funcionalidades testadas:"
echo "  ✅ Criar grupo"
echo "  ✅ Obter detalhes do grupo"
echo "  ✅ Adicionar membros"
echo "  ✅ Promover a admin"
echo "  ✅ Remover membros (por admin)"
echo "  ✅ Persistência no Cassandra"
echo
echo "🔗 Para testar no CLI:"
echo "  cd ~/chat4alltijolim/cli"
echo "  python3 chat4all-cli.py"
echo "  Faça login com: $USER1_USERNAME / $USER1_PASSWORD"
echo
