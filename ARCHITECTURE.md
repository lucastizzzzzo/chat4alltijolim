# Chat4All - Architecture Documentation

## 🏗️ System Architecture

### High-Level Overview

```
┌──────────┐         ┌──────────────┐        ┌──────────┐
│  Client  │────────▶│  API Service │───────▶│  Kafka   │
│  (REST)  │◀────────│  (Port 8082) │        │ (Events) │
└──────────┘         └──────┬───────┘        └────┬─────┘
     │                      │                      │
     │ WebSocket            │ MinIO                │ messages
     │                      ▼                      │ status-updates
     │               ┌─────────────┐              │
     ▼               │    MinIO    │              ▼
┌──────────┐        │  (S3 API)   │      ┌──────────────┐
│WebSocket │        └─────────────┘      │    Router    │
│ Gateway  │               │              │    Worker    │
│(Port8085)│               │              └──────┬───────┘
└────┬─────┘               │                     │
     │                     │                     ├──▶ Cassandra
     │                     │                     │    (Persistence)
     │                     │                     │
     │ Redis Pub/Sub       │                     ├──▶ whatsapp-outbound
     │                     │                     │    instagram-outbound
     └◀────────────────────┴─────────────────────┘
           (Notifications)
```

## 🔄 Message Flow

### 1. Text Message Flow

```
POST /v1/messages
      │
      ▼
   Validation ────(invalid)───▶ 400 Error
      │
      │ (valid)
      ▼
  Kafka Producer ───▶ messages topic (3 partitions)
      │                partition_key: conversation_id
      │
      ▼
   202 Accepted ───▶ Client
      
      
Router Worker (Consumer)
      │
      ├──▶ Parse recipient_id prefix
      │
      ├──▶ Route to platform topic
      │    • whatsapp:+55... → whatsapp-outbound
      │    • instagram:@... → instagram-outbound
      │
      └──▶ Persist to Cassandra
           └──▶ Publish notification to Redis
                └──▶ WebSocket Gateway → Client (real-time)
```

### 2. File Sharing Flow

```
POST /v1/files (multipart)
      │
      ▼
  Stream to MinIO ───▶ S3 Bucket: chat4all-files
      │                Object: {conversation_id}/{file_id}
      │
      ▼
  Save metadata ───▶ Cassandra (files table)
      │             • file_id, filename, size
      │             • storage_path, checksum (SHA-256)
      │
      ▼
  201 Created ───▶ {file_id, file_url}


POST /v1/messages (with file_id)
      │
      ▼
   Normal message flow (see above)
      │
      ▼
   Connector receives message with file_url
      │
      ▼
   Platform sends file (WhatsApp/Instagram API)


GET /v1/files/{id}/download
      │
      ▼
   Generate presigned URL ───▶ MinIO
      │                        Valid for 1 hour
      │
      ▼
   Return URL ───▶ Client
      │
      │ (Client downloads directly from MinIO)
      ▼
   Direct download (no API bottleneck)
```

## 🗄️ Data Models

### Cassandra Schema

#### messages table
```cql
CREATE TABLE messages (
    conversation_id text,
    timestamp bigint,
    message_id text,
    sender_id text,
    recipient_id text,
    content text,
    file_id text,
    status text,  -- SENT, DELIVERED, READ
    delivered_at bigint,
    read_at bigint,
    PRIMARY KEY (conversation_id, timestamp, message_id)
) WITH CLUSTERING ORDER BY (timestamp DESC);
```

**Query Pattern**: `WHERE conversation_id = ? ORDER BY timestamp DESC LIMIT ?`

#### files table
```cql
CREATE TABLE files (
    file_id text PRIMARY KEY,
    conversation_id text,
    filename text,
    content_type text,
    size_bytes bigint,
    storage_path text,
    checksum text,
    uploaded_at bigint,
    uploaded_by text
);
```

#### users table
```cql
CREATE TABLE users (
    user_id text PRIMARY KEY,
    username text,
    password_hash text,
    created_at bigint
);

CREATE INDEX ON users (username);
```

### Kafka Topics

| Topic | Partitions | Key | Purpose |
|-------|-----------|-----|---------|
| `messages` | 3 | `conversation_id` | New messages from API |
| `whatsapp-outbound` | 2 | `recipient_id` | Messages to WhatsApp |
| `instagram-outbound` | 2 | `recipient_id` | Messages to Instagram |
| `status-updates` | 1 | `message_id` | Delivery/read receipts |

## 🎯 Design Patterns

### 1. Event-Driven Architecture (EDA)

**Why**: Decouples services, enables async processing, improves scalability

```
Producer (API) → Kafka Topic → Consumer (Router) → Cassandra
```

**Benefits**:
- API responds quickly (< 10ms) without waiting for persistence
- Router can process at its own pace
- Store-and-forward: messages persist in Kafka if consumer is down

### 2. Microservices (Connectors)

**Why**: Independent scaling, deployment, and failure isolation

```
Router Worker
    │
    ├──▶ whatsapp-outbound ──▶ WhatsApp Connector (independent service)
    │
    └──▶ instagram-outbound ──▶ Instagram Connector (independent service)
```

**Benefits**:
- Scale WhatsApp connector independently (if high traffic)
- Deploy Instagram updates without touching WhatsApp
- One connector failure doesn't affect others

### 3. Presigned URLs (Object Storage)

**Why**: Direct client-to-storage downloads, no API bottleneck

```
Client → GET /v1/files/{id}/download → API
    │
    └──▶ Generate presigned URL from MinIO
         └──▶ Client downloads directly from MinIO (no API proxy)
```

**Benefits**:
- API doesn't proxy large files (saves bandwidth/CPU)
- Scales to millions of downloads
- Secure (time-limited, signature-based)

### 4. Publish-Subscribe (Real-Time Notifications)

**Why**: Real-time updates without polling

```
Router Worker → Redis Pub/Sub → WebSocket Gateway → Clients
```

**Pattern**:
1. Router writes message to Cassandra
2. Router publishes notification to Redis: `PUBLISH notifications:user_123`
3. WebSocket Gateway subscribes: `PSUBSCRIBE notifications:*`
4. Gateway pushes to connected WebSocket clients

**Benefits**:
- Sub-second latency (avg 140ms end-to-end)
- No polling overhead
- Scales horizontally (Redis cluster)

## 🔐 Security

### Authentication Flow

```
POST /auth/token {username, password}
    │
    ▼
Validate credentials (Cassandra)
    │
    ▼
Generate JWT (HS256, 1-hour expiry)
    │
    ▼
Return {access_token}


Protected Endpoints:
    │
    ▼
Extract Bearer token from Authorization header
    │
    ▼
Validate signature + expiration
    │
    ▼
Extract user_id from JWT payload
    │
    ▼
Allow request
```

### JWT Structure

```json
{
  "header": {
    "alg": "HS256",
    "typ": "JWT"
  },
  "payload": {
    "sub": "user-uuid",
    "username": "alice",
    "iat": 1701234567,
    "exp": 1701238167
  },
  "signature": "..."
}
```

### File Download Security

- Presigned URLs with 1-hour expiration
- Signature validation by MinIO
- No direct bucket access (IAM policies)

## 📊 Scalability

### Horizontal Scaling

```bash
# Scale API service (stateless, load-balanced)
docker-compose up -d --scale api-service=3

# Scale router workers (Kafka consumer group)
docker-compose up -d --scale router-worker=3
```

### Kafka Partitioning

**Goal**: Distribute messages across partitions while preserving order per conversation

```
conversation_id: "alice-bob-chat" → hash → partition 0
conversation_id: "carol-david-lunch" → hash → partition 1
conversation_id: "team-standup" → hash → partition 2
```

**Effect**:
- 3 router workers can process different conversations in parallel
- Order preserved within each conversation
- Linear scaling up to number of partitions

### Performance Characteristics

| Metric | Value | Method |
|--------|-------|--------|
| Throughput | 753 msg/min | Load test (k6, 20 VUs) |
| P95 Latency | 2.39ms | Prometheus histogram |
| P99 Latency | 4.85ms | Prometheus histogram |
| Error Rate | 0% | Load test results |
| File Upload | 2GB max | MinIO streaming |

## 🔥 Fault Tolerance

### Worker Failover

```
Worker-1 (partition 0,1,2) ──✗ FAILS
    │
    ▼
Kafka consumer group rebalances
    │
    ▼
Worker-2 (partition 0,1,2,3,4,5) ──✓ Takes over
```

**Validation**: Stopped worker-1 during load test → 0% errors

### Store-and-Forward

```
API → Kafka (durable, replicated)
    │
    │ (Router offline)
    │
    ▼
Messages accumulate in Kafka
    │
    │ (Router back online)
    │
    ▼
Router processes backlog from last committed offset
```

**Guarantee**: At-least-once delivery (manual commit after Cassandra write)

## 📡 Real-Time Notifications

### WebSocket Architecture

```
Client connects:
    ws://localhost:8085?token={JWT}
        │
        ▼
    Authenticate JWT
        │
        ▼
    Extract user_id from token
        │
        ▼
    Subscribe to Redis: PSUBSCRIBE notifications:{user_id}
        │
        ▼
    Maintain persistent connection


Router publishes notification:
    PUBLISH notifications:{recipient_user_id} {message_json}
        │
        ▼
    Redis broadcasts to all subscribers
        │
        ▼
    WebSocket Gateway receives
        │
        ▼
    Gateway pushes to connected WebSocket
        │
        ▼
    Client receives notification (< 150ms)
```

### Notification Format

```json
{
  "type": "NEW_MESSAGE",
  "message_id": "msg-abc123",
  "conversation_id": "alice-bob-chat",
  "sender_id": "whatsapp:+5511999991111",
  "recipient_id": "instagram:@bob_official",
  "content": "Hello from WebSocket!",
  "timestamp": 1701234567890,
  "file_id": null
}
```

## 🎓 Educational Aspects

### Why No Frameworks?

**Goal**: Educational transparency - students see how everything works

**Instead of**:
- Spring Boot → JDK `HttpServer` (50 lines)
- Hibernate → Direct CQL queries
- Spring Kafka → kafka-clients library

**Benefit**: Students learn HTTP, SQL, async patterns (not framework magic)

### Why Cassandra?

**Goal**: Teach NoSQL data modeling principles

**Key Concepts**:
- Partition key = data distribution
- Clustering key = sort order
- Denormalization (no joins)
- Query-driven design

### Why Kafka?

**Goal**: Teach event-driven architecture

**Key Concepts**:
- Pub/Sub pattern
- Partitioning for parallelism
- Consumer groups for load balancing
- Offset management (at-least-once delivery)

## 🔧 Operational Concerns

### Monitoring (Prometheus + Grafana)

**Metrics Collected**:
- `messages_accepted_total` - API accepts
- `messages_rejected_total` - Validation failures
- `http_request_duration_seconds` - Latency histogram
- `kafka_consumer_lag` - Offset lag per partition
- `router_processing_duration_seconds` - Router latency

**Alerts** (production would configure):
- Error rate > 1%
- P99 latency > 500ms
- Kafka lag > 1000 messages

### Logging

**Structured Logging**:
```
[2025-12-03T10:15:30.123Z] [API] [INFO] POST /v1/messages conversation_id=alice-bob-chat status=202 duration_ms=8.5
[2025-12-03T10:15:30.234Z] [Router] [INFO] Consumed message_id=msg-abc123 partition=0 offset=4567
[2025-12-03T10:15:30.345Z] [Router] [INFO] Persisted message_id=msg-abc123 to Cassandra duration_ms=23.4
[2025-12-03T10:15:30.456Z] [Connector] [INFO] Delivered message_id=msg-abc123 to whatsapp:+5511999991111
```

### Deployment

**Docker Compose** (current):
```yaml
services:
  api-service:
    replicas: 1
    ports: ["8082:8080"]
  
  router-worker:
    replicas: 1
    depends_on: [kafka, cassandra]
  
  websocket-gateway:
    replicas: 1
    ports: ["8085:8085"]
```

**Production** (Kubernetes):
```yaml
Deployment:
  - API Service: replicas=3, HPA (CPU > 70%)
  - Router Worker: replicas=2, HPA (Kafka lag)
  - WebSocket Gateway: replicas=2, sticky sessions
  
StatefulSet:
  - Cassandra: replicas=3, RF=3
  - Kafka: replicas=3, RF=2
```

## 📚 Further Reading

- **[docs/adr/](docs/adr/)** - Architecture Decision Records
- **[openapi.yaml](openapi.yaml)** - Complete API specification
- **[README.md](README.md)** - Quick start guide
- **[results/](results/)** - Performance test results

---

**Chat4All** | Educational Distributed Systems Project | November 2025
