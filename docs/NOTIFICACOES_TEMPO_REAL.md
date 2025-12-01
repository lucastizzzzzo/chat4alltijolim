# 🔔 Sistema de Notificações em Tempo Real - Chat4All CLI

## 📋 Visão Geral

O CLI do Chat4All agora possui um **sistema de notificações push** que detecta automaticamente quando você recebe novas mensagens, exibindo alertas visuais no terminal em tempo real.

## ✨ Funcionalidades

### Notificações Automáticas
- ✅ Detecção de novas mensagens a cada **3 segundos**
- ✅ Exibe **nome da conversa** e remetente
- ✅ Mostra **prévia do conteúdo** (60 caracteres)
- ✅ Indica se mensagem tem **arquivo anexado**
- ✅ Som de alerta (beep) no terminal
- ✅ Borda visual destacada em amarelo

### Notificações Inteligentes
- ✅ Não notifica sobre **mensagens próprias**
- ✅ Não notifica sobre **mensagens antigas** (já vistas)
- ✅ Funciona para **múltiplas conversas** simultaneamente
- ✅ Cache de nomes de conversas para melhor UX

## 🚀 Como Usar

### 1. Autenticar no CLI

```bash
cd /home/tizzo/chat4alltijolim/cli
python3 chat4all-cli.py
```

No menu, escolha:
- **Opção 2:** Autenticar (login)
- Digite username e password

### 2. Ativar Notificações

No menu principal, escolha:
- **Opção 12:** 🔔 Ativar notificações em tempo real

Você verá:
```
🔔 Ativando notificações em tempo real...
O sistema verificará novas mensagens a cada 3 segundos
✓ Notificações ativadas!
Você será notificado quando receber novas mensagens.
```

### 3. Receber Notificações

Quando alguém enviar uma mensagem para você, aparecerá:

```
──────────────────────────────────────────────────────────────────────
🔔 NOVA MENSAGEM RECEBIDA
──────────────────────────────────────────────────────────────────────
  Conversa: Projeto Chat4All
  De: bob_1764550000
  Mensagem: Olá Alice! Como você está? 👋
  Horário: 15:23:45
──────────────────────────────────────────────────────────────────────
💡 Use a opção 7 para ver a conversa completa (ID: demo_notifications_...)
```

**Recursos da notificação:**
- 🔔 Som de beep
- 📝 Nome legível da conversa
- 👤 Identificação do remetente
- 📄 Prévia do conteúdo (60 chars)
- 📎 Indicador de arquivo anexado
- ⏰ Horário da mensagem
- 💡 Dica para ver conversa completa

### 4. Desativar Notificações

No menu principal, escolha:
- **Opção 12:** 🔕 Desativar notificações

## 🧪 Demo Automatizado

Criamos um script de demonstração que simula o envio de mensagens:

```bash
cd /home/tizzo/chat4alltijolim/scripts
bash demo-notifications.sh
```

### O que o demo faz:

1. **Cria 2 usuários:** Alice e Bob
2. **Instrui você a:**
   - Abrir novo terminal
   - Fazer login como Alice
   - Ativar notificações
3. **Envia 4 mensagens** do Bob para Alice:
   - Mensagem 1: Cumprimento
   - Mensagem 2: Pergunta sobre documentação
   - Mensagem 3: Convite para reunião
   - Mensagem 4: Alerta urgente

### Como executar o demo:

**Terminal 1 (Demo Script):**
```bash
cd /home/tizzo/chat4alltijolim/scripts
bash demo-notifications.sh
```

**Terminal 2 (CLI como Alice):**
```bash
cd /home/tizzo/chat4alltijolim/cli
python3 chat4all-cli.py

# No menu:
# 2 - Autenticar
# Username: alice_<timestamp do script>
# Password: alice123
# 12 - Ativar notificações

# Aguardar mensagens...
```

## 🏗️ Arquitetura Técnica

### Polling Thread
```python
def _poll_new_messages(self):
    """Thread worker que verifica novas mensagens periodicamente"""
    poll_interval = 3  # Verificar a cada 3 segundos
    
    while not self.stop_notifications.is_set():
        # 1. Buscar conversas do usuário
        # 2. Para cada conversa, buscar últimas 5 mensagens
        # 3. Detectar mensagens novas (não vistas e não próprias)
        # 4. Exibir notificação
```

### Estado da Aplicação
```python
self.notification_enabled: bool          # Flag de estado
self.notification_thread: Thread         # Worker thread
self.last_seen_messages: Set[str]        # IDs já vistos
self.stop_notifications: Event           # Signal para parar
self.conversation_names: Dict[str, str]  # Cache de nomes
```

### Endpoints Utilizados
- `GET /v1/conversations` - Listar conversas do usuário
- `GET /v1/conversations/{id}/messages?limit=5` - Últimas mensagens

### Lógica de Detecção
```python
for msg in messages:
    msg_id = msg.get('message_id')
    sender_id = msg.get('sender_id')
    
    # Condições para notificar:
    if (msg_id not in self.last_seen_messages and  # Nova
        sender_id != self.current_user):           # Não é própria
        
        self.last_seen_messages.add(msg_id)
        self._show_notification(conv_name, msg, conv_id)
```

## 📊 Performance

### Métricas
- **Intervalo de polling:** 3 segundos
- **Mensagens verificadas por ciclo:** 5 (últimas de cada conversa)
- **Overhead de rede:** ~1-2 requisições/segundo (dependendo do número de conversas)
- **Consumo de CPU:** Mínimo (thread daemon)
- **Consumo de memória:** ~10-50 KB (set de IDs vistos)

### Otimizações Implementadas
1. **Limite de 5 mensagens** por conversa (evita sobrecarga)
2. **Cache de nomes** de conversas (reduz requisições)
3. **Set para IDs vistos** (lookup O(1))
4. **Thread daemon** (não bloqueia exit)
5. **Timeout de 5s** em requisições (não trava)

## 🎯 Casos de Uso

### 1. Suporte ao Cliente
```
Agente de suporte logado no CLI com notificações ativas.
Cliente envia mensagem → Agente é notificado imediatamente.
```

### 2. Chat de Equipe
```
Desenvolvedor trabalhando com CLI aberto.
Colega envia mensagem urgente → Notificação aparece com beep.
```

### 3. Monitoramento de Conversas
```
Moderador monitora múltiplas conversas de grupo.
Nova mensagem em qualquer grupo → Notificação mostra qual grupo.
```

## ⚙️ Configuração

### Variáveis de Ambiente (Futuro)
```bash
# Intervalo de polling (segundos)
export CHAT4ALL_POLL_INTERVAL=3

# Tamanho da prévia de mensagem
export CHAT4ALL_PREVIEW_LENGTH=60

# Ativar/desativar beep
export CHAT4ALL_ENABLE_BEEP=true
```

### Customização do Código
```python
# Alterar intervalo de polling (chat4all-cli.py, linha ~XXX)
poll_interval = 3  # Alterar para 5, 10, etc.

# Alterar limite de mensagens verificadas
params={"limit": 5}  # Alterar para 10, 20, etc.

# Alterar tamanho da prévia
content = message.get('content', '')[:60]  # Alterar 60 para outro valor
```

## 🐛 Troubleshooting

### Notificações não aparecem
**Problema:** Ativei notificações mas não recebo alertas.

**Soluções:**
1. Verificar se está autenticado (token válido)
2. Verificar se API está respondendo (`Opção 11 - Status`)
3. Verificar logs de erro (se houver)
4. Desativar e reativar notificações

### Token expirado durante notificações
**Problema:** Notificações param de funcionar após 1 hora.

**Solução:**
- JWT expira em 1 hora
- Faça novo login (`Opção 2`)
- Reative notificações (`Opção 12`)

### Notificações duplicadas
**Problema:** Recebo a mesma notificação múltiplas vezes.

**Causa:** Improvável, mas pode ocorrer se:
- Set de IDs vistos foi resetado
- Sistema foi reiniciado

**Solução:**
- Desativar e reativar notificações
- Limpar cache (sair e entrar no CLI)

### Performance lenta
**Problema:** CLI fica lento com notificações ativas.

**Causa:** Muitas conversas ou mensagens.

**Soluções:**
1. Aumentar intervalo de polling (editar código)
2. Reduzir limite de mensagens verificadas
3. Desativar notificações quando não necessário

## 📈 Melhorias Futuras

### Curto Prazo
- [ ] Filtrar notificações por conversa específica
- [ ] Configuração de intervalo via variável de ambiente
- [ ] Sons diferentes para tipos de mensagem (texto, arquivo, urgente)
- [ ] Exibir contador de notificações não lidas

### Médio Prazo
- [ ] Notificações desktop (via `notify-send` no Linux)
- [ ] Integração com WebSocket para push real-time
- [ ] Priorização de notificações (urgente, normal, baixa)
- [ ] Histórico de notificações recebidas

### Longo Prazo
- [ ] Sistema de regras de notificação (mute, keywords, usuários)
- [ ] Notificações por email/SMS (integração externa)
- [ ] Analytics de notificações (taxa de resposta, tempo médio)
- [ ] Machine learning para priorizar notificações relevantes

## 🔐 Segurança

### Considerações
- ✅ **Token JWT** validado em cada requisição
- ✅ **HTTPS** recomendado em produção
- ✅ **Rate limiting** (3s entre verificações)
- ✅ **Timeout de 5s** previne DOS
- ✅ **Thread daemon** não persiste credenciais

### Boas Práticas
- Não compartilhar terminal com notificações ativas
- Desativar notificações ao compartilhar tela
- Usar variáveis de ambiente para API URL
- Logout ao terminar sessão

## 📝 Logs e Debug

### Habilitar logs detalhados (futuro)
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

### Verificar estado das notificações
```python
# No CLI, após autenticar:
print(f"Notificações: {'ATIVAS' if self.notification_enabled else 'INATIVAS'}")
print(f"Thread: {self.notification_thread.is_alive() if self.notification_thread else 'None'}")
print(f"Mensagens vistas: {len(self.last_seen_messages)}")
```

## 🎓 Conceitos Aprendidos

### Threading em Python
- **Daemon threads:** Não bloqueiam saída do programa
- **Event objects:** Sincronização entre threads
- **Thread safety:** Cuidado com acesso concorrente

### Polling vs WebSocket
- **Polling:** Simples, funciona com qualquer API REST
- **WebSocket:** Mais eficiente, mas requer suporte no backend
- **Trade-off:** Polling suficiente para <100 req/min

### UX no Terminal
- **Cores ANSI:** Destaque visual
- **Beep character:** Alerta sonoro
- **Bordas:** Separação visual clara
- **Status persistente:** Usuário sempre sabe o estado

## 📚 Referências

- [Python Threading](https://docs.python.org/3/library/threading.html)
- [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code)
- [REST API Best Practices](https://restfulapi.net/)
- [Polling vs WebSocket](https://ably.com/blog/websockets-vs-long-polling)

---

**Versão:** 1.0  
**Data:** 30 de Novembro de 2025  
**Autor:** GitHub Copilot para Chat4All  
**Status:** ✅ Implementado e Testado
