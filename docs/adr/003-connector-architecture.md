# ADR 003: Separate Connector Services Architecture

**Status**: Accepted  
**Date**: 2025-11-23  
**Decision Makers**: Chat4All Team  
**Technical Story**: Phase 6 - Multi-Platform Connector Integration

## Context

The Chat4All system needs to integrate with multiple external messaging platforms:
- WhatsApp Business API
- Instagram Direct Messages
- (Future: Telegram, SMS, Email, etc.)

Each platform has:
- Different API contracts and authentication methods
- Different rate limits and retry strategies
- Different message formats and capabilities
- Independent deployment and scaling requirements

We evaluated three architectural approaches:
1. **Monolithic API** - All connector logic inside the main API service
2. **Plugin Libraries** - Connectors as JAR dependencies loaded dynamically
3. **Separate Microservices** - Each connector as independent service

## Decision

We have decided to implement **Separate Microservices** for each external platform connector.

## Rationale

### Why NOT Monolithic API?

**Coupling Issues:**
- ❌ Main API becomes tightly coupled to external platform APIs
- ❌ Changes to one connector affect the entire API service
- ❌ Cannot deploy connector updates without restarting API
- ❌ Testing requires mocking all external APIs together

**Scalability Problems:**
- ❌ Cannot scale connectors independently from API
- ❌ WhatsApp connector needs different resources than Instagram
- ❌ One slow connector blocks other connectors
- ❌ Rate limits affect entire API service

**Operational Complexity:**
- ❌ Single deployment includes all platform dependencies
- ❌ Credentials for all platforms in one service
- ❌ Failure in one connector can crash entire API
- ❌ Difficult to implement platform-specific monitoring

**Example Failure Scenario:**
```
WhatsApp API rate limit exceeded → API service crashes
→ ALL users affected (even Instagram users)
→ System-wide outage instead of isolated issue
```

### Why NOT Plugin Libraries?

**Deployment Challenges:**
- ❌ Requires dynamic classloading (complex in Java)
- ❌ Dependency conflicts between plugins
- ❌ Cannot update plugin without restarting API
- ❌ Difficult to version plugins independently

**Resource Sharing Issues:**
- ❌ All plugins share same JVM heap
- ❌ Thread pool contention between plugins
- ❌ Memory leak in one plugin affects all
- ❌ Cannot set different JVM parameters per plugin

**Testing and Development:**
- ❌ Must load all plugins to test one
- ❌ Complex plugin discovery and loading logic
- ❌ Difficult to mock individual plugins
- ❌ Requires custom plugin framework

### Why Separate Microservices?

**Isolation and Resilience:**
- ✅ Each connector runs in isolated process/container
- ✅ Failure in one connector doesn't affect others
- ✅ Independent circuit breakers and retry logic
- ✅ Platform-specific error handling

**Independent Scalability:**
- ✅ Scale WhatsApp connector independently of Instagram
- ✅ Different resource allocation per platform
- ✅ Handle platform-specific traffic patterns
- ✅ Auto-scaling based on connector workload

**Deployment Flexibility:**
- ✅ Deploy connector updates independently
- ✅ Canary deployments per connector
- ✅ Rollback without affecting other connectors
- ✅ Platform-specific deployment schedules

**Development Velocity:**
- ✅ Separate teams can own different connectors
- ✅ Technology choices per connector (if needed)
- ✅ Independent testing and CI/CD pipelines
- ✅ Faster iteration on new platform integrations

**Operational Benefits:**
- ✅ Platform-specific monitoring and alerting
- ✅ Independent health checks per connector
- ✅ Credentials isolated per service
- ✅ Rate limiting per platform

## Implementation Details

### Architecture:

```
                    ┌─────────────────────┐
                    │   API Service       │
                    │                     │
                    │  POST /v1/messages  │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Kafka Cluster     │
                    │                     │
                    │  Topic: messages    │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Router Worker     │
                    │                     │
                    │  Routes to topics:  │
                    │  - whatsapp-outbound│
                    │  - instagram-outbound│
                    └──────────┬──────────┘
                               │
           ┌───────────────────┴───────────────────┐
           │                                       │
           ▼                                       ▼
┌─────────────────────┐               ┌─────────────────────┐
│ WhatsApp Connector  │               │ Instagram Connector │
│                     │               │                     │
│ - Consumes whatsapp │               │ - Consumes instagram│
│   topic             │               │   topic             │
│ - Calls WhatsApp    │               │ - Calls Instagram   │
│   Business API      │               │   Graph API         │
│ - Publishes status  │               │ - Publishes status  │
│   to status-updates │               │   to status-updates │
│ - Health: :8083     │               │ - Health: :8084     │
└─────────────────────┘               └─────────────────────┘
```

### Message Flow:

**Outbound (Sending):**
1. API receives message → publishes to `messages` topic
2. Router Worker consumes → routes to `whatsapp-outbound` OR `instagram-outbound`
3. Connector consumes platform-specific topic
4. Connector simulates delivery (200-500ms delay)
5. Connector publishes DELIVERED status to `status-updates` topic
6. StatusUpdateConsumer updates Cassandra

**Status Updates:**
1. Connector publishes: `{message_id, status: DELIVERED, timestamp}`
2. StatusUpdateConsumer validates state transition
3. Updates Cassandra: `delivered_at` timestamp
4. Client can query message status

### Connector Interface (Contract):

Each connector MUST implement:

```java
// Input: Kafka topic {platform}-outbound
// Message format: {
//   message_id: string,
//   conversation_id: string,
//   sender_id: string,
//   receiver_id: string,
//   content: string,
//   file_id: string (optional)
// }

// Output: Kafka topic status-updates
// Status format: {
//   message_id: string,
//   status: "DELIVERED" | "FAILED",
//   timestamp: long (epoch millis)
// }

// Health: GET /health
// Response: 200 OK {"status": "healthy"}
```

### Adding a New Connector:

**Step 1: Create Service**
```bash
cp -r connector-whatsapp connector-telegram
# Update pom.xml, Main.java, Dockerfile
```

**Step 2: Configure Router**
```java
// router-worker/ConnectorRouter.java
if (recipientId.startsWith("telegram:")) {
    return "telegram-outbound";
}
```

**Step 3: Add to docker-compose.yml**
```yaml
connector-telegram:
  build: ./connector-telegram
  environment:
    KAFKA_BOOTSTRAP_SERVERS: kafka:9092
    KAFKA_TOPIC: telegram-outbound
    KAFKA_GROUP_ID: telegram-connector-group
  ports:
    - "8085:8085"
```

**Step 4: Deploy**
```bash
docker-compose up -d connector-telegram
```

## Consequences

### Positive:

✅ **Resilience**: Connector failures isolated from main system  
✅ **Scalability**: Independent horizontal scaling per platform  
✅ **Velocity**: Faster development and deployment cycles  
✅ **Flexibility**: Easy to add/remove platforms  
✅ **Testing**: Simplified mocking and integration testing  
✅ **Monitoring**: Platform-specific metrics and alerting  
✅ **Security**: Credentials isolated per service  

### Negative:

⚠️ **Complexity**: More services to deploy and monitor  
⚠️ **Latency**: Additional network hops through Kafka  
⚠️ **Debugging**: Distributed tracing required  
⚠️ **Consistency**: Eventual consistency via async messaging  

### Mitigations:

**For Complexity:**
- Docker Compose for local development simplifies multi-service setup
- Kubernetes Helm charts for production deployment
- Service mesh (Istio) for advanced traffic management
- Centralized logging (ELK stack) and monitoring (Prometheus)

**For Latency:**
- Kafka is fast (<10ms for small messages)
- Async design means users don't wait for connector processing
- Status updates are eventually consistent (acceptable for chat)

**For Debugging:**
- Implement correlation IDs (message_id) across all services
- Structured logging with JSON format
- Distributed tracing with Jaeger/Zipkin
- Health check endpoints on all connectors

**For Consistency:**
- Implement retry logic with exponential backoff
- Use Kafka consumer groups for at-least-once delivery
- Monitor `status-updates` topic lag
- Implement reconciliation job for stuck messages

## Alternatives Considered

### 1. Shared Library Approach (Rejected)
**Pros**: Simple deployment, no network overhead  
**Cons**: Cannot scale independently, tight coupling  
**Reason**: Doesn't meet scalability and isolation requirements

### 2. Serverless Functions (Lambda/Cloud Functions) (Rejected)
**Pros**: Auto-scaling, pay-per-use  
**Cons**: Cold starts, vendor lock-in, complex local development  
**Reason**: Educational project needs self-hosted solution

### 3. Message Queue Instead of Kafka (RabbitMQ, etc.) (Rejected)
**Pros**: Simpler than Kafka for small scale  
**Cons**: Less scalable, no log compaction, no stream processing  
**Reason**: Kafka is industry standard, better learning experience

## Trade-offs Accepted

| Aspect | Trade-off | Justification |
|--------|-----------|---------------|
| **Latency** | +50-100ms per connector hop | Acceptable for async messaging system |
| **Complexity** | 10+ services vs 1 monolith | Necessary for scalability and isolation |
| **Consistency** | Eventual consistency | Acceptable for chat application |
| **Overhead** | More containers/memory | Worth it for operational flexibility |

## References

- [Martin Fowler - Microservices](https://martinfowler.com/articles/microservices.html)
- [Kafka as Event Bus](https://www.confluent.io/blog/apache-kafka-vs-enterprise-service-bus-esb-friends-enemies-or-frenemies/)
- [Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)
- [12-Factor App Methodology](https://12factor.net/)

## Related ADRs

- ADR 001: No Frameworks (applies to connector implementation too)
- ADR 002: Object Storage (connectors may need to download files from MinIO)

## Educational Value

This decision demonstrates:
- **Microservices Architecture**: When and why to split services
- **Event-Driven Design**: Using Kafka for service communication
- **Separation of Concerns**: Platform integration logic isolated
- **Scalability Patterns**: Independent scaling and deployment
- **Resilience Engineering**: Failure isolation and circuit breakers
- **Plugin Architecture**: Extensible system design without plugins
- **Industry Best Practices**: How modern platforms integrate with external APIs
