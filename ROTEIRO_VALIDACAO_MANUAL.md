# 🧪 Roteiro de Validação Manual - Chat4All
## Demonstração Completa do Sistema (Passo a Passo)

**Objetivo:** Validar todos os componentes do sistema de forma manual e visual  
**Tempo estimado:** 20-25 minutos  
**Pré-requisitos:** Docker, Docker Compose, curl, jq (opcional)

---

## 📋 CHECKLIST DE PRÉ-REQUISITOS

Antes de começar, verificar:

```bash
# 1. Docker instalado e rodando
docker --version
# Esperado: Docker version 24.0.0 ou superior

# 2. Docker Compose instalado
docker-compose --version
# Esperado: Docker Compose version 2.20.0 ou superior

# 3. Portas disponíveis
sudo lsof -i :8080   # API Service (deve estar livre)
sudo lsof -i :9090   # Prometheus (deve estar livre)
sudo lsof -i :3000   # Grafana (deve estar livre)
sudo lsof -i :9000   # MinIO (deve estar livre)

# 4. Memória disponível
free -h
# Recomendado: Pelo menos 4GB livres

# 5. Espaço em disco
df -h
# Recomendado: Pelo menos 10GB livres
```

---

## 🚀 ETAPA 1: PREPARAÇÃO DO AMBIENTE (5 minutos)

### 1.1. Limpar Ambiente Anterior

```bash
cd /home/tizzo/chat4alltijolim

# Parar containers antigos (se existirem)
docker-compose down -v

# Limpar volumes órfãos
docker volume prune -f

# Limpar imagens não utilizadas (opcional)
docker image prune -a -f

# Verificar que nada está rodando
docker ps
# Esperado: Nenhum container listado
```

### 1.2. Build do Projeto

```bash
# Compilar todos os módulos Maven
./build.sh

# Verificar que JARs foram criados
echo "✅ Verificando JARs criados:"
ls -lh api-service/target/api-service-*.jar
ls -lh router-worker/target/router-worker-*.jar
ls -lh connector-whatsapp/target/connector-whatsapp-*.jar
ls -lh connector-instagram/target/connector-instagram-*.jar

# Esperado: 4 arquivos .jar com ~10-15 MB cada
```

**✅ VALIDAÇÃO:** Se aparecerem os 4 arquivos .jar, build OK!

### 1.3. Iniciar Infraestrutura

```bash
# Subir toda a stack
docker-compose up -d

echo "⏳ Aguardando containers iniciarem (60 segundos)..."
sleep 60

# Verificar status dos containers
docker-compose ps
```

**✅ VALIDAÇÃO ESPERADA:**
```
NAME                          STATUS
chat4alltijolim-api-service   Up (healthy)
chat4alltijolim-cassandra     Up (healthy)
chat4alltijolim-grafana       Up (healthy)
chat4alltijolim-instagram     Up (healthy)
chat4alltijolim-kafka         Up (healthy)
chat4alltijolim-minio         Up (healthy)
chat4alltijolim-prometheus    Up (healthy)
chat4alltijolim-router-worker Up (healthy)
chat4alltijolim-whatsapp      Up (healthy)
chat4alltijolim-zookeeper     Up (healthy)
```

**❌ SE ALGUM CONTAINER NÃO ESTÁ HEALTHY:**
```bash
# Ver logs do container problemático
docker-compose logs <nome-do-container>

# Exemplo: Ver logs do Kafka
docker-compose logs kafka

# Aguardar mais 30s e verificar novamente
sleep 30
docker-compose ps
```

---

## 📊 ETAPA 2: VALIDAR OBSERVABILIDADE (3 minutos)

### 2.1. Verificar Prometheus

```bash
# Testar endpoint Prometheus
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .job, health: .health}'
```

**✅ VALIDAÇÃO ESPERADA:**
```json
{"job": "api-service", "health": "up"}
{"job": "router-worker", "health": "up"}
{"job": "connector-whatsapp", "health": "up"}
{"job": "connector-instagram", "health": "up"}
{"job": "minio", "health": "up"}
{"job": "prometheus", "health": "up"}
```

**🌐 ABRIR NO NAVEGADOR:**
```
URL: http://localhost:9090
```

**Validações no Prometheus:**
1. Ir em **Status** → **Targets**
2. Verificar que todos os 6 targets estão **UP** (verde)
3. Ir em **Graph**
4. Testar query: `up`
5. Clicar em **Execute**
6. Verificar que aparecem 6 resultados com `value=1`

**📸 CAPTURA DE TELA:** Tirar screenshot dos targets UP

### 2.2. Verificar Grafana

**🌐 ABRIR NO NAVEGADOR:**
```
URL: http://localhost:3000
Login: admin
Senha: admin
```

**Validações no Grafana:**
1. Login com `admin` / `admin`
2. Se pedir para trocar senha, clicar **Skip**
3. Ir em **Dashboards** (ícone de 4 quadrados no menu lateral)
4. Verificar que existem **4 dashboards**:
   - ✅ Chat4All - System Overview
   - ✅ Chat4All - API Service
   - ✅ Chat4All - Router Worker
   - ✅ Chat4All - Connectors

5. Abrir **System Overview**
6. Verificar que gráficos estão carregando (podem estar em 0, é normal sem carga)

**📸 CAPTURA DE TELA:** Tirar screenshot do dashboard System Overview

### 2.3. Verificar MinIO Console

**🌐 ABRIR NO NAVEGADOR:**
```
URL: http://localhost:9001
Login: minioadmin
Senha: minioadmin
```

**Validações no MinIO:**
1. Login com `minioadmin` / `minioadmin`
2. Verificar que bucket **chat4all-files** existe
3. (Estará vazio por enquanto, é normal)

**📸 CAPTURA DE TELA:** Tirar screenshot do console MinIO

---

## 👤 ETAPA 3: CRIAR USUÁRIOS VIA CLI (5 minutos)

### 3.1. Preparar Script de Carga Automática

```bash
# Criar script para popular dados via CLI
cat > /tmp/populate_data.py << 'SCRIPT_EOF'
#!/usr/bin/env python3
"""
Script de população de dados via CLI Chat4All
Cria usuários, vincula identidades, cria grupos e envia mensagens
"""

import requests
import time
import json

BASE_URL = "http://localhost:8080"

# Dados do arquivo DADOS_TESTE_CARGA.txt
USERS = [
    {"username": "alice_santos", "password": "alice123", "email": "alice.santos@empresa.com"},
    {"username": "bruno_silva", "password": "bruno123", "email": "bruno.silva@empresa.com"},
    {"username": "carla_oliveira", "password": "carla123", "email": "carla.oliveira@empresa.com"},
    {"username": "daniel_costa", "password": "daniel123", "email": "daniel.costa@empresa.com"},
    {"username": "eduarda_lima", "password": "eduarda123", "email": "eduarda.lima@empresa.com"},
]

IDENTITIES_WHATSAPP = {
    "alice_santos": "+5511987654321",
    "bruno_silva": "+5511987654322",
    "carla_oliveira": "+5511987654323",
    "daniel_costa": "+5511987654324",
    "eduarda_lima": "+5511987654325",
}

IDENTITIES_INSTAGRAM = {
    "alice_santos": "@alice_santos",
    "bruno_silva": "@bruno_dev",
    "carla_oliveira": "@carla_designer",
    "daniel_costa": "@daniel_frontend",
    "eduarda_lima": "@eduarda_qa",
}

GRUPOS = [
    {
        "name": "Equipe Backend",
        "members": ["bruno_silva", "daniel_costa"]
    },
    {
        "name": "Equipe Frontend", 
        "members": ["alice_santos", "carla_oliveira"]
    },
    {
        "name": "QA e Testes",
        "members": ["eduarda_lima", "alice_santos", "bruno_silva"]
    }
]

def register_user(user):
    """Registrar usuário via API"""
    try:
        response = requests.post(
            f"{BASE_URL}/v1/users/register",
            json=user,
            timeout=10
        )
        if response.status_code in [200, 201]:
            print(f"✅ Usuário {user['username']} criado")
            return True
        elif response.status_code == 409:
            print(f"⚠️  Usuário {user['username']} já existe")
            return True
        else:
            print(f"❌ Erro ao criar {user['username']}: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Exceção ao criar {user['username']}: {e}")
        return False

def login_user(username, password):
    """Fazer login e obter token"""
    try:
        response = requests.post(
            f"{BASE_URL}/v1/auth/login",
            json={"username": username, "password": password},
            timeout=10
        )
        if response.status_code == 200:
            data = response.json()
            token = data.get("access_token") or data.get("token")
            print(f"✅ Login {username} OK")
            return token
        else:
            print(f"❌ Erro login {username}: {response.status_code}")
            return None
    except Exception as e:
        print(f"❌ Exceção login {username}: {e}")
        return None

def link_identity(token, identity_type, identity_value):
    """Vincular identidade WhatsApp ou Instagram"""
    try:
        response = requests.post(
            f"{BASE_URL}/v1/identities",
            headers={"Authorization": f"Bearer {token}"},
            json={"type": identity_type, "value": identity_value},
            timeout=10
        )
        if response.status_code in [200, 201]:
            print(f"✅ Identidade {identity_value} vinculada")
            return True
        elif response.status_code == 409:
            print(f"⚠️  Identidade {identity_value} já vinculada")
            return True
        else:
            print(f"❌ Erro vincular {identity_value}: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Exceção vincular {identity_value}: {e}")
        return False

def create_group(token, group_name, member_tokens):
    """Criar grupo via API"""
    try:
        response = requests.post(
            f"{BASE_URL}/v1/conversations/group",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "name": group_name,
                "participant_ids": member_tokens  # Lista de user_ids
            },
            timeout=10
        )
        if response.status_code in [200, 201]:
            group_id = response.json().get("conversation_id")
            print(f"✅ Grupo '{group_name}' criado (ID: {group_id})")
            return group_id
        else:
            print(f"❌ Erro criar grupo '{group_name}': {response.status_code}")
            return None
    except Exception as e:
        print(f"❌ Exceção criar grupo '{group_name}': {e}")
        return None

def send_message(token, conversation_id, recipient_id, content):
    """Enviar mensagem via API"""
    try:
        response = requests.post(
            f"{BASE_URL}/v1/messages",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "conversation_id": conversation_id,
                "recipient_id": recipient_id,
                "content": content
            },
            timeout=10
        )
        if response.status_code in [200, 201]:
            print(f"✅ Mensagem enviada para {recipient_id}")
            return True
        else:
            print(f"❌ Erro enviar mensagem: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Exceção enviar mensagem: {e}")
        return False

def main():
    print("=" * 80)
    print("🚀 POPULAÇÃO DE DADOS - CHAT4ALL")
    print("=" * 80)
    
    # Etapa 1: Registrar usuários
    print("\n📝 ETAPA 1: Registrando usuários...")
    for user in USERS:
        register_user(user)
        time.sleep(0.5)
    
    # Etapa 2: Fazer login e armazenar tokens
    print("\n🔐 ETAPA 2: Fazendo login de todos os usuários...")
    tokens = {}
    user_ids = {}
    for user in USERS:
        token = login_user(user["username"], user["password"])
        if token:
            tokens[user["username"]] = token
            # Extrair user_id do token (simulado - ajustar conforme API)
            user_ids[user["username"]] = user["username"]  # Ajustar se API retornar user_id
        time.sleep(0.5)
    
    # Etapa 3: Vincular identidades
    print("\n📱 ETAPA 3: Vinculando identidades WhatsApp...")
    for username, phone in IDENTITIES_WHATSAPP.items():
        if username in tokens:
            link_identity(tokens[username], "whatsapp", phone)
            time.sleep(0.3)
    
    print("\n📸 ETAPA 4: Vinculando identidades Instagram...")
    for username, handle in IDENTITIES_INSTAGRAM.items():
        if username in tokens:
            link_identity(tokens[username], "instagram", handle)
            time.sleep(0.3)
    
    # Etapa 5: Criar grupos
    print("\n👥 ETAPA 5: Criando grupos...")
    group_ids = {}
    for grupo in GRUPOS:
        creator = grupo["members"][0]  # Primeiro membro é o criador
        if creator in tokens:
            # Obter user_ids dos membros (ajustar conforme API)
            member_ids = [user_ids[m] for m in grupo["members"] if m in user_ids]
            group_id = create_group(tokens[creator], grupo["name"], member_ids)
            if group_id:
                group_ids[grupo["name"]] = group_id
            time.sleep(0.5)
    
    # Etapa 6: Enviar mensagens de teste
    print("\n💬 ETAPA 6: Enviando mensagens de teste...")
    
    # Mensagem WhatsApp
    if "alice_santos" in tokens:
        send_message(
            tokens["alice_santos"],
            "test_conv_1",
            "whatsapp:+5511999001001",
            "Olá! Mensagem de teste para cliente VIP 1"
        )
        time.sleep(0.5)
    
    # Mensagem Instagram
    if "bruno_silva" in tokens:
        send_message(
            tokens["bruno_silva"],
            "test_conv_2",
            "instagram:@tech_influencer_br",
            "Olá influencer! Testando mensagem via Instagram"
        )
        time.sleep(0.5)
    
    # Mensagem em grupo
    if "Equipe Backend" in group_ids and "carla_oliveira" in tokens:
        send_message(
            tokens["carla_oliveira"],
            group_ids["Equipe Backend"],
            group_ids["Equipe Backend"],  # Recipient é o próprio grupo
            "Bom dia equipe! Reunião de sprint às 10h"
        )
    
    print("\n" + "=" * 80)
    print("✅ POPULAÇÃO CONCLUÍDA!")
    print(f"👤 Usuários criados: {len(USERS)}")
    print(f"📱 Identidades WhatsApp: {len(IDENTITIES_WHATSAPP)}")
    print(f"📸 Identidades Instagram: {len(IDENTITIES_INSTAGRAM)}")
    print(f"👥 Grupos criados: {len(group_ids)}")
    print("=" * 80)

if __name__ == "__main__":
    main()
SCRIPT_EOF

chmod +x /tmp/populate_data.py
```

### 3.2. Executar Script de População

```bash
# Executar script de carga
python3 /tmp/populate_data.py

# Esperado: Ver logs de criação de usuários, vinculação de identidades, 
# criação de grupos e envio de mensagens
```

**✅ VALIDAÇÃO ESPERADA:**
```
================================================================================
🚀 POPULAÇÃO DE DADOS - CHAT4ALL
================================================================================

📝 ETAPA 1: Registrando usuários...
✅ Usuário alice_santos criado
✅ Usuário bruno_silva criado
✅ Usuário carla_oliveira criado
✅ Usuário daniel_costa criado
✅ Usuário eduarda_lima criado

🔐 ETAPA 2: Fazendo login de todos os usuários...
✅ Login alice_santos OK
✅ Login bruno_silva OK
✅ Login carla_oliveira OK
✅ Login daniel_costa OK
✅ Login eduarda_lima OK

📱 ETAPA 3: Vinculando identidades WhatsApp...
✅ Identidade +5511987654321 vinculada
✅ Identidade +5511987654322 vinculada
✅ Identidade +5511987654323 vinculada
✅ Identidade +5511987654324 vinculada
✅ Identidade +5511987654325 vinculada

📸 ETAPA 4: Vinculando identidades Instagram...
✅ Identidade @alice_santos vinculada
✅ Identidade @bruno_dev vinculada
✅ Identidade @carla_designer vinculada
✅ Identidade @daniel_frontend vinculada
✅ Identidade @eduarda_qa vinculada

👥 ETAPA 5: Criando grupos...
✅ Grupo 'Equipe Backend' criado (ID: group-uuid-1)
✅ Grupo 'Equipe Frontend' criado (ID: group-uuid-2)
✅ Grupo 'QA e Testes' criado (ID: group-uuid-3)

💬 ETAPA 6: Enviando mensagens de teste...
✅ Mensagem enviada para whatsapp:+5511999001001
✅ Mensagem enviada para instagram:@tech_influencer_br
✅ Mensagem enviada para grupo Equipe Backend

================================================================================
✅ POPULAÇÃO CONCLUÍDA!
👤 Usuários criados: 5
📱 Identidades WhatsApp: 5
📸 Identidades Instagram: 5
👥 Grupos criados: 3
================================================================================
```

### 3.3. Validar Criação via CLI Interativa (Opcional)

```bash
# Testar login manual via CLI
cd /home/tizzo/chat4alltijolim/cli
python3 chat4all-cli.py

# No menu interativo:
# Opção 2 - Autenticar
# Username: alice_santos
# Password: alice123

# Opção 8 - Listar Conversações
# (Deve mostrar grupos criados)

# Opção 10 - Ver Identidades Vinculadas
# (Deve mostrar WhatsApp e Instagram da Alice)
```

---

## 💬 ETAPA 4: ENVIAR MENSAGENS VIA CLI (5 minutos)

### 4.1. Testar Envio Manual via CLI Interativa

```bash
cd /home/tizzo/chat4alltijolim/cli
python3 chat4all-cli.py

# No menu interativo:
# Opção 2 - Autenticar
# Username: alice_santos
# Password: alice123

# ✅ Login bem-sucedido!

# Opção 5 - Enviar Mensagem
# Conversation ID: marketing_campaign
# Recipient ID: whatsapp:+5511999001001
# Mensagem: Olá! Promoção especial para cliente VIP
# (Enter para enviar sem anexo)

# Esperado: ✅ Mensagem enviada com sucesso! ID: <uuid>
```

**✅ VALIDAÇÃO:** Se aparecer "Mensagem enviada com sucesso", envio OK!

### 4.2. Enviar Mensagem para Instagram via CLI

```bash
# Ainda logado como alice_santos no CLI

# Opção 5 - Enviar Mensagem
# Conversation ID: influencer_outreach
# Recipient ID: instagram:@tech_influencer_br
# Mensagem: Olá! Gostaria de fazer uma parceria com seu canal

# Esperado: ✅ Mensagem enviada com sucesso! ID: <uuid>
```

### 4.3. Ver Logs dos Connectors (Validar Entrega)

```bash
# Abrir terminal separado e acompanhar logs em tempo real
# Terminal 2:
docker-compose logs -f connector-whatsapp connector-instagram

# Esperado ver nos logs (após 2-5 segundos):
# [WhatsApp] ✅ Delivered to +5511999001001 (message_id: <uuid>)
# [WhatsApp] ✅ Read by +5511999001001 (message_id: <uuid>)
# [Instagram] ✅ Delivered to @tech_influencer_br (message_id: <uuid>)
# [Instagram] ✅ Read by @tech_influencer_br (message_id: <uuid>)
```

**✅ VALIDAÇÃO:** Se aparecerem "Delivered" e "Read", ciclo completo funcionou!

**📸 CAPTURA DE TELA:** Tirar screenshot dos logs dos connectors

### 4.4. Script de Carga de Mensagens (Automatizado)

```bash
# Criar script para enviar múltiplas mensagens
cat > /tmp/send_messages.py << 'SCRIPT_EOF'
#!/usr/bin/env python3
"""Script para enviar mensagens em massa via API"""

import requests
import time

BASE_URL = "http://localhost:8080"

# Fazer login
response = requests.post(
    f"{BASE_URL}/v1/auth/login",
    json={"username": "bruno_silva", "password": "bruno123"}
)
TOKEN = response.json().get("access_token") or response.json().get("token")

MENSAGENS = [
    {
        "conv_id": "conv_whatsapp_1",
        "recipient": "whatsapp:+5511999002001",
        "content": "Olá fornecedor! Precisamos renovar o contrato de serviços"
    },
    {
        "conv_id": "conv_whatsapp_2",
        "recipient": "whatsapp:+5511999003001",
        "content": "Reunião de parceria agendada para amanhã às 14h"
    },
    {
        "conv_id": "conv_instagram_1",
        "recipient": "instagram:@empresa_tech_oficial",
        "content": "Parabéns pelo lançamento do novo produto!"
    },
    {
        "conv_id": "conv_instagram_2",
        "recipient": "instagram:@comunidade_devs_br",
        "content": "Vamos participar do próximo meetup!"
    }
]

print("📤 Enviando mensagens em massa...\n")

for i, msg in enumerate(MENSAGENS, 1):
    response = requests.post(
        f"{BASE_URL}/v1/messages",
        headers={"Authorization": f"Bearer {TOKEN}"},
        json={
            "conversation_id": msg["conv_id"],
            "recipient_id": msg["recipient"],
            "content": msg["content"]
        }
    )
    
    if response.status_code in [200, 201]:
        msg_id = response.json().get("message_id")
        print(f"✅ [{i}/{len(MENSAGENS)}] Mensagem enviada para {msg['recipient']}")
        print(f"   ID: {msg_id}")
    else:
        print(f"❌ [{i}/{len(MENSAGENS)}] Erro ao enviar para {msg['recipient']}: {response.status_code}")
    
    time.sleep(1)  # Aguardar 1s entre mensagens

print(f"\n✅ {len(MENSAGENS)} mensagens enviadas!")
SCRIPT_EOF

chmod +x /tmp/send_messages.py
python3 /tmp/send_messages.py
```

**✅ VALIDAÇÃO ESPERADA:**
```
📤 Enviando mensagens em massa...

✅ [1/4] Mensagem enviada para whatsapp:+5511999002001
   ID: msg-uuid-1
✅ [2/4] Mensagem enviada para whatsapp:+5511999003001
   ID: msg-uuid-2
✅ [3/4] Mensagem enviada para instagram:@empresa_tech_oficial
   ID: msg-uuid-3
✅ [4/4] Mensagem enviada para instagram:@comunidade_devs_br
   ID: msg-uuid-4

✅ 4 mensagens enviadas!
```

---

## 📁 ETAPA 5: UPLOAD E DOWNLOAD DE ARQUIVO VIA CLI (5 minutos)

### 5.1. Criar Arquivo de Teste

```bash
# Criar arquivo de texto de ~1MB para teste
dd if=/dev/urandom of=/tmp/test_file.txt bs=1M count=1

# Verificar tamanho
ls -lh /tmp/test_file.txt
# Esperado: ~1.0M

# Criar também um arquivo menor para teste rápido
echo "Conteúdo do relatório técnico Q4 2024" > /tmp/relatorio_q4.txt
```

### 5.2. Upload de Arquivo via CLI

```bash
cd /home/tizzo/chat4alltijolim/cli
python3 chat4all-cli.py

# No menu interativo:
# Opção 2 - Autenticar
# Username: carla_oliveira
# Password: carla123

# Opção 6 - Enviar Mensagem com Arquivo
# Conversation ID: projeto_design
# Recipient ID: whatsapp:+5511987654324
# Mensagem: Segue o relatório do Q4
# Caminho do arquivo: /tmp/relatorio_q4.txt

# Esperado: 
# ⏳ Fazendo upload do arquivo...
# ✅ Upload concluído! File ID: <file-uuid>
# ✅ Mensagem com arquivo enviada! ID: <msg-uuid>
```

**✅ VALIDAÇÃO:** Se aparecer "Upload concluído" e "Mensagem enviada", upload OK!

### 5.3. Verificar Arquivo no MinIO Console

**🌐 IR NO NAVEGADOR:**
1. Abrir http://localhost:9001
2. Login: `minioadmin` / `minioadmin`
3. Ir em **Buckets** → **chat4all-files**
4. Verificar que arquivo aparece na lista com path: `projeto_design/<file-uuid>_relatorio_q4.txt`

**📸 CAPTURA DE TELA:** Tirar screenshot do arquivo no MinIO

### 5.4. Upload de Arquivo Maior (1MB)

```bash
# Ainda no CLI, logado como carla_oliveira

# Opção 6 - Enviar Mensagem com Arquivo
# Conversation ID: compartilhamento_arquivos
# Recipient ID: instagram:@daniel_frontend
# Mensagem: Arquivo de teste de 1MB
# Caminho do arquivo: /tmp/test_file.txt

# Esperado:
# ⏳ Fazendo upload do arquivo (1.0 MB)...
# [████████████████████████████████] 100%
# ✅ Upload concluído! File ID: <file-uuid>
# ✅ Mensagem com arquivo enviada! ID: <msg-uuid>
```

### 5.5. Ver Logs do Connector (Arquivo Anexado)

```bash
# Terminal 2: Ver logs em tempo real
docker-compose logs -f connector-whatsapp connector-instagram

# Esperado ver:
# [WhatsApp] 📎 Sent message with file <file-uuid> (relatorio_q4.txt)
# [WhatsApp] ✅ Delivered to +5511987654324
# [Instagram] 📎 Sent message with file <file-uuid> (test_file.txt)
# [Instagram] ✅ Delivered to @daniel_frontend
```

**✅ VALIDAÇÃO:** Se logs mostrarem "with file", anexo foi processado!

### 5.6. Listar Mensagens e Ver Arquivos Anexados

```bash
# Ainda no CLI

# Opção 7 - Listar Mensagens
# Conversation ID: projeto_design
# Quantidade: 10

# Esperado:
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 📅 2024-11-30 14:30:45
# 👤 carla_oliveira → whatsapp:+5511987654324
# 💬 Segue o relatório do Q4
# 📎 Arquivo: relatorio_q4.txt (35 bytes)
# 📊 Status: READ ✅
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 5.7. Download de Arquivo via Script

```bash
# Criar script de download automatizado
cat > /tmp/download_file.py << 'SCRIPT_EOF'
#!/usr/bin/env python3
"""Script para baixar arquivo via presigned URL"""

import requests
import sys

BASE_URL = "http://localhost:8080"

# Login
response = requests.post(
    f"{BASE_URL}/v1/auth/login",
    json={"username": "daniel_costa", "password": "daniel123"}
)
TOKEN = response.json().get("access_token") or response.json().get("token")

# Obter file_id da última mensagem (ou passar como argumento)
if len(sys.argv) > 1:
    FILE_ID = sys.argv[1]
else:
    print("❌ Uso: python3 download_file.py <file_id>")
    sys.exit(1)

print(f"🔍 Obtendo URL de download para file_id: {FILE_ID}")

# Obter presigned URL
response = requests.get(
    f"{BASE_URL}/v1/files/{FILE_ID}/download",
    headers={"Authorization": f"Bearer {TOKEN}"}
)

if response.status_code != 200:
    print(f"❌ Erro ao obter URL: {response.status_code}")
    print(response.text)
    sys.exit(1)

data = response.json()
download_url = data.get("download_url") or data.get("downloadUrl")
filename = data.get("filename", "downloaded_file")

print(f"✅ URL obtida! Baixando {filename}...")

# Baixar arquivo
response = requests.get(download_url)

if response.status_code == 200:
    output_path = f"/tmp/{filename}"
    with open(output_path, 'wb') as f:
        f.write(response.content)
    
    print(f"✅ Arquivo baixado: {output_path}")
    print(f"📊 Tamanho: {len(response.content)} bytes")
    
    # Calcular checksum
    import hashlib
    checksum = hashlib.sha256(response.content).hexdigest()
    print(f"🔐 SHA256: {checksum[:16]}...")
else:
    print(f"❌ Erro ao baixar: {response.status_code}")
    sys.exit(1)

SCRIPT_EOF

chmod +x /tmp/download_file.py

# Testar download (substituir <file-uuid> pelo ID real)
# python3 /tmp/download_file.py <file-uuid>
```

**✅ VALIDAÇÃO:** Para validar completamente:
```bash
# 1. Obter file_id da mensagem enviada (copiar do CLI ou logs)
# 2. Executar script de download
# 3. Comparar checksums original vs baixado

# Exemplo:
sha256sum /tmp/relatorio_q4.txt
sha256sum /tmp/relatorio_q4.txt  # (arquivo baixado)

# Checksums devem ser IDÊNTICOS!
```

---

## 📖 ETAPA 6: LISTAR MENSAGENS E CONVERSAÇÕES VIA CLI (3 minutos)

### 6.1. Listar Mensagens de uma Conversação

```bash
cd /home/tizzo/chat4alltijolim/cli
python3 chat4all-cli.py

# No menu interativo:
# Opção 2 - Autenticar
# Username: alice_santos
# Password: alice123

# Opção 7 - Listar Mensagens
# Conversation ID: marketing_campaign
# Quantidade (Enter para 10): 20

# Esperado: Lista formatada de mensagens
```

**✅ VALIDAÇÃO ESPERADA:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💬 MENSAGENS DA CONVERSA: marketing_campaign
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 2024-11-30 14:25:30
👤 alice_santos → whatsapp:+5511999001001
💬 Olá! Promoção especial para cliente VIP
📊 Status: READ ✅
   • Enviado: 14:25:30
   • Entregue: 14:25:33
   • Lido: 14:25:36
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 2024-11-30 14:30:45
👤 carla_oliveira → whatsapp:+5511987654324
💬 Segue o relatório do Q4
📎 Arquivo: relatorio_q4.txt (35 bytes)
📊 Status: DELIVERED 📨
   • Enviado: 14:30:45
   • Entregue: 14:30:48
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total: 2 mensagens
```

**✅ VALIDAÇÕES:**
1. Status das mensagens deve progredir: **SENT → DELIVERED → READ**
2. Timestamps `enviado`, `entregue`, `lido` devem estar preenchidos
3. Mensagens com arquivo devem mostrar 📎 e nome do arquivo
4. Formatação deve estar clara e legível

### 6.2. Listar Todas as Conversações

```bash
# Ainda no CLI, logado como alice_santos

# Opção 8 - Listar Conversações

# Esperado: Lista de todas as conversações do usuário
```

**✅ VALIDAÇÃO ESPERADA:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 SUAS CONVERSAÇÕES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1️⃣  Conversation ID: marketing_campaign
    👥 Participantes: alice_santos, whatsapp:+5511999001001
    📅 Criada em: 2024-11-30 14:25:00
    💬 Última mensagem: Olá! Promoção especial para cliente VIP

2️⃣  Conversation ID: influencer_outreach
    👥 Participantes: alice_santos, instagram:@tech_influencer_br
    📅 Criada em: 2024-11-30 14:28:00
    💬 Última mensagem: Olá! Gostaria de fazer uma parceria...

3️⃣  Conversation ID: grupo:Equipe Frontend
    👥 Participantes: alice_santos, carla_oliveira, bruno_silva (3 membros)
    📅 Criada em: 2024-11-30 14:15:00
    💬 Última mensagem: Reunião de sprint às 10h

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total: 3 conversações
```

### 6.3. Verificar Status das Mensagens (Ciclo Completo)

```bash
# Script para validar ciclo de vida das mensagens
cat > /tmp/check_message_status.py << 'SCRIPT_EOF'
#!/usr/bin/env python3
"""Verificar evolução do status das mensagens"""

import requests
import time

BASE_URL = "http://localhost:8080"

# Login
response = requests.post(
    f"{BASE_URL}/v1/auth/login",
    json={"username": "alice_santos", "password": "alice123"}
)
TOKEN = response.json().get("access_token") or response.json().get("token")

# Enviar mensagem
print("📤 Enviando mensagem de teste...")
response = requests.post(
    f"{BASE_URL}/v1/messages",
    headers={"Authorization": f"Bearer {TOKEN}"},
    json={
        "conversation_id": "status_test_conv",
        "recipient_id": "whatsapp:+5511999004001",
        "content": "Teste de evolução de status"
    }
)

if response.status_code not in [200, 201]:
    print(f"❌ Erro ao enviar: {response.status_code}")
    exit(1)

MESSAGE_ID = response.json().get("message_id")
print(f"✅ Mensagem enviada! ID: {MESSAGE_ID}")
print("\n⏳ Acompanhando evolução do status...")

# Acompanhar status por 15 segundos
for i in range(15):
    response = requests.get(
        f"{BASE_URL}/v1/messages?conversation_id=status_test_conv&limit=1",
        headers={"Authorization": f"Bearer {TOKEN}"}
    )
    
    if response.status_code == 200:
        messages = response.json().get("messages", [])
        if messages:
            msg = messages[0]
            status = msg.get("status")
            sent_at = msg.get("sent_at", "")[:19]
            delivered_at = msg.get("delivered_at", "")[:19] if msg.get("delivered_at") else "⏳ Aguardando..."
            read_at = msg.get("read_at", "")[:19] if msg.get("read_at") else "⏳ Aguardando..."
            
            print(f"\n[{i+1}s] Status atual: {status}")
            print(f"  • Enviado: {sent_at}")
            print(f"  • Entregue: {delivered_at}")
            print(f"  • Lido: {read_at}")
            
            if status == "READ":
                print("\n✅ Ciclo completo! SENT → DELIVERED → READ")
                break
    
    time.sleep(1)

print("\n" + "="*60)
print("✅ VALIDAÇÃO CONCLUÍDA!")
print("="*60)
SCRIPT_EOF

chmod +x /tmp/check_message_status.py
python3 /tmp/check_message_status.py
```

**✅ VALIDAÇÃO ESPERADA:**
```
📤 Enviando mensagem de teste...
✅ Mensagem enviada! ID: msg-uuid-123

⏳ Acompanhando evolução do status...

[1s] Status atual: SENT
  • Enviado: 2024-11-30 14:35:10
  • Entregue: ⏳ Aguardando...
  • Lido: ⏳ Aguardando...

[3s] Status atual: DELIVERED
  • Enviado: 2024-11-30 14:35:10
  • Entregue: 2024-11-30 14:35:13
  • Lido: ⏳ Aguardando...

[5s] Status atual: READ
  • Enviado: 2024-11-30 14:35:10
  • Entregue: 2024-11-30 14:35:13
  • Lido: 2024-11-30 14:35:16

✅ Ciclo completo! SENT → DELIVERED → READ

============================================================
✅ VALIDAÇÃO CONCLUÍDA!
============================================================
```

**✅ VALIDAÇÃO CRÍTICA:** 
- Status deve evoluir: **SENT** (imediato) → **DELIVERED** (2-3s) → **READ** (2-3s depois)
- Todos os timestamps devem ser preenchidos no status READ

---

## 📊 ETAPA 7: VALIDAR MÉTRICAS E DASHBOARDS (3 minutos)

### 7.1. Verificar Métricas no Prometheus

**🌐 ABRIR NO NAVEGADOR:**
```
URL: http://localhost:9090
```

**Queries para testar:**

**Query 1: Total de mensagens aceitas**
```promql
messages_accepted_total
```
- Clicar em **Execute**
- Verificar valor > 0

**Query 2: Taxa de mensagens por minuto**
```promql
rate(messages_accepted_total[1m]) * 60
```
- Deve mostrar ~3-5 msg/min (das mensagens que enviamos)

**Query 3: Latência P95**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[1m]))
```
- Deve mostrar latência baixa (< 10ms)

**Query 4: Consumer lag (deve ser 0)**
```promql
kafka_consumer_lag
```
- Deve retornar 0 ou vazio (workers processaram tudo)

**📸 CAPTURA DE TELA:** Tirar screenshot de cada query

### 7.2. Validar Dashboards Grafana

**🌐 ABRIR NO NAVEGADOR:**
```
URL: http://localhost:3000
```

**Dashboard 1: System Overview**
1. Ir em **Dashboards** → **Chat4All - System Overview**
2. Verificar painéis:
   - **HTTP Request Rate**: Deve mostrar ~3-5 req/min (pico durante testes)
   - **Request Latency P95**: Deve mostrar < 10ms
   - **Error Rate**: Deve ser 0%
   - **Messages Processed**: Deve mostrar 3-4 mensagens

**Dashboard 2: API Service**
1. Ir em **Dashboards** → **Chat4All - API Service**
2. Verificar:
   - **Messages Accepted vs Rejected**: Accepted deve ter valores, Rejected = 0
   - **Files Uploaded**: Deve mostrar 1 upload
   - **HTTP Status Codes**: 2xx dominante, sem 5xx

**Dashboard 3: Router Worker**
1. Ir em **Dashboards** → **Chat4All - Router Worker**
2. Verificar:
   - **Consumer Lag**: Deve ser 0 (tudo processado)
   - **Messages Processed**: Deve ter valores
   - **Processing Duration**: Deve ser < 5ms

**Dashboard 4: Connectors**
1. Ir em **Dashboards** → **Chat4All - Connectors**
2. Verificar:
   - **Messages Sent (por canal)**: WhatsApp e Instagram devem ter valores
   - **Connector API Duration**: Deve mostrar 1-3s (simulação de delay)
   - **Circuit Breaker State**: Deve estar em CLOSED (0)

**📸 CAPTURA DE TELA:** Tirar screenshot dos 4 dashboards

---

## 🔄 ETAPA 8: VALIDAR ESCALABILIDADE (OPCIONAL - 3 minutos)

### 8.1. Escalar Router Worker para 2 Instâncias

```bash
# Aumentar para 2 workers
docker-compose up -d --scale router-worker=2

# Aguardar rebalancing do Kafka (30s)
echo "⏳ Aguardando Kafka rebalancing..."
sleep 30

# Verificar que 2 workers estão rodando
docker ps | grep router-worker

# Esperado: 2 containers router-worker
```

### 8.2. Ver Logs de Rebalancing

```bash
# Ver logs de ambos workers
docker-compose logs router-worker | grep -i "partition\|assigned\|revok"

# Esperado ver logs como:
# [Worker-1] Assigned partitions: [0, 1, 2]
# [Worker-2] Assigned partitions: [3, 4, 5]
```

**✅ VALIDAÇÃO:** Se partições foram distribuídas entre workers, scaling funcionou!

### 8.3. Enviar Mensagens com 2 Workers

```bash
# Enviar 5 mensagens rápidas
for i in {1..5}; do
  curl -s -X POST http://localhost:8080/v1/messages \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN_A" \
    -d '{
      "conversation_id": "'$CONV_ID'",
      "recipient_id": "whatsapp:+5511777777777",
      "content": "Mensagem de teste #'$i'"
    }' > /dev/null
  echo "Mensagem $i enviada"
done

# Ver logs de ambos workers processando
docker-compose logs --tail=20 router-worker
```

**✅ VALIDAÇÃO:** Se ambos workers aparecerem nos logs, carga está distribuída!

### 8.4. Verificar Distribuição no Grafana

1. Ir em Grafana → **Router Worker Dashboard**
2. Ver painel **Messages Processed (por instância)**
3. Verificar que ambos workers têm valores (carga distribuída)

---

## 💥 ETAPA 9: VALIDAR TOLERÂNCIA A FALHAS (OPCIONAL - 3 minutos)

### 9.1. Simular Falha de Worker (Failover)

```bash
# Identificar ID de um dos workers
WORKER_ID=$(docker ps --filter "name=router-worker" --format "{{.ID}}" | head -1)
echo "Worker que será parado: $WORKER_ID"

# Parar worker
docker stop $WORKER_ID

echo "⏳ Aguardando Kafka rebalancing (10s)..."
sleep 10

# Ver logs de rebalancing
docker-compose logs router-worker | tail -30 | grep -i "rebalanc\|partition"

# Esperado:
# [Worker sobrevivente] Revoking previously assigned partitions
# [Worker sobrevivente] Adding newly assigned partitions: [0, 1, 2, 3, 4, 5]
```

### 9.2. Enviar Mensagem Durante Failover

```bash
# Enviar mensagem (deve funcionar mesmo com worker parado)
curl -s -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d '{
    "conversation_id": "'$CONV_ID'",
    "recipient_id": "instagram:@teste_failover",
    "content": "Mensagem enviada durante failover!"
  }' | jq

# Ver logs do connector
docker-compose logs connector-instagram | tail -10

# Esperado: Mensagem deve ser processada normalmente
```

**✅ VALIDAÇÃO:** Se mensagem foi entregue (logs mostram "Delivered"), failover funcionou!

### 9.3. Reiniciar Worker Parado

```bash
# Reiniciar worker
docker start $WORKER_ID

echo "⏳ Aguardando worker reconectar (10s)..."
sleep 10

# Ver logs de reconexão
docker-compose logs router-worker | tail -20

# Esperado: Worker volta e participa do rebalancing
```

---

## 🎯 ETAPA 10: VALIDAÇÃO FINAL - QUERY NO BANCO (2 minutos)

### 10.1. Verificar Dados no Cassandra

```bash
# Conectar no Cassandra
docker exec -it chat4alltijolim-cassandra-1 cqlsh

# Dentro do cqlsh:
```

**Query 1: Listar usuários**
```sql
SELECT username, email FROM chat4all.users;
```
**Esperado:** Ver user_a e user_b

**Query 2: Listar conversações**
```sql
SELECT conversation_id, participants FROM chat4all.conversations LIMIT 5;
```
**Esperado:** Ver conversação criada

**Query 3: Listar mensagens com status**
```sql
SELECT message_id, content, status, delivered_at, read_at 
FROM chat4all.messages 
WHERE conversation_id = '<CONV_ID>' 
LIMIT 10;
```
**Esperado:** Ver mensagens com status=READ e timestamps preenchidos

**Query 4: Listar arquivos**
```sql
SELECT file_id, filename, size_bytes, checksum 
FROM chat4all.files 
LIMIT 5;
```
**Esperado:** Ver arquivo test_file.txt com tamanho ~1MB

**Query 5: Contar mensagens por status**
```sql
SELECT status, COUNT(*) as total 
FROM chat4all.messages 
GROUP BY status 
ALLOW FILTERING;
```
**Esperado:** Ver contagem por status (READ deve dominar)

```bash
# Sair do cqlsh
exit
```

**📸 CAPTURA DE TELA:** Tirar screenshot das queries

---

## ✅ CHECKLIST FINAL DE VALIDAÇÃO

Marcar cada item validado:

### Infraestrutura
- [ ] 10 containers rodando e healthy
- [ ] Prometheus acessível (http://localhost:9090)
- [ ] Grafana acessível (http://localhost:3000)
- [ ] MinIO acessível (http://localhost:9001)

### Funcionalidades Básicas
- [ ] Registro de usuários funcionando
- [ ] Login retornando JWT token
- [ ] Criação de conversação funcionando

### Mensagens
- [ ] Envio de mensagem de texto para WhatsApp
- [ ] Envio de mensagem de texto para Instagram
- [ ] Logs dos connectors mostrando "Delivered" e "Read"
- [ ] Status das mensagens: SENT → DELIVERED → READ
- [ ] Listagem de mensagens retornando dados corretos

### Arquivos
- [ ] Upload de arquivo (1MB) bem-sucedido
- [ ] Arquivo aparecendo no MinIO console
- [ ] Envio de mensagem com file_id anexado
- [ ] Download via presigned URL funcionando
- [ ] Checksums do arquivo original e baixado são iguais

### Observabilidade
- [ ] Prometheus scraping 6 targets (todos UP)
- [ ] 4 dashboards Grafana provisionados
- [ ] Métricas aparecendo nos gráficos
- [ ] Queries PromQL retornando valores corretos

### Escalabilidade (Opcional)
- [ ] Scale para 2 workers funcionando
- [ ] Kafka rebalancing automático
- [ ] Partições distribuídas entre workers
- [ ] Carga distribuída (ambos workers processando)

### Tolerância a Falhas (Opcional)
- [ ] Worker parado durante carga
- [ ] Sistema continuou funcionando (0% erros)
- [ ] Kafka redistribuiu partições
- [ ] Worker reiniciado reconectou automaticamente

### Persistência
- [ ] Usuários salvos no Cassandra
- [ ] Conversações salvas no Cassandra
- [ ] Mensagens salvas com timestamps corretos
- [ ] Arquivos salvos no MinIO e metadados no Cassandra

---

## 📊 RELATÓRIO DE VALIDAÇÃO

Após completar todas as etapas, preencher:

```
DATA DO TESTE: ___/___/______
DURAÇÃO TOTAL: ___ minutos

RESULTADOS:

1. Infraestrutura:
   - Containers rodando: ___/10
   - Status: [ ] OK  [ ] FALHOU

2. Funcionalidades:
   - Registro de usuários: [ ] OK  [ ] FALHOU
   - Autenticação JWT: [ ] OK  [ ] FALHOU
   - Envio de mensagens: [ ] OK  [ ] FALHOU
   - Upload/Download arquivos: [ ] OK  [ ] FALHOU
   - Listagem de mensagens: [ ] OK  [ ] FALHOU

3. Observabilidade:
   - Prometheus: [ ] OK  [ ] FALHOU
   - Grafana (4 dashboards): [ ] OK  [ ] FALHOU
   - Métricas funcionando: [ ] OK  [ ] FALHOU

4. Escalabilidade:
   - Scale de workers: [ ] OK  [ ] FALHOU  [ ] NÃO TESTADO
   - Distribuição de carga: [ ] OK  [ ] FALHOU  [ ] NÃO TESTADO

5. Tolerância a Falhas:
   - Failover de worker: [ ] OK  [ ] FALHOU  [ ] NÃO TESTADO
   - Recovery automático: [ ] OK  [ ] FALHOU  [ ] NÃO TESTADO

PROBLEMAS ENCONTRADOS:
______________________________________________________________________
______________________________________________________________________

OBSERVAÇÕES:
______________________________________________________________________
______________________________________________________________________

STATUS FINAL: [ ] ✅ APROVADO  [ ] ❌ REPROVADO
```

---

## 🔧 TROUBLESHOOTING

### Problema 1: Container não fica healthy

**Sintoma:** `docker-compose ps` mostra status "starting" ou "unhealthy"

**Solução:**
```bash
# Ver logs detalhados
docker-compose logs <nome-container>

# Exemplos comuns:
docker-compose logs kafka          # Kafka demora ~60s
docker-compose logs cassandra      # Cassandra demora ~45s

# Aguardar mais tempo
sleep 60
docker-compose ps
```

### Problema 2: Erro 401 Unauthorized

**Sintoma:** Requisições retornam 401

**Solução:**
```bash
# Gerar novo token
TOKEN_A=$(curl -s -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user_a","password":"senha123"}' | jq -r '.token')

# Verificar que token não está vazio
echo $TOKEN_A
```

### Problema 3: Prometheus targets DOWN

**Sintoma:** Targets aparecem vermelhos no Prometheus

**Solução:**
```bash
# Verificar conectividade entre containers
docker exec chat4alltijolim-prometheus-1 wget -O- http://api-service:8080/actuator/prometheus

# Reiniciar Prometheus
docker-compose restart prometheus

# Aguardar 30s
sleep 30
```

### Problema 4: Grafana dashboards vazios

**Sintoma:** Gráficos não mostram dados

**Solução:**
```bash
# Verificar datasource
curl -s http://admin:admin@localhost:3000/api/datasources | jq

# Reiniciar Grafana
docker-compose restart grafana

# Aguardar 30s e recarregar página (Ctrl+Shift+R)
```

### Problema 5: Upload de arquivo falha

**Sintoma:** Upload retorna erro 500

**Solução:**
```bash
# Verificar logs do MinIO
docker-compose logs minio

# Verificar logs da API
docker-compose logs api-service

# Testar conectividade API → MinIO
docker exec chat4alltijolim-api-service-1 curl -I http://minio:9000
```

---

## 🎯 CONCLUSÃO

Após completar este roteiro, você terá validado:

✅ **10 componentes** da infraestrutura  
✅ **5 funcionalidades** principais (auth, messages, files, list, observability)  
✅ **8 conceitos** de sistemas distribuídos (event-driven, consumer groups, failover, etc.)  
✅ **4 dashboards** Grafana com métricas em tempo real  
✅ **6 queries** Cassandra mostrando dados persistidos  

**Tempo total:** ~25 minutos  
**Capturas de tela:** 10-15 screenshots para relatório  

---

## 📸 LISTA DE CAPTURAS DE TELA RECOMENDADAS

Para incluir no relatório técnico:

1. `docker-compose ps` mostrando 10 containers healthy
2. Prometheus targets (todos UP)
3. Grafana - System Overview dashboard
4. Grafana - API Service dashboard
5. Grafana - Router Worker dashboard
6. Grafana - Connectors dashboard
7. MinIO console mostrando arquivo uploaded
8. Logs do WhatsApp connector (Delivered + Read)
9. Query Prometheus mostrando métricas
10. Query Cassandra mostrando mensagens com status READ
11. Terminal mostrando download de arquivo bem-sucedido
12. Logs de rebalancing Kafka (opcional - se testou scaling)

---

**Última atualização:** 30 de Novembro de 2024  
**Preparado por:** GitHub Copilot para Chat4All Team  
**Versão:** 1.0  
**Compatibilidade:** Docker Compose v2.20+, Java 17+
