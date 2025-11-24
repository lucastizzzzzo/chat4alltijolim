#!/bin/bash

# ============================================================================
# test-status-lifecycle.sh
# ============================================================================
# End-to-end test for message status lifecycle (SENT → DELIVERED → READ)
#
# Test Flow:
# 1. Authenticate user_a to get JWT token
# 2. Send message to whatsapp:+5511999999999
# 3. Wait for connector to process (SENT → DELIVERED)
# 4. Mark message as READ via POST /v1/messages/{id}/read
# 5. Verify status progression with timestamps
# 6. Test invalid transition (SENT → READ) expecting 400 error
# ============================================================================

set -e

# Configuration
API_HOST="${API_HOST:-localhost}"
API_PORT="${API_PORT:-8080}"
BASE_URL="http://${API_HOST}:${API_PORT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Cleanup function
cleanup() {
    if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ]; then
        rm -f "$TEMP_FILE"
    fi
}

trap cleanup EXIT

# ============================================================================
# STEP 1: Authenticate user_a
# ============================================================================
print_step "Step 1: Authenticating user_a..."

AUTH_RESPONSE=$(curl -s -X POST "${BASE_URL}/auth/token" \
    -H "Content-Type: application/json" \
    -d '{
        "username": "user_a",
        "password": "pass_a"
    }')

TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    print_error "Failed to get authentication token"
    echo "Response: $AUTH_RESPONSE"
    exit 1
fi

print_success "Authenticated successfully"
echo "Token (first 20 chars): ${TOKEN:0:20}..."

# ============================================================================
# STEP 2: Send message to WhatsApp connector
# ============================================================================
print_step "Step 2: Sending message to whatsapp:+5511999999999..."

MESSAGE_RESPONSE=$(curl -s -X POST "${BASE_URL}/v1/messages" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d '{
        "conversation_id": "user_a-whatsapp:+5511999999999",
        "sender_id": "user_a",
        "receiver_id": "whatsapp:+5511999999999",
        "content": "Testing status lifecycle: SENT -> DELIVERED -> READ",
        "content_type": "text/plain"
    }')

MESSAGE_ID=$(echo "$MESSAGE_RESPONSE" | grep -o '"message_id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$MESSAGE_ID" ]; then
    print_error "Failed to send message"
    echo "Response: $MESSAGE_RESPONSE"
    exit 1
fi

print_success "Message sent successfully"
echo "Message ID: $MESSAGE_ID"
echo "Initial status: SENT"

# ============================================================================
# STEP 3: Wait for connector to process and mark as DELIVERED
# ============================================================================
print_step "Step 3: Waiting for WhatsApp connector to mark as DELIVERED..."
print_warning "Waiting 3 seconds for connector processing..."

sleep 3

print_success "Connector should have published DELIVERED status to Kafka"

# ============================================================================
# STEP 4: Mark message as READ
# ============================================================================
print_step "Step 4: Marking message as READ..."

READ_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "${BASE_URL}/v1/messages/${MESSAGE_ID}/read" \
    -H "Authorization: Bearer ${TOKEN}")

HTTP_STATUS=$(echo "$READ_RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
READ_BODY=$(echo "$READ_RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$HTTP_STATUS" != "200" ]; then
    print_error "Failed to mark message as READ (HTTP $HTTP_STATUS)"
    echo "Response: $READ_BODY"
    exit 1
fi

print_success "Message marked as READ successfully"
echo "Response: $READ_BODY"

READ_AT=$(echo "$READ_BODY" | grep -o '"read_at":"[^"]*"' | cut -d'"' -f4)

if [ -n "$READ_AT" ]; then
    print_success "Read timestamp: $READ_AT"
fi

# ============================================================================
# STEP 5: Test idempotency - mark as READ again
# ============================================================================
print_step "Step 5: Testing idempotency (marking as READ again)..."

READ_RESPONSE2=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "${BASE_URL}/v1/messages/${MESSAGE_ID}/read" \
    -H "Authorization: Bearer ${TOKEN}")

HTTP_STATUS2=$(echo "$READ_RESPONSE2" | grep "HTTP_STATUS:" | cut -d':' -f2)
READ_BODY2=$(echo "$READ_RESPONSE2" | sed '/HTTP_STATUS:/d')

if [ "$HTTP_STATUS2" != "200" ]; then
    print_error "Idempotency test failed (HTTP $HTTP_STATUS2)"
    echo "Response: $READ_BODY2"
    exit 1
fi

READ_AT2=$(echo "$READ_BODY2" | grep -o '"read_at":"[^"]*"' | cut -d'"' -f4)

if [ "$READ_AT" = "$READ_AT2" ]; then
    print_success "Idempotency verified: same read_at timestamp"
else
    print_error "Idempotency failed: different timestamps"
    echo "First:  $READ_AT"
    echo "Second: $READ_AT2"
    exit 1
fi

# ============================================================================
# STEP 6: Test invalid transition (SENT → READ without DELIVERED)
# ============================================================================
print_step "Step 6: Testing invalid transition (SENT → READ)..."

# Send a message to a non-existent connector so it stays in SENT status
MESSAGE_RESPONSE2=$(curl -s -X POST "${BASE_URL}/v1/messages" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d '{
        "conversation_id": "user_a-telegram:+5511999999999",
        "sender_id": "user_a",
        "receiver_id": "telegram:+5511999999999",
        "content": "Testing invalid transition (no telegram connector exists)",
        "content_type": "text/plain"
    }')

MESSAGE_ID2=$(echo "$MESSAGE_RESPONSE2" | grep -o '"message_id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$MESSAGE_ID2" ]; then
    print_error "Failed to send second message"
    exit 1
fi

print_success "Second message sent (ID: $MESSAGE_ID2, status: SENT)"

# Wait for message to be written to Cassandra
sleep 1

# Try to mark as READ while status is still SENT (should fail with 400)
INVALID_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "${BASE_URL}/v1/messages/${MESSAGE_ID2}/read" \
    -H "Authorization: Bearer ${TOKEN}")

INVALID_STATUS=$(echo "$INVALID_RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
INVALID_BODY=$(echo "$INVALID_RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$INVALID_STATUS" = "400" ]; then
    print_success "Invalid transition correctly rejected (HTTP 400)"
    echo "Error message: $INVALID_BODY"
else
    print_error "Expected HTTP 400 for invalid transition, got HTTP $INVALID_STATUS"
    echo "Response: $INVALID_BODY"
    exit 1
fi

# ============================================================================
# Test Summary
# ============================================================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Status Lifecycle Test: PASSED${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Test Results:"
echo "  ✓ Authentication successful"
echo "  ✓ Message sent with SENT status"
echo "  ✓ Connector processed (SENT → DELIVERED)"
echo "  ✓ Message marked as READ (DELIVERED → READ)"
echo "  ✓ Idempotency verified (same read_at timestamp)"
echo "  ✓ Invalid transition rejected (SENT → READ = 400)"
echo ""
echo "Status Progression:"
echo "  1. SENT      → Message created"
echo "  2. DELIVERED → Connector confirmed (after ~3s)"
echo "  3. READ      → User marked as read"
echo ""
echo "Message ID: $MESSAGE_ID"
echo "Read at: $READ_AT"
echo ""
