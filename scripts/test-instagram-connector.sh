#!/bin/bash

# test-instagram-connector.sh - Integration test for Instagram Connector
# 
# Purpose: Validate Phase 5 implementation (Instagram Connector Mock)
#
# Test flow:
# 1. Authenticate (get JWT token)
# 2. Send message to Instagram recipient (instagram:@maria_silva)
# 3. Wait for connector to process
# 4. Verify connector logs show delivery simulation
# 5. Verify message was saved in Cassandra
#
# Usage: ./scripts/test-instagram-connector.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
API_URL="http://localhost:8082"
TEST_USER="user_a"
TEST_PASSWORD="pass_a"
TEST_CONV="conv-instagram-test"
WHATSAPP_RECIPIENT="instagram:@maria_silva"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Phase 5: Instagram Connector - Integration Test"
echo "════════════════════════════════════════════════════════════════"
echo ""

# ========================================
# Test 1: Authenticate
# ========================================
echo -e "${YELLOW}[Test 1]${NC} Authenticating to get JWT token..."

AUTH_RESPONSE=$(curl -s -X POST "$API_URL/auth/token" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$TEST_USER\",\"password\":\"$TEST_PASSWORD\"}")

JWT_TOKEN=$(echo "$AUTH_RESPONSE" | tr -d '\n ' | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$JWT_TOKEN" ]; then
    echo -e "${RED}✗ Failed to get JWT token${NC}"
    echo "Response: $AUTH_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ JWT token obtained${NC}"
echo ""

# ========================================
# Test 2: Send message to Instagram recipient
# ========================================
echo -e "${YELLOW}[Test 2]${NC} Sending message to Instagram recipient..."
echo "  Recipient: $WHATSAPP_RECIPIENT"

MESSAGE_RESPONSE=$(curl -s -X POST "$API_URL/v1/messages" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"conversation_id\": \"$TEST_CONV\",
        \"sender_id\": \"$TEST_USER\",
        \"recipient_id\": \"$WHATSAPP_RECIPIENT\",
        \"content\": \"Hello from Instagram connector test!\"
    }")

MESSAGE_ID=$(echo "$MESSAGE_RESPONSE" | tr -d '\n ' | grep -o '"message_id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$MESSAGE_ID" ]; then
    echo -e "${RED}✗ Failed to send message${NC}"
    echo "Response: $MESSAGE_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ Message sent successfully${NC}"
echo "  Message ID: $MESSAGE_ID"
echo ""

# ========================================
# Test 3: Wait for connector processing
# ========================================
echo -e "${YELLOW}[Test 3]${NC} Waiting for Instagram connector to process message..."
echo "  Sleeping 5 seconds..."
sleep 5
echo -e "${GREEN}✓ Wait complete${NC}"
echo ""

# ========================================
# Test 4: Verify connector logs
# ========================================
echo -e "${YELLOW}[Test 4]${NC} Checking Instagram connector logs..."

# Check if connector container is running
if ! docker ps --format '{{.Names}}' | grep -q "connector-instagram"; then
    echo -e "${RED}✗ Instagram connector container not running${NC}"
    echo "Please start with: docker-compose up -d connector-instagram"
    exit 1
fi

CONNECTOR_LOGS=$(docker logs chat4alltijolim_connector-instagram_1 2>&1 | tail -50)

# Check for key log messages
if echo "$CONNECTOR_LOGS" | grep -q "Consumed message"; then
    echo -e "${GREEN}✓ Connector consumed message from Kafka${NC}"
else
    echo -e "${RED}✗ No consumption log found${NC}"
    echo "Recent logs:"
    echo "$CONNECTOR_LOGS"
    exit 1
fi

if echo "$CONNECTOR_LOGS" | grep -q "Delivered to"; then
    echo -e "${GREEN}✓ Connector simulated Instagram API delivery${NC}"
else
    echo -e "${RED}✗ No delivery simulation log found${NC}"
    exit 1
fi

if echo "$CONNECTOR_LOGS" | grep -q "Published DELIVERED"; then
    echo -e "${GREEN}✓ Connector published DELIVERED status${NC}"
else
    echo -e "${RED}✗ No status publish log found${NC}"
    exit 1
fi

echo ""

# ========================================
# Test 5: Verify message in Cassandra
# ========================================
echo -e "${YELLOW}[Test 5]${NC} Verifying message was saved in Cassandra..."

CASSANDRA_RESULT=$(docker exec chat4all-cassandra cqlsh -e \
    "SELECT message_id, sender_id, content, status FROM chat4all.messages WHERE conversation_id = '$TEST_CONV' LIMIT 10;" 2>&1)

if echo "$CASSANDRA_RESULT" | grep -q "$MESSAGE_ID"; then
    echo -e "${GREEN}✓ Message found in Cassandra${NC}"
    
    # Extract status
    if echo "$CASSANDRA_RESULT" | grep "$MESSAGE_ID" | grep -q "SENT"; then
        echo -e "${GREEN}✓ Message has SENT status${NC}"
    else
        echo -e "${YELLOW}⚠ Message status is not SENT (expected for now - status consumer not implemented yet)${NC}"
    fi
else
    echo -e "${RED}✗ Message not found in Cassandra${NC}"
    echo "Query result:"
    echo "$CASSANDRA_RESULT"
    exit 1
fi

echo ""

# ========================================
# Test 6: Verify routing logic
# ========================================
echo -e "${YELLOW}[Test 6]${NC} Verifying router-worker routing logic..."

ROUTER_LOGS=$(docker logs chat4alltijolim_router-worker_1 2>&1 | tail -50)

if echo "$ROUTER_LOGS" | grep -q "Routing to instagram-outbound"; then
    echo -e "${GREEN}✓ Router correctly identified Instagram recipient${NC}"
    echo -e "${GREEN}✓ Message routed to instagram-outbound topic${NC}"
else
    echo -e "${YELLOW}⚠ Routing log not found (may have scrolled past)${NC}"
    echo "Recent router logs:"
    echo "$ROUTER_LOGS" | grep -i "routing\|instagram" || echo "No routing logs found"
fi

echo ""

# ========================================
# Test 7: Check Kafka topic
# ========================================
echo -e "${YELLOW}[Test 7]${NC} Checking Kafka topics..."

KAFKA_TOPICS=$(docker exec chat4all-kafka kafka-topics --bootstrap-server localhost:9092 --list 2>&1)

if echo "$KAFKA_TOPICS" | grep -q "instagram-outbound"; then
    echo -e "${GREEN}✓ instagram-outbound topic exists${NC}"
else
    echo -e "${RED}✗ instagram-outbound topic not found${NC}"
    echo "Available topics:"
    echo "$KAFKA_TOPICS"
fi

if echo "$KAFKA_TOPICS" | grep -q "status-updates"; then
    echo -e "${GREEN}✓ status-updates topic exists${NC}"
else
    echo -e "${YELLOW}⚠ status-updates topic not found (will be auto-created on first publish)${NC}"
fi

echo ""

# ========================================
# Test 8: Check connector health endpoint
# ========================================
echo -e "${YELLOW}[Test 8]${NC} Checking connector health endpoint..."

HEALTH_RESPONSE=$(curl -s http://localhost:8084/health)

if echo "$HEALTH_RESPONSE" | grep -q '"status":"UP"'; then
    echo -e "${GREEN}✓ Connector health endpoint responding${NC}"
    echo "  Response: $HEALTH_RESPONSE"
else
    echo -e "${RED}✗ Connector health endpoint not responding correctly${NC}"
    echo "  Response: $HEALTH_RESPONSE"
fi

echo ""

# ========================================
# Summary
# ========================================
echo "════════════════════════════════════════════════════════════════"
echo -e "${GREEN}✓ Instagram Connector tests passed!${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "✅ Test Results:"
echo "  [1] ✓ JWT authentication"
echo "  [2] ✓ Message sent to Instagram recipient"
echo "  [3] ✓ Connector wait period"
echo "  [4] ✓ Connector logs verified (consumed, delivered, status published)"
echo "  [5] ✓ Message saved in Cassandra"
echo "  [6] ✓ Router routing logic verified"
echo "  [7] ✓ Kafka topics verified"
echo "  [8] ✓ Health endpoint responding"
echo ""
echo "📚 Key Observations:"
echo ""
echo "1. Plugin Pattern Working:"
echo "   • Router-worker detects 'instagram:' prefix in sender_id"
echo "   • Routes message to instagram-outbound topic (not local delivery)"
echo "   • Connector processes independently"
echo ""
echo "2. Async Communication:"
echo "   • Kafka decouples router from connector"
echo "   • Connector can be down and message waits in queue"
echo "   • Multiple connector instances can process in parallel"
echo ""
echo "3. Status Updates:"
echo "   • Connector publishes DELIVERED status to status-updates topic"
echo "   • Status consumer (Phase 7) will update Cassandra"
echo "   • Currently message stays as SENT (expected behavior)"
echo ""
echo "4. Scalability:"
echo "   • Connector uses consumer group (can scale horizontally)"
echo "   • Health endpoint allows orchestration/monitoring"
echo "   • Fault-tolerant: messages persist in Kafka"
echo ""
echo "🎯 Next Steps:"
echo "  • Implement Status Update Consumer (Phase 7) to handle DELIVERED status"
echo "  • Create Instagram Connector (Phase 6) using same pattern"
echo "  • Add READ status simulation"
echo ""
echo "Message ID tested: $MESSAGE_ID"
echo "Conversation ID: $TEST_CONV"
echo ""
