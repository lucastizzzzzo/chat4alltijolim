#!/usr/bin/env python3
"""
Test WebSocket Notifications
Testa se as notificações via WebSocket estão funcionando corretamente
"""

import asyncio
import websockets
import json
import sys
import requests
import time
from datetime import datetime

# Configuration
API_URL = "http://localhost:8080"
WS_URL = "ws://localhost:8085/notifications"

def log(message, level="INFO"):
    """Log with timestamp"""
    timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
    print(f"[{timestamp}] [{level}] {message}")

def create_user(username, password):
    """Create a new user"""
    try:
        response = requests.post(
            f"{API_URL}/auth/register",
            json={
                "username": username, 
                "password": password,
                "email": f"{username}@test.com"
            },
            timeout=5
        )
        if response.status_code in [200, 201]:
            log(f"✓ User '{username}' created")
            return True
        elif response.status_code == 409:
            log(f"⚠ User '{username}' already exists")
            return True
        else:
            log(f"✗ Failed to create user '{username}': {response.text}", "ERROR")
            return False
    except Exception as e:
        log(f"✗ Error creating user: {e}", "ERROR")
        return False

def authenticate(username, password):
    """Authenticate and get JWT token"""
    try:
        response = requests.post(
            f"{API_URL}/auth/token",
            json={"username": username, "password": password},
            timeout=5
        )
        if response.status_code == 200:
            data = response.json()
            token = data.get("access_token")
            # Extract user_id from JWT sub claim
            import base64
            payload = token.split('.')[1]
            # Add padding if needed
            padding = len(payload) % 4
            if padding:
                payload += '=' * (4 - padding)
            decoded = json.loads(base64.b64decode(payload))
            user_id = decoded.get("sub")
            log(f"✓ Authenticated as '{username}' (user_id: {user_id})")
            return token, user_id
        else:
            log(f"✗ Failed to authenticate '{username}': {response.text}", "ERROR")
            return None, None
    except Exception as e:
        log(f"✗ Error authenticating: {e}", "ERROR")
        return None, None

def create_conversation(token, name, participant_ids):
    """Create a conversation"""
    try:
        response = requests.post(
            f"{API_URL}/v1/groups",
            headers={"Authorization": f"Bearer {token}"},
            json={"name": name, "member_ids": participant_ids},
            timeout=5
        )
        if response.status_code in [200, 201]:
            data = response.json()
            conv_id = data.get("group_id")
            log(f"✓ Conversation created: {conv_id}")
            return conv_id
        else:
            log(f"✗ Failed to create conversation: {response.text}", "ERROR")
            return None
    except Exception as e:
        log(f"✗ Error creating conversation: {e}", "ERROR")
        return None

def send_message(token, conversation_id, content, recipient_id):
    """Send a message"""
    try:
        response = requests.post(
            f"{API_URL}/v1/messages",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "content": content,
                "recipient_id": recipient_id,
                "conversation_id": conversation_id
            },
            timeout=5
        )
        if response.status_code in [200, 201]:
            data = response.json()
            msg_id = data.get("message_id")
            log(f"✓ Message sent: {msg_id}")
            return msg_id
        else:
            log(f"✗ Failed to send message: {response.text}", "ERROR")
            return None
    except Exception as e:
        log(f"✗ Error sending message: {e}", "ERROR")
        return None

async def websocket_client(token, expected_messages):
    """Connect to WebSocket and listen for notifications"""
    uri = f"{WS_URL}?token={token}"
    notifications_received = []
    
    try:
        log("Connecting to WebSocket...")
        async with websockets.connect(uri, ping_interval=20, ping_timeout=10) as websocket:
            log("✓ WebSocket connected!")
            
            # Wait for connection confirmation
            try:
                message = await asyncio.wait_for(websocket.recv(), timeout=5)
                data = json.loads(message)
                if data.get("type") == "connected":
                    log(f"✓ Connection confirmed: {data.get('userId')}")
            except asyncio.TimeoutError:
                log("⚠ No connection confirmation received", "WARN")
            
            # Listen for notifications
            log(f"Waiting for {expected_messages} notification(s)...")
            start_time = time.time()
            timeout = 30  # 30 seconds timeout
            
            while len(notifications_received) < expected_messages:
                try:
                    remaining_time = timeout - (time.time() - start_time)
                    if remaining_time <= 0:
                        log("⚠ Timeout waiting for notifications", "WARN")
                        break
                    
                    message = await asyncio.wait_for(
                        websocket.recv(), 
                        timeout=remaining_time
                    )
                    data = json.loads(message)
                    
                    if data.get("type") == "new_message":
                        elapsed = time.time() - start_time
                        log(f"🔔 NOTIFICATION RECEIVED (after {elapsed:.3f}s):")
                        log(f"   Message ID: {data.get('message_id')}")
                        log(f"   Sender ID: {data.get('sender_id')}")
                        log(f"   Conversation ID: {data.get('conversation_id')}")
                        log(f"   Content: {data.get('content')}")
                        log(f"   Timestamp: {data.get('timestamp')}")
                        notifications_received.append(data)
                    elif data.get("type") == "pong":
                        log("♥ Pong received", "DEBUG")
                    else:
                        log(f"Received message: {message}", "DEBUG")
                        
                except asyncio.TimeoutError:
                    log("⚠ Timeout waiting for notification", "WARN")
                    break
                except websockets.exceptions.ConnectionClosed:
                    log("✗ WebSocket connection closed", "ERROR")
                    break
            
            return notifications_received
            
    except websockets.exceptions.InvalidStatusCode as e:
        log(f"✗ WebSocket connection failed: {e}", "ERROR")
        return []
    except Exception as e:
        log(f"✗ WebSocket error: {e}", "ERROR")
        return []

async def run_test():
    """Run the complete WebSocket notification test"""
    log("=" * 70)
    log("🧪 TESTE DE NOTIFICAÇÕES VIA WEBSOCKET")
    log("=" * 70)
    
    # Generate unique usernames
    timestamp = int(time.time())
    alice_username = f"alice_{timestamp}"
    bob_username = f"bob_{timestamp}"
    
    # Step 1: Create users
    log("\n📝 Step 1: Creating users...")
    if not create_user(alice_username, "alice123"):
        return False
    if not create_user(bob_username, "bob123"):
        return False
    
    # Step 2: Authenticate users
    log("\n🔐 Step 2: Authenticating users...")
    alice_token, alice_id = authenticate(alice_username, "alice123")
    if not alice_token:
        return False
    
    bob_token, bob_id = authenticate(bob_username, "bob123")
    if not bob_token:
        return False
    
    # Step 3: Create conversation
    log("\n💬 Step 3: Creating conversation...")
    conv_id = create_conversation(
        bob_token, 
        f"Test WebSocket {timestamp}", 
        [alice_id, bob_id]
    )
    if not conv_id:
        return False
    
    # Step 4: Connect Alice to WebSocket
    log("\n🔌 Step 4: Connecting Alice to WebSocket...")
    
    # Start WebSocket client in background
    websocket_task = asyncio.create_task(
        websocket_client(alice_token, expected_messages=3)
    )
    
    # Wait a bit for connection to establish
    await asyncio.sleep(2)
    
    # Step 5: Send messages from Bob
    log("\n📨 Step 5: Sending messages from Bob...")
    messages = [
        "Olá Alice! Testando WebSocket 👋",
        "Esta é uma notificação em tempo real!",
        "Você deveria receber isso instantaneamente! ⚡"
    ]
    
    for i, content in enumerate(messages, 1):
        log(f"Sending message {i}/{len(messages)}...")
        msg_id = send_message(bob_token, conv_id, content, alice_id)
        if not msg_id:
            log("✗ Failed to send message", "ERROR")
        await asyncio.sleep(1)  # Small delay between messages
    
    # Step 6: Wait for notifications
    log("\n⏳ Step 6: Waiting for notifications...")
    notifications = await websocket_task
    
    # Step 7: Verify results
    log("\n📊 Step 7: Verifying results...")
    log("=" * 70)
    
    expected = len(messages)
    received = len(notifications)
    
    log(f"Expected notifications: {expected}")
    log(f"Received notifications: {received}")
    
    if received == expected:
        log("✅ TEST PASSED - All notifications received!", "SUCCESS")
        log("=" * 70)
        return True
    elif received > 0:
        log(f"⚠️  TEST PARTIAL - Received {received}/{expected} notifications", "WARN")
        log("=" * 70)
        return False
    else:
        log("❌ TEST FAILED - No notifications received!", "ERROR")
        log("=" * 70)
        log("\n🔍 Troubleshooting:")
        log("  1. Check if WebSocket Gateway is running:")
        log("     docker-compose ps websocket-gateway")
        log("  2. Check WebSocket Gateway logs:")
        log("     docker-compose logs websocket-gateway")
        log("  3. Check if Redis is running:")
        log("     docker-compose ps redis")
        log("  4. Check Router Worker logs:")
        log("     docker-compose logs router-worker")
        return False

def main():
    """Main entry point"""
    try:
        result = asyncio.run(run_test())
        sys.exit(0 if result else 1)
    except KeyboardInterrupt:
        log("\n⚠️  Test interrupted by user", "WARN")
        sys.exit(1)
    except Exception as e:
        log(f"\n❌ Unexpected error: {e}", "ERROR")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
