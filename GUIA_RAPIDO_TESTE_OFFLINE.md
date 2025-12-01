# 🚀 GUIA RÁPIDO - Teste Manual Offline (CLI)

## 📝 RESUMO EXECUTIVO

**Tempo:** 10 minutos  
**Objetivo:** Provar que sistema aceita mensagens mesmo com connectors offline

---

## 🎯 PASSO A PASSO SIMPLIFICADO

### ✅ FASE 1: Conectar (2 min)

**1. A CLI já está aberta no terminal!**

**2. Digite:** `1` (Autenticar)
- Username: `user_a`
- Password: `pass_a`

**3. Enviar mensagem baseline (sistema online):**
- Digite: `2`
- Conversation ID: `conv_teste_001`
- Recipient: `whatsapp:+5511999999999`
- Mensagem: `Teste baseline - sistema online`

---

### ⚠️ FASE 2: Simular Offline (3 min)

**4. Abrir SEGUNDO terminal** (deixar CLI rodando!)

```bash
cd ~/chat4alltijolim
docker-compose stop connector-whatsapp connector-instagram
```

**5. Voltar para CLI - Enviar 3 mensagens:**

**Mensagem 1:**
- Digite: `2`
- Conversation ID: `conv_teste_001`
- Recipient: `whatsapp:+5511888888888`
- Mensagem: `OFFLINE 1 - Connectors parados`

**Mensagem 2:**
- Digite: `2`
- Conversation ID: `conv_teste_001`
- Recipient: `instagram:@teste_offline`
- Mensagem: `OFFLINE 2 - Instagram sem conexão`

**Mensagem 3:**
- Digite: `2`
- Conversation ID: `conv_teste_001`
- Recipient: `whatsapp:+5511777777777`
- Mensagem: `OFFLINE 3 - Testando fila Kafka 🚀`

✅ **Todas devem retornar: "✓ Mensagem enviada com sucesso!"**  
✅ **Status: 202 (Processamento assíncrono)**

**6. Listar mensagens (ainda offline):**
- Digite: `4`
- Conversation ID: `conv_teste_001`
- Limite: `10`

✅ **As 3 novas mensagens devem ter status: SENT** (não processadas)

---

### 🔄 FASE 3: Religar e Validar (5 min)

**7. No segundo terminal:**

```bash
docker-compose start connector-whatsapp connector-instagram
```

**8. Aguardar 15 segundos**

**9. Voltar CLI - Listar novamente:**
- Digite: `4`
- Conversation ID: `conv_teste_001`

✅ **Agora status deve ser: DELIVERED** ✅  
✅ **PROVA: Mensagens processaram automaticamente!**

**10. Validar no Cassandra (segundo terminal):**

```bash
docker exec chat4all-cassandra cqlsh -e "
SELECT message_id, content, status, delivered_at 
FROM chat4all.messages 
WHERE conversation_id = 'conv_teste_001';"
```

✅ **Todas as 4 mensagens com DELIVERED e timestamps**

---

## 🎓 O QUE VOCÊ PROVOU?

✅ **API continua funcionando** mesmo com connectors offline  
✅ **Kafka enfileira mensagens** (buffer assíncrono)  
✅ **Processamento automático** quando connectors voltam  
✅ **Zero perda de dados** (eventual consistency)  
✅ **Sistema é resiliente** a falhas transitórias

---

## 📸 CAPTURAS IMPORTANTES

1. CLI - Envio com connector offline (status 202) ✅
2. CLI - Listagem com status SENT (antes) ✅
3. Terminal - `docker-compose ps` (connectors Exited) ✅
4. CLI - Listagem com status DELIVERED (depois) ✅
5. Cassandra - Query mostrando 4 mensagens ✅

---

## 🔥 COMANDOS RÁPIDOS

### Ver status containers:
```bash
docker-compose ps | grep connector
```

### Ver logs em tempo real:
```bash
docker-compose logs -f connector-whatsapp | grep Delivered
```

### Contar mensagens no Cassandra:
```bash
docker exec chat4all-cassandra cqlsh -e "
SELECT COUNT(*) FROM chat4all.messages 
WHERE conversation_id = 'conv_teste_001';"
```

---

## ⚡ ATALHOS CLI

- **1** = Login
- **2** = Enviar mensagem
- **4** = Listar mensagens
- **8** = Status da infra
- **9** = Limpar tela
- **0** = Sair

---

**✅ CLI RODANDO NO TERMINAL AGORA!**  
**📖 Guia completo:** `TESTE_MANUAL_OFFLINE.md`

---

**Última atualização:** 30 Nov 2024
