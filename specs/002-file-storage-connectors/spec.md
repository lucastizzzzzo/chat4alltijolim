# Feature Specification: Object Storage & External Connectors

**Feature ID**: 002-file-storage-connectors  
**Delivery**: Entrega 2 (Weeks 5-6)  
**Status**: 🟡 Planning  
**Educational Focus**: Distributed storage patterns, Plugin architecture, External system integration

---

## 📚 Learning Objectives (Educational Context)

This feature is designed for **7th semester Information Systems students** learning distributed systems. By implementing this feature, students will understand:

### Core Distributed Systems Concepts

1. **Object Storage Patterns**
   - Separation of metadata (Cassandra) vs binary data (MinIO)
   - Presigned URLs for secure, decentralized file access
   - Multipart upload for reliability with large files

2. **Plugin Architecture**
   - Loose coupling via Kafka topics
   - Service-to-service communication patterns
   - Simulating external API integration (WhatsApp/Instagram)

3. **State Machine Design**
   - Message lifecycle: SENT → DELIVERED → READ
   - Event-driven state transitions
   - Eventual consistency in distributed systems

4. **Scalability Patterns**
   - Storage layer separation (hot path vs cold storage)
   - Asynchronous processing for file uploads
   - Independent scaling of connectors

---

## 🎯 User Stories

### US4: File Upload and Sharing
**As a** Chat4All user  
**I want to** upload files (images, videos, documents) up to 2GB  
**So that** I can share media content in my conversations  

**Educational Value**: Learn object storage patterns, multipart uploads, and metadata management

**Acceptance Criteria**:
- [ ] User can upload files up to 2GB via REST API
- [ ] System generates unique file_id and stores metadata in Cassandra
- [ ] File is stored in MinIO with proper organization (conversation_id/file_id)
- [ ] User receives presigned URL for download (valid 1 hour)
- [ ] Upload supports multipart/form-data (chunked upload)
- [ ] System calculates and stores file checksum (SHA256)

**Technical Requirements**:
- Endpoint: `POST /v1/files/upload`
- Supported formats: .jpg, .png, .pdf, .mp4, .zip (configurable)
- Max file size: 2GB (2,147,483,648 bytes)
- Storage path pattern: `{conversation_id}/{file_id}.{extension}`

---

### US5: Messages with File Attachments
**As a** Chat4All user  
**I want to** send messages with attached files  
**So that** I can share context along with media  

**Educational Value**: Learn how to reference external objects in NoSQL databases

**Acceptance Criteria**:
- [ ] Existing `POST /v1/messages` accepts `type: "file"` payload
- [ ] Message includes `file_id` and references uploaded file
- [ ] System validates file exists before accepting message
- [ ] Message persists with file metadata (filename, size, mimetype)
- [ ] GET endpoint returns file info within message object

**Technical Requirements**:
```json
{
  "conversation_id": "conv_123",
  "sender_id": "user_a",
  "type": "file",
  "file_id": "file_abc123",
  "content": "Check out this document!"
}
```

---

### US6: WhatsApp Connector (Simulated)
**As a** system integrator  
**I want** Chat4All to route messages to WhatsApp Business API (simulated)  
**So that** users can communicate across platforms  

**Educational Value**: Learn plugin architecture, external API integration patterns, and message routing

**Acceptance Criteria**:
- [ ] New service `connector-whatsapp` consumes from Kafka topic `whatsapp-outbound`
- [ ] Connector simulates WhatsApp API call with 200ms delay
- [ ] Logs message delivery: `[WhatsApp] Delivered to +5511999999999`
- [ ] Publishes callback event to Kafka: `status-updates` topic
- [ ] Router Worker updates message status to DELIVERED in Cassandra
- [ ] Connector has health endpoint `/health`

**Technical Requirements**:
- Service: `connector-whatsapp` (new microservice)
- Kafka topic consumption: `whatsapp-outbound`
- Kafka topic production: `status-updates`
- Simulated delay: 200-500ms (random for realism)

---

### US7: Instagram Connector (Simulated)
**As a** system integrator  
**I want** Chat4All to route messages to Instagram DM API (simulated)  
**So that** users can reach contacts on Instagram  

**Educational Value**: Reinforce plugin pattern, demonstrate horizontal scaling of connectors

**Acceptance Criteria**:
- [ ] New service `connector-instagram` consumes from Kafka topic `instagram-outbound`
- [ ] Connector simulates Instagram API call with 300ms delay
- [ ] Logs message delivery: `[Instagram] Delivered to @username`
- [ ] Publishes callback event to Kafka: `status-updates` topic
- [ ] Router Worker updates message status to DELIVERED
- [ ] Connector has health endpoint `/health`

**Technical Requirements**:
- Service: `connector-instagram` (new microservice)
- Kafka topic consumption: `instagram-outbound`
- Kafka topic production: `status-updates`
- Simulated delay: 300-700ms (random)

---

### US8: Message Status Lifecycle
**As a** Chat4All user  
**I want to** see message delivery and read status  
**So that** I know when my message reached the recipient  

**Educational Value**: Learn state machines, event-driven updates, and eventual consistency

**Acceptance Criteria**:
- [ ] Message states: SENT → DELIVERED → READ
- [ ] API accepts `POST /v1/messages/{id}/read` to mark as read
- [ ] Status updates are persisted in Cassandra
- [ ] GET endpoint returns current status with timestamp
- [ ] Status transitions are idempotent (can be called multiple times)
- [ ] Invalid transitions are rejected (e.g., READ → SENT)

**Technical Requirements**:
- New endpoint: `POST /v1/messages/{message_id}/read`
- Cassandra update: `status` and `read_at` timestamp
- Response includes full status history (future: audit log)

---

## 🏗️ Architecture Changes

### New Components

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       ▼
┌─────────────┐      ┌─────────────┐      ┌──────────────┐
│ API Service │─────▶│    Kafka    │─────▶│    MinIO     │
│ + Upload    │      │  (Topics)   │      │ (S3 Storage) │
└─────────────┘      └──────┬──────┘      └──────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         ▼                  ▼                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Router    │    │  Connector  │    │  Connector  │
│   Worker    │    │  WhatsApp   │    │  Instagram  │
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘
       │                  │                  │
       └──────────────────┴──────────────────┘
                          │
                          ▼
                   ┌─────────────┐
                   │  Cassandra  │
                   └─────────────┘
```

### New Kafka Topics

- `whatsapp-outbound` - Messages routed to WhatsApp
- `instagram-outbound` - Messages routed to Instagram  
- `status-updates` - Delivery/read status callbacks
- `file-uploads` - File metadata events (optional)

### New Cassandra Tables

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
    uploaded_at timestamp,
    INDEX conversation_idx (conversation_id)
);

-- Add column to messages table
ALTER TABLE messages ADD file_id text;
ALTER TABLE messages ADD file_metadata map<text, text>;
```

---

## 📋 Technical Specifications

### File Upload Flow

1. **Client** sends multipart/form-data to `POST /v1/files/upload`
2. **API Service** streams chunks to MinIO using SDK
3. **API Service** calculates SHA256 checksum during upload
4. **API Service** stores file metadata in Cassandra
5. **API Service** returns `file_id` and presigned download URL
6. **Client** uses `file_id` in message payload

### Connector Routing Logic

Router Worker decides destination based on `recipient_id` pattern:
- `whatsapp:+5511999999999` → `whatsapp-outbound` topic
- `instagram:@username` → `instagram-outbound` topic
- `user_123` (local) → existing direct delivery

### Status Update Flow

1. **Connector** successfully delivers message
2. **Connector** publishes event to `status-updates` topic
3. **Router Worker** consumes status event
4. **Router Worker** updates `messages.status` in Cassandra
5. **API** reflects new status in GET responses

---

## 🧪 Testing Strategy

### Manual Tests (Educational Priority)

Students should run these tests to **observe distributed systems behavior**:

1. **Test File Upload (Large File)**
   ```bash
   # Upload 100MB file, observe chunked transfer
   ./scripts/test-file-upload.sh
   ```

2. **Test Message with Attachment**
   ```bash
   # Send message referencing uploaded file
   ./scripts/test-message-with-file.sh
   ```

3. **Test WhatsApp Connector**
   ```bash
   # Send to whatsapp:+5511999999999, check logs
   ./scripts/test-whatsapp-connector.sh
   ```

4. **Test Status Transitions**
   ```bash
   # Observe SENT → DELIVERED → READ lifecycle
   ./scripts/test-status-lifecycle.sh
   ```

### Automated Integration Tests

- Upload 1KB, 1MB, 100MB, 1GB files (verify all succeed)
- Upload 2.5GB file (verify rejection)
- Send message with non-existent file_id (verify rejection)
- Verify connector failover (stop connector, restart, verify redelivery)
- Verify status idempotency (mark READ twice, verify no error)

---

## 📖 Educational Notes (For Students)

### Why Separate Object Storage?

**Anti-pattern**: Storing large files in database (BLOB columns)
- Problem: Slow queries, expensive backups, poor scalability

**Best Practice**: Store in object storage, reference in database
- Benefit: Fast metadata queries, cheap storage, infinite scale
- Trade-off: Additional complexity (2 systems to manage)

### Why Presigned URLs?

**Alternative 1**: Proxy all downloads through API
- Problem: API becomes bottleneck, high bandwidth costs

**Alternative 2**: Public bucket with open URLs
- Problem: Security risk, no access control

**Best Practice**: Generate temporary signed URLs
- Benefit: Direct client-to-storage transfer, secure, stateless

### Why Plugin Architecture for Connectors?

**Alternative**: Implement all integrations in Router Worker
- Problem: Tight coupling, hard to scale, hard to test

**Best Practice**: Separate connector services
- Benefit: Independent scaling, isolated failures, easy mocking

---

## 🎓 Deliverables

### Code
- [ ] `file-service/` module (or extend api-service)
- [ ] `connector-whatsapp/` microservice
- [ ] `connector-instagram/` microservice
- [ ] Updated `router-worker/` with routing logic
- [ ] Updated Cassandra schema with `files` table
- [ ] Docker Compose with MinIO service

### Documentation
- [ ] ADR: Why MinIO instead of local filesystem
- [ ] ADR: Why separate connectors instead of plugins
- [ ] OpenAPI spec updated with file endpoints
- [ ] Architecture diagram showing new components

### Tests
- [ ] `scripts/test-file-upload.sh`
- [ ] `scripts/test-whatsapp-connector.sh`
- [ ] `scripts/test-status-lifecycle.sh`
- [ ] Demo: End-to-end file sharing + delivery

### Report (Technical Deliverable)
- [ ] Screenshots of MinIO UI showing uploaded files
- [ ] Connector logs showing delivery simulation
- [ ] Cassandra queries showing status transitions
- [ ] Performance metrics: upload time for 1GB file

---

## 🔗 Dependencies

**Requires Complete**: Entrega 1 (001-basic-messaging-api)
- Working POST /v1/messages endpoint
- Working GET /v1/conversations/{id}/messages endpoint
- Kafka + Cassandra operational
- Router Worker processing messages

**New External Dependencies**:
- MinIO (S3-compatible storage): `docker.io/minio/minio:latest`
- MinIO Java SDK: `io.minio:minio:8.5.7`

**New Maven Modules**:
- `connector-whatsapp/` (standalone service)
- `connector-instagram/` (standalone service)

---

**Next Steps**: See `tasks.md` for detailed implementation breakdown (estimated 45-60 tasks).
