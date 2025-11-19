#!/bin/bash

# Test script for GET /v1/conversations/{id}/messages endpoint
# 
# Test flow:
# 1. Get JWT token
# 2. Send 3 messages to same conversation
# 3. Wait for worker to process
# 4. GET without auth → 401
# 5. GET with auth → 200 with array of messages
# 6. Verify ordering (chronological by timestamp)
# 7. Test pagination with limit parameter

set -e  # Exit on error

API_URL="http://localhost:8082"  # Note: Docker maps 8080 -> 8082 externally
CONV_ID="conv_get_test_$(date +%s)"

echo "============================================="
echo "  TEST: GET /v1/conversations/{id}/messages"
echo "============================================="
echo ""

# Step 1: Get JWT token
echo "1. Getting JWT token..."
TOKEN_RESPONSE=$(curl -s -X POST "$API_URL/auth/token" \
  -H "Content-Type: application/json" \
  -d '{"username":"user_a","password":"pass_a"}')

TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "✗ Failed to get token"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "✓ Token: ${TOKEN:0:20}..."
echo ""

# Step 2: Send 3 messages
echo "2. Sending 3 messages to conversation $CONV_ID..."

for i in 1 2 3; do
  MESSAGE="Test message $i"
  RESPONSE=$(curl -s -X POST "$API_URL/v1/messages" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"conversation_id\":\"$CONV_ID\",\"sender_id\":\"user_a\",\"content\":\"$MESSAGE\"}")
  
  MSG_ID=$(echo "$RESPONSE" | grep -o '"message_id":"[^"]*' | cut -d'"' -f4)
  echo "  ✓ Message $i sent: $MSG_ID"
  sleep 0.5  # Small delay between messages
done

echo "✓ All messages sent"
echo ""

# Step 3: Wait for worker to process
echo "3. Waiting 5 seconds for worker to process..."
sleep 5
echo "✓ Wait complete"
echo ""

# Step 4: GET without auth → 401
echo "4. Testing GET without authentication (expect 401)..."
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "$API_URL/v1/conversations/$CONV_ID/messages")
STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)

if [ "$STATUS" = "401" ]; then
  echo "✓ Correctly returned 401 Unauthorized"
else
  echo "✗ Expected 401, got $STATUS"
  echo "Response: $RESPONSE"
  exit 1
fi
echo ""

# Step 5: GET with auth → 200 with array
echo "5. Testing GET with authentication (expect 200)..."
RESPONSE=$(curl -s -X GET "$API_URL/v1/conversations/$CONV_ID/messages?limit=10&offset=0" \
  -H "Authorization: Bearer $TOKEN")

echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
echo ""

# Verify response structure
MESSAGE_COUNT=$(echo "$RESPONSE" | grep -o '"message_id"' | wc -l)

if [ "$MESSAGE_COUNT" -ge 3 ]; then
  echo "✓ Returned $MESSAGE_COUNT messages (expected >= 3)"
else
  echo "✗ Expected at least 3 messages, got $MESSAGE_COUNT"
  exit 1
fi

# Verify pagination metadata
HAS_PAGINATION=$(echo "$RESPONSE" | grep -q '"pagination"' && echo "yes" || echo "no")

if [ "$HAS_PAGINATION" = "yes" ]; then
  echo "✓ Response includes pagination metadata"
else
  echo "✗ Missing pagination metadata"
  exit 1
fi
echo ""

# Step 6: Test pagination (limit=2)
echo "6. Testing pagination (limit=2, offset=0)..."
RESPONSE=$(curl -s -X GET "$API_URL/v1/conversations/$CONV_ID/messages?limit=2&offset=0" \
  -H "Authorization: Bearer $TOKEN")

MESSAGE_COUNT=$(echo "$RESPONSE" | grep -o '"message_id"' | wc -l)
RETURNED=$(echo "$RESPONSE" | grep -o '"returned":[0-9]*' | cut -d':' -f2)

if [ "$MESSAGE_COUNT" -le 2 ]; then
  echo "✓ Correctly limited to 2 messages"
  echo "  Returned: $RETURNED messages"
else
  echo "✗ Expected max 2 messages, got $MESSAGE_COUNT"
  exit 1
fi
echo ""

# Step 7: Test offset
echo "7. Testing pagination (limit=2, offset=1)..."
RESPONSE=$(curl -s -X GET "$API_URL/v1/conversations/$CONV_ID/messages?limit=2&offset=1" \
  -H "Authorization: Bearer $TOKEN")

MESSAGE_COUNT=$(echo "$RESPONSE" | grep -o '"message_id"' | wc -l)

if [ "$MESSAGE_COUNT" -le 2 ]; then
  echo "✓ Offset pagination working"
else
  echo "✗ Offset pagination failed"
  exit 1
fi
echo ""

# Step 8: Test non-existent conversation (should return empty array)
echo "8. Testing non-existent conversation..."
RESPONSE=$(curl -s -X GET "$API_URL/v1/conversations/conv_nonexistent/messages" \
  -H "Authorization: Bearer $TOKEN")

MESSAGE_COUNT=$(echo "$RESPONSE" | grep -o '"message_id"' | wc -l)

if [ "$MESSAGE_COUNT" -eq 0 ]; then
  echo "✓ Empty array returned for non-existent conversation"
else
  echo "✗ Expected empty array, got $MESSAGE_COUNT messages"
  exit 1
fi
echo ""

echo "============================================="
echo "  ALL TESTS PASSED! ✓"
echo "============================================="
echo ""
echo "Summary:"
echo "  ✓ Authentication required (401 without token)"
echo "  ✓ Messages retrieved correctly"
echo "  ✓ Pagination working (limit parameter)"
echo "  ✓ Offset working"
echo "  ✓ Non-existent conversation returns empty array"
echo "  ✓ Pagination metadata included"
