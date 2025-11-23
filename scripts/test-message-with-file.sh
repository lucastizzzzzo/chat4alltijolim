#!/bin/bash

# test-message-with-file.sh - Integration test for messages with file attachments
# 
# Purpose: Validate Phase 4 implementation (Messages with Files)
#
# Test flow:
# 1. Authenticate (get JWT token)
# 2. Upload file to MinIO
# 3. Send message with type="file" and file_id
# 4. Retrieve conversation messages
# 5. Verify file metadata is included
# 6. Verify presigned download URL is generated
# 7. Download file using presigned URL
# 8. Verify downloaded file matches original
#
# Usage: ./scripts/test-message-with-file.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
API_URL="http://localhost:8080"
TEST_USER="user_a"
TEST_PASSWORD="password_a"
TEST_CONV="conv-test-file-msg"

# Create temp directory for test files
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Phase 4: Messages with File Attachments - Integration Test"
echo "════════════════════════════════════════════════════════════════"
echo ""

# ========================================
# Test 1: Authenticate
# ========================================
echo -e "${YELLOW}[Test 1]${NC} Authenticating to get JWT token..."

AUTH_RESPONSE=$(curl -s -X POST "$API_URL/auth/token" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$TEST_USER\",\"password\":\"$TEST_PASSWORD\"}")

JWT_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$JWT_TOKEN" ]; then
    echo -e "${RED}✗ Failed to get JWT token${NC}"
    echo "Response: $AUTH_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ JWT token obtained${NC}"
echo ""

# ========================================
# Test 2: Upload test file
# ========================================
echo -e "${YELLOW}[Test 2]${NC} Uploading test file..."

# Create test file (1KB of random data)
dd if=/dev/urandom of="$TEST_DIR/test-document.pdf" bs=1024 count=1 2>/dev/null

# Calculate original checksum
ORIGINAL_SHA256=$(sha256sum "$TEST_DIR/test-document.pdf" | awk '{print $1}')
echo "Original file SHA256: $ORIGINAL_SHA256"

# Upload file
UPLOAD_RESPONSE=$(curl -s -X POST "$API_URL/v1/files" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -F "conversation_id=$TEST_CONV" \
    -F "file=@$TEST_DIR/test-document.pdf")

FILE_ID=$(echo "$UPLOAD_RESPONSE" | grep -o '"file_id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$FILE_ID" ]; then
    echo -e "${RED}✗ File upload failed${NC}"
    echo "Response: $UPLOAD_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ File uploaded successfully${NC}"
echo "File ID: $FILE_ID"
echo ""

# ========================================
# Test 3: Send message with file attachment
# ========================================
echo -e "${YELLOW}[Test 3]${NC} Sending message with file attachment..."

MESSAGE_RESPONSE=$(curl -s -X POST "$API_URL/v1/messages" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"conversation_id\": \"$TEST_CONV\",
        \"sender_id\": \"$TEST_USER\",
        \"content\": \"Check out this document!\",
        \"type\": \"file\",
        \"file_id\": \"$FILE_ID\"
    }")

MESSAGE_ID=$(echo "$MESSAGE_RESPONSE" | grep -o '"message_id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$MESSAGE_ID" ]; then
    echo -e "${RED}✗ Failed to send message${NC}"
    echo "Response: $MESSAGE_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ Message sent successfully${NC}"
echo "Message ID: $MESSAGE_ID"
echo ""

# Wait for message to be processed
echo "Waiting 5 seconds for message processing..."
sleep 5
echo ""

# ========================================
# Test 4: Retrieve conversation messages
# ========================================
echo -e "${YELLOW}[Test 4]${NC} Retrieving conversation messages..."

CONV_RESPONSE=$(curl -s -X GET "$API_URL/v1/conversations/$TEST_CONV/messages?limit=10" \
    -H "Authorization: Bearer $JWT_TOKEN")

# Check if response contains our message
if ! echo "$CONV_RESPONSE" | grep -q "$MESSAGE_ID"; then
    echo -e "${RED}✗ Message not found in conversation${NC}"
    echo "Response: $CONV_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ Message found in conversation${NC}"
echo ""

# ========================================
# Test 5: Verify file metadata in response
# ========================================
echo -e "${YELLOW}[Test 5]${NC} Verifying file metadata in message..."

# Check if file_id is present
if ! echo "$CONV_RESPONSE" | grep -q "\"file_id\":\"$FILE_ID\""; then
    echo -e "${RED}✗ file_id not found in message${NC}"
    exit 1
fi

echo -e "${GREEN}✓ file_id present in message${NC}"

# Check if file_metadata is present
if ! echo "$CONV_RESPONSE" | grep -q "\"file_metadata\""; then
    echo -e "${RED}✗ file_metadata not found in message${NC}"
    exit 1
fi

echo -e "${GREEN}✓ file_metadata present in message${NC}"

# Extract filename from metadata
FILENAME=$(echo "$CONV_RESPONSE" | grep -o '"filename":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "  Filename: $FILENAME"

# Extract size from metadata
SIZE_BYTES=$(echo "$CONV_RESPONSE" | grep -o '"size_bytes":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "  Size: $SIZE_BYTES bytes"

# Extract mimetype from metadata
MIMETYPE=$(echo "$CONV_RESPONSE" | grep -o '"mimetype":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "  MIME type: $MIMETYPE"

echo ""

# ========================================
# Test 6: Verify presigned download URL
# ========================================
echo -e "${YELLOW}[Test 6]${NC} Verifying presigned download URL..."

# Check if file_download_url is present
if ! echo "$CONV_RESPONSE" | grep -q "\"file_download_url\""; then
    echo -e "${RED}✗ file_download_url not found in message${NC}"
    echo "Response excerpt:"
    echo "$CONV_RESPONSE" | grep -A10 "$MESSAGE_ID"
    exit 1
fi

echo -e "${GREEN}✓ file_download_url present in message${NC}"

# Extract download URL
DOWNLOAD_URL=$(echo "$CONV_RESPONSE" | grep -o '"file_download_url":"[^"]*"' | cut -d'"' -f4)
echo "Download URL (truncated): ${DOWNLOAD_URL:0:100}..."

# Verify URL structure (should contain X-Amz-Signature)
if ! echo "$DOWNLOAD_URL" | grep -q "X-Amz-Signature"; then
    echo -e "${RED}✗ Download URL doesn't contain S3 signature${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Download URL has S3 signature${NC}"
echo ""

# ========================================
# Test 7: Download file using presigned URL
# ========================================
echo -e "${YELLOW}[Test 7]${NC} Downloading file using presigned URL..."

# Replace internal hostname with localhost (known limitation)
DOWNLOAD_URL_EXTERNAL=$(echo "$DOWNLOAD_URL" | sed 's|http://minio:9000|http://localhost:9000|g')

# Download file
curl -s -o "$TEST_DIR/downloaded-document.pdf" "$DOWNLOAD_URL_EXTERNAL"

if [ ! -f "$TEST_DIR/downloaded-document.pdf" ]; then
    echo -e "${RED}✗ Download failed${NC}"
    exit 1
fi

DOWNLOADED_SIZE=$(stat -c%s "$TEST_DIR/downloaded-document.pdf" 2>/dev/null || stat -f%z "$TEST_DIR/downloaded-document.pdf")
echo -e "${GREEN}✓ File downloaded successfully${NC}"
echo "Downloaded size: $DOWNLOADED_SIZE bytes"
echo ""

# ========================================
# Test 8: Verify file integrity
# ========================================
echo -e "${YELLOW}[Test 8]${NC} Verifying file integrity..."

DOWNLOADED_SHA256=$(sha256sum "$TEST_DIR/downloaded-document.pdf" | awk '{print $1}')

echo "Original SHA256:   $ORIGINAL_SHA256"
echo "Downloaded SHA256: $DOWNLOADED_SHA256"

if [ "$ORIGINAL_SHA256" == "$DOWNLOADED_SHA256" ]; then
    echo -e "${GREEN}✓ Checksum matches! File integrity verified${NC}"
else
    echo -e "${RED}✗ Checksum mismatch! File corrupted${NC}"
    exit 1
fi
echo ""

# ========================================
# Test 9: Send text-only message (no file)
# ========================================
echo -e "${YELLOW}[Test 9]${NC} Sending text-only message (no file)..."

TEXT_MSG_RESPONSE=$(curl -s -X POST "$API_URL/v1/messages" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"conversation_id\": \"$TEST_CONV\",
        \"sender_id\": \"$TEST_USER\",
        \"content\": \"This is a regular text message\"
    }")

TEXT_MESSAGE_ID=$(echo "$TEXT_MSG_RESPONSE" | grep -o '"message_id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TEXT_MESSAGE_ID" ]; then
    echo -e "${RED}✗ Failed to send text message${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Text message sent successfully${NC}"
echo "Message ID: $TEXT_MESSAGE_ID"
echo ""

# ========================================
# Cleanup
# ========================================
echo -e "${YELLOW}[Cleanup]${NC} Removing test files..."
rm -rf "$TEST_DIR"
echo -e "${GREEN}✓ Test files removed${NC}"
echo ""

# ========================================
# Summary
# ========================================
echo "════════════════════════════════════════════════════════════════"
echo -e "${GREEN}✓ All Phase 4 tests passed!${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "📚 Learning Checkpoints:"
echo ""
echo "1. Message Types:"
echo "   - type='text': Regular text message (default)"
echo "   - type='file': Message with file attachment"
echo ""
echo "2. File Attachment Flow:"
echo "   1. Upload file → get file_id"
echo "   2. Send message with type='file' and file_id"
echo "   3. Router-worker persists file_id + metadata"
echo "   4. GET conversation → includes file info + download URL"
echo ""
echo "3. Presigned URL Pattern:"
echo "   - Generated on-demand when fetching messages"
echo "   - Valid for 1 hour (configurable)"
echo "   - Client downloads directly from MinIO (no API proxy)"
echo "   - Scalable: API doesn't handle file transfer"
echo ""
echo "4. Data Denormalization:"
echo "   - file_metadata embedded in messages table"
echo "   - Trade-off: slight duplication vs query performance"
echo "   - NoSQL best practice: optimize for read patterns"
echo ""
echo "5. Backward Compatibility:"
echo "   - Text messages work without changes"
echo "   - file_id and file_metadata are optional"
echo "   - Old clients ignore new fields"
echo ""
echo "Real-world Usage:"
echo "  1. User uploads file (photo, PDF, video)"
echo "  2. App sends message with file_id"
echo "  3. Recipients fetch conversation"
echo "  4. App displays file thumbnail + download button"
echo "  5. User clicks → download from presigned URL"
echo ""
echo "Tasks Completed: T132-T138, T142"
echo "Progress: 37/112 tasks (33%)"
echo ""
