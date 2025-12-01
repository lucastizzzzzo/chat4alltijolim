# Chat4All - Makefile
# Sistema de mensagens distribuído multi-plataforma

.PHONY: help setup build start stop restart clean logs test install-deps check-deps

# Cores para output
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
NC     := \033[0m # No Color

# Configurações
PROJECT_NAME := chat4all
DOCKER_COMPOSE := docker-compose
MAVEN := mvn
PYTHON := python3
PIP := pip3

##@ Ajuda

help: ## Mostra esta mensagem de ajuda
	@echo "$(GREEN)Chat4All - Sistema de Mensagens Distribuído$(NC)"
	@echo ""
	@echo "$(YELLOW)Uso: make [target]$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup e Instalação

check-deps: ## Verifica dependências instaladas
	@echo "$(YELLOW)Verificando dependências...$(NC)"
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)Docker não encontrado!$(NC) Instale: https://docs.docker.com/get-docker/"; exit 1; }
	@command -v docker-compose >/dev/null 2>&1 || { echo "$(RED)Docker Compose não encontrado!$(NC)"; exit 1; }
	@command -v $(MAVEN) >/dev/null 2>&1 || { echo "$(RED)Maven não encontrado!$(NC) Instale: https://maven.apache.org/install.html"; exit 1; }
	@command -v $(PYTHON) >/dev/null 2>&1 || { echo "$(RED)Python3 não encontrado!$(NC)"; exit 1; }
	@command -v java >/dev/null 2>&1 || { echo "$(RED)Java não encontrado!$(NC) Instale Java 11+"; exit 1; }
	@echo "$(GREEN)✓ Todas as dependências estão instaladas!$(NC)"

setup: check-deps ## Configuração inicial do projeto
	@echo "$(YELLOW)Configurando ambiente...$(NC)"
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN)✓ Arquivo .env criado a partir de .env.example$(NC)"; \
	else \
		echo "$(YELLOW)! Arquivo .env já existe$(NC)"; \
	fi
	@echo "$(GREEN)✓ Setup concluído!$(NC)"
	@echo "$(YELLOW)Edite o arquivo .env se necessário antes de continuar$(NC)"

install-deps: ## Instala dependências do projeto
	@echo "$(YELLOW)Instalando dependências Maven...$(NC)"
	$(MAVEN) clean install -DskipTests
	@echo "$(YELLOW)Instalando dependências Python CLI...$(NC)"
	cd cli && $(PIP) install -r requirements.txt
	@echo "$(GREEN)✓ Dependências instaladas!$(NC)"

##@ Docker e Serviços

build: ## Compila todos os serviços (Maven + Docker)
	@echo "$(YELLOW)Compilando projeto Maven...$(NC)"
	$(MAVEN) clean package -DskipTests
	@echo "$(YELLOW)Construindo imagens Docker...$(NC)"
	$(DOCKER_COMPOSE) build
	@echo "$(GREEN)✓ Build concluído!$(NC)"

build-fast: ## Build rápido sem testes
	@echo "$(YELLOW)Build rápido (sem testes)...$(NC)"
	$(MAVEN) clean package -DskipTests -Dmaven.test.skip=true
	$(DOCKER_COMPOSE) build
	@echo "$(GREEN)✓ Build rápido concluído!$(NC)"

start: ## Inicia todos os serviços
	@echo "$(YELLOW)Iniciando serviços...$(NC)"
	$(DOCKER_COMPOSE) up -d
	@echo "$(GREEN)✓ Serviços iniciados!$(NC)"
	@echo ""
	@echo "$(YELLOW)Aguardando inicialização dos serviços (30s)...$(NC)"
	@sleep 30
	@make status

start-infra: ## Inicia apenas infraestrutura (Kafka, Cassandra, Redis, MinIO)
	@echo "$(YELLOW)Iniciando infraestrutura...$(NC)"
	$(DOCKER_COMPOSE) up -d zookeeper kafka cassandra redis minio
	@echo "$(GREEN)✓ Infraestrutura iniciada!$(NC)"

stop: ## Para todos os serviços
	@echo "$(YELLOW)Parando serviços...$(NC)"
	$(DOCKER_COMPOSE) down
	@echo "$(GREEN)✓ Serviços parados!$(NC)"

restart: stop start ## Reinicia todos os serviços

restart-app: ## Reinicia apenas serviços da aplicação
	@echo "$(YELLOW)Reiniciando serviços da aplicação...$(NC)"
	$(DOCKER_COMPOSE) restart api-service router-worker connector-whatsapp connector-instagram websocket-gateway
	@echo "$(GREEN)✓ Aplicação reiniciada!$(NC)"

##@ Logs e Monitoramento

logs: ## Mostra logs de todos os serviços
	$(DOCKER_COMPOSE) logs -f

logs-api: ## Logs do API Service
	$(DOCKER_COMPOSE) logs -f api-service

logs-router: ## Logs do Router Worker
	$(DOCKER_COMPOSE) logs -f router-worker

logs-ws: ## Logs do WebSocket Gateway
	$(DOCKER_COMPOSE) logs -f websocket-gateway

logs-kafka: ## Logs do Kafka
	$(DOCKER_COMPOSE) logs -f kafka

logs-cassandra: ## Logs do Cassandra
	$(DOCKER_COMPOSE) logs -f cassandra

status: ## Mostra status dos serviços
	@echo "$(YELLOW)Status dos Serviços:$(NC)"
	@$(DOCKER_COMPOSE) ps
	@echo ""
	@echo "$(YELLOW)Endpoints Disponíveis:$(NC)"
	@echo "  $(GREEN)API REST:$(NC)           http://localhost:8080"
	@echo "  $(GREEN)WebSocket:$(NC)          ws://localhost:8085"
	@echo "  $(GREEN)MinIO Console:$(NC)      http://localhost:9001"
	@echo "  $(GREEN)Prometheus:$(NC)         http://localhost:9090"
	@echo "  $(GREEN)Grafana:$(NC)            http://localhost:3000"
	@echo "  $(GREEN)API Docs (Swagger):$(NC) Veja openapi.yaml"

##@ Testes

test: ## Executa todos os testes
	@echo "$(YELLOW)Executando testes...$(NC)"
	$(MAVEN) test
	@echo "$(GREEN)✓ Testes concluídos!$(NC)"

test-unit: ## Executa apenas testes unitários
	@echo "$(YELLOW)Executando testes unitários...$(NC)"
	$(MAVEN) test -Dtest=**/*Test
	@echo "$(GREEN)✓ Testes unitários concluídos!$(NC)"

test-integration: ## Executa testes de integração
	@echo "$(YELLOW)Executando testes de integração...$(NC)"
	$(MAVEN) verify -P integration-tests
	@echo "$(GREEN)✓ Testes de integração concluídos!$(NC)"

test-e2e: start ## Executa testes end-to-end
	@echo "$(YELLOW)Executando testes E2E...$(NC)"
	@sleep 10
	@bash scripts/test-end-to-end.sh
	@echo "$(GREEN)✓ Testes E2E concluídos!$(NC)"

test-websocket: ## Testa notificações WebSocket
	@echo "$(YELLOW)Testando WebSocket...$(NC)"
	@$(PYTHON) scripts/test-websocket-notifications.py

##@ CLI e Demos

cli: ## Inicia CLI interativo
	@cd cli && $(PYTHON) chat4all-cli.py

demo: ## Executa demonstração completa
	@echo "$(YELLOW)Executando demonstração...$(NC)"
	@bash scripts/demo-simple.sh

demo-notifications: ## Demo de notificações em tempo real
	@bash scripts/demo-notifications.sh

demo-file-sharing: ## Demo de compartilhamento de arquivos
	@bash scripts/demo-file-sharing.sh

populate: ## Popula banco com dados de teste
	@echo "$(YELLOW)Populando banco de dados...$(NC)"
	@bash scripts/populate-test-data.sh
	@echo "$(GREEN)✓ Dados de teste inseridos!$(NC)"

##@ Database

db-shell: ## Acessa shell do Cassandra
	@echo "$(YELLOW)Conectando ao Cassandra...$(NC)"
	$(DOCKER_COMPOSE) exec cassandra cqlsh

db-view: ## Visualiza dados do Cassandra (HTML)
	@echo "$(YELLOW)Gerando visualização do banco...$(NC)"
	@$(PYTHON) scripts/cassandra-viewer.py
	@echo "$(GREEN)✓ Arquivo cassandra-data.html gerado!$(NC)"

db-reset: ## Reseta o banco de dados
	@echo "$(RED)⚠ ATENÇÃO: Isso vai apagar todos os dados!$(NC)"
	@read -p "Tem certeza? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(DOCKER_COMPOSE) exec cassandra cqlsh -e "DROP KEYSPACE IF EXISTS chat4all;"; \
		$(DOCKER_COMPOSE) restart cassandra; \
		sleep 10; \
		$(DOCKER_COMPOSE) exec cassandra cqlsh -f /schema.cql; \
		echo "$(GREEN)✓ Banco resetado!$(NC)"; \
	fi

##@ Limpeza

clean: ## Remove containers, volumes e builds
	@echo "$(YELLOW)Limpando ambiente...$(NC)"
	$(DOCKER_COMPOSE) down -v
	$(MAVEN) clean
	@echo "$(GREEN)✓ Limpeza concluída!$(NC)"

clean-all: clean ## Limpeza completa (inclui imagens Docker)
	@echo "$(YELLOW)Removendo imagens Docker...$(NC)"
	@docker images | grep $(PROJECT_NAME) | awk '{print $$3}' | xargs -r docker rmi -f
	@echo "$(GREEN)✓ Limpeza completa concluída!$(NC)"

clean-logs: ## Remove logs
	@echo "$(YELLOW)Removendo logs...$(NC)"
	@find . -name "*.log" -type f -delete
	@echo "$(GREEN)✓ Logs removidos!$(NC)"

##@ Desenvolvimento

dev: start-infra ## Ambiente de desenvolvimento (apenas infra)
	@echo "$(GREEN)✓ Infraestrutura iniciada para desenvolvimento$(NC)"
	@echo "$(YELLOW)Execute os serviços da aplicação via IDE ou linha de comando$(NC)"

watch: ## Observa mudanças e recompila automaticamente
	@echo "$(YELLOW)Observando mudanças...$(NC)"
	@while true; do \
		$(MAVEN) compile; \
		inotifywait -r -e modify,create,delete ./*/src; \
	done

fmt: ## Formata código Java
	@echo "$(YELLOW)Formatando código...$(NC)"
	$(MAVEN) spotless:apply
	@echo "$(GREEN)✓ Código formatado!$(NC)"

lint: ## Verifica estilo do código
	@echo "$(YELLOW)Verificando código...$(NC)"
	$(MAVEN) checkstyle:check
	@echo "$(GREEN)✓ Verificação concluída!$(NC)"

##@ Utilitários

health: ## Verifica saúde dos serviços
	@echo "$(YELLOW)Verificando saúde dos serviços...$(NC)"
	@curl -s http://localhost:8080/health | jq . || echo "$(RED)API Service não responde$(NC)"
	@echo ""

version: ## Mostra versões
	@echo "$(YELLOW)Versões:$(NC)"
	@echo "  Docker:        $$(docker --version)"
	@echo "  Docker Compose: $$(docker-compose --version)"
	@echo "  Maven:         $$($(MAVEN) --version | head -n 1)"
	@echo "  Java:          $$(java -version 2>&1 | head -n 1)"
	@echo "  Python:        $$($(PYTHON) --version)"

ports: ## Lista portas em uso
	@echo "$(YELLOW)Portas em uso:$(NC)"
	@netstat -tuln | grep -E ':(8080|8081|8082|8085|9000|9001|9042|9092|6379|3000|9090)' || echo "Nenhuma porta em uso"

backup: ## Backup do banco de dados
	@echo "$(YELLOW)Criando backup...$(NC)"
	@mkdir -p backups
	@$(DOCKER_COMPOSE) exec cassandra nodetool snapshot chat4all
	@echo "$(GREEN)✓ Backup criado!$(NC)"

##@ Instalação Rápida

quickstart: setup build start populate ## Setup completo + inicialização (primeira vez)
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)✓ Chat4All está pronto para uso!$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════$(NC)"
	@echo ""
	@make status
	@echo ""
	@echo "$(YELLOW)Próximos passos:$(NC)"
	@echo "  1. Teste a API: curl http://localhost:8080/health"
	@echo "  2. Execute o CLI: make cli"
	@echo "  3. Veja os logs: make logs"
	@echo "  4. Execute uma demo: make demo"
	@echo ""

# Configuração padrão
.DEFAULT_GOAL := help
