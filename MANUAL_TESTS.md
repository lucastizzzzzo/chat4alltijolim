# 🧪 Chat4All - Guia de Testes Manuais

Este guia mostra como **VOCÊ MESMO** pode verificar que a infraestrutura está funcionando corretamente.

---

## 📋 Pré-requisitos

Antes de começar, certifique-se que tem instalado:
- Docker + Docker Compose
- curl (para testar APIs REST)

---

## 🚀 Teste 1: Iniciar a Infraestrutura

### Comando:
```bash
cd /home/tizzo/chat4alltijolim
docker-compose up -d zookeeper kafka cassandra
```

### O que esperar:
- Containers iniciando: `Creating chat4all-zookeeper`, `Creating chat4all-kafka`, `Creating chat4all-cassandra`
- Mensagem: `done`

### Verificar:
```bash
docker-compose ps
```

### Resultado esperado:
```
NAME                  STATUS              PORTS
chat4all-zookeeper    Up                  2181/tcp
chat4all-kafka        Up (healthy)        9092/tcp, 29092/tcp
chat4all-cassandra    Up (healthy)        9042/tcp
```

✅ **PASSOU**: Todos containers com status `Up` ou `Up (healthy)`  
❌ **FALHOU**: Algum container com status `Exit 1` ou `Restarting`

**Se falhou:** Ver logs com `docker-compose logs <nome-do-container>`

---

## 🗄️ Teste 2: Cassandra - Verificar Schema

### Aguardar inicialização:
```bash
# Cassandra leva ~60 segundos para inicializar
sleep 60
```

### Inicializar schema:
```bash
docker-compose up cassandra-init
```

### O que esperar:
```
[2025-11-18 02:22:01] ✓ Cassandra is ready (attempt 1/30)
[2025-11-18 02:22:04] ✓ Schema initialized successfully
[2025-11-18 02:22:06] ✓ Schema verification successful
[2025-11-18 02:22:06] ✓ Schema initialization complete!
```

### Verificar schema manualmente:
```bash
# Conectar ao CQL shell
docker exec -it chat4all-cassandra cqlsh

# Dentro do cqlsh, executar:
DESCRIBE KEYSPACE chat4all;
```

### Resultado esperado:
```cql
CREATE KEYSPACE chat4all WITH replication = {'class': 'SimpleStrategy', 'replication_factor': '2'};

CREATE TABLE chat4all.messages (
    conversation_id uuid,
    timestamp timestamp,
    message_id uuid,
    sender_id uuid,
    content text,
    status text,
    PRIMARY KEY (conversation_id, timestamp)
) WITH CLUSTERING ORDER BY (timestamp ASC);

CREATE TABLE chat4all.conversations (
    conversation_id uuid PRIMARY KEY,
    participant_ids list<uuid>,
    created_at timestamp,
    type text
);

CREATE TABLE chat4all.users (
    user_id uuid PRIMARY KEY,
    username text,
    created_at timestamp
);
```

✅ **PASSOU**: Keyspace `chat4all` e 3 tabelas (`messages`, `conversations`, `users`) existem  
❌ **FALHOU**: Erro "Keyspace 'chat4all' does not exist"

**Para sair do cqlsh:** Digite `exit` e Enter

---

## 📨 Teste 3: Cassandra - Inserir e Consultar Dados

### Teste manual de escrita/leitura:

```bash
# Conectar ao Cassandra
docker exec -it chat4all-cassandra cqlsh

# Dentro do cqlsh:
USE chat4all;

-- Inserir uma mensagem de teste
INSERT INTO messages (
    conversation_id,
    timestamp,
    message_id,
    sender_id,
    content,
    status
) VALUES (
    uuid(),
    toTimestamp(now()),
    uuid(),
    uuid(),
    'Teste manual - infraestrutura OK!',
    'SENT'
);

-- Consultar todas as mensagens
SELECT * FROM messages LIMIT 10;
```

### Resultado esperado:
```
 conversation_id                      | timestamp                       | content                              | message_id                           | sender_id                            | status
--------------------------------------+---------------------------------+--------------------------------------+--------------------------------------+--------------------------------------+--------
 <algum-uuid>                         | 2025-11-18 02:30:00.000000+0000 | Teste manual - infraestrutura OK!    | <algum-uuid>                         | <algum-uuid>                         | SENT
```

✅ **PASSOU**: Dados inseridos e consultados com sucesso  
❌ **FALHOU**: Erro ao inserir ou consultar

**Para limpar:** `TRUNCATE messages;`

---

## 🔄 Teste 4: Kafka - Verificar Tópicos

### Listar tópicos existentes:
```bash
docker exec chat4all-kafka kafka-topics \
  --list \
  --bootstrap-server localhost:9092
```

### Resultado esperado:
```
__consumer_offsets
messages
```

**Nota:** `__consumer_offsets` é interno do Kafka. O tópico `messages` pode não existir ainda (será criado automaticamente quando publicarmos a primeira mensagem).

### Criar tópico manualmente (se não existir):
```bash
docker exec chat4all-kafka kafka-topics \
  --create \
  --topic messages \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1
```

### Resultado esperado:
```
Created topic messages.
```

✅ **PASSOU**: Tópico `messages` criado (ou já existia)

---

## 📤 Teste 5: Kafka - Produzir e Consumir Mensagens

### Terminal 1 - Iniciar consumidor (receber mensagens):
```bash
docker exec -it chat4all-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic messages \
  --from-beginning
```

**Deixe este terminal aberto!** Ele ficará aguardando mensagens.

### Terminal 2 - Produzir mensagem (enviar):
```bash
docker exec -it chat4all-kafka kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic messages
```

**Agora digite uma mensagem de teste:**
```json
{"message_id":"msg_test123","conversation_id":"conv_abc","sender_id":"user_alice","content":"Teste Kafka!","timestamp":1700000000000,"event_type":"MESSAGE_SENT"}
```

**Pressione Enter** para enviar.

### No Terminal 1 (consumidor), você deve ver:
```json
{"message_id":"msg_test123","conversation_id":"conv_abc","sender_id":"user_alice","content":"Teste Kafka!","timestamp":1700000000000,"event_type":"MESSAGE_SENT"}
```

✅ **PASSOU**: Mensagem apareceu no consumidor  
❌ **FALHOU**: Nada apareceu (verificar se tópico foi criado)

**Para sair:** Pressione `Ctrl+C` em ambos os terminais

---

## 🌐 Teste 6: Zookeeper - Verificar Conectividade

### Verificar se Zookeeper está respondendo:
```bash
docker exec chat4all-zookeeper zkCli.sh -server localhost:2181 ls /brokers/ids
```

### Resultado esperado:
```
[1]
```

Isso significa que existe 1 broker Kafka registrado (broker ID = 1).

✅ **PASSOU**: Zookeeper respondendo e Kafka registrado  
❌ **FALHOU**: Erro de conexão

---

## 📊 Teste 7: Verificar Logs (Troubleshooting)

### Ver logs de qualquer serviço:

```bash
# Logs do Cassandra
docker-compose logs cassandra

# Logs do Kafka
docker-compose logs kafka

# Logs do Zookeeper
docker-compose logs zookeeper

# Seguir logs em tempo real (Ctrl+C para sair)
docker-compose logs -f kafka
```

### O que procurar:

**Cassandra:**
- ✅ Bom: `Starting listening for CQL clients on /0.0.0.0:9042`
- ❌ Ruim: `OutOfMemoryError`, `Cannot allocate memory`

**Kafka:**
- ✅ Bom: `Kafka Server started`
- ❌ Ruim: `Connection to node -1 could not be established`

**Zookeeper:**
- ✅ Bom: `binding to port 0.0.0.0/0.0.0.0:2181`
- ❌ Ruim: `Address already in use`

---

## 🧹 Teste 8: Limpar e Reiniciar (Fresh Start)

### Parar tudo:
```bash
cd /home/tizzo/chat4alltijolim
docker-compose down
```

### Limpar volumes (ATENÇÃO: apaga todos os dados!):
```bash
docker-compose down -v
```

### Reiniciar do zero:
```bash
docker-compose up -d zookeeper kafka cassandra
sleep 60
docker-compose up cassandra-init
```

✅ **PASSOU**: Tudo reiniciou sem erros

---

## 📈 Teste 9: Verificar Uso de Recursos

### Ver CPU e memória dos containers:
```bash
docker stats --no-stream
```

### Resultado esperado:
```
CONTAINER          CPU %     MEM USAGE / LIMIT     NET I/O
chat4all-kafka     2.5%      450MB / 2GB           15kB / 10kB
chat4all-cassandra 5.0%      800MB / 2GB           20kB / 15kB
chat4all-zookeeper 0.5%      100MB / 1GB           5kB / 3kB
```

**Limites aceitáveis:**
- Kafka: ~400-600MB RAM
- Cassandra: ~800MB-1.2GB RAM
- Zookeeper: ~100-200MB RAM

❌ **Problema**: Se CPU > 50% ou memória próxima do limite, pode haver problema

---

## 🎯 Resumo - Checklist de Verificação

Marque cada item após testar:

- [ ] **Teste 1**: Containers iniciaram (docker-compose ps)
- [ ] **Teste 2**: Schema Cassandra criado (DESCRIBE KEYSPACE)
- [ ] **Teste 3**: Insert/Select no Cassandra funciona
- [ ] **Teste 4**: Tópico Kafka existe (kafka-topics --list)
- [ ] **Teste 5**: Produzir/consumir mensagem no Kafka funciona
- [ ] **Teste 6**: Zookeeper respondendo (zkCli.sh)
- [ ] **Teste 7**: Logs sem erros críticos
- [ ] **Teste 8**: Reiniciar do zero funciona
- [ ] **Teste 9**: Uso de recursos dentro dos limites

✅ **TODOS PASSARAM**: Infraestrutura 100% funcional!  
❌ **ALGUM FALHOU**: Ver seção "Troubleshooting" abaixo

---

## 🚨 Troubleshooting - Problemas Comuns

### Problema: "Cannot connect to Cassandra"
**Solução:**
```bash
# Aguardar mais tempo (Cassandra leva 60-90s)
docker-compose logs cassandra | grep "Starting listening"

# Se não aparecer, reiniciar:
docker-compose restart cassandra
```

### Problema: "Kafka broker not available"
**Solução:**
```bash
# Verificar se Zookeeper está OK primeiro
docker exec chat4all-zookeeper zkCli.sh -server localhost:2181 ls /

# Reiniciar Kafka
docker-compose restart kafka
```

### Problema: "Port already in use"
**Solução:**
```bash
# Verificar quem está usando a porta
sudo lsof -i :9042  # Cassandra
sudo lsof -i :9092  # Kafka
sudo lsof -i :2181  # Zookeeper

# Matar processo ou mudar porta no docker-compose.yml
```

### Problema: "Out of memory"
**Solução:**
```bash
# Aumentar memória do Docker Desktop (se Windows/Mac)
# Ou reduzir heap do Cassandra no docker-compose.yml:
# MAX_HEAP_SIZE: '256M'
# HEAP_NEWSIZE: '64M'
```

---

## 🎓 Conceitos Educacionais - O que Cada Teste Ensina

### Teste 1-2: **Orquestração de Containers**
Aprende sobre dependências entre serviços (Kafka precisa do Zookeeper)

### Teste 3: **NoSQL Data Modeling**
Aprende sobre partition key (conversation_id) e clustering key (timestamp)

### Teste 4-5: **Message Brokers**
Aprende sobre pub/sub pattern e particionamento

### Teste 6: **Coordenação Distribuída**
Aprende como Zookeeper gerencia metadata do Kafka

### Teste 7: **Observabilidade**
Aprende a diagnosticar problemas via logs estruturados

### Teste 8: **Idempotência**
Aprende sobre inicialização repetível (schema com IF NOT EXISTS)

### Teste 9: **Resource Management**
Aprende sobre limites de CPU/RAM em sistemas distribuídos

---

## 📚 Próximos Passos

Infraestrutura testada? Agora você pode:

1. **Implementar US3 (Autenticação)**
   - Seguir guia em `specs/001-basic-messaging-api/tasks.md`
   - Começar com testes (TDD: RED → GREEN → REFACTOR)

2. **Testar com aplicação real**
   - Construir JAR: `mvn clean package`
   - Subir api-service: `docker-compose up -d api-service`
   - Testar endpoint: `curl http://localhost:8080/health`

3. **Monitorar em tempo real**
   - Kafka: `docker exec -it chat4all-kafka kafka-consumer-groups --bootstrap-server localhost:9092 --list`
   - Cassandra: `watch -n 1 "docker exec chat4all-cassandra nodetool status"`

---

**Data do Teste**: 2025-11-18  
**Status Atual**: ✅ Infraestrutura 100% funcional  
**Próximo Marco**: Implementar autenticação JWT (US3)
