# Implementation Plan: File Storage & Connectors

**Feature**: 002-file-storage-connectors  
**Estimated Effort**: 16-20 hours (2 weeks for educational context)  
**Complexity**: Moderate (introduces new patterns)

---

## 🎯 Educational Approach

This plan follows **Test-Driven Learning**:
1. **Understand the pattern** (read spec, draw diagrams)
2. **Write tests first** (define expected behavior)
3. **Implement minimally** (make tests pass)
4. **Observe behavior** (run system, check logs)
5. **Reflect and document** (explain trade-offs)

### Week 5 Focus: Object Storage (US4, US5)
**Concepts**: Separation of concerns, multipart uploads, metadata management

### Week 6 Focus: Plugin Architecture (US6, US7, US8)
**Concepts**: Loose coupling, event-driven integration, state machines

---

## 🏗️ Architecture Overview

### New Services

```
chat4alltijolim/
├── api-service/              # EXTEND: Add file upload endpoint
├── router-worker/            # EXTEND: Add connector routing
├── connector-whatsapp/       # NEW: WhatsApp simulator
├── connector-instagram/      # NEW: Instagram simulator
├── shared/                   # EXTEND: Add FileEvent model
└── docker-compose.yml        # EXTEND: Add MinIO + connectors
```

### Technology Stack

| Component | Technology | Why? (Educational) |
|-----------|-----------|-------------------|
| Object Storage | MinIO | S3-compatible, runs locally, easy to inspect |
| File Upload | Java NIO + MinIO SDK | Learn streaming, chunking, checksums |
| Connectors | Standalone services | Learn microservices isolation |
| Routing | Kafka topics | Learn pub/sub pattern |
| State Machine | Cassandra updates | Learn eventual consistency |

---

## 📚 Prerequisites (Knowledge Check)

Students should understand from Entrega 1:
- ✅ How Kafka topics partition messages
- ✅ How Cassandra models data by query pattern
- ✅ How Docker Compose orchestrates services
- ✅ How async processing works (API → Kafka → Worker)

**New Concepts Introduced**:
- 🆕 Object storage vs database storage
- 🆕 Presigned URLs for secure downloads
- 🆕 Plugin architecture with service isolation
- 🆕 State machine design and transitions
- 🆕 Multipart/chunked file uploads

---

## 🔨 Implementation Phases

### Phase 1: MinIO Setup (2 hours)

**Goal**: Get object storage running and testable

**Tasks**:
1. Add MinIO service to `docker-compose.yml`
   - Image: `minio/minio:latest`
   - Ports: 9000 (API), 9001 (Console)
   - Volumes: `./data/minio:/data`
   - Credentials: `MINIO_ROOT_USER=admin`, `MINIO_ROOT_PASSWORD=password123`

2. Create initialization script `cassandra-init/schema-files.cql`
   ```sql
   CREATE TABLE files (
       file_id text PRIMARY KEY,
       conversation_id text,
       uploader_id text,
       filename text,
       size_bytes bigint,
       mimetype text,
       checksum text,
       storage_path text,
       uploaded_at timestamp
   );
   CREATE INDEX files_by_conversation ON files(conversation_id);
   ```

3. Add MinIO client setup in `api-service/`
   ```java
   MinioClient.builder()
       .endpoint("http://minio:9000")
       .credentials("admin", "password123")
       .build();
   ```

**Validation**:
```bash
# Start services
docker-compose up -d

# Access MinIO Console
open http://localhost:9001

# Create bucket "chat4all-files"
# Upload test file manually
```

**Learning Checkpoint**:
- What is object storage? (Unstructured data optimized for large files)
- Why separate from Cassandra? (Different access patterns, cost)
- What is a bucket? (Namespace for organizing objects)

---

### Phase 2: File Upload API (4 hours)

**Goal**: Implement `POST /v1/files/upload` with multipart support

**Tasks**:
1. Add MinIO SDK dependency to `api-service/pom.xml`
   ```xml
   <dependency>
       <groupId>io.minio</groupId>
       <artifactId>minio</artifactId>
       <version>8.5.7</version>
   </dependency>
   ```

2. Create `FileUploadHandler.java`
   - Parse `multipart/form-data`
   - Generate `file_id` (UUID)
   - Calculate SHA256 checksum while streaming
   - Upload to MinIO: `{conversation_id}/{file_id}.{ext}`
   - Store metadata in Cassandra `files` table

3. Create test `FileUploadHandlerTest.java`
   - Test 1MB file upload
   - Test 100MB file upload
   - Test 2.5GB file (should reject)
   - Test invalid file type (if filtering enabled)

4. Create manual test script `scripts/test-file-upload.sh`
   ```bash
   # Create 10MB test file
   dd if=/dev/urandom of=test.bin bs=1M count=10
   
   # Upload via API
   curl -X POST http://localhost:8082/v1/files/upload \
     -H "Authorization: Bearer $TOKEN" \
     -F "file=@test.bin" \
     -F "conversation_id=conv_test"
   ```

**Validation**:
- Upload completes successfully
- File appears in MinIO Console
- Metadata saved in Cassandra
- Checksum matches original

**Learning Checkpoint**:
- Why stream instead of loading entire file in memory? (Memory efficiency)
- Why calculate checksum? (Data integrity verification)
- What is multipart/form-data? (MIME encoding for file uploads)

---

### Phase 3: Presigned URLs (2 hours)

**Goal**: Generate secure download URLs

**Tasks**:
1. Add `GET /v1/files/{file_id}/download` endpoint
   - Query Cassandra for file metadata
   - Generate presigned URL (1 hour expiry)
   - Return JSON with URL

2. Implement presigned URL generation
   ```java
   minioClient.getPresignedObjectUrl(
       GetPresignedObjectUrlArgs.builder()
           .bucket("chat4all-files")
           .object(storagePath)
           .expiry(1, TimeUnit.HOURS)
           .method(Method.GET)
           .build()
   );
   ```

3. Test expiry behavior
   - Generate URL
   - Download immediately (should work)
   - Wait 2 hours, try again (should fail 403)

**Validation**:
```bash
# Get download URL
URL=$(curl -s http://localhost:8082/v1/files/file_123/download \
  -H "Authorization: Bearer $TOKEN" | jq -r '.download_url')

# Download file directly from MinIO
curl -o downloaded.bin "$URL"

# Verify checksum matches
sha256sum downloaded.bin
```

**Learning Checkpoint**:
- Why presigned URLs? (Offload bandwidth from API)
- What happens after expiry? (MinIO rejects request)
- Alternative: API proxy downloads? (Doesn't scale)

---

### Phase 4: Messages with Files (2 hours)

**Goal**: Link file_id to messages (US5)

**Tasks**:
1. Update Cassandra schema
   ```sql
   ALTER TABLE messages ADD file_id text;
   ALTER TABLE messages ADD file_metadata map<text, text>;
   ```

2. Update `MessagesHandler.java`
   - Accept `type: "file"` in payload
   - Validate `file_id` exists in `files` table
   - Store message with file reference

3. Update `ConversationsHandler.java`
   - Include file metadata in GET response
   - Generate presigned URL for each file

4. Create test `scripts/test-message-with-file.sh`
   ```bash
   # Upload file
   FILE_ID=$(curl -s -X POST ... | jq -r '.file_id')
   
   # Send message with file
   curl -X POST http://localhost:8082/v1/messages \
     -H "Authorization: Bearer $TOKEN" \
     -d '{
       "conversation_id": "conv_123",
       "sender_id": "user_a",
       "type": "file",
       "file_id": "'$FILE_ID'",
       "content": "Check this out!"
     }'
   
   # Retrieve and verify
   curl http://localhost:8082/v1/conversations/conv_123/messages
   ```

**Validation**:
- Message persists with file_id
- GET returns file metadata (filename, size, mimetype)
- GET returns presigned download URL
- Download works from returned URL

**Learning Checkpoint**:
- Why store file_id instead of full path? (Abstraction, flexibility)
- What if file deleted but message exists? (Design choice: orphaned reference)

---

### Phase 5: WhatsApp Connector (3 hours)

**Goal**: Create mock connector demonstrating plugin pattern (US6)

**Tasks**:
1. Create new module `connector-whatsapp/`
   ```
   connector-whatsapp/
   ├── pom.xml
   ├── Dockerfile
   └── src/main/java/chat4all/connector/whatsapp/
       ├── Main.java
       ├── WhatsAppConnector.java
       ├── MessageConsumer.java
       └── StatusPublisher.java
   ```

2. Implement Kafka consumer
   - Subscribe to `whatsapp-outbound` topic
   - Deserialize message event
   - Simulate API call (Thread.sleep 200-500ms)
   - Log: `[WhatsApp] Delivered to {recipient_id}`

3. Implement status callback publisher
   - Publish to `status-updates` topic
   - Payload: `{ message_id, status: "DELIVERED", timestamp }`

4. Create health endpoint
   ```java
   HttpServer.create(new InetSocketAddress(8083), 0)
       .createContext("/health", exchange -> {
           exchange.sendResponseHeaders(200, 0);
           exchange.getResponseBody().close();
       });
   ```

5. Update `router-worker/` with routing logic
   - Check `recipient_id` format
   - If starts with `whatsapp:`, route to `whatsapp-outbound`
   - Otherwise, existing local delivery

6. Add to `docker-compose.yml`
   ```yaml
   connector-whatsapp:
     build: ./connector-whatsapp
     depends_on:
       - kafka
     environment:
       KAFKA_BOOTSTRAP_SERVERS: kafka:9092
   ```

**Validation**:
```bash
# Send message to WhatsApp recipient
curl -X POST http://localhost:8082/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "conversation_id": "conv_123",
    "sender_id": "user_a",
    "recipient_id": "whatsapp:+5511999999999",
    "content": "Hello WhatsApp!"
  }'

# Check connector logs
docker-compose logs connector-whatsapp

# Expected:
# [WhatsApp] Consumed message msg_abc123
# [WhatsApp] Simulating API call (350ms delay)
# [WhatsApp] Delivered to whatsapp:+5511999999999
# [WhatsApp] Published status update: DELIVERED
```

**Learning Checkpoint**:
- What is a connector/adapter pattern? (Translate protocols)
- Why separate service? (Isolation, scaling, failure independence)
- What if connector crashes? (Kafka retains message, reprocesses on restart)

---

### Phase 6: Instagram Connector (2 hours)

**Goal**: Duplicate pattern for second platform (US7)

**Tasks**:
1. Copy `connector-whatsapp/` → `connector-instagram/`
2. Change topic: `instagram-outbound`
3. Change log prefix: `[Instagram]`
4. Change simulated delay: 300-700ms
5. Change health port: 8084
6. Add to `docker-compose.yml`

**Validation**:
```bash
# Send to Instagram recipient
curl -X POST http://localhost:8082/v1/messages \
  -d '{"recipient_id": "instagram:@maria_silva", ...}'

# Check both connectors running
docker-compose ps | grep connector
```

**Learning Checkpoint**:
- How easy is it to add a 3rd connector? (Very easy, plug-and-play)
- Could we scale connectors independently? (Yes, add replicas in docker-compose)
- What if WhatsApp slow but Instagram fast? (No interference)

---

### Phase 7: Status Updates (3 hours)

**Goal**: Implement READ status and state machine (US8)

**Tasks**:
1. Update `router-worker/` to consume `status-updates` topic
   - Parse status event
   - Update `messages.status` in Cassandra
   - Log: `Updated message {id} status: {status}`

2. Create `POST /v1/messages/{id}/read` endpoint
   - Validate message exists
   - Update status to READ
   - Set `read_at` timestamp
   - Return 200 OK

3. Implement state machine validation
   ```java
   enum MessageStatus { SENT, DELIVERED, READ }
   
   boolean isValidTransition(MessageStatus from, MessageStatus to) {
       return (from == SENT && to == DELIVERED) ||
              (from == DELIVERED && to == READ);
   }
   ```

4. Create test `scripts/test-status-lifecycle.sh`
   ```bash
   # Send message
   MSG_ID=$(curl -X POST .../messages | jq -r '.message_id')
   
   # Wait for DELIVERED (connector processes)
   sleep 2
   
   # Mark as READ
   curl -X POST http://localhost:8082/v1/messages/$MSG_ID/read
   
   # Verify status history
   curl http://localhost:8082/v1/messages/$MSG_ID | jq '.status'
   ```

**Validation**:
- SENT → DELIVERED works (connector callback)
- DELIVERED → READ works (API call)
- Invalid transitions rejected (READ → SENT returns 400)
- Idempotent (calling READ twice works)

**Learning Checkpoint**:
- What is a state machine? (Defined states + valid transitions)
- Why validate transitions? (Data integrity, business rules)
- Is this strong consistency? (No, eventual - connector may delay)

---

### Phase 8: Testing & Documentation (2 hours)

**Goal**: Complete deliverables and validate learning

**Tasks**:
1. Create comprehensive demo script `scripts/demo-file-connectors.sh`
   - Upload file
   - Send message with attachment
   - Send to WhatsApp connector
   - Send to Instagram connector
   - Mark messages as read
   - Show final state

2. Write ADR `docs/adr/002-object-storage-choice.md`
   - Context: Need to store 2GB files
   - Options: Database BLOBs, Local filesystem, Object storage
   - Decision: MinIO (S3-compatible)
   - Consequences: Added complexity, but scalable

3. Write ADR `docs/adr/003-connector-architecture.md`
   - Context: Need to integrate with external APIs
   - Options: Library in Router Worker, Separate services
   - Decision: Separate microservices per platform
   - Consequences: More services, but isolated failures

4. Update README.md
   - Add MinIO to architecture diagram
   - Add connector services description
   - Update Quick Start with file upload example

5. Create technical report (deliverable)
   - Screenshots of MinIO Console
   - Logs showing connector delivery simulation
   - Cassandra queries showing status transitions
   - Performance notes: Time to upload 1GB file

**Validation**:
- All tests pass
- Demo script runs end-to-end
- Documentation explains design decisions
- Code has educational comments

---

## 📊 Effort Estimation

| Phase | Hours | Complexity | Educational Value |
|-------|-------|-----------|------------------|
| 1. MinIO Setup | 2 | Low | High (new concept) |
| 2. File Upload | 4 | Medium | High (streaming, checksums) |
| 3. Presigned URLs | 2 | Low | High (security pattern) |
| 4. Messages with Files | 2 | Low | Medium (data modeling) |
| 5. WhatsApp Connector | 3 | Medium | Very High (plugin pattern) |
| 6. Instagram Connector | 2 | Low | Medium (repetition) |
| 7. Status Updates | 3 | Medium | High (state machines) |
| 8. Testing & Docs | 2 | Low | High (reflection) |
| **Total** | **20** | - | - |

**Note**: Estimates assume students completed Entrega 1 and understand the codebase.

---

## 🎓 Learning Outcomes

By completing this implementation, students will be able to:

### Technical Skills
- ✅ Configure and use S3-compatible object storage
- ✅ Implement multipart file uploads with streaming
- ✅ Generate presigned URLs for secure downloads
- ✅ Design plugin architecture with service isolation
- ✅ Implement state machines with validation
- ✅ Route messages via Kafka topics

### Conceptual Understanding
- ✅ Explain when to use object storage vs database
- ✅ Describe trade-offs of presigned URLs
- ✅ Justify plugin architecture over monolithic integration
- ✅ Design state machines for distributed systems
- ✅ Reason about eventual consistency in status updates

### Best Practices
- ✅ Separate metadata from binary storage
- ✅ Stream large files instead of loading in memory
- ✅ Validate state transitions to maintain integrity
- ✅ Use health endpoints for service monitoring
- ✅ Document architectural decisions with ADRs

---

## 🚨 Common Pitfalls (Educational Warnings)

### Pitfall 1: Loading Entire File in Memory
**Anti-pattern**:
```java
byte[] fileBytes = request.getBody().readAllBytes();
minioClient.putObject(bucket, key, new ByteArrayInputStream(fileBytes));
```
**Problem**: OutOfMemoryError with 1GB+ files

**Solution**: Stream directly
```java
InputStream inputStream = request.getBody();
minioClient.putObject(bucket, key, inputStream, fileSize);
```

### Pitfall 2: No Checksum Verification
**Problem**: Silent data corruption, no way to verify integrity

**Solution**: Calculate SHA256 during upload, store in metadata

### Pitfall 3: Tight Coupling in Connectors
**Anti-pattern**: Router Worker calls WhatsApp client library directly

**Problem**: Router Worker crashes if WhatsApp SDK has bug

**Solution**: Separate connector service, isolated failure domain

### Pitfall 4: Invalid State Transitions
**Problem**: Message marked READ before DELIVERED (client bug, race condition)

**Solution**: Validate transitions server-side, reject invalid changes

---

## 📦 Deliverables Checklist

- [ ] MinIO running in docker-compose
- [ ] `POST /v1/files/upload` endpoint working
- [ ] `GET /v1/files/{id}/download` returns presigned URL
- [ ] Messages support `type: "file"` with file_id
- [ ] `connector-whatsapp` service operational
- [ ] `connector-instagram` service operational
- [ ] Status updates flow: SENT → DELIVERED → READ
- [ ] `POST /v1/messages/{id}/read` endpoint working
- [ ] `scripts/demo-file-connectors.sh` runs end-to-end
- [ ] ADR 002 (object storage) written
- [ ] ADR 003 (connector architecture) written
- [ ] README updated with new features
- [ ] Technical report with screenshots and metrics

---

**Next**: See `tasks.md` for detailed task breakdown (estimated 50-65 tasks).
