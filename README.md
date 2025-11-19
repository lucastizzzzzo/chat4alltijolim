# Chat4All - Distributed Messaging Platform

**Educational Project** | 7th Semester Information Systems | Distributed Systems Course

[![Java 17](https://img.shields.io/badge/Java-17-orange)](https://openjdk.org/projects/jdk/17/)
[![Kafka](https://img.shields.io/badge/Kafka-3.6-black)](https://kafka.apache.org/)
[![Cassandra](https://img.shields.io/badge/Cassandra-4.1-blue)](https://cassandra.apache.org/)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue)](https://docs.docker.com/compose/)

## 📚 Project Overview

Chat4All is an **educational implementation** of a distributed messaging platform designed to teach 7th semester students core distributed systems concepts:

- **Event-Driven Architecture** (Kafka)
- **Horizontal Scalability** (stateless services)
- **Distributed Databases** (Cassandra)
- **Microservices Pattern**
- **Asynchronous Processing**

### 🎯 Learning Objectives

1. Understand **Kafka partitioning** and how it preserves message ordering
2. Learn **Cassandra query-driven modeling** with partition keys
3. Implement **stateless REST APIs** for horizontal scalability
4. Practice **Test-First Development** (TDD)
5. Experience **Docker Compose** multi-service orchestration

## 🏗️ Architecture

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   Client    │─────▶│ API Service │─────▶│    Kafka    │
│  (curl/app) │◀─────│  (REST API) │      │  (Events)   │
└─────────────┘      └─────────────┘      └──────┬──────┘
                            │                     │
                            │                     ▼
                            │              ┌─────────────┐
                            │              │   Router    │
                            │              │   Worker    │
                            │              └──────┬──────┘
                            │                     │
                            ▼                     ▼
                     ┌─────────────────────────────┐
                     │      Cassandra (NoSQL)      │
                     │  • Messages (by conv_id)    │
                     │  • Conversations            │
                     └─────────────────────────────┘
```

### Key Design Decisions

- **No Frameworks**: Using JDK's built-in `HttpServer` instead of Spring Boot (educational transparency)
- **Minimal Dependencies**: Only 3 external libraries (Kafka, Cassandra, JWT)
- **No ORM**: Direct CQL queries to understand NoSQL patterns
- **Test-First**: All tests written before implementation

## 🚀 Quick Start

### Prerequisites

- **Docker** & **Docker Compose** (20.10+)
- **Java 17** (OpenJDK) - for local development
- **Maven 3.8+** - for building
- **curl** or **httpie** - for testing APIs

### 1. Clone and Build

```bash
# Clone repository
git clone https://github.com/your-username/chat4alltijolim.git
cd chat4alltijolim

# Build all modules
mvn clean package -DskipTests
```

**Note**: The first build may take 2-3 minutes to download dependencies.

### 2. Start All Services

```bash
# Start infrastructure (Kafka, Cassandra, API, Worker)
docker-compose up -d

# Wait for services to be healthy (~60-90 seconds)
# You can monitor with:
docker-compose ps
docker-compose logs -f api-service router-worker

# Check health
curl http://localhost:8082/health
# Expected: {"status":"UP"}
```

**Port Mapping:**
- API Service: `http://localhost:8082` (mapped from internal 8080)
- Cassandra: `localhost:9042`
- Kafka: `localhost:9092` (internal), `localhost:29092` (external)

### 3. Test the System

```bash
# IMPORTANT: API Service is mapped to port 8082 externally
# (check with: docker-compose ps)

# 1. Authenticate and get JWT token
TOKEN=$(curl -s -X POST http://localhost:8082/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username":"user_a","password":"pass_a"}' \
  | jq -r '.access_token')

echo "Token: $TOKEN"

# 2. Send a message
MESSAGE_RESPONSE=$(curl -s -X POST http://localhost:8082/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "conv_demo_123",
    "sender_id": "user_a",
    "content": "Hello from distributed systems!"
  }')

echo "Message sent: $MESSAGE_RESPONSE"

# 3. Wait for worker to process (5 seconds)
echo "Waiting for async processing..."
sleep 5

# 4. Retrieve messages (NEW!)
curl -s -X GET "http://localhost:8082/v1/conversations/conv_demo_123/messages?limit=50&offset=0" \
  -H "Authorization: Bearer $TOKEN" | jq

# Expected output:
# {
#   "conversation_id": "conv_demo_123",
#   "messages": [
#     {
#       "message_id": "msg_...",
#       "sender_id": "user_a",
#       "content": "Hello from distributed systems!",
#       "timestamp": 1763513873763,
#       "status": "DELIVERED"
#     }
#   ],
#   "pagination": {
#     "limit": 50,
#     "offset": 0,
#     "returned": 1
#   }
# }
```

### 4. Run Automated Tests

```bash
# End-to-end test (POST + Worker + Cassandra)
./scripts/test-end-to-end.sh

# GET endpoint test (authentication + pagination)
./scripts/test-get-messages.sh

# Both tests should show:
# ✓ ALL TESTS PASSED!
```

### 5. Run Demo: Conversation between João and Maria

```bash
# Complete demo with 6 messages exchanged
./scripts/demo-simple.sh
```

**Expected Output:**
```
📖 HISTÓRICO DA CONVERSAÇÃO
──────────────────────────────────────────────────────────────────
#    Remetente    Timestamp            Status       Conteúdo
──────────────────────────────────────────────────────────────────
1    👨 João       22:07:02.504         DELIVERED    Oi Maria, tudo bem?
2    👨 João       22:07:03.522         DELIVERED    Podemos conversar sobre o projeto?
3    👨 João       22:07:04.540         DELIVERED    Que tal às 15h?
4    👩 Maria      22:07:17.109         DELIVERED    Oi João! Tudo ótimo, e você?
5    👩 Maria      22:07:18.130         DELIVERED    Claro! Que horas funciona melhor?
6    👩 Maria      22:07:19.156         DELIVERED    Perfeito! Te mando o link às 14h50.
──────────────────────────────────────────────────────────────────
📊 Estatísticas:
   • Mensagens de João: 3
   • Mensagens de Maria: 3
   • Total: 6
   • Status DELIVERED: 6/6
```

## 🔧 Development

### Running Locally (without Docker)

```bash
# Terminal 1: Start Cassandra
docker run -d -p 9042:9042 --name cassandra cassandra:4.1

# Terminal 2: Start Kafka + Zookeeper
docker-compose up -d kafka zookeeper cassandra

# Terminal 3: Run API Service
cd api-service
mvn exec:java -Dexec.mainClass="chat4all.api.Main"

# Terminal 4: Run Router Worker
cd router-worker
mvn exec:java -Dexec.mainClass="chat4all.worker.Main"
```

### Rebuilding After Code Changes

```bash
# Rebuild specific service
mvn clean package -DskipTests -pl api-service -am

# Restart container
docker-compose restart api-service

# Or rebuild Docker image
docker-compose up -d --build api-service
```

## 📖 Implementation Status

This project follows an **incremental delivery** approach. **Entrega 1 MVP is COMPLETE! ✓**

### ✅ Phase 1: Setup (Complete)
- [x] Maven multi-module structure (parent + shared + api-service + router-worker)
- [x] Docker Compose with Kafka (3 partitions), Cassandra, Zookeeper
- [x] Cassandra schema (messages, conversations, users tables)
- [x] Dockerfiles for API and Worker services
- [x] Shared Constants and utilities

### ✅ Phase 2: Foundation (Complete)
- [x] Shared MessageEvent POJO
- [x] Logger utility with timestamped output
- [x] Error handling patterns
- [x] JsonParser for manual JSON serialization (educational)

### ✅ Phase 3: Authentication (Complete)
- [x] POST /auth/token endpoint (JWT generation)
- [x] JwtAuthenticator (token validation)
- [x] TokenGenerator (HS256, 1-hour expiration)
- [x] Authentication middleware for protected routes
- [x] Test script: test-auth-messages.sh

### ✅ Phase 4: API Send Messages (Complete)
- [x] POST /v1/messages endpoint (authenticated)
- [x] MessageValidator (required fields, max lengths)
- [x] MessageProducer (Kafka integration with partitioning)
- [x] Message ID generation (UUID-based)
- [x] Kafka topic: "messages" with 3 partitions

### ✅ Phase 5: Router Worker (Complete)
- [x] CassandraConnection (connection pooling)
- [x] CassandraMessageStore (PreparedStatements)
- [x] MessageProcessor (deduplication + status transitions)
- [x] KafkaMessageConsumer (manual commit, at-least-once)
- [x] Main worker loop with graceful shutdown
- [x] Status transitions: SENT → DELIVERED

### ✅ Phase 6: GET Messages API (Complete - NEW!)
- [x] GET /v1/conversations/{id}/messages endpoint
- [x] CassandraMessageRepository in API Service
- [x] ConversationsHandler (pagination + authentication)
- [x] Query parameters: limit (default 50, max 100), offset
- [x] Pagination metadata in response
- [x] Test script: test-get-messages.sh

### 📋 Entrega 1 Checklist

- [x] **POST /v1/messages** - Enviar mensagem (autenticado, Kafka)
- [x] **GET /v1/conversations/{id}/messages** - Buscar mensagens
- [x] **JWT Authentication** - Token-based auth (simple, static secret)
- [x] **Kafka Integration** - Topic com 3 partições, particionamento por conversation_id
- [x] **Router Worker** - Consumer Kafka → Cassandra persistence
- [x] **Status Transitions** - SENT → DELIVERED (simulated)
- [x] **Docker Compose** - All services running (6 containers)
- [x] **End-to-End Tests** - Automated test scripts
- [x] **Documentation** - ADRs, extensive code comments

### 🎯 Next Steps (Entrega 2 - Future)

See [`specs/002-advanced-features/`](specs/002-advanced-features/) for Phase 7-9:
- [ ] Phase 7: File uploads (2GB support)
- [ ] Phase 8: External connectors (WhatsApp integration)
- [ ] Phase 9: Observability (metrics, tracing)

## 🏛️ Constitutional Principles

This project adheres to the **Chat4All Constitution** (v1.0.0):

### I. Didactic Simplicity
- Code is clear, well-commented, and designed for learning
- Every distributed systems concept is explicitly documented
- No "magic" - students see how everything works

### II. Minimal Dependencies
- Only 3 external libraries: `kafka-clients`, `cassandra-driver-core`, `java-jwt`
- No Spring Boot, no ORMs, no heavy frameworks
- Direct HTTP handling with JDK's `HttpServer`

### III. Test-First Discipline (NON-NEGOTIABLE)
- Tests written BEFORE implementation
- JUnit 5 for unit/integration tests
- Contract tests for Kafka message schemas

### IV. Horizontal Scalability
- Stateless API services (no sticky sessions)
- Kafka partitioning by `conversation_id`
- Docker Compose scaling: `docker-compose up --scale api-service=3`

### V. Cassandra-First Data Storage
- Query-driven schema design
- Partition key = `conversation_id` (data distribution)
- Clustering key = `timestamp` (ordering within partition)

### VI. Incremental Delivery
- Phase 1: Basic API + Kafka + Text Persistence (current scope)
- Phase 2: File uploads (2GB support) - future
- Phase 3: External connectors (WhatsApp, Telegram) - future

## 📁 Project Structure

```
chat4alltijolim/
├── api-service/              # REST API microservice
│   ├── src/main/java/
│   │   └── chat4all/api/
│   │       ├── Main.java             # HTTP server entry point
│   │       ├── http/                 # Request handlers
│   │       ├── auth/                 # JWT authentication
│   │       ├── kafka/                # Kafka producer
│   │       ├── cassandra/            # Database queries
│   │       └── validation/           # Input validation
│   ├── src/test/java/                # Tests (TDD)
│   ├── Dockerfile
│   └── pom.xml
│
├── router-worker/            # Kafka consumer + Cassandra writer
│   ├── src/main/java/
│   │   └── chat4all/worker/
│   │       ├── Main.java             # Consumer loop entry point
│   │       ├── kafka/                # Kafka consumer
│   │       ├── cassandra/            # Database persistence
│   │       └── processing/           # Business logic
│   ├── src/test/java/                # Tests (TDD)
│   ├── Dockerfile
│   └── pom.xml
│
├── shared/                   # Shared utilities and models
│   └── src/main/java/
│       └── chat4all/shared/
│           ├── Constants.java        # Configuration constants
│           ├── Logger.java           # Structured logging
│           └── MessageEvent.java     # Kafka event schema
│
├── cassandra-init/
│   └── schema.cql            # Database schema (DDL)
│
├── docs/
│   └── adr/                  # Architecture Decision Records
│       ├── 001-no-frameworks.md
│       ├── 002-cassandra-schema-design.md
│       └── 003-kafka-partitioning-strategy.md
│
├── specs/001-basic-messaging-api/
│   ├── spec.md               # Feature specification
│   ├── plan.md               # Implementation plan
│   └── tasks.md              # Task breakdown (95 tasks)
│
├── docker-compose.yml        # Orchestration
├── pom.xml                   # Parent POM
└── README.md                 # This file
```

## 🧪 Testing Strategy

### Test-First Development (TDD)

1. **Write Test** - Define expected behavior
2. **Run Test** - Verify it fails (RED)
3. **Implement** - Write minimum code to pass
4. **Run Test** - Verify it passes (GREEN)
5. **Refactor** - Clean up while keeping tests green

### Test Types

- **Unit Tests**: Business logic validation (`MessageValidator`, `JwtAuthenticator`)
- **Integration Tests**: API endpoints with embedded Kafka/Cassandra
- **Contract Tests**: Kafka message schema validation
- **End-to-End Tests**: Complete user journeys

### Running Tests

```bash
# Run all tests
mvn test

# Run tests for specific module
mvn test -pl api-service

# Run specific test class
mvn test -Dtest=MessagesEndpointTest
```

## 📊 Horizontal Scalability Demo

### Concept: Stateless Services

```
┌─────────┐    Load     ┌─────────┐
│ Client  │──Balancer──▶│  API 1  │──┐
└─────────┘             ├─────────┤  │
                        │  API 2  │  ├──▶ Kafka ──▶ Worker 1 ──┐
                        ├─────────┤  │              Worker 2 ──┼──▶ Cassandra
                        │  API 3  │──┘              Worker 3 ──┘
                        └─────────┘
```

### Demo: Scale to 3x3

```bash
# Scale API and Worker services
docker-compose up -d --scale api-service=3 --scale router-worker=3

# Verify partition distribution
docker-compose exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group router-worker-group \
  --describe

# Send 1000 messages (load test)
./scripts/load-test.sh

# Observe: Linear throughput increase with instance count
```

## 🔍 Observability

### View Logs

```bash
# API service logs
docker-compose logs -f api-service

# Worker logs
docker-compose logs -f router-worker

# Kafka logs
docker-compose logs -f kafka
```

### Inspect Cassandra

```bash
# Access CQL shell
docker-compose exec cassandra cqlsh

# Query messages
cqlsh> USE chat4all;
cqlsh:chat4all> SELECT * FROM messages LIMIT 10;

# Check conversation
cqlsh:chat4all> SELECT * FROM conversations;
```

### Monitor Kafka

```bash
# List topics
docker-compose exec kafka kafka-topics --list --bootstrap-server localhost:9092

# Consume messages (view events)
docker-compose exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic messages \
  --from-beginning
```

## 🎓 Educational Resources

### Concepts Demonstrated

1. **Event-Driven Architecture (EDA)**
   - Decoupling via Kafka message broker
   - Asynchronous processing (fire-and-forget)
   - Store-and-forward pattern

2. **Kafka Partitioning**
   - Partition key = `conversation_id`
   - Preserves order within partition
   - Enables parallel processing across partitions

3. **Cassandra Data Modeling**
   - Partition key distributes data
   - Clustering key orders data within partition
   - Denormalization (no joins)

4. **Horizontal Scalability**
   - Stateless services (no local state)
   - Load balancing (round-robin)
   - Consumer group coordination

5. **Idempotency**
   - Deduplication by `message_id`
   - At-least-once delivery + dedup = effectively-once

### Architecture Decision Records (ADRs)

- **ADR-001**: [Why No Frameworks](docs/adr/001-no-frameworks.md)
- **ADR-002**: [Cassandra Schema Design](docs/adr/002-cassandra-schema-design.md)
- **ADR-003**: [Kafka Partitioning Strategy](docs/adr/003-kafka-partitioning-strategy.md)

## 🐛 Troubleshooting

### Issue: Services not starting

```bash
# Check service health
docker-compose ps

# Check logs for errors
docker-compose logs cassandra
docker-compose logs kafka

# Restart services
docker-compose restart
```

### Issue: Cassandra not accepting connections

```bash
# Wait for schema initialization (can take 60s)
docker-compose logs cassandra-init

# Verify schema
docker-compose exec cassandra cqlsh -e "DESCRIBE chat4all;"
```

### Issue: JWT authentication failing

```bash
# Verify JWT_SECRET environment variable matches
docker-compose exec api-service env | grep JWT_SECRET

# Check token expiration (default 1 hour)
```

## 🤝 Contributing

This is an educational project. Follow these principles:

1. **Test-First**: Write tests before implementation
2. **Comment Extensively**: Explain WHY, not just WHAT
3. **No Magic**: Keep code transparent and understandable
4. **Document Decisions**: Create ADRs for architecture choices

## 📝 License

MIT License - Educational use. Feel free to use for learning and academic purposes.

## 👥 Authors

- **Tizzo** - Initial implementation and documentation
- Distributed Systems Course - 7th Semester Information Systems

## 📧 Contact

For questions about this educational project:
- Open an issue on GitHub
- Email: [your-email@example.com]

## 🙏 Acknowledgments

- Apache Software Foundation (Kafka, Cassandra)
- Docker Inc.
- Auth0 (java-jwt library)
- Course instructors and colleagues

## 📚 References

- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Cassandra Data Modeling](https://cassandra.apache.org/doc/latest/cassandra/data-modeling/)
- [12-Factor App Methodology](https://12factor.net/)
- [Microservices Patterns](https://microservices.io/patterns/)
- [Building Event-Driven Microservices](https://www.oreilly.com/library/view/building-event-driven-microservices/9781492057888/)

## 📊 Project Status

**Entrega 1 (Semana 3-4): ✅ COMPLETE**

- [x] API básica (POST /v1/messages, GET /v1/conversations/{id}/messages)
- [x] Autenticação JWT
- [x] Integração Kafka (particionamento por conversation_id)
- [x] Persistência Cassandra
- [x] Router Worker (consumer + status tracking)
- [x] Teste de comunicação entre 2 usuários
- [x] Documentação completa
- [x] Docker Compose funcional

**Next Deliverables:**
- Entrega 2: File uploads (2GB support)
- Entrega 3: External connectors (WhatsApp, Telegram)

---

**Chat4All** - Educational Distributed Messaging Platform | v1.0.0 | November 2025
