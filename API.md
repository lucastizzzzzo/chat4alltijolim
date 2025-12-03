# Chat4All - API Reference

Complete REST and WebSocket API documentation.

## 🔐 Authentication

### Register User

**Endpoint**: `POST /auth/register`

**Request**:
```json
{
  "username": "alice",
  "password": "mypassword",
  "email": "alice@example.com"
}
```

**Response** (201 Created):
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "username": "alice",
  "email": "alice@example.com",
  "created_at": 1701234567890
}
```

### Get Access Token

**Endpoint**: `POST /auth/token`

**Request**:
```json
{
  "username": "alice",
  "password": "mypassword"
}
```

**Response** (200 OK):
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

**Usage**: Include token in all protected endpoints:
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## 💬 Messages

### Send Message

**Endpoint**: `POST /v1/messages`

**Headers**:
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request**:
```json
{
  "conversation_id": "alice-bob-chat",
  "recipient_id": "whatsapp:+5511999998888",
  "content": "Hello, how are you?",
  "file_id": null  // Optional: attach uploaded file
}
```

**Response** (202 Accepted):
```json
{
  "message_id": "msg_550e8400e29b41d4a716446655440000",
  "status": "SENT",
  "timestamp": 1701234567890
}
```

**Recipient ID Formats**:
- WhatsApp: `whatsapp:+[country_code][number]` (e.g., `whatsapp:+5511999998888`)
- Instagram: `instagram:@[username]` (e.g., `instagram:@alice`)

**Status Lifecycle**:
1. `SENT` - Message accepted by API
2. `DELIVERED` - Delivered by connector to platform
3. `READ` - Recipient marked as read

### Get Conversation Messages

**Endpoint**: `GET /v1/conversations/{conversation_id}/messages`

**Headers**:
```
Authorization: Bearer {token}
```

**Query Parameters**:
- `limit` (optional, default: 50, max: 100) - Number of messages to return
- `offset` (optional, default: 0) - Pagination offset

**Response** (200 OK):
```json
{
  "conversation_id": "alice-bob-chat",
  "messages": [
    {
      "message_id": "msg_abc123",
      "sender_id": "whatsapp:+5511999991111",
      "recipient_id": "whatsapp:+5511999998888",
      "content": "Hello, how are you?",
      "file_id": null,
      "timestamp": 1701234567890,
      "status": "DELIVERED",
      "delivered_at": 1701234568123,
      "read_at": null
    },
    {
      "message_id": "msg_def456",
      "sender_id": "whatsapp:+5511999998888",
      "recipient_id": "whatsapp:+5511999991111",
      "content": "I'm great, thanks!",
      "file_id": null,
      "timestamp": 1701234569456,
      "status": "READ",
      "delivered_at": 1701234570000,
      "read_at": 1701234575000
    }
  ],
  "pagination": {
    "limit": 50,
    "offset": 0,
    "returned": 2,
    "has_more": false
  }
}
```

### Mark Message as Read

**Endpoint**: `POST /v1/messages/{message_id}/read`

**Headers**:
```
Authorization: Bearer {token}
```

**Response** (200 OK):
```json
{
  "message_id": "msg_abc123",
  "status": "READ",
  "read_at": 1701234575000
}
```

---

## 📎 Files

### Upload File

**Endpoint**: `POST /v1/files`

**Headers**:
```
Authorization: Bearer {token}
Content-Type: multipart/form-data
```

**Request** (multipart/form-data):
```
file: [binary file data]
conversation_id: alice-bob-chat
```

**Response** (201 Created):
```json
{
  "file_id": "file_550e8400e29b41d4a716446655440000",
  "filename": "document.pdf",
  "content_type": "application/pdf",
  "size_bytes": 2458624,
  "checksum": "sha256:a3b5c8d9e1f2...",
  "uploaded_at": 1701234567890,
  "download_url": "http://localhost:8082/v1/files/file_550e8400e29b41d4a716446655440000/download"
}
```

**Limits**:
- Max file size: 2GB
- Supported formats: All (binary-safe)
- Streaming: Yes (memory-efficient for large files)

### Download File

**Endpoint**: `GET /v1/files/{file_id}/download`

**Headers**:
```
Authorization: Bearer {token}
```

**Response** (200 OK):
```json
{
  "file_id": "file_550e8400e29b41d4a716446655440000",
  "filename": "document.pdf",
  "download_url": "http://minio:9000/chat4all-files/conv_abc/file_xyz.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=...&X-Amz-Date=...&X-Amz-Expires=3600&X-Amz-Signature=...",
  "expires_in": 3600
}
```

**Usage**: Download directly from presigned URL (no authentication needed):
```bash
curl -o downloaded_file.pdf "{download_url}"
```

**Security**:
- Presigned URL valid for 1 hour
- Signature validated by MinIO
- No direct bucket access

---

## 👤 Users

### Get User Identities

**Endpoint**: `GET /v1/users/identities`

**Headers**:
```
Authorization: Bearer {token}
```

**Response** (200 OK):
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "identities": [
    {
      "platform": "whatsapp",
      "value": "+5511999991111",
      "verified": true,
      "linked_at": "2025-11-30T10:15:30Z"
    },
    {
      "platform": "instagram",
      "value": "@alice",
      "verified": true,
      "linked_at": "2025-11-30T10:16:45Z"
    }
  ]
}
```

### Add Identity

**Endpoint**: `POST /v1/users/identities`

**Headers**:
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request**:
```json
{
  "platform": "whatsapp",
  "value": "+5511999991111"
}
```

**Response** (201 Created):
```json
{
  "identity_id": "identity_abc123",
  "platform": "whatsapp",
  "value": "+5511999991111",
  "verified": false,
  "linked_at": "2025-11-30T10:15:30Z"
}
```

### Get User Conversations

**Endpoint**: `GET /v1/users/{user_id}/conversations`

**Headers**:
```
Authorization: Bearer {token}
```

**Response** (200 OK):
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "conversations": [
    {
      "conversation_id": "alice-bob-chat",
      "name": "Chat with Bob",
      "type": "private",
      "participant_ids": [
        "whatsapp:+5511999991111",
        "whatsapp:+5511999998888"
      ],
      "created_at": 1701234567890,
      "last_message_at": 1701234569456
    },
    {
      "conversation_id": "team-standup",
      "name": "Team Standup",
      "type": "group",
      "participant_ids": [
        "whatsapp:+5511999991111",
        "whatsapp:+5511999998888",
        "instagram:@carol"
      ],
      "created_at": 1701234567890,
      "last_message_at": 1701234575000
    }
  ],
  "total": 2
}
```

### Create Conversation

**Endpoint**: `POST /v1/conversations/create`

**Headers**:
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request**:
```json
{
  "conversation_id": "alice-carol-lunch",
  "name": "Lunch Plans",
  "participant_ids": [
    "whatsapp:+5511999991111",
    "instagram:@carol"
  ]
}
```

**Response** (201 Created):
```json
{
  "conversation_id": "alice-carol-lunch",
  "name": "Lunch Plans",
  "type": "private",
  "participant_ids": [
    "whatsapp:+5511999991111",
    "instagram:@carol"
  ],
  "created_at": 1701234567890
}
```

---

## 🔔 WebSocket Notifications

### Connect to WebSocket

**Endpoint**: `ws://localhost:8085/notifications?token={jwt_token}`

**Connection**:
```javascript
const token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...";
const ws = new WebSocket(`ws://localhost:8085/notifications?token=${token}`);

ws.onopen = () => {
  console.log('Connected to WebSocket');
};

ws.onmessage = (event) => {
  const notification = JSON.parse(event.data);
  console.log('Notification:', notification);
};

ws.onerror = (error) => {
  console.error('WebSocket error:', error);
};

ws.onclose = () => {
  console.log('WebSocket closed');
};
```

**Python Example**:
```python
import asyncio
import websockets
import json

async def listen_notifications(token):
    uri = f"ws://localhost:8085/notifications?token={token}"
    async with websockets.connect(uri) as websocket:
        print("Connected to WebSocket")
        async for message in websocket:
            notification = json.loads(message)
            print(f"Notification: {notification}")

asyncio.run(listen_notifications(your_token))
```

### Notification Types

#### Connection Established
```json
{
  "type": "connected",
  "connection_id": "conn_abc123",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": 1701234567890
}
```

#### New Message
```json
{
  "type": "new_message",
  "message_id": "msg_abc123",
  "conversation_id": "alice-bob-chat",
  "sender_id": "whatsapp:+5511999998888",
  "recipient_id": "whatsapp:+5511999991111",
  "content": "Hello from WebSocket!",
  "file_id": null,
  "timestamp": 1701234567890
}
```

#### Status Update
```json
{
  "type": "status_update",
  "message_id": "msg_abc123",
  "status": "DELIVERED",
  "timestamp": 1701234568123
}
```

#### Ping/Pong (Keep-Alive)
```json
// Server sends ping every 30 seconds
{
  "type": "ping"
}

// Client should respond with pong
{
  "type": "pong"
}
```

### Performance

- **Average Latency**: ~140ms (end-to-end: API → Kafka → Router → Redis → WebSocket)
- **Connection Limit**: Unlimited (educational version)
- **Reconnection**: Client responsibility (connection lost → reconnect with same token)

---

## ❤️ Health Check

### Service Health

**Endpoint**: `GET /health`

**Response** (200 OK):
```json
{
  "status": "UP",
  "timestamp": 1701234567890,
  "components": {
    "api": "UP",
    "kafka": "UP",
    "cassandra": "UP",
    "minio": "UP",
    "redis": "UP"
  }
}
```

---

## ❌ Error Responses

### Standard Error Format (RFC 7807)

**400 Bad Request** (Validation Error):
```json
{
  "error": "Validation failed",
  "details": {
    "conversation_id": "Required field missing",
    "content": "Must not exceed 4096 characters"
  },
  "timestamp": 1701234567890
}
```

**401 Unauthorized** (Invalid Token):
```json
{
  "error": "Invalid or expired token",
  "timestamp": 1701234567890
}
```

**404 Not Found** (Resource Not Found):
```json
{
  "error": "Message not found",
  "message_id": "msg_nonexistent",
  "timestamp": 1701234567890
}
```

**409 Conflict** (Duplicate):
```json
{
  "error": "Username already exists",
  "username": "alice",
  "timestamp": 1701234567890
}
```

**413 Payload Too Large** (File Too Big):
```json
{
  "error": "File size exceeds 2GB limit",
  "size_bytes": 2147483648,
  "max_size_bytes": 2147483648,
  "timestamp": 1701234567890
}
```

**500 Internal Server Error**:
```json
{
  "error": "Internal server error",
  "request_id": "req_abc123",
  "timestamp": 1701234567890
}
```

---

## 📊 Rate Limits

**Current Implementation**: No rate limits (educational version)

**Production Recommendations**:
- API: 100 requests/minute per user
- File Upload: 10 uploads/minute per user
- WebSocket: 1 connection per user
- Messages: 60 messages/minute per conversation

---

## 🧪 Testing Endpoints

### cURL Examples

**Register and Authenticate**:
```bash
# Register
curl -X POST http://localhost:8082/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"mypassword","email":"alice@example.com"}'

# Get token
TOKEN=$(curl -s -X POST http://localhost:8082/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"mypassword"}' \
  | jq -r '.access_token')
```

**Send Message**:
```bash
curl -X POST http://localhost:8082/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "alice-bob-chat",
    "recipient_id": "whatsapp:+5511999998888",
    "content": "Hello World!"
  }'
```

**Upload File**:
```bash
curl -X POST http://localhost:8082/v1/files \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@document.pdf" \
  -F "conversation_id=alice-bob-chat"
```

**Get Messages**:
```bash
curl -X GET "http://localhost:8082/v1/conversations/alice-bob-chat/messages?limit=50" \
  -H "Authorization: Bearer $TOKEN" | jq
```

---

## 📚 Additional Resources

- **[README.md](README.md)** - Quick start guide
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture documentation
- **[openapi.yaml](openapi.yaml)** - OpenAPI 3.0 specification (Swagger)
- **[cli/README.md](cli/README.md)** - Interactive CLI documentation

---

**Chat4All API** | Version 1.0 | November 2025
