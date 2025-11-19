Semana 3– 4 – Implementação da API Básica, Kafka e Persistência de
Mensagens de Texto

Objetivo:

Desenvolver a primeira versão funcional do sistema: API REST/gRPC para
enviar mensagens, fila de eventos (Kafka) e persistência de mensagens no
banco distribuído.

Atividades:

1. Implementar API básica
    o Endpoints:
       ▪ POST /v1/messages (envio de mensagem de texto).
       ▪ GET /v1/conversations/{id}/messages (listar mensagens).
    o Implementar autenticação simples (ex.: JWT com chave
       estática).
2. Integração com Kafka
    o Criar tópico messages particionado por conversation_id.
    o Implementar produtor Kafka no serviço de API e consumidor
       (worker) que lê as mensagens e salva no banco.
3. Persistência de mensagens
    o Implementar camada de persistência (ex.: Cassandra /
       PostgreSQL distribuído).
    o Salvar mensagem + estado inicial (SENT) + metadados
       (timestamp, remetente, canais, etc.).
4. Worker simples
    o Criar serviço router-worker que consome mensagens do Kafka e
       atualiza status DELIVERED simulando envio.
    o Gerar logs de auditoria.
5. Teste de comunicação interna
    o Enviar e receber mensagens entre 2 usuários via API.
    o Confirmar persistência e leitura no banco.
6. Documentação e versionamento


```
o Atualizar README com endpoints, exemplos de uso e instruções
de execução.
o Criar script de inicialização automática (Docker Compose) com
Kafka e DB.
```
Entregas esperadas:

- API funcional (envio e listagem de mensagens).
- Kafka + consumidor em execução.
- Banco de dados armazenando mensagens.
- Documentação dos endpoints e arquitetura revisada.
- Log de execução demonstrando troca de mensagens entre dois
    usuários.


