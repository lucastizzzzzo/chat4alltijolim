# Feature Specification: Basic Messaging API

**Feature Branch**: `001-basic-messaging-api`  
**Created**: 2025-11-17  
**Status**: Draft  
**Input**: Platform for routing messages between users with multi-platform support, persistence, delivery control, and horizontal scalability

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Send and Receive Text Messages (Priority: P1) 🎯 MVP

A user wants to send a text message to another user and have it delivered reliably through the system, even if the recipient is offline.

**Why this priority**: This is the core functionality of any messaging platform. Without reliable message sending and receiving, nothing else matters. This story demonstrates the complete event-driven flow: API → Kafka → Worker → Cassandra.

**Independent Test**: Can be fully tested by sending a message via POST /v1/messages and retrieving it via GET /v1/conversations/{id}/messages. Delivers a working messaging system.

**Acceptance Scenarios**:

1. **Given** two authenticated users (user_a and user_b), **When** user_a sends a text message "Hello" to user_b, **Then** the message is accepted by the API with status 202 and published to Kafka
2. **Given** a message has been published to Kafka, **When** the router worker processes it, **Then** the message is persisted in Cassandra with status SENT and a unique message_id
3. **Given** a message is stored in Cassandra, **When** user_b requests their conversation messages, **Then** they receive the message with correct content, timestamp, sender, and status
4. **Given** user_b is offline when a message arrives, **When** the worker processes the message, **Then** it is stored with status PENDING for later delivery
5. **Given** a message is successfully delivered to the recipient's client, **When** delivery confirmation is received, **Then** the message status is updated to DELIVERED in Cassandra

---

### User Story 2 - Create and Manage Conversations (Priority: P1) 🎯 MVP

Users need to create private 1:1 conversations before exchanging messages, with each conversation having a unique identifier for message routing and partitioning.

**Why this priority**: Conversations are the foundation for message organization and Kafka partitioning. Without conversation_id, we cannot demonstrate proper message ordering or horizontal scalability through partitioning.

**Independent Test**: Can be tested by creating a conversation via POST /v1/conversations and verifying it's retrievable. Works independently from message sending.

**Acceptance Scenarios**:

1. **Given** two authenticated users (user_a and user_b), **When** user_a creates a conversation with user_b, **Then** a unique conversation_id is generated and returned
2. **Given** a conversation exists, **When** either participant requests conversation details, **Then** they receive conversation metadata (id, participants, created_at)
3. **Given** a conversation_id, **When** messages are sent in that conversation, **Then** all messages use the same conversation_id as the Kafka partition key
4. **Given** an attempt to create a duplicate conversation, **When** the same two users already have a conversation, **Then** the existing conversation_id is returned (idempotent)

---

### User Story 3 - Authenticate Users (Priority: P1) 🎯 MVP

Users must authenticate to send and receive messages, using a simple JWT-based authentication system.

**Why this priority**: Security baseline. Without authentication, we cannot associate messages with users or prevent unauthorized access. Simple JWT keeps implementation minimal per constitution.

**Independent Test**: Can be tested by calling POST /auth/token with credentials and using the token to access protected endpoints. Fully independent of messaging logic.

**Acceptance Scenarios**:

1. **Given** valid user credentials, **When** a user requests a token via POST /auth/token, **Then** a valid JWT token is returned with 1-hour expiration
2. **Given** an authenticated request with valid JWT, **When** accessing protected endpoints (/v1/messages, /v1/conversations), **Then** the request is authorized and processed
3. **Given** an expired or invalid JWT, **When** accessing protected endpoints, **Then** the request is rejected with 401 Unauthorized
4. **Given** a request without authentication header, **When** accessing protected endpoints, **Then** the request is rejected with 401 Unauthorized

---

### User Story 4 - List Conversation Message History (Priority: P2)

Users want to retrieve the complete history of messages in a conversation, paginated for performance.

**Why this priority**: Essential for user experience but secondary to sending/receiving. Can be added after core message flow works. Demonstrates Cassandra query patterns.

**Independent Test**: Populate Cassandra with test messages, then retrieve via GET /v1/conversations/{id}/messages with pagination parameters. Validates read path independently.

**Acceptance Scenarios**:

1. **Given** a conversation with 50 messages, **When** user requests messages with limit=20, **Then** the 20 most recent messages are returned with pagination metadata
2. **Given** a paginated request, **When** user provides since_timestamp parameter, **Then** only messages after that timestamp are returned
3. **Given** messages from multiple senders, **When** retrieving conversation history, **Then** messages are ordered chronologically (oldest to newest or newest to oldest based on parameter)
4. **Given** a conversation with no messages, **When** user requests message history, **Then** an empty list is returned with 200 OK

---

### User Story 5 - Demonstrate Horizontal Scalability (Priority: P2)

The system must demonstrate that multiple instances of API and worker services can run concurrently, with load distributed via Kafka partitioning.

**Why this priority**: Core learning objective from constitution. Not user-facing but critical for demonstrating distributed systems concepts. Can be validated after core functionality works.

**Independent Test**: Deploy multiple instances via Docker Compose scaling, send messages to different conversations, verify even distribution across workers and consistent message ordering per conversation.

**Acceptance Scenarios**:

1. **Given** 3 API service instances behind a load balancer, **When** clients send messages, **Then** requests are distributed across all instances without errors
2. **Given** 3 worker instances consuming from Kafka, **When** messages arrive in different partitions, **Then** workers process messages in parallel without conflicts
3. **Given** messages in the same conversation, **When** processed by different worker instances over time, **Then** message ordering is preserved (by conversation_id partitioning)
4. **Given** a worker instance failure, **When** Kafka rebalances partitions, **Then** another worker picks up the failed instance's partitions without message loss

---

### Edge Cases

- What happens when **Kafka is temporarily unavailable**? API should return 503 Service Unavailable, clients should retry
- What happens when **Cassandra is temporarily unavailable**? Worker should retry with exponential backoff, message remains in Kafka
- What happens when a **conversation_id is malformed**? API validates and rejects with 400 Bad Request before publishing to Kafka
- What happens with **concurrent message sends to same conversation**? Kafka ordering guarantees prevent races, workers process sequentially
- What happens when **JWT secret key changes**? All existing tokens invalidate, users must re-authenticate (documented limitation for Phase 1)
- What happens with **very long messages** (edge of reasonable size)? API validates max length (e.g., 10KB text) and rejects oversized messages

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST accept text messages via POST /v1/messages with conversation_id, sender, recipient, and text content
- **FR-002**: System MUST publish accepted messages to Kafka topic partitioned by conversation_id
- **FR-003**: System MUST persist messages in Cassandra with fields: message_id (UUID), conversation_id, sender_id, content, timestamp, status
- **FR-004**: System MUST support message status lifecycle: SENT → DELIVERED (Phase 1 scope)
- **FR-005**: System MUST provide GET /v1/conversations/{id}/messages endpoint returning messages in chronological order
- **FR-006**: System MUST authenticate users via JWT tokens obtained from POST /auth/token
- **FR-007**: System MUST create conversations with unique conversation_id via POST /v1/conversations
- **FR-008**: System MUST reject requests without valid JWT with 401 Unauthorized
- **FR-009**: System MUST validate message content (non-empty text, max 10KB size)
- **FR-010**: System MUST ensure idempotent message processing using message_id for deduplication
- **FR-011**: System MUST log all operations with correlation IDs (trace_id, conversation_id, message_id)
- **FR-012**: Worker services MUST consume from Kafka with at-least-once delivery guarantee
- **FR-013**: System MUST support running multiple instances of API and Worker services concurrently
- **FR-014**: System MUST preserve message ordering within a single conversation (via Kafka partitioning)
- **FR-015**: System MUST be deployable via single docker-compose up command

### Non-Functional Requirements

- **NFR-001**: API message acceptance latency MUST be < 200ms p95 (validation + Kafka publish)
- **NFR-002**: Worker processing latency MUST be < 500ms p95 (Kafka consume + Cassandra write)
- **NFR-003**: System MUST handle 1,000 messages/second per API instance
- **NFR-004**: System MUST demonstrate linear scalability (2x instances → ~2x throughput)
- **NFR-005**: Cassandra replication factor MUST be configurable (minimum 2)
- **NFR-006**: All errors MUST be logged with context (service name, trace_id, error type)
- **NFR-007**: All external calls (Kafka, Cassandra) MUST implement retry with exponential backoff
- **NFR-008**: Code MUST follow PEP 8 (Python) or Go fmt conventions
- **NFR-009**: Maximum cyclomatic complexity per function MUST be ≤ 10
- **NFR-010**: All public APIs MUST have docstrings with parameters and return values

### Key Entities *(include if feature involves data)*

- **User**: Represents a system user; attributes: user_id (UUID), username (string), password_hash (string), created_at (timestamp)
- **Conversation**: Represents a 1:1 or group chat; attributes: conversation_id (UUID), type (private/group), participant_ids (list of user_ids), created_at (timestamp)
- **Message**: Represents a single message; attributes: message_id (UUID), conversation_id (UUID), sender_id (UUID), content (text), timestamp (timestamp), status (SENT/DELIVERED/READ)
- **KafkaEvent**: Internal event structure; attributes: event_id (UUID), event_type (NEW_MESSAGE), conversation_id (partition key), payload (Message data), timestamp

**Relationships**:
- A User can participate in multiple Conversations (many-to-many)
- A Conversation contains multiple Messages (one-to-many)
- A Message belongs to exactly one Conversation and one sender User
- Each Message generates one KafkaEvent for processing

**Cassandra Schema Considerations** (following query-driven design):
- Messages table: Partition key = conversation_id, Clustering key = timestamp (for ordering)
- Conversations table: Partition key = conversation_id
- Users table: Partition key = user_id

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Two users can exchange messages end-to-end (send + receive) within 1 second under normal conditions
- **SC-002**: System successfully processes 1,000 messages in under 10 seconds with single API + single worker instance
- **SC-003**: When scaled to 2 API instances + 2 worker instances, system processes 2,000 messages in under 10 seconds (demonstrates linear scaling)
- **SC-004**: Message ordering is preserved: 100 messages sent sequentially in same conversation arrive in correct order 100% of the time
- **SC-005**: System survives worker restart: messages sent during restart are not lost and are processed after worker recovers
- **SC-006**: All automated tests (unit, integration, contract) pass with 100% success rate
- **SC-007**: Docker Compose deployment starts all services (API, Worker, Kafka, Cassandra) successfully in under 60 seconds
- **SC-008**: API returns 202 Accepted within 200ms for 95% of message submissions (p95 latency)
- **SC-009**: README documentation enables a new student to run the system and send test messages within 10 minutes
- **SC-010**: No silent failures: all errors are logged with sufficient context to debug (trace_id, conversation_id visible in logs)

## Out of Scope (Phase 1)

The following are explicitly **NOT** included in this phase per constitution's Incremental Delivery principle:

- ❌ File uploads (2GB support) - deferred to Phase 2
- ❌ External platform connectors (WhatsApp, Instagram, Telegram) - deferred to Phase 2
- ❌ Group conversations (n-participants) - only 1:1 private conversations in Phase 1
- ❌ Read receipts (READ status) - only SENT/DELIVERED in Phase 1
- ❌ Real-time push notifications / WebSockets - deferred to Phase 2
- ❌ Message search functionality - deferred to later phases
- ❌ User registration system - use pre-configured test users
- ❌ Production-grade monitoring (Prometheus/Grafana) - basic logging only in Phase 1
- ❌ Distributed tracing (OpenTelemetry) - deferred to Phase 2

## Technical Constraints

Following the constitution:

- **Minimal Dependencies**: Use Python standard library + cassandra-driver + kafka-python + PyJWT only
- **No ORM**: Direct Cassandra queries using cassandra-driver
- **No Web Framework**: Use Python's built-in http.server or Go's net/http (no Flask, FastAPI, Django)
- **Test-First**: All tests written before implementation
- **Docker Compose**: Single command deployment
- **Documentation**: Every function documented, architecture decisions in /docs/adr/

## Next Steps

1. Run `/speckit.plan 001-basic-messaging-api` to generate implementation plan
2. Review plan.md and validate Technical Context matches constitution
3. Run `/speckit.tasks 001-basic-messaging-api` to generate task breakdown
4. Begin Phase 1 implementation following Test-First discipline
