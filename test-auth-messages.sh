#!/bin/bash

echo "========================================="
echo "  Testing Authentication + Messages API"
echo "========================================="
echo ""

# 1. Get JWT token
echo "Step 1: Getting JWT token..."
AUTH_RESPONSE=$(curl -s -X POST http://localhost:8081/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username":"user_a","password":"pass_a"}')

echo "Response: $AUTH_RESPONSE"

TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "❌ Failed to get token"
  exit 1
fi

echo "✅ Token received: ${TOKEN:0:50}..."
echo ""

# 2. Try to send message WITHOUT token (should fail)
echo "Step 2: Trying to send message WITHOUT token (should fail)..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://localhost:8081/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"conversation_id":"conv_test","sender_id":"user_a","content":"Test without auth"}')

HTTP_CODE=$(echo "$RESPONSE" | grep HTTP_CODE | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v HTTP_CODE)

echo "Response: $BODY"
echo "HTTP Status: $HTTP_CODE"

if [ "$HTTP_CODE" = "401" ]; then
  echo "✅ Correctly rejected (401 Unauthorized)"
else
  echo "❌ Expected 401, got $HTTP_CODE"
fi
echo ""

# 3. Send message WITH valid token (should succeed)
echo "Step 3: Sending message WITH valid token..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://localhost:8081/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"conversation_id":"conv_authenticated","sender_id":"user_a","content":"Authenticated message!"}')

HTTP_CODE=$(echo "$RESPONSE" | grep HTTP_CODE | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v HTTP_CODE)

echo "Response: $BODY"
echo "HTTP Status: $HTTP_CODE"

if [ "$HTTP_CODE" = "202" ]; then
  echo "✅ Message accepted (202)"
else
  echo "❌ Expected 202, got $HTTP_CODE"
fi
echo ""

# 4. Try to send message with mismatched sender_id (should fail 403)
echo "Step 4: Trying to send message with WRONG sender_id (should fail)..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://localhost:8081/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"conversation_id":"conv_test","sender_id":"user_b","content":"Impersonation attempt"}')

HTTP_CODE=$(echo "$RESPONSE" | grep HTTP_CODE | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v HTTP_CODE)

echo "Response: $BODY"
echo "HTTP Status: $HTTP_CODE"

if [ "$HTTP_CODE" = "403" ]; then
  echo "✅ Correctly rejected impersonation (403 Forbidden)"
else
  echo "❌ Expected 403, got $HTTP_CODE"
fi
echo ""

echo "========================================="
echo "  ✅ Authentication Tests Complete!"
echo "========================================="
