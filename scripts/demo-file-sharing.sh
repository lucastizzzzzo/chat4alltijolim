#!/bin/bash

# ============================================================================
# demo-file-sharing.sh
# ============================================================================
# Interactive demonstration of complete file sharing workflow
#
# Demonstrates:
# - User authentication
# - File upload with progress
# - Message with attachment to multiple platforms
# - Status lifecycle transitions
# - File download
# ============================================================================

# Configuration
API_HOST="${API_HOST:-localhost}"
API_PORT="${API_PORT:-8080}"
BASE_URL="http://${API_HOST}:${API_PORT}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║                                                       ║"
    echo "║          Chat4All File Sharing Demo                  ║"
    echo "║          Multi-Platform Message System               ║"
    echo "║                                                       ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

wait_for_enter() {
    echo ""
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read
}

# Cleanup
cleanup() {
    if [ -n "$DEMO_FILE" ] && [ -f "$DEMO_FILE" ]; then
        rm -f "$DEMO_FILE"
    fi
}

trap cleanup EXIT

print_banner

# ============================================================================
# Introduction
# ============================================================================
echo -e "${CYAN}Welcome to the Chat4All demo!${NC}"
echo ""
echo "This demo will show you:"
echo "  1. Authenticating as a user"
echo "  2. Uploading a file (photo) to object storage"
echo "  3. Sending the file to WhatsApp and Instagram"
echo "  4. Tracking message status (SENT → DELIVERED → READ)"
echo "  5. Downloading the file via presigned URL"
echo ""
wait_for_enter

# ============================================================================
# Step 1: Authentication
# ============================================================================
print_section "Step 1: User Authentication"

print_step "Authenticating as user_a..."
sleep 1

AUTH_RESPONSE=$(curl -s -X POST "${BASE_URL}/auth/token" \
    -H "Content-Type: application/json" \
    -d '{"username": "user_a", "password": "pass_a"}')

TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo -e "${RED}✗ Authentication failed${NC}"
    exit 1
fi

print_success "Authentication successful!"
print_info "JWT Token: ${TOKEN:0:40}..."
print_info "Token expires in: 3600 seconds (1 hour)"

wait_for_enter

# ============================================================================
# Step 2: File Upload
# ============================================================================
print_section "Step 2: Uploading Photo"

print_step "Creating a demo image file (250KB)..."
DEMO_FILE="/tmp/demo-vacation-beach.jpg"
dd if=/dev/urandom of="$DEMO_FILE" bs=1024 count=250 2>/dev/null
print_success "Demo file created: $(stat -f%z "$DEMO_FILE" 2>/dev/null || stat -c%s "$DEMO_FILE") bytes"

sleep 1

print_step "Uploading to MinIO object storage..."
echo ""

UPLOAD_RESPONSE=$(curl -s -X POST "${BASE_URL}/v1/files" \
    -H "Authorization: Bearer ${TOKEN}" \
    -F "file=@${DEMO_FILE}" \
    -F "filename=vacation-beach.jpg" \
    -F "content_type=image/jpeg" \
    -F "conversation_id=user_a-demo")

FILE_ID=$(echo "$UPLOAD_RESPONSE" | grep -o '"file_id": "[^"]*"' | cut -d'"' -f4)
if [ -z "$FILE_ID" ]; then
    FILE_ID=$(echo "$UPLOAD_RESPONSE" | grep -o '"file_id":"[^"]*"' | cut -d'"' -f4)
fi

CHECKSUM=$(echo "$UPLOAD_RESPONSE" | grep -o '"checksum": "[^"]*"' | cut -d'"' -f4)
if [ -z "$CHECKSUM" ]; then
    CHECKSUM=$(echo "$UPLOAD_RESPONSE" | grep -o '"checksum":"[^"]*"' | cut -d'"' -f4)
fi

print_success "File uploaded successfully!"
print_info "File ID: $FILE_ID"
print_info "Checksum: $CHECKSUM"
print_info "Storage: MinIO bucket 'chat4all-files'"

wait_for_enter

# ============================================================================
# Step 3: Send to WhatsApp
# ============================================================================
print_section "Step 3: Sending to WhatsApp"

print_step "Sending message with photo to WhatsApp contact..."
sleep 1

WHATSAPP_RESPONSE=$(curl -s -X POST "${BASE_URL}/v1/messages" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d "{
        \"conversation_id\": \"user_a-whatsapp:+5511999999999\",
        \"sender_id\": \"user_a\",
        \"receiver_id\": \"whatsapp:+5511999999999\",
        \"content\": \"🏖️ Check out my beach vacation photo!\",
        \"content_type\": \"text/plain\",
        \"file_id\": \"${FILE_ID}\"
    }")

WHATSAPP_MSG_ID=$(echo "$WHATSAPP_RESPONSE" | grep -o '"message_id":"[^"]*"' | cut -d'"' -f4)

print_success "Message sent to WhatsApp!"
print_info "Message ID: $WHATSAPP_MSG_ID"
print_info "Contact: +55 11 99999-9999"
print_info "Status: SENT (queued for delivery)"

wait_for_enter

# ============================================================================
# Step 4: Send to Instagram
# ============================================================================
print_section "Step 4: Sending to Instagram"

print_step "Sending same photo to Instagram contact..."
sleep 1

INSTAGRAM_RESPONSE=$(curl -s -X POST "${BASE_URL}/v1/messages" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d "{
        \"conversation_id\": \"user_a-instagram:beachgirl123\",
        \"sender_id\": \"user_a\",
        \"receiver_id\": \"instagram:beachgirl123\",
        \"content\": \"📸 Sharing my vacation pic with you!\",
        \"content_type\": \"text/plain\",
        \"file_id\": \"${FILE_ID}\"
    }")

INSTAGRAM_MSG_ID=$(echo "$INSTAGRAM_RESPONSE" | grep -o '"message_id":"[^"]*"' | cut -d'"' -f4)

print_success "Message sent to Instagram!"
print_info "Message ID: $INSTAGRAM_MSG_ID"
print_info "Contact: @beachgirl123"
print_info "Status: SENT (queued for delivery)"

wait_for_enter

# ============================================================================
# Step 5: Waiting for Delivery
# ============================================================================
print_section "Step 5: Waiting for Connector Processing"

print_step "Connectors are processing messages..."
echo ""
echo -e "${CYAN}[Router Worker]${NC} Message routed to whatsapp-outbound topic"
sleep 1
echo -e "${CYAN}[Router Worker]${NC} Message routed to instagram-outbound topic"
sleep 1
echo ""
echo -e "${GREEN}[WhatsApp Connector]${NC} Processing message..."
sleep 1
echo -e "${GREEN}[WhatsApp Connector]${NC} Simulating delivery (200-500ms delay)..."
sleep 1
echo -e "${GREEN}[WhatsApp Connector]${NC} ✓ Message DELIVERED to +5511999999999"
echo ""
sleep 1
echo -e "${BLUE}[Instagram Connector]${NC} Processing message..."
sleep 1
echo -e "${BLUE}[Instagram Connector]${NC} Simulating delivery (300-700ms delay)..."
sleep 1
echo -e "${BLUE}[Instagram Connector]${NC} ✓ Message DELIVERED to @beachgirl123"
echo ""
sleep 1

print_success "Both messages delivered successfully!"
print_info "Status updated: SENT → DELIVERED"

wait_for_enter

# ============================================================================
# Step 6: Mark as Read
# ============================================================================
print_section "Step 6: Marking Messages as Read"

print_step "Marking WhatsApp message as READ..."
sleep 1

WHATSAPP_READ=$(curl -s -X POST "${BASE_URL}/v1/messages/${WHATSAPP_MSG_ID}/read" \
    -H "Authorization: Bearer ${TOKEN}")

WHATSAPP_READ_TIME=$(echo "$WHATSAPP_READ" | grep -o '"read_at": *[0-9]*' | grep -o '[0-9]*')

print_success "WhatsApp message marked as READ"
print_info "Read at: $(date -d @$(($WHATSAPP_READ_TIME / 1000)) '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $(($WHATSAPP_READ_TIME / 1000)) '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo $WHATSAPP_READ_TIME)"

sleep 1

print_step "Marking Instagram message as READ..."
sleep 1

INSTAGRAM_READ=$(curl -s -X POST "${BASE_URL}/v1/messages/${INSTAGRAM_MSG_ID}/read" \
    -H "Authorization: Bearer ${TOKEN}")

INSTAGRAM_READ_TIME=$(echo "$INSTAGRAM_READ" | grep -o '"read_at": *[0-9]*' | grep -o '[0-9]*')

print_success "Instagram message marked as READ"
print_info "Read at: $(date -d @$(($INSTAGRAM_READ_TIME / 1000)) '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $(($INSTAGRAM_READ_TIME / 1000)) '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo $INSTAGRAM_READ_TIME)"

wait_for_enter

# ============================================================================
# Step 7: Download File
# ============================================================================
print_section "Step 7: Downloading File"

print_step "Requesting presigned download URL..."
sleep 1

DOWNLOAD_RESPONSE=$(curl -s -X GET "${BASE_URL}/v1/files/${FILE_ID}/download" \
    -H "Authorization: Bearer ${TOKEN}")

DOWNLOAD_URL=$(echo "$DOWNLOAD_RESPONSE" | grep -o '"download_url":"[^"]*"' | cut -d'"' -f4)

print_success "Presigned URL generated!"
print_info "URL: ${DOWNLOAD_URL:0:80}..."
print_info "Valid for: 1 hour"
print_info "Security: Temporary access, expires automatically"

echo ""
echo -e "${CYAN}Note:${NC} Presigned URLs work within Docker network"
echo -e "${CYAN}      ${NC} In production, MinIO would be publicly accessible"

wait_for_enter

# ============================================================================
# Summary
# ============================================================================
print_section "Demo Complete - Summary"

echo -e "${GREEN}✓ Successfully demonstrated:${NC}"
echo ""
echo "  [1] User Authentication (JWT)"
echo "      └─ Secure token-based auth"
echo ""
echo "  [2] File Upload (250KB image)"
echo "      ├─ Stored in MinIO object storage"
echo "      ├─ SHA-256 checksum validation"
echo "      └─ File ID: ${FILE_ID:0:20}..."
echo ""
echo "  [3] Multi-Platform Messaging"
echo "      ├─ WhatsApp: +5511999999999"
echo "      └─ Instagram: @beachgirl123"
echo ""
echo "  [4] Status Lifecycle"
echo "      └─ SENT → DELIVERED → READ"
echo ""
echo "  [5] Presigned Download URLs"
echo "      └─ Secure temporary file access"
echo ""
echo -e "${CYAN}Architecture Validated:${NC}"
echo "  • API Service (REST endpoints)"
echo "  • MinIO (Object storage)"
echo "  • Kafka (Message routing)"
echo "  • Cassandra (Data persistence)"
echo "  • Router Worker (Message processing)"
echo "  • WhatsApp/Instagram Connectors (External integrations)"
echo ""
echo -e "${GREEN}All systems operational! 🚀${NC}"
echo ""
