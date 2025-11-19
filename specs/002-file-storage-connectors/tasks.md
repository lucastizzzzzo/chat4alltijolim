# Tasks: File Storage & External Connectors

**Input**: Design documents from `/specs/002-file-storage-connectors/`
**Prerequisites**: plan.md (required), spec.md (required for user stories)
**Depends On**: 001-basic-messaging-api (MUST be 100% complete)

**Language**: Java 17 with MinIO SDK
**Architecture**: Object Storage + Plugin-based Connectors
**Tests**: Test-First discipline - observe behavior, then implement

## Format: `- [ ] [ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US4-US8)
- Include exact file paths in descriptions

---

## Phase 1: Object Storage Setup (MinIO)

**Purpose**: Configure S3-compatible storage for files up to 2GB

- [ ] T101 [P] [SETUP] Add MinIO service to docker-compose.yml (image: minio/minio:latest, ports: 9000, 9001, volumes: ./data/minio, environment: MINIO_ROOT_USER, MINIO_ROOT_PASSWORD)
- [ ] T102 [P] [SETUP] Create minio-init/ directory with setup script to create bucket "chat4all-files" and set access policy
- [ ] T103 [SETUP] Update cassandra-init/schema.cql with CREATE TABLE files (file_id, conversation_id, uploader_id, filename, size_bytes, mimetype, checksum, storage_path, uploaded_at) and INDEX on conversation_id
- [ ] T104 [P] [SETUP] Add MinIO Java SDK dependency to api-service/pom.xml (io.minio:minio:8.5.7)
- [ ] T105 [SETUP] Create shared/src/main/java/chat4all/shared/FileEvent.java POJO (file_id, conversation_id, uploader_id, filename, size_bytes, mimetype, checksum, storage_path, uploaded_at)
- [ ] T106 [SETUP] Test MinIO connectivity: start docker-compose, access http://localhost:9001, verify bucket creation

---

## Phase 2: File Upload API (US4)

**Purpose**: Implement POST /v1/files/upload with multipart support and streaming

- [ ] T107 [US4] Create api-service/src/main/java/chat4all/api/storage/MinioClientFactory.java singleton (endpoint: minio:9000, credentials from env vars)
- [ ] T108 [US4] Create api-service/src/main/java/chat4all/api/storage/FileUploadHandler.java class with handle(HttpExchange) method parsing multipart/form-data headers
- [ ] T109 [US4] Implement FileUploadHandler.parseMultipartBoundary(HttpExchange) to extract boundary from Content-Type header
- [ ] T110 [US4] Implement FileUploadHandler.streamToMinIO(InputStream, String fileId, String conversationId) using MinioClient.putObject() with streaming
- [ ] T111 [US4] Implement FileUploadHandler.calculateChecksum(InputStream) using MessageDigest SHA256 while streaming to MinIO
- [ ] T112 [US4] Create api-service/src/main/java/chat4all/api/cassandra/FileRepository.java with insertFile(FileEvent) method using prepared statement
- [ ] T113 [US4] Implement FileUploadHandler response: return JSON with file_id, checksum, size_bytes, storage_path (201 Created)
- [ ] T114 [US4] Add file size validation: reject if > 2GB (2_147_483_648 bytes) with 413 Payload Too Large
- [ ] T115 [US4] Add mimetype validation: check against allowed list (image/*, application/pdf, video/*, application/zip) - optional but recommended
- [ ] T116 [US4] Register POST /v1/files/upload endpoint in api-service/src/main/java/chat4all/api/Main.java with FileUploadHandler
- [ ] T117 [P] [US4] Write test api-service/src/test/java/chat4all/api/storage/FileUploadHandlerTest.java with testUpload1MBFile()
- [ ] T118 [P] [US4] Write test FileUploadHandlerTest.testUpload100MBFile() verifying checksum matches
- [ ] T119 [P] [US4] Write test FileUploadHandlerTest.testUpload2_5GBFile() expecting 413 error
- [ ] T120 [US4] Create scripts/test-file-upload.sh: create 10MB test file with dd, upload via curl multipart, verify response contains file_id
- [ ] T121 [US4] Manual validation: upload file, check MinIO Console UI at http://localhost:9001, verify file appears in bucket chat4all-files

---

## Phase 3: Presigned URLs (US4 continued)

**Purpose**: Generate secure temporary download URLs

- [ ] T122 [US4] Create api-service/src/main/java/chat4all/api/storage/FileDownloadHandler.java class
- [ ] T123 [US4] Implement FileDownloadHandler: GET /v1/files/{file_id}/download - query Cassandra files table for metadata
- [ ] T124 [US4] Implement FileDownloadHandler.generatePresignedUrl(String storagePath) using MinioClient.getPresignedObjectUrl() with 1 hour expiry
- [ ] T125 [US4] Return JSON response: {file_id, filename, size_bytes, mimetype, download_url, expires_at} (200 OK)
- [ ] T126 [US4] Handle file not found: return 404 if file_id doesn't exist in Cassandra
- [ ] T127 [US4] Register GET /v1/files/{file_id}/download endpoint in Main.java
- [ ] T128 [P] [US4] Write test FileDownloadHandlerTest.testGeneratePresignedUrl() verifying URL contains signature parameter
- [ ] T129 [P] [US4] Write test FileDownloadHandlerTest.testFileNotFound() expecting 404
- [ ] T130 [US4] Create scripts/test-file-download.sh: upload file, get download URL, download via curl, verify checksum matches original
- [ ] T131 [US4] Manual validation: generate URL, copy to browser, verify direct download from MinIO (no API proxy)

---

## Phase 4: Messages with File Attachments (US5)

**Purpose**: Link file_id to messages table

- [ ] T132 [US5] Update cassandra-init/schema.cql: ALTER TABLE messages ADD file_id text; ALTER TABLE messages ADD file_metadata map<text, text>;
- [ ] T133 [US5] Update shared/src/main/java/chat4all/shared/MessageEvent.java: add fields fileId (String) and fileMetadata (Map<String, String>)
- [ ] T134 [US5] Update api-service/src/main/java/chat4all/api/http/MessagesHandler.java: parse optional "type" field (default: "text", accept: "file")
- [ ] T135 [US5] Implement MessagesHandler validation: if type="file", require file_id field; verify file_id exists in files table
- [ ] T136 [US5] Update router-worker/src/main/java/chat4all/worker/cassandra/CassandraMessageStore.java: insert file_id and file_metadata when persisting message
- [ ] T137 [US5] Update api-service/src/main/java/chat4all/api/http/ConversationsHandler.java: include file_id and file_metadata in GET response
- [ ] T138 [US5] Implement ConversationsHandler: for messages with file_id, generate presigned URL and include in response under "file_download_url"
- [ ] T139 [P] [US5] Write test MessagesHandlerTest.testSendMessageWithFile() verifying file_id persisted
- [ ] T140 [P] [US5] Write test MessagesHandlerTest.testSendMessageWithInvalidFileId() expecting 400 error
- [ ] T141 [P] [US5] Write test ConversationsHandlerTest.testGetMessagesIncludesFileMetadata() verifying response structure
- [ ] T142 [US5] Create scripts/test-message-with-file.sh: upload file, get file_id, send message with file_id, retrieve conversation, verify file metadata present
- [ ] T143 [US5] Manual validation: send message with file, retrieve via GET, click download URL in response, verify file downloads

---

## Phase 5: WhatsApp Connector Mock (US6)

**Purpose**: Simulate external WhatsApp Business API integration

- [ ] T144 [US6] Create connector-whatsapp/ module: pom.xml with kafka-clients dependency
- [ ] T145 [US6] Create connector-whatsapp/src/main/java/chat4all/connector/whatsapp/Main.java entry point
- [ ] T146 [US6] Create connector-whatsapp/src/main/java/chat4all/connector/whatsapp/WhatsAppConnector.java class with run() method
- [ ] T147 [US6] Implement WhatsAppConnector.createConsumer(): subscribe to Kafka topic "whatsapp-outbound"
- [ ] T148 [US6] Implement WhatsAppConnector.processMessage(ConsumerRecord): deserialize MessageEvent, log "[WhatsApp] Consumed message {message_id}"
- [ ] T149 [US6] Implement WhatsAppConnector.simulateApiCall(): Thread.sleep(random 200-500ms), log "[WhatsApp] Delivered to {recipient_id}"
- [ ] T150 [US6] Create connector-whatsapp/src/main/java/chat4all/connector/whatsapp/StatusPublisher.java for publishing to "status-updates" topic
- [ ] T151 [US6] Implement StatusPublisher.publishDelivered(String messageId): create event {message_id, status: "DELIVERED", timestamp}, send to Kafka
- [ ] T152 [US6] Implement WhatsAppConnector health endpoint: HttpServer on port 8083, GET /health returns {"status":"UP"}
- [ ] T153 [US6] Create connector-whatsapp/Dockerfile: FROM openjdk:17-slim, COPY JAR, CMD ["java", "-jar", "connector-whatsapp.jar"]
- [ ] T154 [US6] Add connector-whatsapp service to docker-compose.yml: build ./connector-whatsapp, depends_on kafka, environment KAFKA_BOOTSTRAP_SERVERS=kafka:9092
- [ ] T155 [US6] Update router-worker/src/main/java/chat4all/worker/processing/MessageProcessor.java: add routing logic - if recipient_id starts with "whatsapp:", produce to "whatsapp-outbound" topic instead of local delivery
- [ ] T156 [P] [US6] Write test WhatsAppConnectorTest.testConsumeMessage() mocking Kafka consumer
- [ ] T157 [P] [US6] Write test WhatsAppConnectorTest.testPublishStatusUpdate() verifying event structure
- [ ] T158 [US6] Create scripts/test-whatsapp-connector.sh: send message to "whatsapp:+5511999999999", wait 2s, check docker logs for delivery confirmation
- [ ] T159 [US6] Manual validation: start all services, send message to whatsapp: recipient, observe connector logs showing delivery simulation

---

## Phase 6: Instagram Connector Mock (US7)

**Purpose**: Second connector demonstrating plugin pattern scalability

- [ ] T160 [P] [US7] Create connector-instagram/ module by copying connector-whatsapp/
- [ ] T161 [US7] Update connector-instagram/pom.xml: change artifactId to connector-instagram
- [ ] T162 [US7] Rename packages: chat4all.connector.instagram
- [ ] T163 [US7] Update InstagramConnector: subscribe to "instagram-outbound" topic
- [ ] T164 [US7] Update InstagramConnector.simulateApiCall(): sleep random 300-700ms, log "[Instagram] Delivered to {recipient_id}"
- [ ] T165 [US7] Update InstagramConnector health endpoint: port 8084
- [ ] T166 [US7] Create connector-instagram/Dockerfile (same structure as WhatsApp)
- [ ] T167 [US7] Add connector-instagram service to docker-compose.yml
- [ ] T168 [US7] Update router-worker MessageProcessor: if recipient_id starts with "instagram:", produce to "instagram-outbound" topic
- [ ] T169 [P] [US7] Write test InstagramConnectorTest.testConsumeMessage()
- [ ] T170 [US7] Create scripts/test-instagram-connector.sh: send message to "instagram:@maria_silva", verify logs
- [ ] T171 [US7] Manual validation: send messages to both whatsapp: and instagram: recipients, verify both connectors process independently

---

## Phase 7: Status Update Consumer (US8)

**Purpose**: Complete message lifecycle: SENT → DELIVERED → READ

- [ ] T172 [US8] Create new Kafka topic in docker-compose.yml: "status-updates" (1 partition, replication 1)
- [ ] T173 [US8] Create router-worker/src/main/java/chat4all/worker/status/StatusUpdateConsumer.java class
- [ ] T174 [US8] Implement StatusUpdateConsumer.consume(): subscribe to "status-updates" topic, deserialize status events
- [ ] T175 [US8] Implement StatusUpdateConsumer.updateMessageStatus(String messageId, String status): update messages.status in Cassandra using prepared statement
- [ ] T176 [US8] Add status update consumer thread to router-worker Main.java (runs parallel to message consumer)
- [ ] T177 [US8] Update cassandra-init/schema.cql: ALTER TABLE messages ADD delivered_at timestamp; ALTER TABLE messages ADD read_at timestamp;
- [ ] T178 [P] [US8] Write test StatusUpdateConsumerTest.testUpdateToDelivered() verifying Cassandra update
- [ ] T179 [US8] Manual validation: send message, wait 2s, query Cassandra messages table, verify status changed from SENT to DELIVERED

---

## Phase 8: Read Status API (US8 continued)

**Purpose**: Allow clients to mark messages as read

- [ ] T180 [US8] Create api-service/src/main/java/chat4all/api/http/MessageStatusHandler.java class
- [ ] T181 [US8] Implement POST /v1/messages/{message_id}/read endpoint: parse message_id from path
- [ ] T182 [US8] Implement MessageStatusHandler: query current status from Cassandra, validate transition (DELIVERED → READ is valid, SENT → READ is invalid)
- [ ] T183 [US8] Create shared/src/main/java/chat4all/shared/MessageStatus.java enum (SENT, DELIVERED, READ) with isValidTransition(from, to) method
- [ ] T184 [US8] Implement MessageStatusHandler: if valid, update messages.status to READ and set read_at timestamp
- [ ] T185 [US8] Return 200 OK with JSON: {message_id, status: "READ", read_at: timestamp} or 400 Bad Request if invalid transition
- [ ] T186 [US8] Register POST /v1/messages/{message_id}/read endpoint in Main.java
- [ ] T187 [P] [US8] Write test MessageStatusHandlerTest.testMarkAsRead() for valid DELIVERED → READ transition
- [ ] T188 [P] [US8] Write test MessageStatusHandlerTest.testInvalidTransition() expecting 400 for SENT → READ
- [ ] T189 [P] [US8] Write test MessageStatusHandlerTest.testIdempotency() calling read twice, both succeed
- [ ] T190 [US8] Create scripts/test-status-lifecycle.sh: send message, wait for DELIVERED, mark as READ, verify all status transitions

---

## Phase 9: Integration Testing

**Purpose**: End-to-end validation of complete system

- [ ] T191 Create scripts/test-file-connectors-e2e.sh: comprehensive test uploading file, sending to whatsapp, sending to instagram, marking read
- [ ] T192 Update scripts/test-end-to-end.sh: include file upload and connector routing scenarios
- [ ] T193 Create scripts/demo-file-sharing.sh: interactive demo showing full file sharing workflow with timestamps
- [ ] T194 [P] Manual test: upload 1GB file, measure time, verify success (should complete in <60s on reasonable connection)
- [ ] T195 [P] Manual test: stop connector-whatsapp mid-processing, restart, verify message reprocessed (Kafka consumer group recovery)
- [ ] T196 Manual test: send 10 messages to whatsapp and instagram simultaneously, verify both connectors process without interference

---

## Phase 10: Documentation & ADRs

**Purpose**: Educational reflection and design rationale

- [ ] T197 Create docs/adr/002-object-storage-choice.md: document why MinIO over database BLOBs or local filesystem
- [ ] T198 Create docs/adr/003-connector-architecture.md: document why separate services over plugin libraries
- [ ] T199 Create docs/adr/004-presigned-urls.md: document security and scalability benefits of presigned URLs
- [ ] T200 Update README.md: add MinIO to architecture diagram, add file upload example to Quick Start
- [ ] T201 Update README.md: add connector services description, explain routing logic
- [ ] T202 Add code comments: explain streaming approach in FileUploadHandler (memory efficiency)
- [ ] T203 Add code comments: explain state machine validation in MessageStatus enum
- [ ] T204 Create docs/FILE_UPLOAD_FLOW.md: detailed sequence diagram of file upload → message send → download
- [ ] T205 Create docs/CONNECTOR_PATTERN.md: explain plugin architecture, how to add new connector

---

## Phase 11: Technical Report (Deliverable)

**Purpose**: Document implementation for academic submission

- [ ] T206 Take screenshots: MinIO Console showing uploaded files in bucket structure
- [ ] T207 Take screenshots: Docker logs showing connector delivery simulation
- [ ] T208 Run Cassandra queries: SELECT * FROM files; SELECT * FROM messages WHERE file_id IS NOT NULL;
- [ ] T209 Measure performance: upload 100MB, 500MB, 1GB files, record times, include in report
- [ ] T210 Document findings: explain why multipart upload needed for large files, cite chunk size used
- [ ] T211 Document findings: explain eventual consistency observed when marking message read before delivered
- [ ] T212 Create report PDF: include all screenshots, code snippets, architecture diagrams, performance data

---

## Summary

**Total Tasks**: 112 (T101-T212)
**Estimated Effort**: 18-22 hours (educational pace with exploration)
**Critical Path**: Setup → Upload API → Presigned URLs → Messages → Connectors → Status Updates

**Parallel Opportunities**:
- T104, T105 (dependencies setup)
- T117-T119 (test writing)
- T139-T141 (test writing)
- T156-T157 (connector tests)
- T160-T166 (Instagram connector - copy of WhatsApp)

**Prerequisites**:
- ✅ Entrega 1 must be 100% complete
- ✅ Kafka and Cassandra operational
- ✅ API Service and Router Worker working
- ✅ Students comfortable with Docker Compose

**Educational Checkpoints**:
1. After Phase 2: Understand streaming vs loading in memory
2. After Phase 3: Understand presigned URLs security model
3. After Phase 5: Understand plugin architecture benefits
4. After Phase 8: Understand state machine design

---

**Instructor Notes**: 
- Phases 1-4 focus on object storage patterns (can be 1 week)
- Phases 5-8 focus on plugin architecture (can be 1 week)
- Phases 9-11 are validation and documentation
- Encourage students to observe system behavior through logs before implementing
- Remind students to document trade-offs in ADRs (not just solutions)
