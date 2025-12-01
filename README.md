# Chat4All - Distributed Messaging Platform

**Educational Project** | 7th Semester Information Systems | Distributed Systems Course

[![Java 17](https://img.shields.io/badge/Java-17-orange)](https://openjdk.org/projects/jdk/17/)
[![Kafka](https://img.shields.io/badge/Kafka-3.6-black)](https://kafka.apache.org/)
[![Cassandra](https://img.shields.io/badge/Cassandra-4.1-blue)](https://cassandra.apache.org/)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue)](https://docs.docker.com/compose/)
[![Redis](https://img.shields.io/badge/Redis-7.2-red)](https://redis.io/)
[![MinIO](https://img.shields.io/badge/MinIO-S3-ff69b4)](https://min.io/)
[![WebSocket](https://img.shields.io/badge/WebSocket-Real--time-green)](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)
[![OpenAPI](https://img.shields.io/badge/OpenAPI-3.0-brightgreen)](https://swagger.io/specification/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> 🎓 **Complete distributed systems implementation** featuring event-driven architecture, real-time notifications, horizontal scalability, and production-grade observability.

---

## 📑 Table of Contents

- [Project Overview](#-project-overview)
- [Architecture](#%EF%B8%8F-architecture)
- [Quick Start](#-quick-start)
- [Interactive CLI](#%EF%B8%8F-interactive-cli-user-friendly-interface)
- [Real-Time Notifications (WebSocket)](#-real-time-notifications-websocket)
- [API Documentation (OpenAPI/Swagger)](#-api-documentation-openapiswagger)
- [Observability & Monitoring](#-observability--monitoring-entrega-3)
- [Development](#-development)
- [Documentation](#-documentation)
- [Testing Strategy](#-testing-strategy)
- [Horizontal Scalability](#-horizontal-scalability-demo)
- [Connector Architecture](#-connector-architecture-entrega-2)
- [Troubleshooting](#-troubleshooting)
- [Project Status](#-project-status)

## 📚 Project Overview

Chat4All is an **educational implementation** of a distributed messaging platform designed to teach 7th semester students core distributed systems concepts:

- **Event-Driven Architecture** (Kafka)
- **Horizontal Scalability** (stateless services)
- **Distributed Databases** (Cassandra)
- **Microservices Pattern**
- **Asynchronous Processing**

### 🚀 Quick Installation

For quick setup on any machine (educational purposes):

```bash
# 1. Clone and enter directory
git clone https://github.com/lucastizzzzzo/chat4alltijolim.git
cd chat4alltijolim

# 2. One-command setup (checks deps, builds, starts everything)
make quickstart
```

See **[INSTALL.md](INSTALL.md)** for detailed installation guide and **[Makefile](Makefile)** for all available commands.

### 🎯 Learning Objectives

1. ✅ Understand **Kafka partitioning** and how it preserves message ordering
2. ✅ Learn **Cassandra query-driven modeling** with partition keys
3. ✅ Implement **stateless REST APIs** for horizontal scalability
4. ✅ Practice **Test-First Development** (TDD)
5. ✅ Experience **Docker Compose** multi-service orchestration
6. ✅ Build **WebSocket real-time notifications** with Redis Pub/Sub
7. ✅ Implement **object storage** with presigned URLs (MinIO/S3)
8. ✅ Apply **microservices patterns** (connectors, circuit breakers)
9. ✅ Configure **observability stack** (Prometheus, Grafana)
10. ✅ Conduct **load testing** and performance analysis

## 🏗️ Architecture

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   Client    │─────▶│ API Service │─────▶│    Kafka    │
│  (curl/app) │◀─────│  (REST API) │      │  (Events)   │
│             │      └──────┬──────┘      └──────┬──────┘
│             │             │                     │
│             │             │ Upload              │ messages
│             │             │                     │ status-updates
│             │             ▼                     ▼
│             │      ┌─────────────┐      ┌─────────────┐
│             │      │    MinIO    │      │   Router    │
│             │      │  (Object    │      │   Worker    │
│             │      │   Storage)  │      └──────┬──────┘
│             │      └─────────────┘             │
│             │             │                    │ Writes +
│             │             │ Presigned          │ Publishes
│             │             │ URLs               │ notifications
│             │             │                    ▼
│             │             │             ┌──────────────┐
│             │             │             │  Connectors  │
│             │             │             ├──────────────┤
│             │             │             │  WhatsApp    │
│             │             │             │  Instagram   │
│             │             │             └──────┬───────┘
│             │             │                    │
│             │             │                    │ status-updates
│             │             ▼                    ▼
│             │      ┌────────────────────────────────┐
│             │      │      Cassandra (NoSQL)         │
│             │      │  • Messages (by conv_id)       │
│             │      │  • Files metadata              │
│             │      │  • Conversations               │
│             │      │  • Status lifecycle            │
│             │      └────────────────────────────────┘
│             │                    ▲
│             │                    │ Message written
│             │                    │
│             │             ┌──────┴──────┐
│             │             │    Redis    │◀──── Router Worker
│             │             │  Pub/Sub    │      publishes notification
│             │             └──────┬──────┘
│             │                    │ notifications:user_id
│             │                    │
│             │             ┌──────▼──────┐
│             │             │  WebSocket  │
│             │             │   Gateway   │
│             │             └──────┬──────┘
│             │                    │
│     WebSocket Connection         │
│     (Real-time Notifications)    │
│◀────────────────────────────────┘
└─────────────┘
```

### Message Flow

**Text Message (Phases 1-6):**
```
Client → API (POST /v1/messages) → Kafka → Router → Cassandra
                                             └─▶ Connectors → Status Updates → Cassandra
```

**File Message (Phases 7-8):**
```
1. Upload:    Client → API (POST /v1/files) → MinIO (streaming) → metadata → Cassandra
2. Send:      Client → API (POST /v1/messages with file_id) → Kafka → Router
3. Route:     Router → whatsapp-outbound or instagram-outbound → Connector
4. Status:    Connector → status-updates → Router → Cassandra (DELIVERED, READ)
5. Download:  Client → API (GET /v1/files/{id}/download) → Presigned URL → MinIO (direct)
```

### Key Design Decisions

- **No Frameworks**: Using JDK's built-in `HttpServer` instead of Spring Boot (educational transparency)
- **Minimal Dependencies**: Only 3 external libraries (Kafka, Cassandra, JWT) + MinIO client
- **No ORM**: Direct CQL queries to understand NoSQL patterns
- **Test-First**: All tests written before implementation
- **Object Storage**: MinIO for scalable file storage (80% cost savings vs database BLOBs)
- **Microservices**: Separate connectors for WhatsApp/Instagram (independent scaling)
- **Presigned URLs**: Secure, time-limited download links (direct client-to-storage, no API bottleneck)

## 🚀 Quick Start

### Prerequisites

- **Docker** & **Docker Compose** (20.10+)
- **Java 17** (OpenJDK) - for local development
- **Maven 3.8+** - for building
- **curl** or **httpie** - for testing APIs
- **Python 3.8+** - for WebSocket notification tests

### 1. Clone and Build

```bash
# Clone repository
git clone https://github.com/your-username/chat4alltijolim.git
cd chat4alltijolim

# Build all modules (REQUIRED before docker-compose)
./build.sh
```

**Important**: The `build.sh` script compiles all modules and creates the JARs needed by Docker. This is required on fresh clones because `target/` directories are gitignored. First build may take 2-3 minutes to download dependencies.

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
- WebSocket Gateway: `ws://localhost:8085` (real-time notifications)
- MinIO Console: `http://localhost:9001` (web UI, credentials: minioadmin/minioadmin)
- MinIO API: `http://localhost:9000` (S3-compatible API)
- Redis: `localhost:6379` (Pub/Sub for notifications)
- Cassandra: `localhost:9042`
- Kafka: `localhost:9092` (internal), `localhost:29092` (external)
- Prometheus: `http://localhost:9090` (metrics)
- Grafana: `http://localhost:3000` (dashboards, admin/admin)

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

# Alternatively, use the interactive CLI (more user-friendly!)
./cli/chat4all-cli.py
# See cli/README.md for full documentation

# 2. Send a text message
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

# 4. Retrieve messages
curl -s -X GET "http://localhost:8082/v1/conversations/conv_demo_123/messages?limit=50&offset=0" \
  -H "Authorization: Bearer $TOKEN" | jq

# 5. Upload a file (Entrega 2)
FILE_RESPONSE=$(curl -s -X POST http://localhost:8082/v1/files \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/etc/hosts" \
  -F "conversation_id=conv_demo_123")

echo "File uploaded: $FILE_RESPONSE"

FILE_ID=$(echo $FILE_RESPONSE | jq -r '.file_id')

# 6. Send message with file attachment to WhatsApp
MESSAGE_WITH_FILE=$(curl -s -X POST http://localhost:8082/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"conversation_id\": \"conv_demo_123\",
    \"sender_id\": \"user_a\",
    \"recipient_id\": \"whatsapp:+5511999998888\",
    \"content\": \"Check out this file!\",
    \"file_id\": \"$FILE_ID\"
  }")

echo "Message with file sent: $MESSAGE_WITH_FILE"

# 7. Wait for connector to process
sleep 5

# 8. Get presigned download URL (valid for 1 hour)
curl -s -X GET "http://localhost:8082/v1/files/$FILE_ID/download" \
  -H "Authorization: Bearer $TOKEN" | jq

# Expected output:
# {
#   "download_url": "http://minio:9000/chat4all-files/conv_demo_123/file_xyz.jpg?X-Amz-Signature=...",
#   "expires_in": 3600,
#   "filename": "hosts"
# }

# Or use the test scripts:
./scripts/test-end-to-end.sh          # Basic text messaging
./scripts/test-file-upload.sh         # Upload 1KB, 1MB, 10MB files
./scripts/test-file-download.sh       # Test presigned URLs
./scripts/test-file-connectors-e2e.sh # Complete file sharing workflow
./scripts/demo-file-sharing.sh        # Interactive demo (Entrega 2)

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

## 🖥️ Interactive CLI (User-Friendly Interface)

Instead of using `curl` directly, you can use our **interactive CLI** for a better user experience:

### Quick Setup

```bash
# Install CLI dependencies
./cli/setup.sh

# Run interactive CLI
./cli/chat4all-cli.py

# Or set custom API URL
export CHAT4ALL_API_URL=http://localhost:8080
./cli/chat4all-cli.py
```

### CLI Features

The CLI provides a menu-driven interface with:

```
Menu Principal:
  1. Autenticar (login)              → Get JWT token
  2. Enviar mensagem                 → Send text message
  3. Enviar mensagem com arquivo     → Send message with file
  4. Listar mensagens                → List conversation messages
  5. Marcar mensagem como lida       → Mark as READ
  6. Upload de arquivo               → Upload file to MinIO
  7. Download de arquivo             → Download via presigned URL
  8. Status da infraestrutura        → Check services health
  9. Limpar tela
  0. Sair
```

**Advantages over curl:**
- ✅ No need to memorize API endpoints
- ✅ Automatic token management
- ✅ Input validation
- ✅ Colored output for better readability
- ✅ Formatted timestamps and status
- ✅ Progress indicators for uploads/downloads
- ✅ Error messages in plain Portuguese

**Example Session:**

```
./cli/chat4all-cli.py

👤 Logado como: user_a

Escolha uma opção: 2

📨 Enviar Mensagem
Conversation ID: conv_demo_123
Recipient ID: whatsapp:+5511999998888
Mensagem: Olá! Como vai?
✓ Mensagem enviada com sucesso!
  Message ID: msg_abc123...
  Status: SENT
```

See **[cli/README.md](cli/README.md)** for complete CLI documentation.

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

## 📊 Observability & Monitoring (Entrega 3)

### Access Dashboards

```bash
# Prometheus (metrics database)
open http://localhost:9090

# Grafana (visualization)
open http://localhost:3000
# Credentials: admin / admin
```

### Pre-configured Dashboards

1. **System Overview** - All services health, throughput, errors
2. **API Service** - HTTP requests, latency P95/P99, validation errors
3. **Router Worker** - Kafka consumer lag, processing time, routing
4. **Connectors** - Message delivery, API duration, circuit breakers

### Key Metrics

**Prometheus Queries:**
```promql
# Messages per minute
rate(messages_accepted_total[1m]) * 60

# P95 HTTP latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Error rate percentage
(sum(rate(messages_rejected_total[5m])) / sum(rate(http_requests_total[5m]))) * 100

# Kafka consumer lag
max(kafka_consumer_lag) by (topic, partition)
```

### Load Testing

**Run baseline test (20 VUs, 5 min):**
```bash
k6 run scripts/load-tests/02-baseline.js
```

**Expected results:**
- Throughput: > 500 msg/min
- P95 Latency: < 200ms
- Error Rate: < 0.5%

**Run spike test (store-and-forward validation):**
```bash
k6 run scripts/load-tests/03-spike.js
```

**See results:**
- `results/SCALING_RESULTS.md` - Scalability analysis
- `results/FAULT_TOLERANCE_RESULTS.md` - Failover testing
- `RELATORIO_TECNICO_ENTREGA3.md` - Complete technical report

### Performance Metrics (Validated)

| Metric | Target | Achieved | Status |
|--------|--------|----------|--------|
| Throughput | 500-600 msg/min | **753 msg/min** | ✅ 126% |
| P95 Latency | < 200ms | **2.39ms** | ✅ 1.2% |
| P99 Latency | < 500ms | **4.85ms** | ✅ 1.0% |
| Error Rate | < 0.5% | **0.00%** | ✅ 0% |
| Uptime (Failover) | > 99% | **100%** | ✅ |

## 🔔 Real-Time Notifications (WebSocket)

### What are WebSocket Notifications?

WebSocket notifications provide **real-time push updates** to connected clients when new messages arrive. This eliminates the need for polling and enables instant messaging experiences.

### Architecture

```
Message Flow:
1. Client sends message via REST API
2. API → Kafka → Router Worker → Cassandra (persistence)
3. Router Worker publishes to Redis: PUBLISH notifications:user_123
4. WebSocket Gateway subscribes to Redis: PSUBSCRIBE notifications:*
5. Gateway pushes notification to connected WebSocket client
6. Client receives notification in < 150ms

Technology Stack:
- WebSocket Server: Java-WebSocket 1.5.3 (Java 11)
- Pub/Sub: Redis 7.2 (in-memory, ultra-low latency)
- Authentication: JWT tokens (same as REST API)
- Protocol: ws:// (ws://localhost:8085)
```

### How to Connect

**1. Get JWT Token (same as REST API):**
```bash
TOKEN=$(curl -s -X POST http://localhost:8082/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"password"}' \
  | jq -r '.access_token')
```

**2. Connect via WebSocket with token:**
```javascript
// JavaScript example
const ws = new WebSocket('ws://localhost:8085?token=' + token);

ws.onopen = () => console.log('Connected to WebSocket Gateway');

ws.onmessage = (event) => {
  const notification = JSON.parse(event.data);
  console.log('New message:', notification);
  // {
  //   "type": "NEW_MESSAGE",
  //   "message_id": "msg_abc123",
  //   "conversation_id": "conv_demo_123",
  //   "sender_id": "user_bob",
  //   "content": "Hello!",
  //   "timestamp": 1701234567890
  // }
};

ws.onerror = (error) => console.error('WebSocket error:', error);
ws.onclose = () => console.log('Disconnected');
```

**3. Python example (using websockets library):**
```python
import asyncio
import websockets
import json

async def listen_notifications(token):
    uri = f"ws://localhost:8085?token={token}"
    async with websockets.connect(uri) as websocket:
        print("Connected to WebSocket Gateway")
        while True:
            notification = await websocket.recv()
            data = json.loads(notification)
            print(f"New message: {data['content']}")

# Run
asyncio.run(listen_notifications(your_token))
```

### Testing WebSocket Notifications

**Automated end-to-end test:**
```bash
# Comprehensive test: Creates users, connects WebSocket, sends 3 messages
python3 scripts/test-websocket-notifications.py

# Expected output:
# ✓ Created user alice_...
# ✓ Created user bob_...
# ✓ Authenticated alice
# ✓ Authenticated bob
# ✓ Created conversation conv_...
# ✓ WebSocket connected: connection-id
# 🔔 NOTIFICATION RECEIVED (after 2.119s)
# 🔔 NOTIFICATION RECEIVED (after 3.126s)
# 🔔 NOTIFICATION RECEIVED (after 4.134s)
# ✅ TEST PASSED - All notifications received!
```

**Manual test with two terminals:**
```bash
# Terminal 1: Connect WebSocket (Alice listening)
python3 -c "
import asyncio, websockets, json, requests
token = requests.post('http://localhost:8082/auth/token',
                     json={'username':'alice','password':'password'}).json()['access_token']
async def listen():
    async with websockets.connect(f'ws://localhost:8085?token={token}') as ws:
        print('Listening for notifications...')
        while True:
            msg = await ws.recv()
            print(f'Received: {msg}')
asyncio.run(listen())
"

# Terminal 2: Send message (Bob sending to Alice)
TOKEN_BOB=$(curl -s -X POST http://localhost:8082/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username":"bob","password":"password"}' \
  | jq -r '.access_token')

curl -X POST http://localhost:8082/v1/messages \
  -H "Authorization: Bearer $TOKEN_BOB" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "conv_test_123",
    "sender_id": "user_bob",
    "recipient_id": "user_alice",
    "content": "Hello Alice, testing WebSocket!"
  }'

# Terminal 1 should receive notification within 150ms
```

### Notification Format

```json
{
  "type": "NEW_MESSAGE",
  "message_id": "msg_abc123xyz",
  "conversation_id": "conv_demo_123",
  "sender_id": "user_bob",
  "recipient_id": "user_alice",
  "content": "Hello from WebSocket!",
  "timestamp": 1701234567890,
  "file_id": null
}
```

### Performance

- **Average Latency**: ~140ms (end-to-end: API → Kafka → Router → Redis → WebSocket)
- **Success Rate**: 100% (validated with 6 consecutive test notifications)
- **Connection Limit**: Unlimited in educational version (production: configure backpressure)
- **Reconnection**: Manual (client responsibility in current implementation)

### Troubleshooting

**WebSocket connection fails:**
```bash
# Check WebSocket Gateway is running
docker-compose ps websocket-gateway

# Check logs
docker-compose logs websocket-gateway

# Verify Redis is healthy
docker-compose exec redis redis-cli PING
# Expected: PONG
```

**Not receiving notifications:**
```bash
# Check Router Worker is publishing to Redis
docker-compose logs router-worker | grep "Redis notification publisher"
# Expected: ✓ Redis publisher initialized: redis:6379

# Test Redis Pub/Sub manually
docker-compose exec redis redis-cli
> PSUBSCRIBE notifications:*
# Send a message via API, should see: message notifications:user_alice
```

**JWT authentication error:**
```bash
# Verify token is valid
curl http://localhost:8082/v1/conversations/test/messages \
  -H "Authorization: Bearer $TOKEN"
# If this works, token is valid for WebSocket too
```

## 📚 API Documentation (OpenAPI/Swagger)

Complete API documentation is available in **OpenAPI 3.0** format.

### View Documentation

**Option 1: Swagger UI (Recommended)**
```bash
# Using Docker
docker run -p 8080:8080 \
  -e SWAGGER_JSON=/openapi.yaml \
  -v $(pwd)/openapi.yaml:/openapi.yaml \
  swaggerapi/swagger-ui

# Open browser
open http://localhost:8080
```

**Option 2: Swagger Editor (Online)**
```bash
# Copy content of openapi.yaml
cat openapi.yaml

# Paste into Swagger Editor
open https://editor.swagger.io/
```

**Option 3: VS Code Extension**
```bash
# Install extension
code --install-extension 42Crunch.vscode-openapi

# Open openapi.yaml in VS Code
code openapi.yaml
# Right-click → "OpenAPI: Preview"
```

### API Overview

**Authentication:**
- `POST /auth/register` - Register new user
- `POST /auth/token` - Get JWT access token

**Messages:**
- `POST /v1/messages` - Send message (text or with file)
- `GET /v1/conversations/{id}/messages` - Retrieve messages (paginated)
- `POST /v1/messages/{id}/read` - Mark message as read

**Files:**
- `POST /v1/files` - Upload file (multipart, up to 2GB)
- `GET /v1/files/{id}/download` - Get presigned download URL

**Health:**
- `GET /health` - Service health check

### Quick Examples

**1. Register and authenticate:**
```bash
# Register
curl -X POST http://localhost:8082/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"mypassword"}'

# Get token
TOKEN=$(curl -s -X POST http://localhost:8082/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"mypassword"}' \
  | jq -r '.access_token')
```

**2. Send message:**
```bash
curl -X POST http://localhost:8082/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "conv_123",
    "sender_id": "user_alice",
    "content": "Hello World!"
  }'
```

**3. Upload and send file:**
```bash
# Upload file
FILE_RESPONSE=$(curl -s -X POST http://localhost:8082/v1/files \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@document.pdf" \
  -F "conversation_id=conv_123")

FILE_ID=$(echo $FILE_RESPONSE | jq -r '.file_id')

# Send message with file
curl -X POST http://localhost:8082/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"conversation_id\": \"conv_123\",
    \"sender_id\": \"user_alice\",
    \"content\": \"Check out this document\",
    \"file_id\": \"$FILE_ID\"
  }"
```

**4. Get messages:**
```bash
curl -X GET "http://localhost:8082/v1/conversations/conv_123/messages?limit=50&offset=0" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**5. Download file:**
```bash
# Get presigned URL
DOWNLOAD_URL=$(curl -s -X GET "http://localhost:8082/v1/files/$FILE_ID/download" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.download_url')

# Download file
curl -o downloaded_file.pdf "$DOWNLOAD_URL"
```

### Schema Details

All request/response schemas are documented in `openapi.yaml` with:
- Required/optional fields
- Data types and formats
- Validation rules (min/max length, patterns)
- Example values
- Error responses

**Key Schemas:**
- `SendMessageRequest` - Message submission
- `Message` - Message object with status lifecycle
- `FileUploadResponse` - File metadata with checksum
- `FileDownloadResponse` - Presigned URL with expiration
- `Error` - RFC 7807 Problem Details format

See `openapi.yaml` for complete specifications.

## 📊 Observability & Monitoring (Entrega 3)

### Access Dashboards

```bash
# Prometheus (metrics database)
open http://localhost:9090

# Grafana (visualization)
open http://localhost:3000
# Credentials: admin / admin
```

### Pre-configured Dashboards

1. **System Overview** - All services health, throughput, errors
2. **API Service** - HTTP requests, latency P95/P99, validation errors
3. **Router Worker** - Kafka consumer lag, processing time, routing
4. **Connectors** - Message delivery, API duration, circuit breakers

### Key Metrics

**Prometheus Queries:**
```promql
# Messages per minute
rate(messages_accepted_total[1m]) * 60

# P95 HTTP latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Error rate percentage
(sum(rate(messages_rejected_total[5m])) / sum(rate(http_requests_total[5m]))) * 100

# Kafka consumer lag
max(kafka_consumer_lag) by (topic, partition)
```

### Load Testing

**Run baseline test (20 VUs, 5 min):**
```bash
k6 run scripts/load-tests/02-baseline.js
```

**Expected results:**
- Throughput: > 500 msg/min
- P95 Latency: < 200ms
- Error Rate: < 0.5%

**Run spike test (store-and-forward validation):**
```bash
k6 run scripts/load-tests/03-spike.js
```

**See results:**
- `results/SCALING_RESULTS.md` - Scalability analysis
- `results/FAULT_TOLERANCE_RESULTS.md` - Failover testing
- `RELATORIO_TECNICO_ENTREGA3.md` - Complete technical report

### Performance Metrics (Validated)

| Metric | Target | Achieved | Status |
|--------|--------|----------|--------|
| Throughput | 500-600 msg/min | **753 msg/min** | ✅ 126% |
| P95 Latency | < 200ms | **2.39ms** | ✅ 1.2% |
| P99 Latency | < 500ms | **4.85ms** | ✅ 1.0% |
| Error Rate | < 0.5% | **0.00%** | ✅ 0% |
| Uptime (Failover) | > 99% | **100%** | ✅ |

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

## 📖 Documentation

### Core Documentation

- **[README.md](README.md)** - This file (Quick start, examples, API overview)
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Complete architecture documentation
- **[openapi.yaml](openapi.yaml)** - OpenAPI 3.0 API specification (Swagger)

### Technical Reports

- **[RELATORIO_TECNICO_ENTREGA3.md](RELATORIO_TECNICO_ENTREGA3.md)** - Entrega 3 technical report
- **[SUMARIO_EXECUTIVO.md](SUMARIO_EXECUTIVO.md)** - Executive summary

### Guides & Manuals

- **[CLI README](cli/README.md)** - Interactive CLI user guide
- **[GUIA_TESTES_ENTREGA3.md](GUIA_TESTES_ENTREGA3.md)** - Testing guide for Entrega 3
- **[MANUAL_TESTS.md](MANUAL_TESTS.md)** - Manual testing procedures

### Architecture Decision Records (ADRs)

- **[ADR-001](docs/adr/001-no-frameworks.md)** - Why No Frameworks
- **[ADR-002](docs/adr/002-object-storage-choice.md)** - MinIO vs Database BLOBs
- **[ADR-003](docs/adr/003-connector-architecture.md)** - Microservices vs Monolithic
- **[ADR-004](docs/adr/004-presigned-urls.md)** - Presigned URLs for Downloads
- **[ADR-005](docs/adr/005-circuit-breaker.md)** - Circuit Breaker Pattern
- **[ADR-006](docs/adr/006-observability-strategy.md)** - Observability Strategy

### Test Results

- **[results/SCALING_RESULTS.md](results/SCALING_RESULTS.md)** - Scalability analysis
- **[results/FAULT_TOLERANCE_RESULTS.md](results/FAULT_TOLERANCE_RESULTS.md)** - Failover testing
- **[TEST_SUCCESS_REPORT.md](TEST_SUCCESS_REPORT.md)** - Test execution report

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

### ✅ Phase 7: File Upload/Download (Complete - Entrega 2!)
- [x] POST /v1/files endpoint (multipart/form-data, up to 2GB)
- [x] FileUploadHandler with streaming (memory-efficient, handles large files)
- [x] MinIO integration (S3-compatible object storage)
- [x] Cassandra files table (metadata: file_id, conversation_id, storage_path, size, checksum)
- [x] GET /v1/files/{id}/download (presigned URLs, 1-hour expiry)
- [x] SHA-256 checksums for integrity validation
- [x] Test scripts: test-file-upload.sh, test-file-download.sh

### ✅ Phase 8: Multi-Platform Connectors (Complete - Entrega 2!)
- [x] Connector microservices architecture (WhatsApp, Instagram)
- [x] Kafka routing: recipient_id prefix → topic mapping (whatsapp:xxx → whatsapp-outbound)
- [x] OutboundMessageConsumer in each connector
- [x] StatusUpdateProducer for delivery confirmations
- [x] Simulated delivery (educational: no real API integrations)
- [x] Independent scaling and deployment per platform
- [x] Test script: test-whatsapp-connector.sh

### ✅ Phase 9: Message Status Lifecycle (Complete - Entrega 2!)
- [x] MessageStatus enum: SENT → DELIVERED → READ (state machine validation)
- [x] StatusUpdateConsumer in Router Worker (processes status-updates topic)
- [x] POST /v1/messages/{id}/read endpoint (mark message as read)
- [x] Cassandra schema updates: delivered_at, read_at timestamps
- [x] Two-step query pattern: SELECT by message_id → UPDATE by full primary key
- [x] Test script: test-status-lifecycle.sh

### ✅ Phase 10: Integration Testing (Complete - Entrega 2!)
- [x] test-file-connectors-e2e.sh: Comprehensive E2E test (10 steps, 7 integration points)
- [x] demo-file-sharing.sh: Interactive demonstration with colored output
- [x] Validates: Auth → Upload → Send to WhatsApp → Send to Instagram → Mark READ → Download
- [x] **Test Result**: 100% PASS - All systems integrated successfully!

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

### 📋 Entrega 2 Checklist (NEW - Current Focus!)

- [x] **File Upload** - POST /v1/files (multipart, 2GB support, streaming)
- [x] **Object Storage** - MinIO integration (S3-compatible, scalable)
- [x] **File Download** - Presigned URLs (secure, time-limited, direct downloads)
- [x] **Multi-Platform Routing** - recipient_id prefix → Kafka topic mapping
- [x] **WhatsApp Connector** - Microservice consuming whatsapp-outbound topic
- [x] **Instagram Connector** - Microservice consuming instagram-outbound topic
- [x] **Status Lifecycle** - SENT → DELIVERED → READ state machine
- [x] **Status Updates** - Connectors publish to status-updates topic
- [x] **Mark as Read** - POST /v1/messages/{id}/read endpoint
- [x] **Integration Tests** - test-file-connectors-e2e.sh (100% PASS)
- [x] **Documentation** - ADRs 002-004, comprehensive code comments

### 🎯 Next Steps (Entrega 3 - Future)

See [`specs/003-observability/`](specs/003-observability/) for Phase 11-12:
- [ ] Phase 11: Technical Report (deliverable)
- [ ] Phase 12: Performance testing (100MB, 500MB, 1GB uploads)

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
│   │       │   ├── MessagesHandler.java
│   │       │   ├── ConversationsHandler.java
│   │       │   ├── FileUploadHandler.java (streaming, up to 2GB)
│   │       │   ├── FileDownloadHandler.java (presigned URLs)
│   │       │   └── MessageStatusHandler.java (mark as read)
│   │       ├── auth/                 # JWT authentication
│   │       ├── kafka/                # Kafka producer
│   │       ├── cassandra/            # Database queries
│   │       ├── storage/              # MinIO integration
│   │       └── validation/           # Input validation
│   ├── src/test/java/                # Tests (TDD)
│   ├── Dockerfile
│   └── pom.xml
│
├── router-worker/            # Kafka consumer + Cassandra writer
│   ├── src/main/java/
│   │   └── chat4all/worker/
│   │       ├── Main.java             # Consumer loop entry point
│   │       ├── kafka/                # Kafka consumer + routing logic
│   │       │   ├── KafkaMessageConsumer.java
│   │       │   ├── MessageRouter.java (recipient_id → topic)
│   │       │   └── StatusUpdateConsumer.java
│   │       ├── cassandra/            # Database persistence
│   │       └── processing/           # Business logic
│   │           └── MessageProcessor.java (status state machine)
│   ├── src/test/java/                # Tests (TDD)
│   ├── Dockerfile
│   └── pom.xml
│
├── connector-whatsapp/       # WhatsApp connector microservice (NEW)
│   ├── src/main/java/
│   │   └── chat4all/connector/
│   │       ├── Main.java
│   │       ├── OutboundMessageConsumer.java (whatsapp-outbound topic)
│   │       └── StatusUpdateProducer.java (publishes DELIVERED status)
│   ├── Dockerfile
│   └── pom.xml
│
├── connector-instagram/      # Instagram connector microservice (NEW)
│   ├── src/main/java/
│   │   └── chat4all/connector/
│   │       ├── Main.java
│   │       ├── OutboundMessageConsumer.java (instagram-outbound topic)
│   │       └── StatusUpdateProducer.java
│   ├── Dockerfile
│   └── pom.xml
│
├── shared/                   # Shared utilities and models
│   └── src/main/java/
│       └── chat4all/shared/
│           ├── Constants.java        # Configuration constants
│           ├── Logger.java           # Structured logging
│           ├── MessageEvent.java     # Kafka event schema
│           └── MessageStatus.java    # Status enum (SENT/DELIVERED/READ)
│
├── cassandra-init/
│   └── schema.cql            # Database schema (messages, files, conversations)
│
├── docs/
│   └── adr/                  # Architecture Decision Records
│       ├── 001-no-frameworks.md
│       ├── 002-object-storage-choice.md (NEW - MinIO rationale)
│       ├── 003-connector-architecture.md (NEW - microservices pattern)
│       └── 004-presigned-urls.md (NEW - security model)
│
├── specs/
│   ├── 001-basic-messaging-api/
│   │   ├── spec.md               # Feature specification
│   │   ├── plan.md               # Implementation plan
│   │   └── tasks.md              # Task breakdown (95 tasks - COMPLETE)
│   └── 002-file-storage-connectors/
│       ├── spec.md               # File upload + connectors spec
│       ├── plan.md               # Technical approach
│       └── tasks.md              # Task breakdown (112 tasks - 81/112 complete)
│
├── scripts/
│   ├── test-end-to-end.sh        # Basic messaging E2E
│   ├── test-file-upload.sh       # Upload 1KB, 1MB, 10MB files
│   ├── test-file-download.sh     # Presigned URLs
│   ├── test-file-connectors-e2e.sh  # Complete integration test (NEW)
│   ├── demo-file-sharing.sh      # Interactive demo (NEW)
│   └── test-status-lifecycle.sh  # Status transitions (NEW)
│
├── docker-compose.yml        # Orchestration (10 services)
├── pom.xml                   # Parent POM
└── README.md                 # This file
```

**Service Count**: 11 Docker containers
- 1x API Service
- 1x Router Worker
- 2x Connectors (WhatsApp, Instagram)
- 1x WebSocket Gateway (real-time notifications)
- 1x MinIO (object storage)
- 1x Redis (Pub/Sub)
- 1x Cassandra
- 1x Kafka
- 1x Zookeeper
- 1x Prometheus (metrics)
- 1x Grafana (visualization)

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
- **ADR-002**: [Object Storage Choice (MinIO vs Database BLOBs)](docs/adr/002-object-storage-choice.md)
- **ADR-003**: [Connector Architecture (Microservices vs Monolithic)](docs/adr/003-connector-architecture.md)
- **ADR-004**: [Presigned URLs for Secure Downloads](docs/adr/004-presigned-urls.md)

## 🔌 Connector Architecture (Entrega 2)

### What are Connectors?

Connectors are **independent microservices** that translate Chat4All's internal message format to external platform APIs (WhatsApp, Instagram, Telegram, etc.). Each connector runs in its own Docker container and communicates via Kafka topics.

### Why Separate Microservices?

**Isolation**: One connector failure doesn't affect others  
**Scaling**: Scale WhatsApp connector independently if it has more traffic  
**Velocity**: Deploy Instagram updates without touching WhatsApp code  
**Monitoring**: Platform-specific metrics and health checks  

See [ADR-003](docs/adr/003-connector-architecture.md) for full rationale (comparison with monolithic and plugin approaches).

### Routing Logic: recipient_id Prefix

Messages are routed to connectors based on the **recipient_id prefix**:

```java
// Router Worker extracts prefix and maps to Kafka topic
String recipientId = message.getRecipientId();  // e.g., "whatsapp:+5511999998888"

String platform = recipientId.split(":")[0];    // Extract "whatsapp"
String kafkaTopic = platform + "-outbound";     // Result: "whatsapp-outbound"

kafkaProducer.send(kafkaTopic, message);
```

**Supported Platforms:**

| recipient_id Format | Kafka Topic | Connector Service |
|---------------------|-------------|-------------------|
| `whatsapp:+5511999998888` | `whatsapp-outbound` | `connector-whatsapp` |
| `instagram:@john_doe` | `instagram-outbound` | `connector-instagram` |
| `telegram:123456789` | `telegram-outbound` | `connector-telegram` (future) |

### Message Flow (with Connectors)

```
1. Client sends message with recipient_id="whatsapp:+5511999998888"
   ↓
2. API Service → Kafka (messages topic)
   ↓
3. Router Worker extracts prefix → routes to whatsapp-outbound topic
   ↓
4. WhatsApp Connector consumes message → simulates delivery
   ↓
5. Connector publishes to status-updates topic: {message_id, status: DELIVERED}
   ↓
6. Router Worker updates Cassandra: SET status = 'DELIVERED', delivered_at = now()
   ↓
7. Client queries GET /v1/conversations/{id}/messages → sees status: DELIVERED
```

### Adding a New Connector

See [docs/CONNECTOR_PATTERN.md](docs/CONNECTOR_PATTERN.md) (coming soon) for step-by-step guide.

**Quick Summary:**
1. Create new Maven module: `connector-{platform}/`
2. Implement `OutboundMessageConsumer` (Kafka consumer for `{platform}-outbound` topic)
3. Implement `StatusUpdateProducer` (publish to `status-updates` topic)
4. Add Dockerfile and service to `docker-compose.yml`
5. Update Router Worker routing logic (if needed)

**Example Connector Interface:**
```java
public interface PlatformConnector {
    void sendMessage(String platformUserId, String content, String fileUrl);
    void reportStatus(String messageId, MessageStatus status);
}
```

### Current Connectors

- **WhatsApp Connector** (`connector-whatsapp/`) - Simulated delivery (educational)
- **Instagram Connector** (`connector-instagram/`) - Simulated delivery (educational)

**Note**: Current implementation simulates delivery for educational purposes. Production deployment would integrate with real platform APIs (WhatsApp Business API, Instagram Graph API).

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

**Entrega 3 (Semana 9-11): ✅ COMPLETE**

- [x] Observability stack (Prometheus + Grafana)
- [x] 4 auto-provisioned Grafana dashboards
- [x] Metrics instrumentation (API, Router, Connectors)
- [x] Load testing with k6 (baseline, spike, file upload)
- [x] Performance validation (753 msg/min, P95 2.39ms, 0% errors)
- [x] Horizontal scalability tests (1 vs 2 workers)
- [x] Fault tolerance validation (worker failover, store-and-forward)
- [x] Technical report (RELATORIO_TECNICO_ENTREGA3.md)
- [x] ADRs 005-006 (Circuit Breakers, Observability Strategy)

**Entrega 2 (Semana 7-8): ✅ COMPLETE**

- [x] File upload/download (MinIO, presigned URLs, 2GB support)
- [x] Multi-platform connectors (WhatsApp, Instagram microservices)
- [x] Message routing by recipient_id prefix
- [x] Status lifecycle (SENT → DELIVERED → READ)
- [x] Integration tests (test-file-connectors-e2e.sh - 100% PASS)
- [x] Documentation (ADRs 002-004, comprehensive comments)

**Entrega 1 (Semana 3-4): ✅ COMPLETE**

- [x] API básica (POST /v1/messages, GET /v1/conversations/{id}/messages)
- [x] Autenticação JWT
- [x] Integração Kafka (particionamento por conversation_id)
- [x] Persistência Cassandra
- [x] Router Worker (consumer + status tracking)
- [x] Teste de comunicação entre 2 usuários
- [x] Documentação completa
- [x] Docker Compose funcional

---

**Chat4All** - Educational Distributed Messaging Platform | v1.0.0 | November 2025
