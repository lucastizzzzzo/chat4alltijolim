#!/bin/bash
echo "=== TESTE END-TO-END: API → Kafka → Worker → Cassandra ==="
echo ""

# 1. Get token
echo "1. Getting JWT token..."
TOKEN=$(curl -s -X POST http://localhost:8080/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username":"user_a","password":"pass_a"}' | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "✓ Token: ${TOKEN:0:50}..."
echo ""

# 2. Send message
echo "2. Sending message with authentication..."
RESPONSE=$(curl -s -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"conversation_id":"conv_e2e_test","sender_id":"user_a","content":"Full E2E test!"}')

echo "Response: $RESPONSE"
MESSAGE_ID=$(echo "$RESPONSE" | grep -o '"message_id":"[^"]*' | cut -d'"' -f4)
echo "✓ Message ID: $MESSAGE_ID"
echo ""

# 3. Wait for worker to process
echo "3. Waiting 3 seconds for worker to process..."
sleep 3
echo ""

# 4. Check Worker logs
echo "4. Checking Worker logs..."
docker-compose logs router-worker | grep -A 10 "$MESSAGE_ID" | tail -15
echo ""

# 5. Check Cassandra
echo "5. Checking Cassandra database..."
docker-compose exec -T cassandra cqlsh -e "SELECT message_id, sender_id, status, content FROM chat4all.messages WHERE conversation_id='conv_e2e_test' ALLOW FILTERING;" | grep -v "^$"
echo ""

echo "=== TEST COMPLETE ==="
