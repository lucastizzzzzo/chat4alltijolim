# Chat4All CLI - Interface de Linha de Comando

Uma interface CLI interativa e user-friendly para o Chat4All, eliminando a necessidade de usar `curl` diretamente.

## 🚀 Instalação

```bash
# Instalar dependências Python
pip install -r cli/requirements.txt

# Ou usar Python 3 diretamente
python3 -m pip install requests
```

## 📖 Uso

```bash
# Executar o CLI
./cli/chat4all-cli.py

# Ou com Python explicitamente
python3 cli/chat4all-cli.py
```

## 🎯 Funcionalidades

### Menu Interativo

```
Menu Principal:
  1. Autenticar (login)
  2. Enviar mensagem
  3. Enviar mensagem com arquivo
  4. Listar mensagens de uma conversa
  5. Marcar mensagem como lida
  6. Upload de arquivo
  7. Download de arquivo
  8. Status da infraestrutura
  9. Limpar tela
  0. Sair
```

### 1. Autenticação

Faz login e obtém token JWT:

```
🔐 Autenticação
Usuários disponíveis: user_a, user_b, user_c
Digite o user_id: user_a
✓ Autenticado com sucesso!
  Usuário: user_a
  Token válido por: 1 hora
```

### 2. Enviar Mensagem

Envia mensagem de texto para WhatsApp ou Instagram:

```
📨 Enviar Mensagem
Conversation ID: conv_demo_123
Recipient ID: whatsapp:+5511999998888
Mensagem: Olá! Como vai?
✓ Mensagem enviada com sucesso!
  Message ID: msg_abc123...
  Status: SENT
```

### 3. Enviar Mensagem com Arquivo

Envia mensagem com arquivo anexado:

```
📎 Enviar Mensagem com Arquivo
File ID (faça upload primeiro com opção 6): file_xyz789
Conversation ID: conv_demo_123
Recipient ID: instagram:@maria_silva
Mensagem (opcional): Confere essa foto!
✓ Mensagem com arquivo enviada!
```

### 4. Listar Mensagens

Lista mensagens de uma conversa com formatação colorida:

```
💬 Listar Mensagens
Conversation ID: conv_demo_123
Limite (padrão 10): 5
✓ 3 mensagens encontradas:

[2025-11-23 14:30:45]
  De: user_a
  Para: whatsapp:+5511999998888
  Mensagem: Olá! Como vai?
  Status: DELIVERED
  ID: msg_abc123...

[2025-11-23 14:35:22]
  De: user_b
  Para: instagram:@joao_santos
  Mensagem: Tudo bem! E você?
  Status: READ
  Arquivo: file_xyz789
  ID: msg_def456...
```

### 5. Marcar como Lida

Marca mensagem como READ:

```
✓ Marcar como Lida
Message ID: msg_abc123
✓ Mensagem marcada como lida!
```

### 6. Upload de Arquivo

Faz upload de arquivo local para MinIO:

```
📤 Upload de Arquivo
Caminho do arquivo: ./documento.pdf
Conversation ID: conv_demo_123
Tamanho: 250.50 KB
Uploading...
✓ Upload concluído!
  File ID: file_xyz789abc
  Filename: documento.pdf
  Size: 256512 bytes
  Checksum: sha256:8f434346...
```

### 7. Download de Arquivo

Baixa arquivo via presigned URL:

```
📥 Download de Arquivo
File ID: file_xyz789abc
✓ URL de download gerada
  URL: http://minio:9000/chat4all-files/...
  Expira em: 3600 segundos

Baixando arquivo...
✓ Arquivo salvo: ./documento.pdf
  Tamanho: 250.50 KB
```

### 8. Status da Infraestrutura

Verifica se os serviços estão online:

```
🔧 Status da Infraestrutura

  ✓ API Service: Online
  ✓ MinIO: Online

Para verificar containers Docker:
  docker-compose ps
```

## 🎨 Características

### Cores e Formatação

- 🟢 Verde: Sucesso, status online
- 🟡 Amarelo: Avisos, informações importantes
- 🔴 Vermelho: Erros, offline
- 🔵 Azul/Ciano: Títulos, prompts
- **Negrito**: Informações destacadas

### User-Friendly

- ✅ Menu interativo numerado
- ✅ Validação de entrada
- ✅ Mensagens de erro claras
- ✅ Formatação de datas legível
- ✅ Progress indicators para uploads/downloads
- ✅ Cores para status de mensagens (SENT/DELIVERED/READ)

### Segurança

- 🔒 Token JWT armazenado em memória (não em disco)
- 🔒 Validação de autenticação antes de cada ação
- 🔒 Timeout de 1 hora (token expira)

## 🔧 Configuração

### Variáveis de Ambiente

```bash
# URL da API (padrão: http://localhost:8082)
export CHAT4ALL_API_URL=http://localhost:8082

# Executar CLI
./cli/chat4all-cli.py
```

## 📋 Exemplos de Uso

### Fluxo Completo: Enviar foto pelo Instagram

```bash
1. Executar CLI: ./cli/chat4all-cli.py
2. Opção 1: Autenticar como user_a
3. Opção 6: Upload de foto.jpg → obter file_id
4. Opção 3: Enviar mensagem com arquivo
   - File ID: [file_id do passo 3]
   - Conversation ID: conv_demo_123
   - Recipient: instagram:@maria_silva
   - Mensagem: Confere essa foto!
5. Opção 4: Listar mensagens para verificar status
6. Aguardar 2 segundos (connector processa)
7. Opção 4: Listar novamente → status mudou para DELIVERED
```

### Fluxo: Conversa WhatsApp

```bash
Terminal 1 (user_a):
1. Autenticar como user_a
2. Enviar mensagem para whatsapp:+5511999998888
3. Listar mensagens da conversa

Terminal 2 (user_b):
1. Autenticar como user_b
2. Listar mensagens da mesma conversa
3. Marcar mensagens como lidas
```

## 🆚 Comparação: curl vs CLI

### Antes (curl)

```bash
# Autenticar
TOKEN=$(curl -X POST http://localhost:8082/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"user_id":"user_a"}' | jq -r '.token')

# Enviar mensagem
curl -X POST http://localhost:8082/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "conv_demo_123",
    "sender_id": "user_a",
    "recipient_id": "whatsapp:+5511999998888",
    "content": "Olá! Como vai?"
  }'

# Listar mensagens
curl -X GET "http://localhost:8082/v1/messages?conversation_id=conv_demo_123&limit=10" \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Agora (CLI)

```
./cli/chat4all-cli.py

Menu interativo →
1. Autenticar: user_a
2. Enviar mensagem
   Conversation ID: conv_demo_123
   Recipient: whatsapp:+5511999998888
   Mensagem: Olá! Como vai?
4. Listar mensagens
   Conversation ID: conv_demo_123
   Limite: 10
```

**Vantagens do CLI:**

- ✅ Sem necessidade de memorizar comandos curl
- ✅ Validação automática de entrada
- ✅ Formatação legível de saída
- ✅ Gestão automática de token
- ✅ Cores para melhor visualização
- ✅ Menu guiado (não precisa ler documentação)
- ✅ Mensagens de erro claras

## 🐛 Troubleshooting

### Erro: `ModuleNotFoundError: No module named 'requests'`

```bash
pip install requests
```

### Erro: `Connection refused`

Verifique se a API está rodando:

```bash
docker-compose ps api-service
# Se não estiver rodando:
docker-compose up -d
```

### Erro: `401 Unauthorized`

Seu token expirou (1 hora). Autentique novamente (opção 1).

### CLI não executa: `Permission denied`

```bash
chmod +x cli/chat4all-cli.py
```

## 📚 Documentação Relacionada

- [README.md](../README.md) - Documentação principal do Chat4All
- [MANUAL_TESTS.md](../docs/TESTES_MANUAIS_ENTREGA1.md) - Testes manuais com curl
- [API Documentation](../README.md#api-endpoints) - Endpoints REST

## 🎯 Roadmap Futuro

- [ ] Modo watch (auto-refresh de mensagens)
- [ ] Histórico de comandos (setas ↑/↓)
- [ ] Autocomplete de conversation_id
- [ ] Notificações de novas mensagens
- [ ] Suporte a múltiplas conversas em abas
- [ ] Export de conversas (JSON/CSV)
- [ ] Configuração persistente (~/.chat4all/config.json)

---

**Chat4All CLI** - Tornando o Chat4All mais acessível! 🚀
