# Tasks: Basic Messaging API

**Input**: Design documents from `/specs/001-basic-messaging-api/`
**Prerequisites**: plan.md (required), spec.md (required for user stories)

**Language**: Java 17 with minimal dependencies (kafka-clients, cassandra-driver-core, java-jwt)
**Architecture**: Event-driven microservices (API Service + Router Worker)
**Tests**: Test-First discipline - all tests written BEFORE implementation

## Format: `- [ ] [ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Java multi-module Maven project:
- `api-service/src/main/java/chat4all/api/` - API service code
- `router-worker/src/main/java/chat4all/worker/` - Worker service code
- `api-service/src/test/java/chat4all/api/` - API tests
- `router-worker/src/test/java/chat4all/worker/` - Worker tests

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, Docker Compose, Cassandra schema, Maven structure

- [X] T001 Create Maven multi-module project structure with parent pom.xml, api-service module, and router-worker module
- [X] T002 [P] Configure parent pom.xml with Java 17, dependency management (kafka-clients, cassandra-driver-core, java-jwt, JUnit 5)
- [X] T003 [P] Create api-service/pom.xml with dependencies: kafka-clients, java-jwt, org.json, JUnit 5, AssertJ
- [X] T004 [P] Create router-worker/pom.xml with dependencies: kafka-clients, cassandra-driver-core, JUnit 5, AssertJ
- [X] T005 Create Cassandra schema in cassandra-init/schema.cql with keyspace chat4all, messages table (partition key: conversation_id, clustering: timestamp), conversations table, users table
- [X] T006 [P] Create docker-compose.yml with services: zookeeper, kafka, cassandra, api-service (ports 8080-8081), router-worker
- [X] T007 [P] Create Dockerfile for api-service (openjdk:17-slim, copy JAR, EXPOSE 8080, run Main)
- [X] T008 [P] Create Dockerfile for router-worker (openjdk:17-slim, copy JAR, run Main)
- [X] T009 Create shared/src/main/java/chat4all/shared/Logger.java for structured logging with trace_id, conversation_id, message_id context
- [X] T010 [P] Create shared/src/main/java/chat4all/shared/MessageEvent.java POJO (message_id, conversation_id, sender_id, content, timestamp, event_type)
- [X] T011 Create README.md with quickstart instructions: prerequisites (Docker, Maven, Java 17), build command, docker-compose up, test curl commands
- [X] T012 Create docs/adr/001-no-frameworks.md documenting decision to avoid Spring Boot for educational transparency

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T013 Implement shared/src/main/java/chat4all/shared/Constants.java with Kafka topic names, default ports, JWT secret env var name
- [X] T014 Create api-service/src/main/java/chat4all/api/util/JsonParser.java for manual JSON parsing (educate on serialization) with methods: parseRequest, toJson
- [X] T015 [P] Create api-service/src/main/java/chat4all/api/util/ValidationException.java custom exception for input validation errors
- [X] T016 [P] Create router-worker/src/main/java/chat4all/worker/util/RetryHandler.java with exponential backoff logic for Cassandra/Kafka retries
- [X] T017 Create cassandra-init script to execute schema.cql on container startup (add to docker-compose.yml init container or entrypoint)
- [ ] T018 Verify Maven build succeeds: mvn clean compile for all modules (NOTE: Maven not installed on this system - manual verification required by student)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 3 - Authenticate Users (Priority: P1) 🎯 MVP

**Goal**: Implement JWT-based authentication to secure all API endpoints

**Independent Test**: Call POST /auth/token with test credentials, receive JWT, use token to access protected endpoint, verify 401 without token

### Tests for User Story 3 ⚠️ WRITE TESTS FIRST

- [X] T019 [P] [US3] Write unit test AuthEndpointTest.java: testValidCredentialsReturnToken, testInvalidCredentialsReturn401
- [X] T020 [P] [US3] Write unit test JwtAuthenticatorTest.java: testValidateValidToken, testValidateExpiredToken, testValidateInvalidSignature
- [X] T021 [US3] Write unit test TokenGeneratorTest.java: testGenerateTokenWithUserId, testTokenContainsClaims, testTokenExpiration
- [ ] T022 [US3] Run tests - verify they FAIL (red phase of TDD)

### Implementation for User Story 3

- [X] T023 [P] [US3] Implement api-service/src/main/java/chat4all/api/auth/TokenGenerator.java with generateToken(String userId) method using java-jwt, HS256 algorithm, 1-hour expiration
- [X] T024 [P] [US3] Implement api-service/src/main/java/chat4all/api/auth/JwtAuthenticator.java with validateToken(String token) method, verify signature and expiration, throw exception if invalid
- [X] T025 [US3] Implement api-service/src/main/java/chat4all/api/http/AuthHandler.java handling POST /auth/token, hardcoded test users (user_a/pass_a, user_b/pass_b), return JWT token JSON
- [ ] T026 [US3] Add authentication middleware to api-service/src/main/java/chat4all/api/http/HttpRequestHandler.java: extract Authorization header, validate JWT, attach userId to context, return 401 if invalid
- [ ] T027 [US3] Run tests - verify they PASS (green phase), refactor code for clarity
- [ ] T028 [US3] Add extensive comments explaining JWT structure (header.payload.signature), HMAC-SHA256, Base64URL encoding, expiration claims

**Checkpoint**: At this point, authentication works independently - can obtain token and access protected endpoints

---

## Phase 4: User Story 1 - Send Messages (API Part) (Priority: P1) 🎯 MVP

**Goal**: Accept POST /v1/messages, validate, publish to Kafka, return 202 Accepted

**Independent Test**: Send message via POST /v1/messages with valid JWT, verify 202 response, check Kafka topic using kafka-console-consumer

### Tests for User Story 1 (API) ⚠️ WRITE TESTS FIRST

- [ ] T029 [P] [US1] Write integration test MessagesEndpointTest.java: testSendMessageReturns202, testSendMessagePublishesToKafka (use embedded Kafka or Testcontainers)
- [ ] T030 [P] [US1] Write unit test MessageValidatorTest.java: testValidateValidMessage, testValidateEmptyContent, testValidateOversizedContent, testValidateInvalidConversationId
- [ ] T031 [US1] Write contract test KafkaMessageSchemaTest.java: testMessageEventSerializesToJson, testMessageEventDeserializesFromJson, testRequiredFieldsPresent
- [ ] T032 [US1] Run tests - verify they FAIL (red phase of TDD)

### Implementation for User Story 1 (API)

- [X] T033 [P] [US1] Implement api-service/src/main/java/chat4all/api/validation/MessageValidator.java with validate(MessageRequest) method: check conversation_id UUID, content non-empty, max 10KB
- [X] T034 [US1] Implement api-service/src/main/java/chat4all/api/kafka/KafkaMessageProducer.java with constructor (KafkaProducer config from env), publishMessage(MessageEvent) using conversation_id as partition key
- [X] T035 [US1] Add methods to shared/MessageEvent.java: toJson() for serialization, fromJson(String) for deserialization
- [X] T036 [US1] Implement api-service/src/main/java/chat4all/api/http/MessagesHandler.java handling POST /v1/messages: parse JSON, validate, generate message_id UUID, create MessageEvent, publish to Kafka, return 202 with message_id
- [X] T037 [US1] Wire POST /v1/messages route in api-service/src/main/java/chat4all/api/Main.java HttpServer, ensure authentication middleware applied
- [ ] T038 [US1] Add error handling: 400 for validation errors, 503 if Kafka unavailable, log with trace_id and conversation_id
- [ ] T039 [US1] Run tests - verify they PASS (green phase), refactor for clarity
- [ ] T040 [US1] Add extensive comments explaining: Kafka partitioning by conversation_id preserves message order, at-least-once delivery semantics, event-driven architecture decoupling

**Checkpoint**: At this point, can send messages via API and see them published to Kafka topic

---

## Phase 5: User Story 1 - Process Messages (Worker Part) (Priority: P1) 🎯 MVP

**Goal**: Consume messages from Kafka, persist to Cassandra with SENT status, update to DELIVERED

**Independent Test**: Publish message to Kafka, verify worker consumes and persists to Cassandra, check status transitions

### Tests for User Story 1 (Worker) ⚠️ WRITE TESTS FIRST

- [ ] T041 [P] [US1] Write integration test KafkaToCassandraFlowTest.java: testConsumeMessageAndPersist, testStatusTransitionSentToDelivered (use Testcontainers for Kafka + Cassandra)
- [ ] T042 [P] [US1] Write unit test MessageProcessorTest.java: testProcessNewMessage, testProcessDuplicateMessage (should skip)
- [ ] T043 [US1] Write integration test DeduplicationTest.java: testDuplicateMessageIdIgnored, testCacheExpiration
- [ ] T044 [US1] Run tests - verify they FAIL (red phase of TDD)

### Implementation for User Story 1 (Worker)

- [ ] T045 [P] [US1] Implement router-worker/src/main/java/chat4all/worker/cassandra/CassandraConnection.java with cluster initialization, session management, config from env (contact points, port, keyspace), shutdown hook
- [ ] T046 [US1] Implement router-worker/src/main/java/chat4all/worker/cassandra/CassandraMessageStore.java with saveMessage(MessageEntity), updateMessageStatus(UUID, String), PreparedStatements for performance
- [ ] T047 [P] [US1] Implement router-worker/src/main/java/chat4all/worker/cassandra/MessageEntity.java POJO matching Cassandra schema (conversation_id, timestamp, message_id, sender_id, content, status)
- [ ] T048 [US1] Implement router-worker/src/main/java/chat4all/worker/processing/DeduplicationChecker.java with isDuplicate(UUID) querying Cassandra, in-memory cache (ConcurrentHashMap) with TTL for performance
- [ ] T049 [US1] Implement router-worker/src/main/java/chat4all/worker/processing/MessageProcessor.java with process(MessageEvent): check duplicate, create MessageEntity with status SENT, save to Cassandra, simulate delivery (sleep 100ms), update status to DELIVERED
- [ ] T050 [US1] Implement router-worker/src/main/java/chat4all/worker/kafka/KafkaMessageConsumer.java with KafkaConsumer initialization (subscribe to "messages" topic, consumer group "router-worker-group"), startConsuming() loop: poll, process, manual commit
- [ ] T051 [US1] Implement router-worker/src/main/java/chat4all/worker/Main.java entry point: initialize CassandraConnection, KafkaMessageConsumer, call startConsuming(), add shutdown hooks
- [ ] T052 [US1] Add retry logic with exponential backoff (using RetryHandler) for Cassandra write failures
- [ ] T053 [US1] Run tests - verify they PASS (green phase), refactor for clarity
- [ ] T054 [US1] Add extensive comments explaining: consumer group coordination, partition assignment, manual commit for at-least-once delivery, deduplication via message_id for idempotency, store-and-forward pattern

**Checkpoint**: At this point, User Story 1 (Send and Receive) is complete end-to-end - messages flow from API → Kafka → Worker → Cassandra

---

## Phase 6: User Story 4 - List Message History (Priority: P2)

**Goal**: Implement GET /v1/conversations/{id}/messages to query Cassandra and return paginated messages

**Independent Test**: Populate Cassandra with test messages, call GET endpoint with pagination params, verify correct ordering and filtering

### Tests for User Story 4 ⚠️ WRITE TESTS FIRST

- [ ] T055 [P] [US4] Write integration test ConversationsEndpointTest.java: testGetMessagesReturnsChronological, testGetMessagesWithPagination, testGetMessagesWithSinceTimestamp, testEmptyConversation
- [ ] T056 [US4] Run tests - verify they FAIL (red phase of TDD)

### Implementation for User Story 4

- [ ] T057 [US4] Add getMessages(UUID conversationId, int limit, Timestamp sinceTimestamp) method to router-worker CassandraMessageStore (or duplicate class in api-service for simplicity)
- [ ] T058 [US4] Create api-service/src/main/java/chat4all/api/cassandra/CassandraConnection.java (duplicate from worker for Phase 1 simplicity - document trade-off in ADR)
- [ ] T059 [US4] Create api-service/src/main/java/chat4all/api/cassandra/CassandraMessageStore.java with getMessages() querying Cassandra: SELECT * FROM messages WHERE conversation_id = ? AND timestamp > ? ORDER BY timestamp ASC LIMIT ?
- [ ] T060 [US4] Implement api-service/src/main/java/chat4all/api/http/ConversationsHandler.java handling GET /v1/conversations/{id}/messages: extract conversation_id from path, parse query params (limit, since), query Cassandra, return JSON array
- [ ] T061 [US4] Wire GET /v1/conversations/{id}/messages route in api-service Main.java, apply authentication middleware
- [ ] T062 [US4] Add error handling: 400 for invalid UUID, 404 if conversation not found (optional), log queries
- [ ] T063 [US4] Run tests - verify they PASS (green phase), refactor for clarity
- [ ] T064 [US4] Add comments explaining Cassandra query patterns: partition key + clustering key enables efficient range queries, ORDER BY timestamp works because it's the clustering key

**Checkpoint**: At this point, User Stories 1 AND 4 work independently - can send and retrieve messages

---

## Phase 7: User Story 2 - Create Conversations (Priority: P1) 🎯 MVP

**Goal**: Implement POST /v1/conversations to create conversations with unique conversation_id

**Independent Test**: Create conversation via POST /v1/conversations, verify conversation_id returned, verify idempotency (duplicate creation returns same ID)

### Tests for User Story 2 ⚠️ WRITE TESTS FIRST

- [ ] T065 [P] [US2] Write integration test CreateConversationTest.java: testCreateConversationReturnsId, testCreateConversationPersistsToC assandra, testIdempotency (optional - complex query)
- [ ] T066 [US2] Run tests - verify they FAIL (red phase of TDD)

### Implementation for User Story 2

- [ ] T067 [US2] Add createConversation(UUID conversationId, List<UUID> participantIds) method to api-service CassandraMessageStore: INSERT INTO conversations
- [ ] T068 [US2] Add conversationExists(UUID conversationId) method for idempotency check (optional - simplified for Phase 1)
- [ ] T069 [US2] Implement api-service/src/main/java/chat4all/api/http/CreateConversationHandler.java handling POST /v1/conversations: parse participants list, generate conversation_id UUID, save to Cassandra, return JSON with conversation_id
- [ ] T070 [US2] Wire POST /v1/conversations route in api-service Main.java, apply authentication middleware
- [ ] T071 [US2] Run tests - verify they PASS (green phase), refactor for clarity
- [ ] T072 [US2] Add comments explaining: conversation_id used as Kafka partition key for ordering, Cassandra partition key for distribution

**Checkpoint**: All P1 user stories (US1, US2, US3) are complete - full MVP functionality working

---

## Phase 8: User Story 5 - Horizontal Scalability Demo (Priority: P2)

**Goal**: Prove system scales horizontally by running multiple instances and measuring performance

**Independent Test**: Scale to 3x3 instances, send 1000 messages to different conversations, verify even partition distribution, measure throughput increase

### Tests for User Story 5

- [ ] T073 [US5] Create scripts/scale-demo.sh: start docker-compose, scale api-service=3 and router-worker=3, send 100 messages via curl loop to different conversations, query Kafka consumer group status, verify partition assignment across workers
- [ ] T074 [P] [US5] Create scripts/load-test.sh: send 1000 messages over 10 seconds using curl loop, measure throughput (msgs/sec) and latency (API response time)
- [ ] T075 [US5] Execute load test with 1 API + 1 Worker instance, record baseline throughput in docs/load-test-results.md
- [ ] T076 [US5] Execute load test with 2 API + 2 Worker instances, verify ~2x throughput (linear scaling), record results
- [ ] T077 [US5] Execute load test with 3 API + 3 Worker instances, verify ~3x throughput, record results

### Documentation for User Story 5

- [ ] T078 [US5] Create docs/scalability-guide.md explaining: why API is stateless (no session affinity), how Kafka partitioning preserves order, how Cassandra distributes data by partition key, how to add instances without downtime
- [ ] T079 [US5] Update README.md with scaling instructions: docker-compose up --scale api-service=N --scale router-worker=M
- [ ] T080 [US5] Create docs/adr/003-kafka-partitioning-strategy.md documenting conversation_id as partition key ensures ordered processing per conversation while enabling parallelism across conversations

**Checkpoint**: All user stories complete - system demonstrates horizontal scalability

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Finalize code quality, documentation, and delivery readiness

- [ ] T081 [P] Code review: verify all classes have extensive comments explaining distributed systems concepts (partitioning, eventual consistency, at-least-once delivery, idempotency)
- [ ] T082 [P] Code review: verify maximum method complexity ≤ 10 cyclomatic complexity using linter or manual check
- [ ] T083 [P] Add JavaDoc to all public methods in all classes with @param, @return, @throws annotations
- [ ] T084 Create package-info.java for each package explaining module purpose and key design decisions
- [ ] T085 [P] Create docs/adr/002-cassandra-schema-design.md documenting partition key (conversation_id) and clustering key (timestamp) decisions for query-driven design
- [ ] T086 [P] Create docs/adr/004-jwt-authentication.md documenting choice of simple JWT over OAuth for Phase 1 educational focus
- [ ] T087 Create specs/001-basic-messaging-api/quickstart.md with step-by-step setup, example curl commands for all endpoints, expected responses, troubleshooting
- [ ] T088 Update README.md with architecture overview (link to esqueleto.md diagrams), technology choices and rationale, quick start (./scripts/start.sh), link to API documentation
- [ ] T089 Create scripts/demo.sh that: starts system, authenticates two users, user_a sends message to user_b, user_b retrieves messages, shows status transitions (SENT → DELIVERED), outputs clear step-by-step explanation
- [ ] T090 Create scripts/start.sh wrapper for docker-compose up with pre-build Maven step
- [ ] T091 Run mvn clean test on all modules - verify 100% tests pass
- [ ] T092 Generate test coverage report using JaCoCo Maven plugin (optional but recommended)
- [ ] T093 Verify alignment with entrega1.md checklist: ✅ POST /v1/messages, ✅ GET /v1/conversations/{id}/messages, ✅ JWT auth, ✅ Kafka + conversation_id partitioning, ✅ Cassandra SENT/DELIVERED, ✅ Router worker, ✅ Docker Compose, ✅ Documentation, ✅ Demo script
- [ ] T094 [P] Create .gitignore with target/, .idea/, *.iml, .DS_Store, logs/
- [ ] T095 Final validation: run ./scripts/demo.sh and verify complete end-to-end flow works, capture console output for documentation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 3 (Phase 3)**: Depends on Foundational phase completion
- **User Story 1 API (Phase 4)**: Depends on US3 (needs auth middleware)
- **User Story 1 Worker (Phase 5)**: Depends on Foundational phase - can proceed in parallel with Phase 4 if two developers
- **User Story 4 (Phase 6)**: Depends on US1 Worker (needs Cassandra store implementation)
- **User Story 2 (Phase 7)**: Depends on Foundational phase - can proceed in parallel with Phase 6
- **User Story 5 (Phase 8)**: Depends on all P1 user stories (US1, US2, US3) completion
- **Polish (Phase 9)**: Depends on all phases completion

### User Story Dependencies

- **US3 (Auth)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **US1 (Send/Receive)**: Depends on US3 (needs auth) - Split into API (Phase 4) and Worker (Phase 5) parts
- **US4 (List History)**: Depends on US1 Worker (reuses Cassandra patterns) - Independently testable
- **US2 (Conversations)**: Depends on Foundational phase only - Can run parallel with US4
- **US5 (Scalability)**: Depends on US1, US2, US3 completion - Validates entire system

### Within Each User Story

- Tests MUST be written and FAIL before implementation (Test-First discipline)
- Unit tests before integration tests
- Implementation follows test-driven development (Red-Green-Refactor)
- Code comments added during implementation (not after)
- Story complete before moving to next priority

### Parallel Opportunities

- **Phase 1 (Setup)**: Tasks T002, T003, T004, T006, T007, T008, T010 can run in parallel (different files)
- **Phase 2 (Foundational)**: Tasks T015, T016 can run in parallel
- **Phase 3 (US3 Tests)**: Tasks T019, T020 can run in parallel
- **Phase 3 (US3 Impl)**: Tasks T023, T024 can run in parallel
- **Phase 4 (US1 API Tests)**: Tasks T029, T030 can run in parallel
- **Phase 4 (US1 API Impl)**: Tasks T033, T034 can run in parallel
- **Phase 5 (US1 Worker Tests)**: Tasks T041, T042 can run in parallel
- **Phase 5 (US1 Worker Impl)**: Tasks T045, T046, T047 can run in parallel
- **Phase 4 and Phase 5**: Can proceed in parallel if two developers (API and Worker are independent microservices)
- **Phase 6 and Phase 7**: Can proceed in parallel (different endpoints)
- **Phase 9 (Polish)**: Tasks T081, T082, T083, T084, T085, T086, T094 can run in parallel

---

## Parallel Example: User Story 1 (Send/Receive)

```bash
# Phase 4: API Part - Launch tests together
Task T029: "Write integration test MessagesEndpointTest.java"
Task T030: "Write unit test MessageValidatorTest.java"

# Phase 4: API Part - Launch implementation together
Task T033: "Implement MessageValidator.java"
Task T034: "Implement KafkaMessageProducer.java"

# Phase 5: Worker Part - Launch tests together
Task T041: "Write integration test KafkaToCassandraFlowTest.java"
Task T042: "Write unit test MessageProcessorTest.java"

# Phase 5: Worker Part - Launch implementation together
Task T045: "Implement CassandraConnection.java"
Task T046: "Implement CassandraMessageStore.java"
Task T047: "Implement MessageEntity.java"
```

---

## Implementation Strategy

### MVP First (User Stories 1, 2, 3 Only)

1. Complete Phase 1: Setup (2-3 days)
2. Complete Phase 2: Foundational (1 day) → **CRITICAL GATE**
3. Complete Phase 3: User Story 3 - Auth (1-2 days) → **Can authenticate**
4. Complete Phase 4: User Story 1 API (1-2 days) → **Can send messages to Kafka**
5. Complete Phase 5: User Story 1 Worker (2 days) → **End-to-end message flow working** 🎯 MVP
6. Complete Phase 7: User Story 2 (1 day) → **Conversations working**
7. Complete Phase 6: User Story 4 (1 day) → **Full P1 functionality**
8. **STOP and VALIDATE**: Test all P1 user stories independently

### Full Delivery (Include P2 Stories)

9. Complete Phase 8: User Story 5 - Scalability (2 days) → **Demonstrate horizontal scaling**
10. Complete Phase 9: Polish (1-2 days) → **Delivery ready**

Total estimated effort:
- MVP (P1 only): 8-10 days single developer, 5-6 days with pair
- Full delivery (P1 + P2): 12-14 days single developer, 8-9 days with pair
- Student learning pace: 3-4 weeks with study time

### Incremental Delivery Checkpoints

- **After Phase 3**: Auth works - can obtain JWT token
- **After Phase 4**: Can send message via API, see in Kafka (use kafka-console-consumer)
- **After Phase 5**: Can send message, see persisted in Cassandra with status transitions (use cqlsh)
- **After Phase 6**: Can retrieve message history
- **After Phase 7**: Can create conversations
- **After Phase 8**: Can demonstrate 3x3 scaling with linear throughput
- **After Phase 9**: Complete system ready for delivery and demonstration

### Validation at Each Checkpoint

- Run all tests: `mvn clean test`
- Verify docker-compose starts: `docker-compose up`
- Test with curl commands from quickstart.md
- Check logs for errors and correlation IDs
- Verify Cassandra data: `docker-compose exec cassandra cqlsh`
- Verify Kafka messages: `docker-compose exec kafka kafka-console-consumer --topic messages --bootstrap-server localhost:9092`

---

## Notes

**Educational Focus** (ensure extensive comments on):
- Kafka partitioning by conversation_id preserves ordering per conversation
- Cassandra partition key (conversation_id) distributes data across nodes
- Cassandra clustering key (timestamp) orders data within partition
- At-least-once delivery from Kafka requires idempotency (message_id deduplication)
- Stateless API services enable horizontal scaling (no session affinity)
- Eventual consistency trade-offs in Cassandra (document where relevant)
- Consumer group coordination and partition rebalancing
- Manual commit in Kafka consumer for reliability
- Store-and-forward pattern for offline message delivery

**Test-First Discipline** (strictly enforced):
- Every task with "Write test" MUST complete before "Implement" task
- Tests MUST fail when first written (red phase)
- Implementation MUST make tests pass (green phase)
- Refactor for clarity while keeping tests green
- No implementation without failing tests first

**Simplifications for Phase 1** (document in comments):
- Hardcoded test users (user_a/pass_a, user_b/pass_b) - no user registration
- Only 1:1 conversations (no group support in Phase 1)
- Only SENT/DELIVERED status (no READ receipts)
- No real-time push notifications (store-and-forward only)
- Single Kafka broker for local dev simplicity
- Duplicate CassandraMessageStore in API service (no shared module complexity)

**Alignment with esqueleto.md**:
- ✅ Frontend Service → api-service (stateless, HTTP handling, Kafka producer)
- ✅ Message Broker → Kafka (event-driven, partitioned by conversation_id)
- ✅ Router Worker → router-worker (Kafka consumer, business logic, Cassandra persistence)
- ✅ Message Store → Cassandra (distributed NoSQL, partition by conversation_id)
- ⚠️ Simplified: No separate API Gateway, Metadata DB, Presence Service in Phase 1

**Alignment with entrega1.md**:
- ✅ POST /v1/messages (send text) - Phase 4
- ✅ GET /v1/conversations/{id}/messages (list messages) - Phase 6
- ✅ JWT authentication (simple, static key) - Phase 3
- ✅ Kafka topic partitioned by conversation_id - Phase 4-5
- ✅ Cassandra persistence with SENT/DELIVERED status - Phase 5
- ✅ Router worker consuming and processing - Phase 5
- ✅ Docker Compose with Kafka and Cassandra - Phase 1
- ✅ Documentation (README, endpoints, architecture) - Phase 9
- ✅ Demo script showing two users exchanging messages - Phase 9

**Constitution Compliance**:
- ✅ Didactic Simplicity: Extensive comments, clear single responsibility classes
- ✅ Minimal Dependencies: Only 3 external libs (kafka-clients, cassandra-driver, java-jwt)
- ✅ Test-First Discipline: Tests before implementation in every phase
- ✅ Horizontal Scalability: Stateless services, Kafka partitioning, Docker Compose scaling
- ✅ Cassandra-First: Query-driven schema, partition keys, eventual consistency
- ✅ Incremental Delivery: Phased implementation, independent user stories
