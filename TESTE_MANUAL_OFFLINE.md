# 🧪 Teste Manual de Resiliência - CLI Offline

**Objetivo:** Testar envio de mensagens com connectors offline e validar processamento após reconexão

**Duração:** 10 minutos

---

## 📋 PREPARAÇÃO

### 1. Ativar ambiente Python da CLI

```bash
cd ~/chat4alltijolim/cli
source venv/bin/activate
python chat4all-cli.py
```

---

## 🔥 CENÁRIO 1: Envio com Sistema Online (Baseline)

### Passo 1.1: Autenticar
- No menu da CLI, digite: **1** (Autenticar)
- Username: `user_a`
- Password: `pass_a`
- ✅ Deve mostrar: "✓ Autenticado com sucesso!"

### Passo 1.2: Enviar mensagem teste (baseline)
- No menu, digite: **2** (Enviar mensagem)
- Conversation ID: `conv_teste_manual_001`
- Recipient ID: `whatsapp:+5511999887766`
- Mensagem: `Mensagem BASELINE - Sistema online normal`
- ✅ Deve retornar status 202 Accepted

### Passo 1.3: Listar mensagens enviadas
- No menu, digite: **4** (Listar mensagens)
- Conversation ID: `conv_teste_manual_001`
- Limite: `10`
- ✅ Aguarde 10-15 segundos
- ✅ Status deve aparecer como **DELIVERED**

---

## ⚠️ CENÁRIO 2: Simular Connectors OFFLINE

### Passo 2.1: Abrir segundo terminal (não fechar a CLI!)

```bash
# Em outro terminal, parar os connectors
cd ~/chat4alltijolim
docker-compose stop connector-whatsapp connector-instagram

# Verificar que pararam
docker-compose ps | grep connector
```

✅ Deve mostrar status "Exited"

### Passo 2.2: Enviar mensagens com connectors OFFLINE

**Voltar para o terminal da CLI**

- No menu, digite: **2** (Enviar mensagem)
- Conversation ID: `conv_teste_manual_001`
- Recipient ID: `whatsapp:+5511666555444`
- Mensagem: `Mensagem 1 - CONNECTORS OFFLINE (teste de resiliência)`
- ✅ Deve retornar status 202 Accepted (API aceita mesmo offline!)

**Enviar segunda mensagem:**

- No menu, digite: **2** novamente
- Conversation ID: `conv_teste_manual_001`
- Recipient ID: `instagram:@teste_offline`
- Mensagem: `Mensagem 2 - Instagram também offline`
- ✅ Deve retornar status 202 Accepted

**Enviar terceira mensagem:**

- No menu, digite: **2** novamente
- Conversation ID: `conv_teste_manual_001`
- Recipient ID: `whatsapp:+5511333222111`
- Mensagem: `Mensagem 3 - Testando fila Kafka 🚀`
- ✅ Deve retornar status 202 Accepted

### Passo 2.3: Verificar mensagens estão em SENT (não processadas)

- No menu, digite: **4** (Listar mensagens)
- Conversation ID: `conv_teste_manual_001`
- ✅ As 3 novas mensagens devem ter status **SENT** (não DELIVERED)
- ✅ Isso prova que estão aguardando na fila Kafka!

---

## 🔄 CENÁRIO 3: Religar Connectors (Simular Rede Volta)

### Passo 3.1: Religar connectors

**No segundo terminal:**

```bash
docker-compose start connector-whatsapp connector-instagram

# Verificar que voltaram
docker-compose ps | grep connector
```

✅ Deve mostrar status "Up"

### Passo 3.2: Aguardar processamento automático

- **Aguarde 15-20 segundos** (connectors precisam reconectar ao Kafka)

### Passo 3.3: Verificar que mensagens foram processadas

**Voltar para o terminal da CLI**

- No menu, digite: **4** (Listar mensagens)
- Conversation ID: `conv_teste_manual_001`
- ✅ Agora as mensagens devem ter status **DELIVERED**!

**🎯 PROVA DE RESILIÊNCIA:**
- Mensagens enviadas durante "offline" foram enfileiradas no Kafka
- Quando connectors voltaram, processaram automaticamente
- Status mudou de SENT → DELIVERED

---

## 🔍 CENÁRIO 4: Validação no Cassandra

### Passo 4.1: Verificar persistência

**No segundo terminal:**

```bash
docker exec chat4all-cassandra cqlsh -e "
SELECT message_id, content, status, delivered_at 
FROM chat4all.messages 
WHERE conversation_id = 'conv_teste_manual_001';"
```

✅ Deve listar todas as 4 mensagens (1 baseline + 3 offline)  
✅ Timestamps `delivered_at` devem estar preenchidos

### Passo 4.2: Ver logs dos connectors

```bash
docker-compose logs connector-whatsapp | tail -30 | grep "Delivered\|msg_"
docker-compose logs connector-instagram | tail -30 | grep "Delivered\|msg_"
```

✅ Deve mostrar logs de processamento após reconnect

---

## 📊 CHECKLIST DE VALIDAÇÃO

Marcar cada validação realizada:

### Fase 1: Sistema Online
- [ ] CLI autenticou com sucesso (user_a)
- [ ] Mensagem baseline enviada e aceita (202)
- [ ] Mensagem aparece com status DELIVERED após 10s

### Fase 2: Connectors Offline
- [ ] Connectors parados com sucesso (docker-compose stop)
- [ ] 3 mensagens enviadas e aceitas (202) mesmo offline
- [ ] Listagem mostra status SENT (não processadas)
- [ ] API continua funcionando normalmente

### Fase 3: Recovery
- [ ] Connectors religados (docker-compose start)
- [ ] Após 15-20s, status mudou para DELIVERED
- [ ] Nenhuma mensagem perdida
- [ ] Processamento automático confirmado

### Fase 4: Persistência
- [ ] Query Cassandra mostra 4 mensagens
- [ ] Timestamps delivered_at preenchidos
- [ ] Logs dos connectors mostram processamento

---

## 🎯 CONCEITOS VALIDADOS

✅ **Event-Driven Architecture**  
→ API desacoplada dos connectors (pode funcionar independente)

✅ **Message Queue (Kafka)**  
→ Mensagens ficam na fila quando consumers offline

✅ **Eventual Consistency**  
→ Processamento diferido garantido quando serviço volta

✅ **Fault Tolerance**  
→ Sistema resiliente a falhas transitórias de componentes

✅ **Observabilidade**  
→ Status das mensagens permite rastreamento completo

---

## 💡 DICAS EXTRAS

### Ver mensagens em tempo real no Cassandra:

```bash
# Rodar em loop enquanto testa
watch -n 2 'docker exec chat4all-cassandra cqlsh -e "
SELECT message_id, status, delivered_at 
FROM chat4all.messages 
WHERE conversation_id = '\''conv_teste_manual_001'\'';" 2>/dev/null'
```

### Ver logs dos connectors em tempo real:

```bash
# Terminal separado
docker-compose logs -f connector-whatsapp connector-instagram | grep -i "delivered\|consumed"
```

### Testar com mais carga:

Se quiser enviar várias mensagens rápido:
- Use opção **2** da CLI várias vezes seguidas
- Todas devem retornar 202 mesmo com connectors offline
- Todas devem processar quando connectors voltarem

---

## 🚨 TROUBLESHOOTING

### Problema: CLI não conecta

**Sintoma:** Erro "Não foi possível conectar à API"

**Solução:**
```bash
# Verificar que API está rodando
docker-compose ps api-service

# Ver logs da API
docker-compose logs api-service | tail -20
```

### Problema: Connectors não param

**Sintoma:** `docker-compose stop` não funciona

**Solução:**
```bash
# Forçar parada
docker-compose kill connector-whatsapp connector-instagram

# Verificar
docker-compose ps | grep connector
```

### Problema: Mensagens não processam após religar

**Sintoma:** Status continua SENT depois de 30s

**Solução:**
```bash
# Ver logs dos connectors
docker-compose logs connector-whatsapp | tail -50

# Verificar reconexão ao Kafka
docker-compose logs connector-whatsapp | grep -i "assigned\|partition\|rebalanc"

# Aguardar mais 30s (pode demorar até 60s o rebalancing)
```

### Problema: Mensagens não aparecem na listagem

**Sintoma:** CLI não mostra mensagens

**Solução:**
```bash
# Verificar direto no Cassandra
docker exec chat4all-cassandra cqlsh -e "
SELECT COUNT(*) 
FROM chat4all.messages 
WHERE conversation_id = 'conv_teste_manual_001';"

# Se contar 0, problema na persistência
# Ver logs do router-worker
docker-compose logs router-worker | tail -30
```

---

## 📸 CAPTURAS DE TELA RECOMENDADAS

Para incluir no relatório:

1. **CLI - Menu principal** (mostrando opções)
2. **CLI - Autenticação bem-sucedida** (✓ Autenticado)
3. **CLI - Envio de mensagem com connector offline** (status 202)
4. **CLI - Listagem mostrando status SENT** (antes do processamento)
5. **Terminal - docker-compose ps** (connectors Exited)
6. **Terminal - docker-compose start** (religando connectors)
7. **CLI - Listagem mostrando status DELIVERED** (após processamento)
8. **Cassandra query** (mensagens com timestamps)
9. **Logs dos connectors** (processamento após reconnect)

---

## 🎓 EXPLICAÇÃO TÉCNICA (Para Defesa)

**Pergunta esperada:** "Como o sistema garante que mensagens não se perdem?"

**Resposta:**

1. **API → Kafka (sync):** API publica no Kafka e aguarda ACK do broker (garantia de persistência)

2. **Kafka → Connectors (async):** Connectors são consumers com offset tracking:
   - Se connector cai, offset não avança
   - Mensagens ficam na partição até serem consumidas
   - Quando connector volta, consome do último offset

3. **Status tracking:** Sistema usa 3 níveis:
   - `SENT`: Persistido no Cassandra via API
   - `DELIVERED`: Connector enviou para API externa
   - `READ`: Confirmação de leitura

4. **Eventual consistency:** Sistema garante processamento eventual, não imediato

---

**Duração Total do Teste:** ~10 minutos  
**Nível de Dificuldade:** Fácil (CLI amigável)  
**Pré-requisitos:** Python 3, venv ativado, sistema rodando

---

**Última atualização:** 30 de Novembro de 2024  
**Preparado por:** GitHub Copilot para Chat4All Team
