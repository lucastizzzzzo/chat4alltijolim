# Contributing to Chat4All

Obrigado por contribuir com este projeto educacional! 🎓

## 🎯 Princípios

Este projeto segue a **Constituição Chat4All** com princípios não-negociáveis:

### I. Simplicidade Didática
- Código deve ser **claro e educacional**
- Comentários explicam o **PORQUÊ**, não apenas o QUÊ
- Cada conceito de sistemas distribuídos deve ser explícito

### II. Dependências Mínimas
- Apenas 3 bibliotecas externas: `kafka-clients`, `cassandra-driver-core`, `java-jwt`
- Sem frameworks pesados (Spring Boot, Hibernate, etc.)
- HTTP com JDK nativo (`com.sun.net.httpserver`)

### III. Test-First (NÃO-NEGOCIÁVEL)
- **Testes ANTES da implementação**
- Cobertura mínima: 80%
- Testes de contrato para mensagens Kafka

### IV. Escalabilidade Horizontal
- Serviços stateless (sem sticky sessions)
- Particionamento Kafka por `conversation_id`
- Suporte a múltiplas instâncias via Docker Compose scale

### V. Cassandra-First
- Schema driven by queries
- Partition key para distribuição
- Clustering key para ordenação

### VI. Entrega Incremental
- Commits pequenos e frequentes
- Cada fase 100% funcional antes da próxima
- Branches por feature

## 🔧 Setup de Desenvolvimento

```bash
# Clone
git clone https://github.com/your-username/chat4alltijolim.git
cd chat4alltijolim

# Build
mvn clean install

# Run tests
mvn test

# Start services
docker-compose up -d
```

## 📝 Convenções de Código

### Java

```java
/**
 * PROPÓSITO EDUCACIONAL: [Conceito sendo ensinado]
 * ==================
 * 
 * [Explicação detalhada do conceito de sistemas distribuídos]
 * 
 * EXEMPLO:
 * ```
 * [Código de exemplo]
 * ```
 * 
 * @author Chat4All Educational Project
 */
public class ExemploClasse {
    // Comentários em português para estudantes brasileiros
}
```

### Commits

Formato: `<tipo>: <descrição> [#issue]`

**Tipos:**
- `feat`: Nova funcionalidade
- `fix`: Correção de bug
- `docs`: Apenas documentação
- `test`: Adicionar/modificar testes
- `refactor`: Refatoração sem mudança de comportamento
- `perf`: Melhoria de performance
- `chore`: Tarefas de manutenção

**Exemplos:**
```bash
git commit -m "feat: adicionar endpoint GET /v1/conversations/{id}/messages"
git commit -m "test: adicionar testes para MessageValidator"
git commit -m "docs: atualizar README com instruções de deploy"
```

### Branches

```bash
# Features
git checkout -b feature/001-get-endpoint

# Bugfixes
git checkout -b fix/kafka-connection-timeout

# Documentação
git checkout -b docs/adr-cassandra-schema
```

## 🧪 Testes

### Estrutura

```
src/test/java/
├── unit/           # Testes unitários (rápidos)
├── integration/    # Testes de integração (Kafka, Cassandra)
└── contract/       # Testes de contrato (schemas)
```

### Rodando Testes

```bash
# Todos
mvn test

# Apenas unitários
mvn test -Dgroups=unit

# Apenas integração
mvn test -Dgroups=integration

# Com cobertura
mvn clean test jacoco:report
```

## 📋 Checklist para Pull Request

- [ ] Testes escritos ANTES da implementação
- [ ] Todos os testes passando (`mvn test`)
- [ ] Cobertura >= 80% para novas classes
- [ ] Comentários educacionais extensivos
- [ ] README atualizado (se aplicável)
- [ ] ADR criado para decisões arquiteturais
- [ ] Demo script atualizado (se novo endpoint)
- [ ] Docker Compose funcional

## 🏗️ Arquitetura

### Adicionando Novo Endpoint

1. **Escrever teste primeiro** (TDD)
   ```java
   // api-service/src/test/java/.../NewEndpointTest.java
   ```

2. **Criar Handler**
   ```java
   // api-service/src/main/java/.../http/NewHandler.java
   ```

3. **Registrar rota**
   ```java
   // api-service/src/main/java/.../Main.java
   server.createContext("/v1/new", newHandler);
   ```

4. **Atualizar documentação**
   - README.md
   - Postman collection (se existir)
   - Demo script

### Adicionando Novo Worker

1. **Definir contrato da mensagem**
   ```java
   // shared/src/main/java/.../events/NewEvent.java
   ```

2. **Criar processor**
   ```java
   // router-worker/src/main/java/.../processor/NewProcessor.java
   ```

3. **Registrar no consumer**
   ```java
   // router-worker/src/main/java/.../Main.java
   ```

## 📖 Documentação

### Architecture Decision Records (ADR)

Para decisões arquiteturais importantes:

```bash
# Criar novo ADR
cp docs/adr/000-template.md docs/adr/004-nova-decisao.md
```

Formato:
```markdown
# ADR-004: [Título da Decisão]

## Status
[Proposto | Aceito | Rejeitado | Substituído por ADR-XXX]

## Contexto
[Descrever o problema ou necessidade]

## Decisão
[Descrever a solução escolhida]

## Consequências
- **Positivas**: [Lista]
- **Negativas**: [Lista]
- **Trade-offs**: [Lista]

## Alternativas Consideradas
1. [Alternativa 1] - Rejeitada porque...
2. [Alternativa 2] - Rejeitada porque...
```

### Code Comments

Sempre incluir:

```java
/**
 * PROPÓSITO EDUCACIONAL: [Conceito]
 * 
 * POR QUE ESTA ABORDAGEM?
 * - [Razão 1]
 * - [Razão 2]
 * 
 * ALTERNATIVAS CONSIDERADAS:
 * - [Alt 1]: Rejeitada porque...
 * - [Alt 2]: Rejeitada porque...
 * 
 * PRODUÇÃO REAL:
 * Em sistemas de produção, você usaria [biblioteca/framework]
 * porque [razão]. Aqui usamos implementação manual para
 * fins educacionais.
 */
```

## 🐛 Reportando Bugs

Use GitHub Issues com template:

```markdown
## Descrição
[Descrição clara do bug]

## Passos para Reproduzir
1. [Passo 1]
2. [Passo 2]
3. [Observar erro]

## Comportamento Esperado
[O que deveria acontecer]

## Comportamento Atual
[O que está acontecendo]

## Ambiente
- OS: [Linux/Mac/Windows]
- Docker: [versão]
- Java: [versão]

## Logs
```
[Colar logs relevantes]
```

## Screenshots (se aplicável)
[Anexar imagens]
```

## 💡 Sugerindo Features

Para novas funcionalidades:

1. Verificar se alinha com os princípios educacionais
2. Criar issue com template de feature request
3. Discutir no issue antes de implementar
4. Criar ADR se decisão arquitetural significativa

## 🎓 Dúvidas?

- Abra uma issue com tag `question`
- Consulte a documentação em `docs/`
- Revise os ADRs existentes
- Verifique exemplos em `shared/src/test/java/`

---

**Obrigado por contribuir com a educação em Sistemas Distribuídos!** 🚀
