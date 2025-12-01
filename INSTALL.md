# Chat4All - Guia de Instalação Rápida

## 🚀 Instalação em Máquinas de Terceiros

Este guia facilita a execução do Chat4All em qualquer máquina para fins educacionais.

### 📋 Pré-requisitos

- **Docker** (versão 20.10+) - [Instalar Docker](https://docs.docker.com/get-docker/)
- **Docker Compose** (versão 1.29+)
- **Java** (versão 11+) - [Instalar Java](https://adoptium.net/)
- **Maven** (versão 3.6+) - [Instalar Maven](https://maven.apache.org/install.html)
- **Python 3** (versão 3.8+)
- **Git**

#### Verificar instalação:
```bash
docker --version
docker-compose --version
java -version
mvn --version
python3 --version
git --version
```

### 📦 Instalação Rápida (3 passos)

#### 1. Clone o repositório
```bash
git clone https://github.com/lucastizzzzzo/chat4alltijolim.git
cd chat4alltijolim
```

#### 2. Execute o setup automático
```bash
make quickstart
```

Isso irá:
- ✅ Verificar dependências
- ✅ Criar arquivo `.env` com configurações padrão
- ✅ Compilar o projeto (Maven)
- ✅ Construir imagens Docker
- ✅ Iniciar todos os serviços
- ✅ Popular o banco com dados de teste
- ✅ Mostrar status e endpoints disponíveis

#### 3. Teste a instalação
```bash
# Verificar saúde da API
curl http://localhost:8080/health

# Ou use o Makefile
make health
```

### 🎯 Comandos Principais

```bash
# Ver todos os comandos disponíveis
make help

# Iniciar serviços
make start

# Parar serviços
make stop

# Ver logs
make logs

# Status dos serviços
make status

# Executar testes
make test

# CLI interativo
make cli

# Demonstração
make demo
```

### 🌐 Endpoints Disponíveis

Após `make start`:

| Serviço | URL | Descrição |
|---------|-----|-----------|
| **API REST** | http://localhost:8080 | API principal |
| **WebSocket** | ws://localhost:8085 | Notificações em tempo real |
| **MinIO Console** | http://localhost:9001 | Armazenamento de arquivos |
| **Prometheus** | http://localhost:9090 | Métricas |
| **Grafana** | http://localhost:3000 | Dashboards (admin/admin) |

### ⚙️ Configuração Personalizada

#### Editar configurações:
```bash
# Copiar .env.example para .env (já feito pelo make setup)
cp .env.example .env

# Editar conforme necessário
nano .env
```

#### Principais variáveis:
```bash
# Portas dos serviços
API_SERVICE_PORT=8080
WEBSOCKET_PORT=8085
MINIO_ENDPOINT=http://localhost:9000

# Kafka
KAFKA_BOOTSTRAP_SERVERS=localhost:9092

# Cassandra
CASSANDRA_CONTACT_POINTS=localhost
CASSANDRA_PORT=9042

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
```

#### Aplicar mudanças:
```bash
make restart
```

### 🧪 Testes e Validação

```bash
# Testes unitários
make test-unit

# Testes de integração
make test-integration

# Testes end-to-end
make test-e2e

# Teste WebSocket
make test-websocket

# Popular dados de teste
make populate
```

### 📊 Demonstrações

```bash
# Demo simples
make demo

# Demo de notificações
make demo-notifications

# Demo de compartilhamento de arquivos
make demo-file-sharing

# CLI interativo
make cli
```

### 🗄️ Gerenciamento de Banco de Dados

```bash
# Acessar shell do Cassandra
make db-shell

# Visualizar dados (gera HTML)
make db-view

# Resetar banco de dados
make db-reset

# Backup
make backup
```

### 🛠️ Desenvolvimento

```bash
# Iniciar apenas infraestrutura (para dev local)
make dev

# Build rápido (sem testes)
make build-fast

# Formatar código
make fmt

# Verificar estilo
make lint

# Ver versões instaladas
make version
```

### 🧹 Limpeza

```bash
# Parar e remover containers
make clean

# Limpeza completa (inclui imagens)
make clean-all

# Remover logs
make clean-logs
```

### 🔧 Troubleshooting

#### Porta já em uso:
```bash
# Ver portas em uso
make ports

# Editar .env para mudar portas
nano .env

# Reiniciar
make restart
```

#### Serviços não iniciam:
```bash
# Verificar logs
make logs

# Verificar status
make status

# Limpar e reiniciar
make clean
make build
make start
```

#### Erro de memória:
```bash
# Editar .env
JAVA_OPTS=-Xmx1024m -Xms512m
MAVEN_OPTS=-Xmx2048m -Xms1024m

# Reiniciar
make restart-app
```

#### Docker sem permissão:
```bash
# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER

# Relogar ou:
newgrp docker
```

### 📚 Documentação Completa

- **API**: Ver `openapi.yaml` ou usar Swagger UI
- **Arquitetura**: Ver `docs/ARCHITECTURE.md`
- **Guia Rápido**: Ver `docs/QUICK_REFERENCE.md`
- **README**: Ver `README.md`

### 🎓 Uso Educacional

Este projeto é configurado para ser facilmente executado em ambientes educacionais:

1. **Configuração simplificada**: Arquivo `.env` com valores padrão
2. **Makefile abrangente**: Comandos fáceis de usar
3. **Dados de teste**: População automática do banco
4. **Documentação completa**: Guias e exemplos
5. **Demos prontas**: Scripts para demonstração

### 📝 Notas de Segurança

⚠️ **IMPORTANTE**: As configurações padrão são para ambiente educacional/desenvolvimento.

Para produção, altere:
- Senhas do MinIO (`MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`)
- Senha do Grafana (`GRAFANA_ADMIN_PASSWORD`)
- Configurações de rede e segurança

### 💡 Dicas

1. **Primeira execução**: Use `make quickstart` - faz tudo automaticamente
2. **Desenvolvimento**: Use `make dev` para rodar só a infraestrutura
3. **Ver tudo funcionando**: Use `make demo` após `make start`
4. **Problemas**: Use `make logs` para ver o que está acontecendo
5. **Ajuda**: Use `make help` para ver todos os comandos

### 🆘 Suporte

Para problemas ou dúvidas:
1. Verificar logs: `make logs`
2. Verificar status: `make status`
3. Consultar documentação em `docs/`
4. Abrir issue no GitHub

---

**Feito para educação - Chat4All 2024** 🎓
