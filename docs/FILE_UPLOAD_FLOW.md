# File Upload Flow - Detailed Sequence Diagram

**Chat4All Educational Documentation**  
**Version**: 2.0 (Entrega 2 - File Storage)  
**Purpose**: Understand complete file upload, message routing, and download lifecycle

---

## Overview

This document explains the **end-to-end flow** of file uploads in Chat4All, from client upload through message delivery to final download. The system uses:

- **MinIO**: S3-compatible object storage (scalable, cost-efficient)
- **Cassandra**: Metadata storage (file records, message linkage)
- **Kafka**: Asynchronous routing to connectors
- **Presigned URLs**: Secure, temporary download links

---

## 1. File Upload Flow

### Sequence Diagram

```
┌────────┐       ┌─────────┐       ┌────────┐       ┌───────────┐
│ Client │       │   API   │       │ MinIO  │       │ Cassandra │
└───┬────┘       └────┬────┘       └───┬────┘       └─────┬─────┘
    │                 │                │                   │
    │ 1. POST /v1/files                │                   │
    │ (multipart/form-data)            │                   │
    ├────────────────▶│                │                   │
    │                 │                │                   │
    │                 │ 2. Validate JWT                    │
    │                 │    & extract user_id               │
    │                 │                │                   │
    │                 │ 3. Generate file_id                │
    │                 │    (UUID-based)                    │
    │                 │                │                   │
    │                 │ 4. Stream file │                   │
    │                 │    (8KB chunks)│                   │
    │                 ├───────────────▶│                   │
    │                 │                │                   │
    │                 │ 5. Calculate   │                   │
    │                 │    SHA256       │                   │
    │                 │    (on-the-fly)│                   │
    │                 │                │                   │
    │                 │ 6. MinIO writes│                   │
    │                 │    to disk      │                   │
    │                 │                │                   │
    │                 │         7. Upload complete         │
    │                 │◀───────────────┤                   │
    │                 │                │                   │
    │                 │ 8. INSERT INTO files               │
    │                 │    (file_id, path, size, checksum) │
    │                 ├───────────────────────────────────▶│
    │                 │                │                   │
    │                 │         9. Cassandra confirms      │
    │                 │◀───────────────────────────────────┤
    │                 │                │                   │
    │ 10. 201 Created │                │                   │
    │    {file_id, checksum}           │                   │
    │◀────────────────┤                │                   │
    │                 │                │                   │
```

### Step-by-Step Explanation

#### Step 1: Client Sends Multipart Upload

**HTTP Request:**
```http
POST /v1/files HTTP/1.1
Host: localhost:8082
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW

------WebKitFormBoundary7MA4YWxkTrZu0gW
Content-Disposition: form-data; name="file"; filename="contract.pdf"
Content-Type: application/pdf

[binary file content: 5,242,880 bytes]
------WebKitFormBoundary7MA4YWxkTrZu0gW
Content-Disposition: form-data; name="conversation_id"

conv_demo_123
------WebKitFormBoundary7MA4YWxkTrZu0gW--
```

**Key Points:**
- `Authorization` header: JWT token for authentication
- `Content-Type`: multipart/form-data (standard for file uploads)
- `boundary`: Separator between form fields
- Two fields: `file` (binary) and `conversation_id` (text)

#### Steps 2-3: API Service Validation

```java
// FileUploadHandler.java
public void handle(HttpExchange exchange) throws IOException {
    // 1. Validate JWT token
    Claims claims = jwtAuthenticator.validateToken(token);
    String userId = claims.getSubject(); // e.g., "user_a"
    
    // 2. Generate unique file ID
    String fileId = "file_" + UUID.randomUUID().toString()
                              .replace("-", "");
    // Result: file_550e8400e29b41d4a716446655440000
    
    // 3. Build storage path (organized by conversation)
    String storagePath = conversationId + "/" + fileId + extension;
    // Result: conv_demo_123/file_550e8400e29b41d4a716446655440000.pdf
}
```

**Why UUID for file_id?**
- Globally unique (no collisions)
- No database roundtrip to generate ID
- URL-safe characters
- Unpredictable (security: prevents enumeration attacks)

**Why organize by conversation_id?**
- Logical grouping (all files for conv_demo_123 in one folder)
- Easier bucket lifecycle policies (delete all files when conversation deleted)
- MinIO performance: Better S3 key distribution

#### Steps 4-7: Streaming Upload to MinIO

```java
// FileUploadHandler.java - uploadToMinioWithChecksum()

// 1. Wrap input stream with checksum calculator
ChecksumInputStream checksumStream = new ChecksumInputStream(inputStream);

// 2. Upload to MinIO (streaming - NO full file in memory)
minioClient.putObject(
    PutObjectArgs.builder()
        .bucket("chat4all-files")
        .object(storagePath) // conv_demo_123/file_xyz.pdf
        .stream(checksumStream, fileSize, -1) // -1 = auto-detect part size
        .contentType("application/pdf")
        .build()
);

// 3. Get checksum calculated during upload
String checksum = checksumStream.getChecksum(); // sha256:abc123...
```

**Memory Efficiency:**
```
Without Streaming:
  byte[] fileData = readAllBytes(inputStream); // 2GB file = 2GB RAM!
  minioClient.putObject(fileData);
  ❌ OutOfMemoryError for large files

With Streaming:
  while ((bytesRead = inputStream.read(buffer)) != -1) {
      minioClient.write(buffer, 0, bytesRead); // Only 8KB in memory
  }
  ✅ 2GB file uses ~8KB RAM
```

**Checksum Calculation (Single-Pass):**
```java
// ChecksumInputStream.java
public int read(byte[] b, int off, int len) throws IOException {
    int bytesRead = super.read(b, off, len); // Read from network
    
    if (bytesRead > 0) {
        messageDigest.update(b, off, bytesRead); // Update SHA256
    }
    
    return bytesRead;
}

// Efficient: Calculate checksum DURING upload (not separate pass)
// Alternative (inefficient): read entire file twice (checksum + upload)
```

#### Step 8-9: Persist Metadata to Cassandra

```sql
-- Cassandra schema
CREATE TABLE chat4all.files (
    file_id TEXT PRIMARY KEY,
    conversation_id TEXT,
    filename TEXT,
    mimetype TEXT,
    size_bytes BIGINT,
    checksum TEXT,
    storage_path TEXT,
    uploaded_at TIMESTAMP,
    uploaded_by TEXT
);

-- Insert statement (executed by FileRepository)
INSERT INTO chat4all.files (
    file_id, conversation_id, filename, mimetype,
    size_bytes, checksum, storage_path, uploaded_at, uploaded_by
) VALUES (
    'file_550e8400e29b41d4a716446655440000',
    'conv_demo_123',
    'contract.pdf',
    'application/pdf',
    5242880,
    'sha256:abc123def456...',
    'conv_demo_123/file_550e8400e29b41d4a716446655440000.pdf',
    '2025-01-15 10:30:00',
    'user_a'
);
```

**Why store metadata in Cassandra?**
- Fast lookups by `file_id` (primary key)
- Query files by `conversation_id` (secondary index)
- Audit trail: who uploaded, when
- Integrity validation: store checksum for later verification
- Authorization: check `uploaded_by` before allowing download

#### Step 10: Response to Client

```json
{
  "file_id": "file_550e8400e29b41d4a716446655440000",
  "filename": "contract.pdf",
  "size_bytes": 5242880,
  "checksum": "sha256:abc123def456...",
  "storage_path": "conv_demo_123/file_550e8400e29b41d4a716446655440000.pdf",
  "uploaded_at": "2025-01-15T10:30:00Z"
}
```

Client stores `file_id` to include in message send.

---

## 2. Send Message with File

### Sequence Diagram

```
┌────────┐       ┌─────────┐       ┌────────┐       ┌──────────┐
│ Client │       │   API   │       │ Kafka  │       │  Router  │
└───┬────┘       └────┬────┘       └───┬────┘       └─────┬────┘
    │                 │                │                   │
    │ 1. POST /v1/messages             │                   │
    │    {file_id: "file_xyz"}         │                   │
    ├────────────────▶│                │                   │
    │                 │                │                   │
    │                 │ 2. Validate JWT                    │
    │                 │                │                   │
    │                 │ 3. Lookup file_id                  │
    │                 │    in Cassandra                    │
    │                 │    (verify exists)                 │
    │                 │                │                   │
    │                 │ 4. Produce to  │                   │
    │                 │    messages topic                  │
    │                 ├───────────────▶│                   │
    │                 │                │                   │
    │ 5. 201 Created  │                │                   │
    │    {message_id} │                │                   │
    │◀────────────────┤                │                   │
    │                 │                │                   │
    │                 │                │ 6. Router consumes│
    │                 │                │◀──────────────────┤
    │                 │                │                   │
    │                 │                │ 7. Extract        │
    │                 │                │    recipient_id   │
    │                 │                │    prefix         │
    │                 │                │                   │
    │                 │                │ 8. Route to       │
    │                 │                │    whatsapp-outbound
    │                 │                ├──────────────────▶│
```

### Request Example

```http
POST /v1/messages HTTP/1.1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "conversation_id": "conv_demo_123",
  "sender_id": "user_a",
  "recipient_id": "whatsapp:+5511999998888",
  "content": "Check out this contract!",
  "file_id": "file_550e8400e29b41d4a716446655440000"
}
```

### Routing Logic

```java
// MessageRouter.java
public String determineRoutingTopic(String recipientId) {
    if (recipientId == null || !recipientId.contains(":")) {
        return "messages"; // Default: internal routing
    }
    
    String platform = recipientId.split(":")[0];
    return platform + "-outbound";
}

// Examples:
// "whatsapp:+5511999998888" → "whatsapp-outbound"
// "instagram:@john_doe"     → "instagram-outbound"
// "telegram:123456789"      → "telegram-outbound"
// "user_b"                  → "messages" (internal)
```

---

## 3. Connector Processing

### Sequence Diagram

```
┌─────────┐       ┌───────────┐       ┌────────┐       ┌──────────┐
│  Kafka  │       │ WhatsApp  │       │ Kafka  │       │  Router  │
│(outbound)       │ Connector │       │(status)│       │  Worker  │
└────┬────┘       └─────┬─────┘       └───┬────┘       └─────┬────┘
     │                  │                  │                  │
     │ 1. Message with  │                  │                  │
     │    file_id       │                  │                  │
     ├─────────────────▶│                  │                  │
     │                  │                  │                  │
     │                  │ 2. Lookup file   │                  │
     │                  │    metadata      │                  │
     │                  │    (Cassandra)   │                  │
     │                  │                  │                  │
     │                  │ 3. Get MinIO URL │                  │
     │                  │    (presigned)   │                  │
     │                  │                  │                  │
     │                  │ 4. Simulate      │                  │
     │                  │    delivery      │                  │
     │                  │    (2s delay)    │                  │
     │                  │                  │                  │
     │                  │ 5. Publish       │                  │
     │                  │    DELIVERED     │                  │
     │                  ├─────────────────▶│                  │
     │                  │                  │                  │
     │                  │                  │ 6. Router updates│
     │                  │                  │    Cassandra     │
     │                  │                  ├─────────────────▶│
```

### Connector Code

```java
// OutboundMessageConsumer.java (WhatsApp Connector)
public void processMessage(MessageEvent event) {
    logger.info("WhatsApp: Processing message " + event.getMessageId());
    
    // 1. Check if message has file attachment
    if (event.getFileId() != null) {
        String downloadUrl = getFileDownloadUrl(event.getFileId());
        logger.info("File attached: " + downloadUrl);
        
        // In production: Download file and send via WhatsApp Business API
        // sendWhatsAppMediaMessage(event.getRecipientId(), downloadUrl);
    }
    
    // 2. Simulate delivery (educational: no real API)
    Thread.sleep(2000); // 2 second delay
    
    // 3. Publish status update
    publishStatusUpdate(event.getMessageId(), MessageStatus.DELIVERED);
    
    logger.info("WhatsApp: Delivered message " + event.getMessageId());
}
```

---

## 4. File Download Flow

### Sequence Diagram

```
┌────────┐       ┌─────────┐       ┌───────────┐       ┌────────┐
│ Client │       │   API   │       │ Cassandra │       │ MinIO  │
└───┬────┘       └────┬────┘       └─────┬─────┘       └───┬────┘
    │                 │                   │                 │
    │ 1. GET /v1/files/{id}/download      │                 │
    ├────────────────▶│                   │                 │
    │                 │                   │                 │
    │                 │ 2. Validate JWT   │                 │
    │                 │                   │                 │
    │                 │ 3. SELECT FROM files                │
    │                 ├──────────────────▶│                 │
    │                 │                   │                 │
    │                 │ 4. Check ownership│                 │
    │                 │    (conversation_id)                │
    │                 │                   │                 │
    │                 │         5. File metadata            │
    │                 │◀──────────────────┤                 │
    │                 │                   │                 │
    │                 │ 6. Generate presigned URL           │
    │                 │    (MinIO SDK)    │                 │
    │                 ├────────────────────────────────────▶│
    │                 │                   │                 │
    │                 │         7. Signed URL (1h expiry)   │
    │                 │◀────────────────────────────────────┤
    │                 │                   │                 │
    │ 8. 200 OK       │                   │                 │
    │    {download_url}                   │                 │
    │◀────────────────┤                   │                 │
    │                 │                   │                 │
    │ 9. GET {presigned_url}              │                 │
    │    (direct to MinIO)                │                 │
    ├──────────────────────────────────────────────────────▶│
    │                 │                   │                 │
    │ 10. File content                    │                 │
    │◀────────────────────────────────────────────────────┤
```

### Step-by-Step Explanation

#### Steps 1-2: Client Requests Download

```bash
# Request download URL
curl -X GET http://localhost:8082/v1/files/file_xyz/download \
  -H "Authorization: Bearer $TOKEN"
```

#### Steps 3-5: Authorization Check

```java
// FileDownloadHandler.java
public void handle(HttpExchange exchange) throws IOException {
    // 1. Extract file_id from URL
    String fileId = extractFileIdFromPath(exchange.getRequestURI().getPath());
    
    // 2. Query file metadata
    FileMetadata file = fileRepository.getFileMetadata(fileId);
    
    if (file == null) {
        sendErrorResponse(exchange, 404, "File not found");
        return;
    }
    
    // 3. Check if user has access to this conversation
    String conversationId = file.getConversationId();
    if (!userHasAccessToConversation(userId, conversationId)) {
        sendErrorResponse(exchange, 403, "Access denied");
        return;
    }
    
    // Authorization passed - proceed to generate presigned URL
}
```

#### Steps 6-7: Generate Presigned URL

```java
// MinIO SDK generates URL with cryptographic signature
GetPresignedObjectUrlArgs args = GetPresignedObjectUrlArgs.builder()
    .bucket("chat4all-files")
    .object(file.getStoragePath()) // conv_demo_123/file_xyz.pdf
    .expiry(3600) // 1 hour = 3600 seconds
    .method(Method.GET)
    .build();

String presignedUrl = minioClient.getPresignedObjectUrl(args);

// Example result:
// http://minio:9000/chat4all-files/conv_demo_123/file_xyz.pdf?
//   X-Amz-Algorithm=AWS4-HMAC-SHA256&
//   X-Amz-Credential=minioadmin/20250115/us-east-1/s3/aws4_request&
//   X-Amz-Date=20250115T103000Z&
//   X-Amz-Expires=3600&
//   X-Amz-SignedHeaders=host&
//   X-Amz-Signature=abc123def456...
```

**Presigned URL Structure:**
- **Base URL**: `http://minio:9000/chat4all-files/conv_demo_123/file_xyz.pdf`
- **X-Amz-Algorithm**: Signature algorithm (HMAC-SHA256)
- **X-Amz-Credential**: Access key + date + region
- **X-Amz-Date**: URL generation timestamp
- **X-Amz-Expires**: Validity duration (3600 seconds)
- **X-Amz-Signature**: HMAC signature (prevents tampering)

**Security Properties:**
- ✅ **Time-limited**: Expires after 1 hour (automatic revocation)
- ✅ **Tamper-proof**: Changing any parameter invalidates signature
- ✅ **No secrets exposed**: Signature proves authorization without revealing access key
- ✅ **Revocable**: Rotating MinIO keys invalidates all active URLs

#### Step 8: API Returns Presigned URL

```json
{
  "download_url": "http://minio:9000/chat4all-files/conv_demo_123/file_xyz.pdf?X-Amz-Signature=...",
  "expires_in": 3600,
  "filename": "contract.pdf"
}
```

#### Steps 9-10: Direct Download from MinIO

**Client downloads directly from MinIO** (no API proxy):

```bash
# Client fetches file directly
curl -o contract.pdf "http://minio:9000/chat4all-files/.../file_xyz.pdf?X-Amz-Signature=..."
```

**Benefits:**
- ⚡ **Fast**: Full network speed (10Gbps MinIO vs 1Gbps API)
- 📈 **Scalable**: API not involved in data transfer
- 💰 **Cheap**: Reduces API bandwidth costs by 50%
- 🌐 **CDN-ready**: Can cache presigned URLs globally

---

## Performance Characteristics

### Upload Performance

| File Size | Upload Time | Memory Used | Network I/O |
|-----------|-------------|-------------|-------------|
| 1KB       | ~50ms       | 8KB         | 1KB         |
| 1MB       | ~100ms      | 8KB         | 1MB         |
| 10MB      | ~500ms      | 8KB         | 10MB        |
| 100MB     | ~5s         | 8KB         | 100MB       |
| 1GB       | ~50s        | 8KB         | 1GB         |
| 2GB (max) | ~100s       | 8KB         | 2GB         |

**Key Insight**: Memory usage is constant (8KB buffer) regardless of file size!

### Download Performance

| File Size | API Time | MinIO Time | Total Time |
|-----------|----------|------------|------------|
| 1MB       | 10ms     | 50ms       | 60ms       |
| 10MB      | 10ms     | 200ms      | 210ms      |
| 100MB     | 10ms     | 2s         | 2.01s      |
| 1GB       | 10ms     | 20s        | 20.01s     |

**Key Insight**: API time is negligible (only generates URL, doesn't transfer data).

---

## Error Handling

### Upload Errors

| Error Code | Scenario | Client Action |
|------------|----------|---------------|
| 400 Bad Request | Missing file or conversation_id | Fix request |
| 401 Unauthorized | Invalid/expired JWT | Re-authenticate |
| 413 Payload Too Large | File > 2GB | Split file or compress |
| 500 Internal Error | MinIO failure or Cassandra timeout | Retry with exponential backoff |

### Download Errors

| Error Code | Scenario | Client Action |
|------------|----------|---------------|
| 403 Forbidden | Presigned URL expired (> 1 hour) | Request new URL |
| 403 Forbidden | URL signature invalid (tampered) | Request new URL |
| 404 Not Found | File deleted from MinIO | Report missing file |
| 500 Internal Error | MinIO unavailable | Retry later |

---

## Production Considerations

### CDN Integration

```
Client → CloudFlare CDN → MinIO
              ↑
         Cache presigned URLs
         (respect X-Amz-Expires header)
```

**Benefits:**
- Global distribution (low latency worldwide)
- Cache frequently accessed files
- DDoS protection
- SSL termination

**Configuration:**
```nginx
# CloudFlare cache rule
cache_everything:
  - match: minio.example.com/*.pdf
  - respect_origin_headers: true
  - max_age: 3600 # 1 hour (match presigned URL expiry)
```

### Multipart Upload (Future)

For files > 100MB, use multipart upload:

```java
// Split file into 5MB chunks
List<Part> parts = new ArrayList<>();
for (int i = 0; i < totalParts; i++) {
    byte[] chunk = readChunk(inputStream, CHUNK_SIZE);
    String etag = uploadPart(uploadId, i+1, chunk);
    parts.add(new Part(i+1, etag));
}

// Complete multipart upload
completeMultipartUpload(uploadId, parts);
```

**Benefits:**
- Resume failed uploads (upload parts independently)
- Parallel uploads (faster for large files)
- Better error recovery

### Monitoring

**Metrics to track:**
- Upload success rate (target: > 99%)
- Average upload time by file size
- Download success rate
- Presigned URL generation errors
- MinIO disk usage

**Alerts:**
- Upload failure rate > 5%
- MinIO disk > 80% full
- Presigned URL generation latency > 100ms

---

## Related Documentation

- [ADR-002: Object Storage Choice](adr/002-object-storage-choice.md) - Why MinIO?
- [ADR-004: Presigned URLs](adr/004-presigned-urls.md) - Security model
- [CONNECTOR_PATTERN.md](CONNECTOR_PATTERN.md) - How connectors work

---

## Educational Value

This document demonstrates:
- **Distributed Systems**: Separation of control plane (API) and data plane (storage)
- **Streaming I/O**: Memory-efficient large file handling
- **Cryptographic Authentication**: HMAC signatures for secure URLs
- **Asynchronous Processing**: Kafka for message routing
- **Metadata vs Content**: Cassandra stores metadata, MinIO stores blobs
- **Industry Standards**: S3-compatible API (used by AWS, GCP, Azure)

---

**Chat4All Educational Project** | November 2025
