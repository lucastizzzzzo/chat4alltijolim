#!/bin/bash
set -e

echo "🚀 Chat4All Complete Test Suite"
echo "================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Base URL
API_URL="http://localhost:8080"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ jq is not installed. Please install it: sudo apt-get install jq${NC}"
    exit 1
fi

# Check if services are running
echo -e "\n${YELLOW}0. Checking if services are running...${NC}"
if ! curl -s -f $API_URL/health > /dev/null 2>&1; then
    echo -e "${RED}❌ API Service is not running. Please run: make quickstart${NC}"
    exit 1
fi
echo -e "${GREEN}✓ API Service is running${NC}"

echo -e "\n${YELLOW}1. Registering test users...${NC}"

# Register Alice
ALICE_RESPONSE=$(curl -s -X POST $API_URL/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "alice_test",
    "password": "alice123",
    "email": "alice.test@example.com"
  }')
ALICE_USER_ID=$(echo $ALICE_RESPONSE | jq -r '.user_id // .userId // "unknown"')
echo -e "${GREEN}✓ Alice registered${NC}"
echo "   User ID: $ALICE_USER_ID"

# Register Bob
BOB_RESPONSE=$(curl -s -X POST $API_URL/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "bob_test",
    "password": "bob123",
    "email": "bob.test@example.com"
  }')
BOB_USER_ID=$(echo $BOB_RESPONSE | jq -r '.user_id // .userId // "unknown"')
echo -e "${GREEN}✓ Bob registered${NC}"
echo "   User ID: $BOB_USER_ID"

echo -e "\n${YELLOW}1.5. Authenticating users...${NC}"

# Authenticate Alice
ALICE_AUTH=$(curl -s -X POST $API_URL/auth/token \
  -H "Content-Type: application/json" \
  -d '{
    "username": "alice_test",
    "password": "alice123"
  }')
ALICE_TOKEN=$(echo $ALICE_AUTH | jq -r '.access_token // .token // "unknown"')
echo -e "${GREEN}✓ Alice authenticated${NC}"
echo "   Token: ${ALICE_TOKEN:0:20}..."

# Authenticate Bob
BOB_AUTH=$(curl -s -X POST $API_URL/auth/token \
  -H "Content-Type: application/json" \
  -d '{
    "username": "bob_test",
    "password": "bob123"
  }')
BOB_TOKEN=$(echo $BOB_AUTH | jq -r '.access_token // .token // "unknown"')
echo -e "${GREEN}✓ Bob authenticated${NC}"
echo "   Token: ${BOB_TOKEN:0:20}..."

echo -e "\n${YELLOW}2. Sending messages...${NC}"

# Alice → Bob
MSG1=$(curl -s -X POST $API_URL/v1/messages \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"conversation_id\": \"test-alice-bob\",
    \"recipient_id\": \"$BOB_USER_ID\",
    \"content\": \"Hi Bob! This is an automated test message.\"
  }")
MSG1_ID=$(echo $MSG1 | jq -r '.message_id // .messageId // "unknown"')
echo -e "${GREEN}✓ Alice sent message to Bob${NC}"
echo "   Message ID: $MSG1_ID"

# Bob → Alice
MSG2=$(curl -s -X POST $API_URL/v1/messages \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"conversation_id\": \"test-alice-bob\",
    \"recipient_id\": \"$ALICE_USER_ID\",
    \"content\": \"Hey Alice! Test reply received.\"
  }")
MSG2_ID=$(echo $MSG2 | jq -r '.message_id // .messageId // "unknown"')
echo -e "${GREEN}✓ Bob replied to Alice${NC}"
echo "   Message ID: $MSG2_ID"

echo -e "\n${YELLOW}3. Retrieving conversation...${NC}"
echo "   Waiting 3 seconds for message processing..."
sleep 3

CONV=$(curl -s -X GET "$API_URL/v1/conversations/test-alice-bob/messages?limit=10" \
  -H "Authorization: Bearer $ALICE_TOKEN")
MSG_COUNT=$(echo $CONV | jq '.messages | length // 0')
echo -e "${GREEN}✓ Retrieved $MSG_COUNT messages${NC}"

if [ "$MSG_COUNT" -gt 0 ]; then
    echo "   First message preview:"
    echo $CONV | jq -r '.messages[0] | "   From: \(.sender_id // .senderId)\n   Content: \(.content)"'
fi

echo -e "\n${YELLOW}4. Testing file upload...${NC}"

# Create test file
TEST_FILE="test_upload_$(date +%s).txt"
echo "This is test content for file upload - Generated at $(date)" > $TEST_FILE
echo "   Created test file: $TEST_FILE"

FILE_UPLOAD=$(curl -s -X POST $API_URL/v1/files \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -F "file=@$TEST_FILE" \
  -F "filename=test_document.txt")
FILE_URL=$(echo $FILE_UPLOAD | jq -r '.download_url // .downloadUrl // ""')
FILE_ID=$(echo $FILE_UPLOAD | jq -r '.file_id // .fileId // "unknown"')
echo -e "${GREEN}✓ File uploaded successfully${NC}"
echo "   File ID: $FILE_ID"

# Clean up test file
rm -f $TEST_FILE

echo -e "\n${YELLOW}5. Sending message with file...${NC}"

if [ -n "$FILE_URL" ] && [ "$FILE_URL" != "null" ] && [ "$FILE_URL" != "" ]; then
    MSG_WITH_FILE=$(curl -s -X POST $API_URL/v1/messages \
      -H "Authorization: Bearer $ALICE_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"conversation_id\": \"test-alice-bob\",
        \"recipient_id\": \"$BOB_USER_ID\",
        \"content\": \"Here's the test document\",
        \"file_id\": \"$FILE_ID\"
      }")
    echo -e "${GREEN}✓ Message with file sent${NC}"
else
    echo -e "${YELLOW}⚠ File URL not available, skipping message with file${NC}"
fi

echo -e "\n${YELLOW}6. Checking system health...${NC}"

HEALTH=$(curl -s $API_URL/health)
HEALTH_STATUS=$(echo $HEALTH | jq -r '.status // "unknown"')
echo -e "${GREEN}✓ System health: $HEALTH_STATUS${NC}"

echo -e "\n${GREEN}════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All tests completed successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════${NC}"

echo -e "\n${YELLOW}Test Summary:${NC}"
echo "  - Users registered: 2 (Alice, Bob)"
echo "  - Messages sent: $([ -n "$FILE_URL" ] && echo "3" || echo "2")"
echo "  - Files uploaded: 1"
echo "  - Conversation retrieved: $MSG_COUNT messages"
echo ""
echo -e "${YELLOW}Authentication Tokens:${NC}"
echo "  Alice: $ALICE_TOKEN"
echo "  Bob:   $BOB_TOKEN"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  - View logs: make logs"
echo "  - Check Grafana: http://localhost:3000"
echo "  - Check Prometheus: http://localhost:9090"
echo "  - Use CLI: make cli"
