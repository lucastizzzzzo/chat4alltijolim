# Chat4All - Architecture Documentation

**Version**: 1.0.0 (Entrega 3)  
**Last Updated**: November 2024  
**Status**: Production-ready educational implementation

---

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Component Details](#component-details)
4. [Data Flow](#data-flow)
5. [Technology Stack](#technology-stack)
6. [Scalability & Performance](#scalability--performance)
7. [Security Model](#security-model)
8. [Deployment Architecture](#deployment-architecture)
9. [References](#references)

---

## Overview

Chat4All is a **distributed messaging platform** designed as an educational project to demonstrate core distributed systems concepts. The architecture follows event-driven microservices patterns with emphasis on:

- **Horizontal Scalability**: Stateless services that scale independently
- **Event-Driven Architecture**: Kafka as the central event backbone
- **Asynchronous Processing**: Decoupled producers and consumers
- **Distributed Data Storage**: Cassandra for high availability
- **Real-Time Notifications**: WebSocket + Redis Pub/Sub
- **Object Storage**: MinIO (S3-compatible) for file handling

### Design Philosophy

1. **Educational Transparency**: Code is clear, well-commented, designed for learning
2. **Minimal Dependencies**: Only essential libraries (no Spring Boot, no ORMs)
3. **Test-First Development**: All features have automated tests
4. **Production Patterns**: Real-world distributed systems patterns
5. **Incremental Complexity**: Built in phases from simple to complex

---

## System Architecture

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              CLIENT LAYER                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                  │
│  │   REST API   │  │  WebSocket   │  │ File Upload  │                  │
│  │   Clients    │  │   Clients    │  │   Clients    │                  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘                  │
└─────────┼──────────────────┼──────────────────┼──────────────────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            API GATEWAY LAYER                             │
│  ┌──────────────────────────────────┐  ┌────────────────────────────┐  │
│  │        API Service (8082)        │  │  WebSocket Gateway (8085)  │  │
│  │  • JWT Authentication            │  │  • JWT Authentication      │  │
│  │  • Request Validation            │  │  • Redis Subscription      │  │
│  │  • Kafka Publishing              │  │  • Real-time Push          │  │
│  │  • File Upload/Download          │  │  • Connection Management   │  │
│  └───────┬──────────────────────────┘  └────────┬───────────────────┘  │
└──────────┼─────────────────────────────────────┼────────────────────────┘
           │                                      │
           │                                      │ Subscribe
           │ Produce                              │ notifications:*
           │                                      │
           ▼                                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         EVENT BACKBONE LAYER                             │
│  ┌────────────────────────────┐      ┌──────────────────────────────┐  │
│  │      Apache Kafka          │      │         Redis                │  │
│  │  Topics:                   │      │  • Pub/Sub Pattern           │  │
│  │  • messages                │      │  • Ultra-low latency         │  │
│  │  • whatsapp-outbound       │      │  • Pattern subscriptions     │  │
│  │  • instagram-outbound      │      │  • In-memory performance     │  │
│  │  • status-updates          │      │                              │  │
│  └────────┬───────────────────┘      └──────────────────────────────┘  │
└───────────┼──────────────────────────────────────────────────────────────┘
            │ Consume
            │
            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        PROCESSING LAYER                                  │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                       Router Worker                                 │ │
│  │  • Kafka Consumer (messages topic)                                  │ │
│  │  • Message Persistence (Cassandra)                                  │ │
│  │  • Routing Logic (recipient_id → topic)                             │ │
│  │  • Notification Publishing (Redis)                                  │ │
│  │  • Status Update Consumer                                           │ │
│  └────────┬───────────────────────────────────────────────────────────┘ │
│           │ Produce                                                      │
│           │                                                              │
│           ▼                                                              │
│  ┌─────────────────────────┐      ┌─────────────────────────────────┐  │
│  │  WhatsApp Connector     │      │  Instagram Connector            │  │
│  │  • whatsapp-outbound    │      │  • instagram-outbound           │  │
│  │  • Platform API calls   │      │  • Platform API calls           │  │
│  │  • Status publishing    │      │  • Status publishing            │  │
│  │  • Circuit breaker      │      │  • Circuit breaker              │  │
│  └─────────────────────────┘      └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
            │
            │ Write/Read
            │
            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         PERSISTENCE LAYER                                │
│  ┌────────────────────────────┐      ┌──────────────────────────────┐  │
│  │   Apache Cassandra         │      │         MinIO                │  │
│  │   • messages table         │      │  • S3-compatible storage     │  │
│  │   • files table            │      │  • Presigned URLs            │  │
│  │   • conversations table    │      │  • Bucket: chat4all-files    │  │
│  │   • users table            │      │  • Streaming uploads         │  │
│  └────────────────────────────┘      └──────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
            │
            │ Metrics
            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      OBSERVABILITY LAYER                                 │
│  ┌────────────────────────────┐      ┌──────────────────────────────┐  │
│  │       Prometheus           │      │         Grafana              │  │
│  │   • Metrics collection     │◀────▶│  • Visualization             │  │
│  │   • Time-series database   │      │  • 4 Dashboards              │  │
│  │   • PromQL queries         │      │  • Alerting (future)         │  │
│  └────────────────────────────┘      └──────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

### Architecture Layers

1. **Client Layer**: HTTP/WebSocket clients (browsers, mobile apps, CLI)
2. **API Gateway Layer**: Entry points with authentication and validation
3. **Event Backbone Layer**: Message brokers (Kafka, Redis)
4. **Processing Layer**: Business logic and routing
5. **Persistence Layer**: Data storage (Cassandra, MinIO)
6. **Observability Layer**: Metrics and monitoring

---

## Component Details

### 1. API Service

**Responsibility**: REST API for client interactions

**Technologies**:
- Java 17 (OpenJDK)
- JDK HttpServer (no frameworks)
- Kafka Producer Client 3.6.0
- JWT authentication (java-jwt 4.4.0)
- MinIO Java SDK 8.5.7

**Key Features**:
- JWT token generation and validation
- Request validation
- Kafka message publishing
- File streaming upload (memory-efficient)
- Presigned URL generation
- Prometheus metrics (port 9091)

**Endpoints**:
- `POST /auth/register` - User registration
- `POST /auth/token` - JWT authentication
- `POST /v1/messages` - Send message
- `GET /v1/conversations/{id}/messages` - Retrieve messages
- `POST /v1/files` - Upload file
- `GET /v1/files/{id}/download` - Get download URL
- `POST /v1/messages/{id}/read` - Mark as read
- `GET /health` - Health check

**Scalability**: Stateless, horizontally scalable with `docker-compose up --scale api-service=N`

---

### 2. Router Worker

**Responsibility**: Message processing, persistence, routing

**Technologies**:
- Java 17 (OpenJDK)
- Kafka Consumer Client 3.6.0
- Cassandra Driver 4.17.0
- Jedis (Redis client) 5.1.0

**Key Features**:
- Kafka consumer with manual commit (at-least-once delivery)
- Message deduplication by `message_id`
- Status lifecycle validation (SENT → DELIVERED → READ)
- Platform routing by `recipient_id` prefix
- Redis notification publishing
- Prometheus metrics (port 8082)

**Processing Flow**:
1. Consume message from `messages` topic
2. Deduplicate using Cassandra (message_id check)
3. Write to Cassandra messages table
4. Extract recipient_id prefix (e.g., `whatsapp:`)
5. Route to platform-specific topic (e.g., `whatsapp-outbound`)
6. Publish notification to Redis: `PUBLISH notifications:user_123`

**Scalability**: Stateless consumers, Kafka partition-based parallelism

---

### 3. WebSocket Gateway

**Responsibility**: Real-time notification delivery

**Technologies**:
- Java 11 (OpenJDK)
- Java-WebSocket 1.5.3
- Jedis (Redis client) 5.1.0
- JWT validation

**Key Features**:
- WebSocket server on port 8085
- JWT authentication via query parameter (`?token=...`)
- Redis Pub/Sub subscriber (`PSUBSCRIBE notifications:*`)
- Connection lifecycle management
- User-to-connection mapping
- Prometheus metrics (port 9095)

**Connection Flow**:
1. Client connects: `ws://localhost:8085?token=<jwt>`
2. Gateway validates JWT, extracts user_id
3. Gateway subscribes to Redis: `PSUBSCRIBE notifications:user_123`
4. On Redis message, gateway pushes to WebSocket client
5. Client receives notification in < 150ms

**Performance**: 100% notification delivery, ~140ms average latency

---

### 4. Platform Connectors

**Responsibility**: External platform integration

**Technologies**:
- Java 17 (OpenJDK)
- Kafka Consumer/Producer
- Circuit breaker pattern
- HTTP clients (simulated in educational version)

**Implementations**:
- **WhatsApp Connector**: Consumes `whatsapp-outbound` topic
- **Instagram Connector**: Consumes `instagram-outbound` topic

**Key Features**:
- Independent microservices (isolated failures)
- Platform-specific API calls (simulated)
- Status update publishing (`status-updates` topic)
- Circuit breaker for resilience
- Retry logic with exponential backoff
- Prometheus metrics (ports 9093, 9094)

**Message Flow**:
1. Consume from platform-specific topic
2. Translate to platform API format
3. Send to external platform (simulated)
4. Publish status update: `{message_id, status: DELIVERED}`
5. Router Worker updates Cassandra

---

### 5. Apache Kafka

**Responsibility**: Event backbone and message broker

**Configuration**:
- 1 broker (scalable to multiple)
- 3 partitions per topic (enables parallel processing)
- At-least-once delivery guarantee
- Manual offset commit

**Topics**:
| Topic | Partitions | Purpose | Producers | Consumers |
|-------|-----------|---------|-----------|-----------|
| `messages` | 3 | All messages | API Service | Router Worker |
| `whatsapp-outbound` | 3 | WhatsApp routing | Router Worker | WhatsApp Connector |
| `instagram-outbound` | 3 | Instagram routing | Router Worker | Instagram Connector |
| `status-updates` | 3 | Status changes | Connectors | Router Worker |

**Partitioning Strategy**:
- Key: `conversation_id` (preserves order within conversation)
- Enables parallel processing across conversations
- Supports horizontal scaling of consumers

---

### 6. Apache Cassandra

**Responsibility**: Distributed NoSQL database

**Schema Design** (Query-driven modeling):

**messages table**:
```cql
CREATE TABLE messages (
    conversation_id TEXT,      -- Partition key (data distribution)
    timestamp BIGINT,          -- Clustering key (ordering)
    message_id TEXT,           -- Unique identifier
    sender_id TEXT,
    recipient_id TEXT,
    content TEXT,
    file_id TEXT,
    status TEXT,               -- SENT, DELIVERED, READ
    delivered_at BIGINT,
    read_at BIGINT,
    PRIMARY KEY (conversation_id, timestamp)
) WITH CLUSTERING ORDER BY (timestamp DESC);
```

**files table**:
```cql
CREATE TABLE files (
    file_id TEXT PRIMARY KEY,
    conversation_id TEXT,
    filename TEXT,
    size BIGINT,
    content_type TEXT,
    storage_path TEXT,
    checksum TEXT,
    uploaded_at BIGINT
);
```

**conversations table**:
```cql
CREATE TABLE conversations (
    conversation_id TEXT PRIMARY KEY,
    created_at BIGINT,
    participant_ids SET<TEXT>,
    last_message_at BIGINT
);
```

**users table**:
```cql
CREATE TABLE users (
    user_id TEXT PRIMARY KEY,
    username TEXT,
    password TEXT,  -- Plain text in educational version
    created_at BIGINT
);
CREATE INDEX ON users (username);
```

**Data Modeling Principles**:
- Partition key distributes data across nodes
- Clustering key orders data within partition
- Denormalization (no joins, query-driven)
- Time-series data with timestamp clustering

---

### 7. MinIO

**Responsibility**: S3-compatible object storage

**Configuration**:
- Bucket: `chat4all-files`
- Access: Private (presigned URLs)
- Ports: 9000 (API), 9001 (Console)
- Credentials: minioadmin/minioadmin (dev only)

**Storage Pattern**:
```
Path: {bucket}/{conversation_id}/{file_id}.{extension}
Example: chat4all-files/conv_123/file_abc.pdf
```

**Why MinIO over Database BLOBs**:
- 80% cost savings (storage + bandwidth)
- Direct client-to-storage downloads (no API bottleneck)
- S3-compatible (easy migration to AWS)
- Horizontal scalability

See [ADR-002](adr/002-object-storage-choice.md) for full rationale.

---

### 8. Redis

**Responsibility**: Pub/Sub for real-time notifications

**Configuration**:
- Port: 6379
- Pattern subscription: `notifications:*`
- In-memory, ultra-low latency (< 10ms)

**Usage Pattern**:
```
# Router Worker publishes
PUBLISH notifications:user_alice_123 '{"type":"NEW_MESSAGE",...}'

# WebSocket Gateway subscribes
PSUBSCRIBE notifications:*

# Gateway receives and forwards to client
```

**Why Redis Pub/Sub**:
- Ultra-low latency (< 10ms publish-to-receive)
- Pattern-based subscriptions (wildcard support)
- Lightweight (in-memory)
- Simple Pub/Sub model (no persistence needed)

---

### 9. Prometheus + Grafana

**Responsibility**: Observability and monitoring

**Prometheus**:
- Metrics collection (pull-based, 15s interval)
- Time-series database
- PromQL query language
- Port: 9090

**Grafana**:
- Visualization dashboards (4 pre-configured)
- Alerting (future implementation)
- Port: 3000 (admin/admin)

**Metrics Collected**:
- HTTP request duration (histogram)
- Kafka consumer lag (gauge)
- Message processing rate (counter)
- Circuit breaker state (gauge)
- File upload size (histogram)

**Key Dashboards**:
1. System Overview (all services)
2. API Service (latency, throughput, errors)
3. Router Worker (Kafka lag, processing time)
4. Connectors (delivery, circuit breakers)

---

## Data Flow

### Message Send Flow (Text Message)

```
Step 1: Client Request
   Client
     │ POST /v1/messages
     │ Authorization: Bearer <jwt>
     │ {
     │   "conversation_id": "conv_123",
     │   "sender_id": "user_alice",
     │   "recipient_id": "whatsapp:+5511999998888",
     │   "content": "Hello!"
     │ }
     ▼
   API Service (Port 8082)
     │ 1. Validate JWT token
     │ 2. Validate request fields
     │ 3. Generate message_id
     │ 4. Produce to Kafka
     │
     ▼ 202 Accepted
   Client

Step 2: Kafka Event Bus
   API Service
     │ Produce
     ▼
   Kafka Topic: messages
     │ Partition: hash(conversation_id) % 3
     │ Message: {"message_id": "msg_abc", ...}
     ▼
   Router Worker (Kafka Consumer)

Step 3: Processing & Persistence
   Router Worker
     │ 1. Consume message
     │ 2. Deduplicate (check message_id in Cassandra)
     │ 3. Write to Cassandra (status: SENT)
     │ 4. Extract recipient_id prefix: "whatsapp:"
     │ 5. Produce to whatsapp-outbound topic
     │ 6. Publish to Redis: PUBLISH notifications:user_alice
     ▼
   Cassandra (messages table)
   Kafka (whatsapp-outbound topic)
   Redis (notifications:user_alice channel)

Step 4: Platform Routing
   WhatsApp Connector (Kafka Consumer)
     │ 1. Consume from whatsapp-outbound
     │ 2. Translate to WhatsApp API format
     │ 3. Send to WhatsApp (simulated)
     │ 4. Produce status update: {message_id, status: DELIVERED}
     ▼
   Kafka Topic: status-updates

Step 5: Status Update
   Router Worker (Status Consumer)
     │ 1. Consume from status-updates
     │ 2. SELECT to get full primary key
     │ 3. UPDATE status in Cassandra: DELIVERED
     │ 4. SET delivered_at = now()
     ▼
   Cassandra (messages table updated)

Step 6: Real-time Notification
   Redis
     │ Pub: notifications:user_alice
     ▼
   WebSocket Gateway (Subscriber)
     │ 1. Receive from Redis
     │ 2. Find connected client (user_alice)
     │ 3. Push via WebSocket
     ▼
   Client (WebSocket Connection)
     │ onmessage event
     │ {"type": "NEW_MESSAGE", "message_id": "msg_abc", ...}
     ▼
   Client UI updates (< 150ms total latency)
```

**Total Latency Breakdown**:
- API → Kafka: ~5ms
- Kafka → Router Worker: ~10ms (consumer poll interval)
- Router Worker → Cassandra: ~5ms
- Router Worker → Redis: ~5ms
- Redis → WebSocket Gateway: < 10ms
- Gateway → Client: ~5ms
- **Total**: ~40ms (excluding connector processing)

---

### File Upload Flow

```
Step 1: File Upload
   Client
     │ POST /v1/files (multipart/form-data)
     │ file: <binary data>
     │ conversation_id: conv_123
     ▼
   API Service
     │ 1. Validate JWT
     │ 2. Stream to MinIO (memory-efficient)
     │ 3. Calculate SHA-256 checksum
     │ 4. Store metadata in Cassandra
     │
     ▼ 201 Created
   Client
     │ {
     │   "file_id": "file_abc",
     │   "checksum": "e3b0c44...",
     │   "size": 1048576
     │ }

Step 2: Send Message with File
   Client
     │ POST /v1/messages
     │ {
     │   "conversation_id": "conv_123",
     │   "content": "Check this out",
     │   "file_id": "file_abc"
     │ }
     ▼
   [Same flow as text message]

Step 3: File Download
   Client
     │ GET /v1/files/file_abc/download
     ▼
   API Service
     │ 1. Validate JWT
     │ 2. Query Cassandra for file metadata
     │ 3. Generate presigned URL (MinIO)
     │ 4. Return URL (valid 1 hour)
     │
     ▼ 200 OK
   Client
     │ {
     │   "download_url": "http://minio:9000/...",
     │   "expires_in": 3600
     │ }

Step 4: Direct Download
   Client
     │ GET <presigned_url>
     ▼
   MinIO (direct connection)
     │ Validate signature
     │ Stream file binary
     ▼
   Client (downloaded file)
```

**Why Presigned URLs**:
- No API bottleneck (direct client-to-storage)
- Time-limited access (security)
- Reduced API server load
- Suitable for large files (GB+)

See [ADR-004](adr/004-presigned-urls.md) for rationale.

---

## Technology Stack

### Backend Services

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| API Service | Java + JDK HttpServer | 17 | REST API |
| Router Worker | Java + Kafka Consumer | 17 | Message processing |
| WebSocket Gateway | Java + Java-WebSocket | 11 | Real-time notifications |
| Connectors | Java + Kafka | 17 | Platform integration |

### Infrastructure

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Message Broker | Apache Kafka | 3.6.0 | Event backbone |
| Database | Apache Cassandra | 4.1 | NoSQL persistence |
| Object Storage | MinIO | Latest | S3-compatible storage |
| Cache/Pub-Sub | Redis | 7.2 | Real-time notifications |
| Metrics | Prometheus | Latest | Metrics collection |
| Visualization | Grafana | Latest | Dashboards |
| Orchestration | Docker Compose | 3.8 | Service management |

### Libraries

| Library | Version | Purpose |
|---------|---------|---------|
| kafka-clients | 3.6.0 | Kafka producer/consumer |
| cassandra-driver-core | 4.17.0 | Cassandra client |
| java-jwt | 4.4.0 | JWT authentication |
| minio | 8.5.7 | MinIO S3 client |
| jedis | 5.1.0 | Redis client |
| Java-WebSocket | 1.5.3 | WebSocket server |
| simpleclient_httpserver | 0.16.0 | Prometheus client |

**No Frameworks Policy**:
- No Spring Boot (educational transparency)
- No ORMs (understand NoSQL patterns)
- Direct HTTP with JDK HttpServer
- Manual JSON serialization

See [ADR-001](adr/001-no-frameworks.md) for rationale.

---

## Scalability & Performance

### Horizontal Scalability

**Stateless Services** (scale independently):
```bash
# Scale API Service to 3 instances
docker-compose up -d --scale api-service=3

# Scale Router Worker to 3 instances (Kafka partitioning)
docker-compose up -d --scale router-worker=3

# Scale connectors independently
docker-compose up -d --scale connector-whatsapp=2
```

**Kafka Partitioning** (parallel processing):
- 3 partitions per topic
- Partition key: `conversation_id`
- Consumer group: 1 consumer per partition (max 3)
- Preserves message order within conversation

**Cassandra Scaling** (horizontal):
- Partition key: `conversation_id` (data distribution)
- Add nodes: `docker-compose up -d --scale cassandra=3`
- Replication factor: 3 (production)

### Performance Metrics (Validated)

**Load Test Results** (k6, 20 VUs, 5 minutes):

| Metric | Target | Achieved | Status |
|--------|--------|----------|--------|
| Throughput | 500-600 msg/min | **753 msg/min** | ✅ 126% |
| P95 Latency | < 200ms | **2.39ms** | ✅ 1.2% |
| P99 Latency | < 500ms | **4.85ms** | ✅ 1.0% |
| Error Rate | < 0.5% | **0.00%** | ✅ 0% |

**Scalability Test** (1 vs 2 Router Workers):

| Workers | Throughput | Kafka Lag | CPU Usage |
|---------|-----------|-----------|-----------|
| 1 | 753 msg/min | 0 | 15% |
| 2 | ~1500 msg/min (est.) | 0 | 8% each |

**WebSocket Performance**:
- Average notification latency: **140ms**
- Success rate: **100%** (6/6 test notifications)
- Concurrent connections: Unlimited (educational)

See `results/SCALING_RESULTS.md` for detailed analysis.

### Fault Tolerance

**Store-and-Forward Pattern**:
- Messages persist in Kafka (7 days retention)
- Router Worker failure → messages buffer in Kafka
- Worker restart → resumes from last committed offset
- Zero message loss

**Circuit Breaker Pattern** (connectors):
- Open on 5 consecutive failures
- Half-open after 30s
- Prevents cascade failures
- Metrics exposed to Prometheus

**Health Checks**:
- All services: `/health` endpoint
- Prometheus scraping every 15s
- Grafana alerting (future)

See `results/FAULT_TOLERANCE_RESULTS.md` for failover tests.

---

## Security Model

### Authentication & Authorization

**JWT Tokens**:
- Algorithm: HS256 (HMAC-SHA256)
- Secret: Shared between API Service and WebSocket Gateway
- Expiration: 1 hour
- Claims: `sub` (user_id), `iat`, `exp`

**Token Flow**:
1. Client: `POST /auth/token` → JWT token
2. Client: Include in requests: `Authorization: Bearer <token>`
3. API Service: Validates token on every request
4. WebSocket: Validates token on connection: `ws://...?token=<jwt>`

**Limitations** (educational version):
- No refresh tokens
- Plain text passwords (production: bcrypt/argon2)
- Shared secret (production: RSA keys)
- No rate limiting

### File Security

**Presigned URLs**:
- Time-limited (1 hour expiration)
- Signature-based validation (HMAC-SHA256)
- No authentication required on download (URL is secret)
- Direct client-to-MinIO (no API proxy)

**Upload Validation**:
- Max file size: 2GB
- Checksum verification (SHA-256)
- JWT authentication required
- Multipart streaming (memory-efficient)

### Network Security

**Docker Network Isolation**:
- Internal network: `chat4all-network`
- Services communicate via service names (DNS)
- External access: Only exposed ports (8082, 8085, 9000, etc.)

**Production Recommendations**:
- TLS/SSL for all external connections
- API Gateway with rate limiting
- OAuth2/OpenID Connect
- Network policies (Kubernetes)

---

## Deployment Architecture

### Docker Compose (Development)

**11 Services**:
1. Zookeeper (Kafka coordination)
2. Kafka (message broker)
3. Cassandra (database)
4. Redis (Pub/Sub)
5. MinIO (object storage)
6. API Service (REST API)
7. Router Worker (message processing)
8. WebSocket Gateway (real-time notifications)
9. WhatsApp Connector
10. Instagram Connector
11. Prometheus (metrics)
12. Grafana (visualization)

**Docker Compose Commands**:
```bash
# Start all services
docker-compose up -d

# Scale specific service
docker-compose up -d --scale router-worker=3

# View logs
docker-compose logs -f router-worker

# Restart service
docker-compose restart api-service

# Stop all
docker-compose down
```

### Production Deployment (Kubernetes)

**Recommended Architecture**:

```yaml
# Example Kubernetes resources

# API Service Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-service
  template:
    metadata:
      labels:
        app: api-service
    spec:
      containers:
      - name: api-service
        image: chat4all/api-service:1.0.0
        ports:
        - containerPort: 8080
        env:
        - name: KAFKA_BOOTSTRAP_SERVERS
          value: "kafka:9092"
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi

# Service (LoadBalancer)
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  type: LoadBalancer
  selector:
    app: api-service
  ports:
  - port: 80
    targetPort: 8080

# HorizontalPodAutoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-service
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**External Services** (managed):
- Kafka: Confluent Cloud or Amazon MSK
- Cassandra: AWS Keyspaces or DataStax Astra
- MinIO: AWS S3
- Redis: AWS ElastiCache or Redis Cloud
- Observability: Datadog, New Relic, or Grafana Cloud

---

## References

### Architecture Decision Records (ADRs)

- [ADR-001: No Frameworks](adr/001-no-frameworks.md)
- [ADR-002: Object Storage Choice (MinIO)](adr/002-object-storage-choice.md)
- [ADR-003: Connector Architecture (Microservices)](adr/003-connector-architecture.md)
- [ADR-004: Presigned URLs for Downloads](adr/004-presigned-urls.md)
- [ADR-005: Circuit Breaker Pattern](adr/005-circuit-breaker.md)
- [ADR-006: Observability Strategy](adr/006-observability-strategy.md)

### External Resources

**Apache Kafka**:
- [Official Documentation](https://kafka.apache.org/documentation/)
- [Partitioning Strategy](https://kafka.apache.org/documentation/#design_partitioning)
- [Consumer Groups](https://kafka.apache.org/documentation/#consumergroups)

**Apache Cassandra**:
- [Data Modeling Guide](https://cassandra.apache.org/doc/latest/cassandra/data-modeling/)
- [CQL Reference](https://cassandra.apache.org/doc/latest/cassandra/cql/)
- [Best Practices](https://cassandra.apache.org/doc/latest/cassandra/operating/compaction/index.html)

**Distributed Systems Patterns**:
- [Microservices Patterns](https://microservices.io/patterns/)
- [Event-Driven Architecture](https://martinfowler.com/articles/201701-event-driven.html)
- [Building Event-Driven Microservices (O'Reilly)](https://www.oreilly.com/library/view/building-event-driven-microservices/9781492057888/)

**WebSocket & Real-Time**:
- [WebSocket Protocol (RFC 6455)](https://tools.ietf.org/html/rfc6455)
- [Redis Pub/Sub](https://redis.io/docs/manual/pubsub/)

**Observability**:
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)

---

**Document Version**: 1.0.0  
**Last Updated**: November 2024  
**Maintainer**: Chat4All Development Team
