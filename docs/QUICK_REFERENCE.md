# Chat4All - Quick Reference

**Version**: 1.0.0 | **Status**: Production-ready educational implementation

---

## 🎯 Quick Links

| Resource | Description | Link |
|----------|-------------|------|
| **Quick Start** | Get started in 5 minutes | [README.md](../README.md#-quick-start) |
| **Architecture** | Complete architecture docs | [ARCHITECTURE.md](ARCHITECTURE.md) |
| **API Docs** | OpenAPI/Swagger specification | [openapi.yaml](../openapi.yaml) |
| **CLI Guide** | Interactive CLI tutorial | [cli/README.md](../cli/README.md) |

---

## 🏗️ System Architecture

```
Client → API (8082) → Kafka → Router Worker → Cassandra
   │                               ↓
   │                          Redis Pub/Sub
   │                               ↓
   └─────── WebSocket (8085) ─────┘
```

**Components**: 11 Docker containers  
**Languages**: Java 17 (API, Router, Connectors), Java 11 (WebSocket)  
**Databases**: Cassandra (NoSQL), Redis (Pub/Sub), MinIO (S3-compatible)

---

## 🚀 Quick Commands

### Start System
```bash
# Build all services (first time only)
./build.sh

# Start all containers
docker-compose up -d

# Check health
curl http://localhost:8082/health
```

### Test System
```bash
# End-to-end test (text messages)
./scripts/test-end-to-end.sh

# WebSocket notifications test
python3 scripts/test-websocket-notifications.py

# File upload/download test
./scripts/test-file-upload.sh
```

### Interactive CLI
```bash
# Install dependencies
./cli/setup.sh

# Run CLI
./cli/chat4all-cli.py
```

---

## 📡 API Endpoints

### Authentication
- `POST /auth/register` - Register new user
- `POST /auth/token` - Get JWT token

### Messages
- `POST /v1/messages` - Send message
- `GET /v1/conversations/{id}/messages` - Get messages (paginated)
- `POST /v1/messages/{id}/read` - Mark as read

### Files
- `POST /v1/files` - Upload file (multipart, 2GB max)
- `GET /v1/files/{id}/download` - Get presigned URL

### Health
- `GET /health` - Service health check

**Full API Spec**: [openapi.yaml](../openapi.yaml)

---

## 🔑 Quick Start Example

```bash
# 1. Register user
curl -X POST http://localhost:8082/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"mypassword"}'

# 2. Get token
TOKEN=$(curl -s -X POST http://localhost:8082/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"mypassword"}' \
  | jq -r '.access_token')

# 3. Send message
curl -X POST http://localhost:8082/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "conv_123",
    "sender_id": "user_alice",
    "content": "Hello World!"
  }'

# 4. Get messages
curl -X GET "http://localhost:8082/v1/conversations/conv_123/messages?limit=50&offset=0" \
  -H "Authorization: Bearer $TOKEN" | jq
```

---

## 🔔 WebSocket Notifications

### Connect to WebSocket
```javascript
const ws = new WebSocket('ws://localhost:8085?token=' + jwt_token);

ws.onmessage = (event) => {
  const notification = JSON.parse(event.data);
  console.log('New message:', notification.content);
};
```

### Test Notifications
```bash
python3 scripts/test-websocket-notifications.py
```

**Expected latency**: ~140ms  
**Success rate**: 100%

---

## 📊 Service Ports

| Service | Port | Purpose |
|---------|------|---------|
| API Service | 8082 | REST API |
| WebSocket Gateway | 8085 | Real-time notifications |
| Prometheus | 9090 | Metrics database |
| Grafana | 3000 | Dashboards (admin/admin) |
| MinIO Console | 9001 | Object storage UI (minioadmin/minioadmin) |
| MinIO API | 9000 | S3-compatible API |
| Cassandra | 9042 | CQL |
| Redis | 6379 | Pub/Sub |
| Kafka | 9092 (internal), 29092 (external) | Message broker |

---

## 🧪 Testing

### Automated Tests
```bash
# Unit tests
mvn test

# End-to-end tests
./scripts/test-end-to-end.sh

# File upload/download
./scripts/test-file-upload.sh
./scripts/test-file-download.sh

# WebSocket notifications
python3 scripts/test-websocket-notifications.py

# Complete integration test
./scripts/test-file-connectors-e2e.sh
```

### Load Testing
```bash
# Install k6
brew install k6  # macOS
# or: sudo apt install k6  # Ubuntu

# Run baseline test (20 VUs, 5 min)
k6 run scripts/load-tests/02-baseline.js

# Expected: 753 msg/min, P95 < 3ms, 0% errors
```

### Manual Testing
```bash
# Interactive CLI (recommended)
./cli/chat4all-cli.py

# Or demo scripts
./scripts/demo-simple.sh
./scripts/demo-file-sharing.sh
```

---

## 🔧 Development

### Local Development (without Docker)
```bash
# Terminal 1: Start infrastructure
docker-compose up -d kafka cassandra redis minio

# Terminal 2: Run API Service
cd api-service
mvn exec:java -Dexec.mainClass="chat4all.api.Main"

# Terminal 3: Run Router Worker
cd router-worker
mvn exec:java -Dexec.mainClass="chat4all.worker.Main"
```

### Rebuild After Changes
```bash
# Rebuild specific module
mvn clean package -DskipTests -pl api-service -am

# Rebuild Docker image
docker-compose up -d --build api-service
```

### View Logs
```bash
# Follow logs
docker-compose logs -f api-service

# Last 100 lines
docker-compose logs --tail=100 router-worker

# All services
docker-compose logs --tail=50
```

---

## 📊 Observability

### Dashboards
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)

### Key Metrics
```promql
# Messages per minute
rate(messages_accepted_total[1m]) * 60

# P95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Error rate
rate(messages_rejected_total[5m])
```

### Performance (Validated)
- **Throughput**: 753 msg/min (126% above target)
- **P95 Latency**: 2.39ms (99% below target)
- **Error Rate**: 0.00%
- **WebSocket Latency**: ~140ms

---

## 🐛 Troubleshooting

### Services not starting
```bash
# Check status
docker-compose ps

# View logs
docker-compose logs cassandra

# Restart all
docker-compose restart
```

### JWT authentication failing
```bash
# Verify token
curl http://localhost:8082/health

# Check JWT_SECRET matches
docker-compose exec api-service env | grep JWT_SECRET
docker-compose exec websocket-gateway env | grep JWT_SECRET
```

### WebSocket not receiving notifications
```bash
# Check WebSocket Gateway
docker-compose logs websocket-gateway | grep "Redis"

# Check Router Worker publishing
docker-compose logs router-worker | grep "Redis notification publisher"

# Test Redis manually
docker-compose exec redis redis-cli
> PSUBSCRIBE notifications:*
```

### Kafka consumer lag
```bash
# Check consumer group
docker-compose exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group router-worker-group \
  --describe
```

---

## 📚 Key Concepts

### Event-Driven Architecture
- **Kafka**: Central event backbone, 3 partitions per topic
- **Partitioning**: By `conversation_id` (preserves order)
- **At-least-once**: Manual commit + deduplication

### Horizontal Scalability
- **Stateless Services**: API, Router Worker, Connectors
- **Kafka Partitioning**: 1 consumer per partition (max 3)
- **Cassandra**: Partition key distribution

### Real-Time Notifications
- **Redis Pub/Sub**: Ultra-low latency (< 10ms)
- **WebSocket**: Persistent connections, JWT auth
- **Pattern Subscriptions**: `notifications:*`

### Object Storage
- **MinIO**: S3-compatible, presigned URLs
- **Streaming Uploads**: Memory-efficient (2GB support)
- **Direct Downloads**: Client-to-storage (no API bottleneck)

---

## 🎓 Learning Resources

### Architecture Decision Records
- [ADR-001: No Frameworks](adr/001-no-frameworks.md) - Why avoid Spring Boot
- [ADR-002: Object Storage](adr/002-object-storage-choice.md) - MinIO vs BLOBs
- [ADR-003: Connectors](adr/003-connector-architecture.md) - Microservices pattern
- [ADR-004: Presigned URLs](adr/004-presigned-urls.md) - Security model

### External Resources
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Cassandra Data Modeling](https://cassandra.apache.org/doc/latest/cassandra/data-modeling/)
- [Microservices Patterns](https://microservices.io/patterns/)
- [Building Event-Driven Microservices](https://www.oreilly.com/library/view/building-event-driven-microservices/9781492057888/)

---

## 🤝 Contributing

1. **Test-First**: Write tests before implementation
2. **Comment Extensively**: Explain WHY, not just WHAT
3. **No Magic**: Keep code transparent
4. **Document Decisions**: Create ADRs

See [CONTRIBUTING.md](../CONTRIBUTING.md) for full guidelines.

---

## 📝 License

MIT License - Educational use encouraged

---

**Need Help?**
- Open an issue on GitHub
- Check [MANUAL_TESTS.md](../MANUAL_TESTS.md)
- See [TROUBLESHOOTING](../README.md#-troubleshooting)

**Last Updated**: November 2024  
**Version**: 1.0.0 (Entrega 3 Complete)
