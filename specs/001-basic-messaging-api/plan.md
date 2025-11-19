# Implementation Plan: Basic Messaging API

**Branch**: `001-basic-messaging-api` | **Date**: 2025-11-17 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-basic-messaging-api/spec.md`

## Summary

Develop Phase 1 of Chat4All platform: a didactic, minimal-dependency Java implementation demonstrating distributed systems concepts through event-driven messaging architecture. Core flow: REST API → Kafka (partitioned by conversation_id) → Router Worker → Cassandra persistence. Focus on horizontal scalability patterns and educational clarity for 7th semester students.

## Technical Context

**Language/Version**: Java 17 (LTS) with standard library emphasis
**Primary Dependencies**: 
- `kafka-clients` (Apache Kafka producer/consumer)
- `cassandra-driver-core` (DataStax Java driver for Cassandra)
- `java-jwt` (Auth0 JWT library - minimal, well-documented)
- Standard JDK libraries for HTTP server (`com.sun.net.httpserver`), JSON (`org.json` or manual parsing for education), logging

**Storage**: Apache Cassandra 4.x (distributed, eventually consistent NoSQL)
**Testing**: JUnit 5 + AssertJ (simple assertions), no mocking frameworks
**Target Platform**: Linux server, containerized via Docker
**Project Type**: Microservices (API Service + Worker Service) - separate modules
**Performance Goals**: 
- API latency: <200ms p95 (accept + Kafka publish)
- Worker latency: <500ms p95 (consume + Cassandra write)
- Throughput: 1,000 msgs/sec per API instance

**Constraints**: 
- NO frameworks (Spring Boot, Quarkus, Micronaut) - violates Minimal Dependencies
- NO ORMs (Hibernate) - direct Cassandra queries for learning
- Manual HTTP handling using JDK's `HttpServer`
- Manual JSON parsing or minimal library (educational transparency)
- Code MUST have extensive comments explaining distributed systems concepts
- Maximum method complexity: 10 cyclomatic complexity

**Scale/Scope**: 
- Phase 1 only: text messaging, no files, no external connectors
- 2 microservices: `api-service`, `router-worker`
- Docker Compose with 6 containers: 2x API, 2x Worker, Kafka, Cassandra
- Demonstrable horizontal scaling (add instances via compose scale)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

✅ **I. Didactic Simplicity**
- Using Java 17 standard libraries (well-documented, familiar to students)
- No framework magic - direct HTTP server implementation teaches request/response lifecycle
- Extensive inline comments explaining: partitioning, eventual consistency, at-least-once delivery
- Each class has clear single responsibility (e.g., `KafkaMessageProducer`, `CassandraMessageStore`)

✅ **II. Minimal Dependencies**
- Only 3 external libraries: kafka-clients, cassandra-driver, java-jwt
- Justification documented: Kafka client (enables distribution), Cassandra driver (database access), JWT (standard auth)
- HTTP handled by JDK `com.sun.net.httpserver.HttpServer` (no Netty, no Jetty)
- JSON handled manually or with lightweight `org.json` (educational choice - students see parsing logic)

✅ **III. Test-First Discipline (NON-NEGOTIABLE)**
- JUnit 5 tests written before implementation
- Test structure: unit tests (business logic), integration tests (API endpoints with embedded Kafka/Cassandra), contract tests (Kafka message schema validation)
- No mocking frameworks - use real embedded Kafka/Cassandra or test containers for integration tests

✅ **IV. Horizontal Scalability**
- API service is stateless (no local state, no sticky sessions)
- Kafka partitioning by `conversation_id` ensures ordered processing per conversation
- Cassandra schema uses `conversation_id` as partition key (distributes data)
- Docker Compose demonstrates scaling: `docker-compose up --scale api-service=3 --scale router-worker=3`

✅ **V. Cassandra-First Data Storage**
- Schema follows query-driven design: messages table partitioned by `conversation_id`, clustered by `timestamp`
- No joins - denormalized data (user info embedded in message if needed)
- Eventual consistency accepted and documented in comments
- Replication factor = 2 (configurable in docker-compose)

✅ **VI. Incremental Delivery**
- Scope limited to entrega1.md: POST /v1/messages, GET /v1/conversations/{id}/messages
- No file upload, no connectors, no WebSockets in Phase 1
- Docker Compose with single `docker-compose up` command
- Each user story independently testable

## Project Structure

### Documentation (this feature)

```text
specs/001-basic-messaging-api/
├── plan.md              # This file
├── spec.md              # Feature specification (already created)
├── research.md          # Phase 0 output (architecture research)
├── data-model.md        # Phase 1 output (Cassandra schema design)
├── quickstart.md        # Phase 1 output (setup + demo instructions)
├── contracts/           # Phase 1 output (Kafka message schemas, API contracts)
│   ├── api-endpoints.md
│   └── kafka-events.md
└── tasks.md             # Phase 2 output (NOT created by this command)
```

### Source Code (repository root)

```text
chat4all/
├── api-service/                  # Stateless REST API microservice
│   ├── src/
│   │   ├── main/
│   │   │   └── java/
│   │   │       └── chat4all/
│   │   │           └── api/
│   │   │               ├── Main.java                    # Entry point, HttpServer setup
│   │   │               ├── http/
│   │   │               │   ├── HttpRequestHandler.java  # Routes requests to handlers
│   │   │               │   ├── MessagesHandler.java     # POST /v1/messages
│   │   │               │   ├── ConversationsHandler.java # GET /v1/conversations/{id}/messages
│   │   │               │   └── AuthHandler.java         # POST /auth/token
│   │   │               ├── auth/
│   │   │               │   ├── JwtAuthenticator.java    # JWT validation
│   │   │               │   └── TokenGenerator.java      # JWT creation
│   │   │               ├── kafka/
│   │   │               │   ├── KafkaMessageProducer.java # Kafka producer wrapper
│   │   │               │   └── MessageEvent.java        # Event POJO
│   │   │               ├── validation/
│   │   │               │   └── MessageValidator.java    # Input validation logic
│   │   │               └── util/
│   │   │                   ├── JsonParser.java          # Manual JSON parsing
│   │   │                   └── Logger.java              # Structured logging
│   │   └── test/
│   │       └── java/
│   │           └── chat4all/
│   │               └── api/
│   │                   ├── integration/
│   │                   │   ├── MessagesEndpointTest.java
│   │                   │   └── AuthEndpointTest.java
│   │                   ├── contract/
│   │                   │   └── KafkaMessageSchemaTest.java
│   │                   └── unit/
│   │                       ├── MessageValidatorTest.java
│   │                       └── JwtAuthenticatorTest.java
│   ├── Dockerfile
│   └── pom.xml                   # Maven build (minimal dependencies)
│
├── router-worker/                # Kafka consumer + Cassandra writer
│   ├── src/
│   │   ├── main/
│   │   │   └── java/
│   │   │       └── chat4all/
│   │   │           └── worker/
│   │   │               ├── Main.java                    # Entry point, consumer loop
│   │   │               ├── kafka/
│   │   │               │   ├── KafkaMessageConsumer.java # Kafka consumer wrapper
│   │   │               │   └── MessageEvent.java        # Event POJO (shared schema)
│   │   │               ├── cassandra/
│   │   │               │   ├── CassandraConnection.java  # Session management
│   │   │               │   ├── CassandraMessageStore.java # Write/update messages
│   │   │               │   └── MessageEntity.java       # Message data model
│   │   │               ├── processing/
│   │   │               │   ├── MessageProcessor.java    # Core business logic
│   │   │               │   └── DeduplicationChecker.java # Idempotency via message_id
│   │   │               └── util/
│   │   │                   ├── RetryHandler.java        # Exponential backoff
│   │   │                   └── Logger.java              # Structured logging
│   │   └── test/
│   │       └── java/
│   │           └── chat4all/
│   │               └── worker/
│   │                   ├── integration/
│   │                   │   ├── KafkaToC assandraFlowTest.java
│   │                   │   └── DeduplicationTest.java
│   │                   └── unit/
│   │                       ├── MessageProcessorTest.java
│   │                       └── RetryHandlerTest.java
│   ├── Dockerfile
│   └── pom.xml
│
├── shared/                       # Shared utilities (if needed, keep minimal)
│   └── src/
│       └── main/
│           └── java/
│               └── chat4all/
│                   └── shared/
│                       ├── MessageEvent.java     # Kafka event schema (shared)
│                       └── Constants.java        # Kafka topic names, etc.
│
├── docker-compose.yml            # Orchestration: Kafka, Cassandra, services
├── cassandra-init/               # Cassandra schema initialization
│   └── schema.cql                # CREATE KEYSPACE, CREATE TABLE scripts
├── docs/
│   ├── adr/                      # Architecture Decision Records
│   │   ├── 001-no-frameworks.md
│   │   ├── 002-cassandra-schema-design.md
│   │   └── 003-kafka-partitioning-strategy.md
│   └── diagrams/                 # Architecture diagrams from esqueleto.md
│       ├── components.png
│       ├── sequence.png
│       └── deployment.png
├── scripts/
│   ├── run-tests.sh              # Execute all tests
│   ├── load-test.sh              # Simple load test (curl loop or JMeter)
│   └── scale-demo.sh             # Demonstrate horizontal scaling
├── README.md                     # Quickstart, architecture overview, how to run
└── pom.xml                       # Parent POM (if using Maven multi-module)
```

**Structure Decision**: 

Multi-module Maven project with two microservices (`api-service`, `router-worker`) and optional `shared` module for common code. This structure:
- **Demonstrates microservices pattern** (Principle IV, Horizontal Scalability) by isolating API and Worker concerns
- **Enables independent scaling** - each service has its own Dockerfile and can be scaled via Docker Compose
- **Maintains simplicity** - no complex parent/child module hierarchies, just 2-3 modules
- **Follows esqueleto.md** - clear separation of Frontend Service (api-service) and Router Worker (router-worker)

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations - all constitution principles satisfied.

**Justification for 3 External Dependencies** (not a violation, but documented per Principle II):

| Dependency | Why Needed | Alternative Rejected Because |
|------------|------------|------------------------------|
| kafka-clients | Implements Kafka producer/consumer protocol; enables distributed message broker pattern critical to architecture | Writing custom Kafka protocol client would take weeks and obscure learning objectives; Kafka is infrastructure, not application logic |
| cassandra-driver-core | Provides CQL (Cassandra Query Language) execution and connection pooling; enables distributed database access | Raw CQL-over-TCP implementation would require understanding Cassandra's binary protocol; driver is thin wrapper around CQL (students still write queries) |
| java-jwt (Auth0) | Generates and validates JWT tokens per RFC 7519; minimal library (single purpose) | Manual JWT implementation requires understanding HMAC-SHA256, Base64URL encoding - orthogonal to distributed systems learning; well-documented library preserves didactic clarity |

## Phase 0: Architecture Research & Design

**Goal**: Understand Cassandra query patterns, Kafka partitioning, and Java HTTP server setup before writing code.

**Activities**:

1. **Research Cassandra Schema Design** (query-driven modeling)
   - Research: How to design tables for write-heavy workload (messages)
   - Research: Partition key selection (conversation_id ensures even distribution)
   - Research: Clustering key (timestamp for chronological ordering)
   - Research: Replication strategy (NetworkTopologyStrategy with RF=2)
   - Output: `data-model.md` with schema DDL and rationale

2. **Research Kafka Partitioning Strategy**
   - Research: How partition keys guarantee ordering (same conversation_id → same partition)
   - Research: Consumer group coordination and rebalancing
   - Research: At-least-once delivery semantics and idempotency patterns
   - Output: Section in `research.md` explaining partitioning with diagrams

3. **Research Java HTTP Server Implementation**
   - Research: `com.sun.net.httpserver.HttpServer` API (JDK built-in)
   - Research: Thread pool configuration for handling concurrent requests
   - Research: Request routing patterns without frameworks
   - Output: Code example in `research.md` showing basic HTTP server setup

4. **Document Kafka Message Contract**
   - Define: JSON schema for `NEW_MESSAGE` event
   - Define: Required fields (message_id, conversation_id, sender_id, content, timestamp)
   - Output: `contracts/kafka-events.md` with schema and validation rules

5. **Document API Endpoint Contracts**
   - Define: Request/response schemas for POST /v1/messages and GET /v1/conversations/{id}/messages
   - Define: Error response format (status codes, error messages)
   - Output: `contracts/api-endpoints.md` with examples

6. **Create ADR for No-Framework Decision**
   - Document: Why avoiding Spring Boot (hides HTTP, DI, too much magic)
   - Document: Educational benefit of manual implementation
   - Output: `docs/adr/001-no-frameworks.md`

**Deliverables**:
- `research.md` (Cassandra, Kafka, Java HTTP research)
- `data-model.md` (Cassandra schema with rationale)
- `contracts/kafka-events.md` (Kafka message schema)
- `contracts/api-endpoints.md` (REST API contracts)
- `docs/adr/001-no-frameworks.md` (Architecture decision)

## Phase 1: Project Setup & Infrastructure

**Goal**: Establish project structure, dependencies, and Docker Compose environment.

**Activities**:

1. **Create Maven Multi-Module Project**
   - Create parent `pom.xml` with dependency management
   - Create `api-service/pom.xml` with kafka-clients, java-jwt dependencies
   - Create `router-worker/pom.xml` with kafka-clients, cassandra-driver dependencies
   - Configure Java 17 compilation target
   - Add JUnit 5 and AssertJ for testing

2. **Setup Docker Compose Environment**
   - Define Kafka service (single broker for Phase 1 simplicity)
   - Define Zookeeper service (required by Kafka)
   - Define Cassandra service (single node with RF=2 once scaled)
   - Define api-service (build from Dockerfile, ports 8080, 8081)
   - Define router-worker (build from Dockerfile, no exposed ports)
   - Configure network and volumes

3. **Create Cassandra Schema Initialization**
   - Write `cassandra-init/schema.cql` with:
     - CREATE KEYSPACE chat4all WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 2}
     - CREATE TABLE messages (conversation_id UUID, timestamp TIMESTAMP, message_id UUID, sender_id UUID, content TEXT, status TEXT, PRIMARY KEY (conversation_id, timestamp))
     - CREATE TABLE conversations (conversation_id UUID PRIMARY KEY, participant_ids LIST<UUID>, created_at TIMESTAMP)
   - Add init-container or startup script to execute schema

4. **Create Dockerfile for api-service**
   - Base image: openjdk:17-slim
   - Copy compiled JAR
   - EXPOSE 8080
   - CMD to run Main class

5. **Create Dockerfile for router-worker**
   - Base image: openjdk:17-slim
   - Copy compiled JAR
   - CMD to run Main class

6. **Setup Logging Utility**
   - Create `shared/Logger.java` with structured logging (JSON format)
   - Log levels: INFO, WARN, ERROR
   - Include trace_id, conversation_id, message_id in context

7. **Write README.md with Quickstart**
   - Prerequisites: Docker, Docker Compose, Java 17, Maven
   - Commands: `mvn clean package`, `docker-compose up`, test endpoints with curl
   - Output: `README.md` in root

**Deliverables**:
- Maven project structure with `pom.xml` files
- `docker-compose.yml` with Kafka, Cassandra, services
- `cassandra-init/schema.cql`
- Dockerfiles for both services
- `README.md` with setup instructions
- Compilable (but empty) project skeleton

## Phase 2: API Service - Authentication (User Story 3)

**Goal**: Implement JWT-based authentication to secure endpoints.

**Test-First Approach**:
1. Write `AuthEndpointTest.java` (integration test)
2. Write `JwtAuthenticatorTest.java` and `TokenGeneratorTest.java` (unit tests)
3. Run tests - **they must fail**
4. Implement code to make tests pass

**Activities**:

1. **Implement TokenGenerator.java**
   - Method: `generateToken(String userId)` returns JWT string
   - Use java-jwt library with HS256 algorithm
   - Include claims: user_id, issued_at, expires_at (1 hour)
   - Secret key from environment variable (configurable)
   - Add extensive comments explaining JWT structure

2. **Implement JwtAuthenticator.java**
   - Method: `validateToken(String token)` returns userId or throws exception
   - Verify signature using same secret key
   - Check expiration
   - Add comments explaining verification steps

3. **Implement AuthHandler.java**
   - Handle POST /auth/token
   - Request body: {"username": "...", "password": "..."}
   - For Phase 1: hardcoded test users (user_a: pass_a, user_b: pass_b)
   - Response: {"access_token": "...", "expires_in": 3600}
   - Return 401 for invalid credentials

4. **Integrate Authentication Middleware**
   - In `HttpRequestHandler.java`, extract Authorization header
   - Call `JwtAuthenticator.validateToken()` before routing to protected endpoints
   - Return 401 if token missing/invalid
   - Attach userId to request context

**Deliverables**:
- Tests: `AuthEndpointTest.java`, `JwtAuthenticatorTest.java`, `TokenGeneratorTest.java` (passing)
- Implementation: `TokenGenerator.java`, `JwtAuthenticator.java`, `AuthHandler.java`
- Documented JWT format and validation logic

## Phase 3: API Service - Message Sending (User Story 1, Part 1)

**Goal**: Accept POST /v1/messages, validate, publish to Kafka, return 202 Accepted.

**Test-First Approach**:
1. Write `MessagesEndpointTest.java` (integration test with embedded Kafka)
2. Write `MessageValidatorTest.java` (unit test)
3. Write `KafkaMessageSchemaTest.java` (contract test)
4. Run tests - **they must fail**
5. Implement code to make tests pass

**Activities**:

1. **Implement MessageValidator.java**
   - Method: `validate(MessageRequest request)` throws ValidationException if invalid
   - Validations:
     - conversation_id is valid UUID
     - content is non-empty, max 10KB
     - sender_id matches authenticated user
   - Add comments explaining validation rules

2. **Implement KafkaMessageProducer.java**
   - Initialize KafkaProducer in constructor (config from env vars)
   - Method: `publishMessage(MessageEvent event)` sends to "messages" topic
   - Use conversation_id as partition key (explain in comments why this preserves order)
   - Handle send errors (log and throw)
   - Add shutdown hook to close producer gracefully

3. **Define MessageEvent.java (Kafka event POJO)**
   - Fields: message_id (UUID), conversation_id (UUID), sender_id (UUID), content (String), timestamp (ISO-8601), event_type ("NEW_MESSAGE")
   - Method: `toJson()` serializes to JSON string
   - Method: `fromJson(String)` deserializes from JSON
   - Add comments explaining event structure

4. **Implement MessagesHandler.java**
   - Handle POST /v1/messages
   - Parse JSON request body
   - Validate using MessageValidator
   - Generate unique message_id (UUID.randomUUID())
   - Create MessageEvent
   - Publish to Kafka via KafkaMessageProducer
   - Return 202 Accepted with {"status": "accepted", "message_id": "..."}
   - Handle errors: 400 for validation, 503 if Kafka unavailable

5. **Wire up HTTP Server Routes**
   - In `Main.java`, create HttpServer on port 8080
   - Register `/v1/messages` → MessagesHandler
   - Register `/auth/token` → AuthHandler
   - Start server with fixed thread pool (Executors.newFixedThreadPool(10))
   - Add comments explaining stateless design

**Deliverables**:
- Tests: `MessagesEndpointTest.java`, `MessageValidatorTest.java`, `KafkaMessageSchemaTest.java` (passing)
- Implementation: `MessageValidator.java`, `KafkaMessageProducer.java`, `MessageEvent.java`, `MessagesHandler.java`
- Runnable API service that accepts messages and publishes to Kafka
- ADR: `docs/adr/003-kafka-partitioning-strategy.md` explaining partition key choice

## Phase 4: Router Worker - Message Processing (User Story 1, Part 2)

**Goal**: Consume messages from Kafka, persist to Cassandra, update status to DELIVERED.

**Test-First Approach**:
1. Write `KafkaToCassandraFlowTest.java` (integration test)
2. Write `MessageProcessorTest.java` (unit test)
3. Write `DeduplicationTest.java` (integration test)
4. Run tests - **they must fail**
5. Implement code to make tests pass

**Activities**:

1. **Implement CassandraConnection.java**
   - Initialize Cassandra Cluster and Session in constructor
   - Configuration from environment variables (contact points, port, keyspace)
   - Method: `getSession()` returns Session
   - Add shutdown hook to close cluster
   - Add comments explaining connection pooling

2. **Implement CassandraMessageStore.java**
   - Method: `saveMessage(MessageEntity message)` executes INSERT INTO messages
   - Use PreparedStatement for performance (explain in comments)
   - Method: `messageExists(UUID messageId)` checks for duplicates (idempotency)
   - Method: `updateMessageStatus(UUID messageId, String status)` executes UPDATE
   - Add retry logic with exponential backoff for Cassandra failures
   - Add comments explaining denormalization and partition key strategy

3. **Implement MessageEntity.java**
   - Fields: conversation_id, timestamp, message_id, sender_id, content, status
   - Constructor from MessageEvent
   - Add comments linking to Cassandra schema

4. **Implement DeduplicationChecker.java**
   - Method: `isDuplicate(UUID messageId)` queries Cassandra
   - Cache recent message IDs in-memory (ConcurrentHashMap with TTL) for performance
   - Add comments explaining at-least-once delivery and why dedup is necessary

5. **Implement MessageProcessor.java**
   - Method: `process(MessageEvent event)` orchestrates the workflow:
     1. Check for duplicate (skip if exists)
     2. Create MessageEntity with status = "SENT"
     3. Save to Cassandra
     4. Simulate delivery (sleep 100ms)
     5. Update status to "DELIVERED"
   - Wrap in try-catch with logging
   - Add extensive comments explaining store-and-forward pattern

6. **Implement KafkaMessageConsumer.java**
   - Initialize KafkaConsumer in constructor (subscribe to "messages" topic)
   - Consumer group: "router-worker-group"
   - Enable auto-commit: false (manual commit after processing)
   - Method: `startConsuming()` enters infinite loop:
     - Poll messages
     - For each message, call MessageProcessor.process()
     - Commit offset after successful processing
     - Log errors and continue (resilience)
   - Add shutdown hook
   - Add comments explaining consumer group coordination and partition assignment

7. **Implement Main.java for router-worker**
   - Initialize CassandraConnection
   - Initialize KafkaMessageConsumer
   - Call startConsuming() (blocks)
   - Add shutdown hooks for graceful termination

**Deliverables**:
- Tests: `KafkaToCassandraFlowTest.java`, `MessageProcessorTest.java`, `DeduplicationTest.java` (passing)
- Implementation: All worker classes listed above
- Runnable router-worker that consumes from Kafka and persists to Cassandra
- ADR: `docs/adr/002-cassandra-schema-design.md` explaining partition key and clustering key decisions

## Phase 5: API Service - Message Retrieval (User Story 4)

**Goal**: Implement GET /v1/conversations/{id}/messages to query message history.

**Test-First Approach**:
1. Write `ConversationsEndpointTest.java` (integration test)
2. Run tests - **they must fail**
3. Implement code to make tests pass

**Activities**:

1. **Add Query Method to CassandraMessageStore**
   - Method: `getMessages(UUID conversationId, int limit, Timestamp sinceTimestamp)`
   - Execute: SELECT * FROM messages WHERE conversation_id = ? AND timestamp > ? ORDER BY timestamp ASC LIMIT ?
   - Return List<MessageEntity>
   - Add comments explaining Cassandra query patterns (partition key + clustering key)

2. **Implement ConversationsHandler.java**
   - Handle GET /v1/conversations/{id}/messages
   - Extract conversation_id from path
   - Parse query params: limit (default 50), since (optional timestamp)
   - Query Cassandra via CassandraMessageStore (injected or singleton)
   - Return JSON array of messages
   - Handle errors: 400 for invalid UUID, 404 if conversation doesn't exist (optional check)

3. **Share CassandraMessageStore with API Service**
   - Option 1: Duplicate class in api-service (simple, no shared module complexity)
   - Option 2: Move to `shared` module (cleaner but adds complexity)
   - Choose Option 1 for simplicity, document in ADR
   - Add comments explaining trade-off

4. **Wire up Route in API Service**
   - Register `/v1/conversations/{id}/messages` → ConversationsHandler

**Deliverables**:
- Tests: `ConversationsEndpointTest.java` (passing)
- Implementation: Query method in CassandraMessageStore, ConversationsHandler
- Functional message retrieval endpoint

## Phase 6: Conversation Management (User Story 2)

**Goal**: Implement POST /v1/conversations to create conversations (minimal for Phase 1).

**Test-First Approach**:
1. Write `CreateConversationTest.java` (integration test)
2. Run tests - **they must fail**
3. Implement code to make tests pass

**Activities**:

1. **Add Conversation Methods to Cassandra Store**
   - Method: `createConversation(UUID conversationId, List<UUID> participantIds)`
   - Execute: INSERT INTO conversations (conversation_id, participant_ids, created_at) VALUES (?, ?, ?)
   - Method: `conversationExists(UUID conversationId)` for idempotency check

2. **Implement CreateConversationHandler.java**
   - Handle POST /v1/conversations
   - Request body: {"participants": ["user_id_1", "user_id_2"]}
   - Generate conversation_id (UUID)
   - Check if conversation already exists (optional: query by participants - complex, skip for Phase 1)
   - Save to Cassandra
   - Return {"conversation_id": "..."}

3. **Wire up Route**
   - Register `/v1/conversations` → CreateConversationHandler

**Deliverables**:
- Tests: `CreateConversationTest.java` (passing)
- Implementation: Conversation methods, CreateConversationHandler
- Functional conversation creation endpoint

## Phase 7: Horizontal Scalability Demonstration (User Story 5)

**Goal**: Prove system scales horizontally by running multiple instances.

**Activities**:

1. **Update docker-compose.yml for Scaling**
   - Ensure api-service and router-worker have no hard-coded single-instance assumptions
   - Use load balancer (nginx or round-robin DNS) for api-service (optional: docker-compose can expose multiple ports)

2. **Create scale-demo.sh Script**
   - Start system: `docker-compose up -d`
   - Scale API: `docker-compose up -d --scale api-service=3`
   - Scale Worker: `docker-compose up -d --scale router-worker=3`
   - Send 100 messages to different conversations using curl loop
   - Query Kafka consumer group status: `kafka-consumer-groups --describe --group router-worker-group`
   - Verify partition distribution across workers
   - Query Cassandra to confirm all messages persisted
   - Document output showing: multiple API instances handling requests, multiple workers consuming from different partitions

3. **Create Load Test Script**
   - Use curl in bash loop or JMeter (prefer curl for simplicity)
   - Send 1000 messages over 10 seconds
   - Measure: throughput (msgs/sec), latency (API response time)
   - Document results in `docs/load-test-results.md`

4. **Document Scalability Patterns**
   - Update README with scaling instructions
   - Create `docs/scalability-guide.md` explaining:
     - Why API is stateless (no session affinity needed)
     - How Kafka partitioning preserves message order
     - How Cassandra distributes data by partition key
     - How to add more instances without downtime

**Deliverables**:
- `scripts/scale-demo.sh` (executable demo script)
- `scripts/load-test.sh` (simple load test)
- `docs/scalability-guide.md` (scalability explanation)
- `docs/load-test-results.md` (test results with screenshots)
- Updated README with scaling instructions

## Phase 8: Documentation & Polish

**Goal**: Finalize documentation, code comments, and prepare for delivery.

**Activities**:

1. **Code Review for Educational Quality**
   - Review every class for comments explaining distributed systems concepts
   - Ensure maximum method complexity ≤ 10 (use linter or manual check)
   - Add JavaDoc to all public methods
   - Add package-level documentation (package-info.java) explaining module purpose

2. **Complete Architecture Decision Records**
   - Finalize all ADRs (if missing):
     - 001-no-frameworks.md
     - 002-cassandra-schema-design.md
     - 003-kafka-partitioning-strategy.md
     - 004-jwt-authentication.md
     - 005-json-parsing-approach.md

3. **Create Quickstart Guide**
   - `specs/001-basic-messaging-api/quickstart.md` with:
     - Step-by-step setup (prerequisites, build, run)
     - Example curl commands for all endpoints
     - Expected responses
     - Troubleshooting common issues

4. **Update README.md**
   - Architecture overview with link to esqueleto.md diagrams
   - Technology choices and rationale
   - Quick start (single command: `./scripts/start.sh`)
   - Link to quickstart.md for details
   - Link to API documentation (contracts/api-endpoints.md)

5. **Create Demo Script**
   - `scripts/demo.sh` that:
     - Starts system
     - Creates two users
     - Authenticates both users
     - User A sends message to User B
     - User B retrieves messages
     - Shows message status (SENT → DELIVERED)
     - Outputs clear step-by-step explanation

6. **Verify All Tests Pass**
   - Run `mvn clean test` (all tests must pass)
   - Run integration tests with docker-compose test environment
   - Generate test coverage report (optional: JaCoCo plugin)

7. **Create Final Delivery Checklist**
   - Verify alignment with entrega1.md requirements:
     - ✅ POST /v1/messages implemented
     - ✅ GET /v1/conversations/{id}/messages implemented
     - ✅ JWT authentication implemented
     - ✅ Kafka integration with conversation_id partitioning
     - ✅ Cassandra persistence with SENT/DELIVERED status
     - ✅ Router worker consuming and processing
     - ✅ Docker Compose setup
     - ✅ Documentation complete
     - ✅ Demo script showing two users exchanging messages
     - ✅ Logs demonstrating message flow

**Deliverables**:
- Fully commented codebase (educational quality)
- Complete ADRs in docs/adr/
- `quickstart.md` guide
- Updated README.md
- `scripts/demo.sh` demonstrating end-to-end flow
- All tests passing
- Delivery checklist verified

## Dependencies & Execution Order

### Phase Dependencies
- **Phase 0 (Research)**: No dependencies - start immediately
- **Phase 1 (Setup)**: Depends on Phase 0 (need schema design from data-model.md)
- **Phase 2 (Auth)**: Depends on Phase 1 (need project structure)
- **Phase 3 (API Send)**: Depends on Phase 2 (need auth for protected endpoints)
- **Phase 4 (Worker)**: Can start in parallel with Phase 3 (independent microservice)
- **Phase 5 (API Retrieve)**: Depends on Phase 4 (need Cassandra store implementation)
- **Phase 6 (Conversations)**: Depends on Phase 5 (uses same Cassandra patterns)
- **Phase 7 (Scalability)**: Depends on Phases 3-6 (need complete system)
- **Phase 8 (Documentation)**: Depends on all phases (final polish)

### Parallelization Opportunities
- **After Phase 1 completes**: Phase 2 (Auth) and Phase 4 (Worker) can proceed in parallel if two developers available
- **After Phase 3 completes**: Phase 5 (API Retrieve) and Phase 6 (Conversations) can proceed in parallel (different endpoints)

### Critical Path
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 5 → Phase 7 → Phase 8
(Phases 4 and 6 can happen in parallel but must complete before Phase 7)

## Implementation Strategy

### MVP First (Minimal Viable Product)
1. Phase 0-1: Setup (2-3 days)
2. Phase 2-3: Auth + Send Messages (2-3 days) → **First testable milestone**
3. Phase 4: Worker (2 days) → **End-to-end message flow working**
4. Phase 5: Retrieve Messages (1 day) → **Complete API**
5. Phase 6-7: Conversations + Scaling (2 days) → **Full Phase 1 scope**
6. Phase 8: Polish (1 day) → **Delivery ready**

Total estimated effort: 10-12 days for single developer, 7-8 days with pair

### Validation Checkpoints
- After Phase 3: Can send message via API, see it in Kafka (use kafka-console-consumer)
- After Phase 4: Can send message via API, see it persisted in Cassandra (use cqlsh)
- After Phase 5: Can send and retrieve messages (complete cycle)
- After Phase 7: Can scale to 3x3 instances and demonstrate linear throughput increase

## Notes

**Educational Focus Areas** (ensure these are well-commented):
- Kafka partitioning preserves ordering per conversation
- Cassandra partition key distributes data, clustering key orders within partition
- At-least-once delivery requires idempotency (deduplication by message_id)
- Stateless services enable horizontal scaling
- Eventual consistency trade-offs (explain in comments where relevant)

**Simplifications for Phase 1** (explicitly document):
- No user registration system (hardcoded test users for auth)
- No group conversations (only 1:1, as per entrega1.md scope)
- No read receipts (only SENT/DELIVERED status)
- No real-time push (store-and-forward only)
- Single Kafka broker (no clustering for local dev simplicity)
- Single Cassandra node initially (scale to 3 nodes optional)

**Alignment with esqueleto.md**:
- ✅ API Gateway → api-service HttpServer (authentication, validation)
- ✅ Frontend Service → api-service handlers (stateless, enqueue to Kafka)
- ✅ Message Broker → Kafka (event-driven, partitioned)
- ✅ Router Worker → router-worker (consume, persist, update status)
- ✅ Message Store → Cassandra (distributed NoSQL, partition by conversation_id)
- ⚠️  Simplified: No separate API Gateway, Metadata DB, Presence Service in Phase 1

**Next Step**: Run `/speckit.tasks 001-basic-messaging-api` to break down into granular task list.
