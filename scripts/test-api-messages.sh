#!/bin/bash

# Test Script: POST /v1/messages
# 
# This script demonstrates the complete flow:
# 1. Get JWT token from /auth/token
# 2. Send message using /v1/messages (with JWT)
# 3. Verify responses

set -e

API_URL="http://localhost:8080"

echo "========================================"
echo "  Chat4All API - Message Sending Test"
echo "========================================"
echo

# Step 1: Authenticate and get JWT token
echo "Step 1: Authenticating as user_a..."
AUTH_RESPONSE=$(curl -s -X POST "$API_URL/auth/token" \
  -H "Content-Type: application/json" \
  -d '{"username":"user_a","password":"pass_a"}')

echo "Response: $AUTH_RESPONSE"
echo

# Extract access token using grep/sed (no jq dependency)
TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "❌ Failed to get token!"
  exit 1
fi

echo "✅ Token received: ${TOKEN:0:50}..."
echo

# Step 2: Send message
echo "Step 2: Sending message..."
MESSAGE_RESPONSE=$(curl -s -X POST "$API_URL/v1/messages" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "conversation_id": "conv_test123",
    "sender_id": "user_a",
    "content": "Hello from test script!"
  }')

echo "Response: $MESSAGE_RESPONSE"
echo

# Check if message_id is present (indicates success)
if echo "$MESSAGE_RESPONSE" | grep -q '"message_id"'; then
  echo "✅ Message sent successfully!"
else
  echo "❌ Failed to send message!"
  exit 1
fi

echo
echo "========================================"
echo "  ✅ All tests passed!"
echo "========================================"
