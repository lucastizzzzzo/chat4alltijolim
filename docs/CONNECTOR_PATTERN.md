# Connector Pattern - Plugin Architecture Guide

**Chat4All Educational Documentation**  
**Version**: 2.0 (Entrega 2 - Multi-Platform Connectors)  
**Purpose**: Understand connector architecture and learn how to add new connectors

---

## Overview

**Connectors** are independent microservices that bridge Chat4All's internal messaging system with external communication platforms (WhatsApp, Instagram, Telegram, etc.). Each connector:

- Runs in its own Docker container (isolation)
- Consumes messages from platform-specific Kafka topics
- Translates Chat4All message format to platform API format
- Reports delivery status back to the system

---

## Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────┐
│                   Chat4All Core System                       │
│                                                              │
│  ┌────────┐    ┌─────────┐    ┌────────┐    ┌──────────┐  │
│  │  API   │───▶│  Kafka  │───▶│ Router │───▶│ Cassandra│  │
│  │Service │    │ (events)│    │ Worker │    │          │  │
│  └────────┘    └────┬────┘    └───┬────┘    └──────────┘  │
│                     │               │                       │
└─────────────────────┼───────────────┼───────────────────────┘
                      │               │
                      │               │ Routes by recipient_id
                      │               │
        ┌─────────────┴───────────────┴─────────────┐
        │                                            │
        ▼                                            ▼
┌───────────────┐                         ┌───────────────┐
│ whatsapp-     │                         │ instagram-    │
│ outbound      │                         │ outbound      │
│ (Kafka topic) │                         │ (Kafka topic) │
└───────┬───────┘                         └───────┬───────┘
        │                                         │
        ▼                                         ▼
┌────────────────┐                       ┌────────────────┐
│   WhatsApp     │                       │   Instagram    │
│   Connector    │                       │   Connector    │
│  (Container)   │                       │  (Container)   │
└───────┬────────┘                       └───────┬────────┘
        │                                        │
        │     ┌──────────────┐                  │
        └────▶│ status-updates│◀─────────────────┘
              │ (Kafka topic) │
              └───────┬────────┘
                      │
                      ▼
              ┌──────────────┐
              │   Router     │
              │   Worker     │
              │ (updates DB) │
              └──────────────┘
```

### Message Flow

**1. Outbound Flow (Chat4All → External Platform):**
```
Client → API → Kafka (messages) → Router → Kafka ({platform}-outbound)
                                              ↓
                                         Connector → External API
```

**2. Status Update Flow (External Platform → Chat4All):**
```
External API → Connector → Kafka (status-updates) → Router → Cassandra
```

---

## Connector Interface Contract

### Input: Consume from `{platform}-outbound` Topic

**Message Format (JSON):**
```json
{
  "message_id": "msg_550e8400e29b41d4a716446655440000",
  "conversation_id": "conv_demo_123",
  "sender_id": "user_a",
  "recipient_id": "whatsapp:+5511999998888",
  "content": "Hello from Chat4All!",
  "file_id": "file_abc123...",
  "timestamp": 1705312800000,
  "status": "SENT"
}
```

**Key Fields:**
- `message_id`: Unique message identifier (used for status updates)
- `recipient_id`: Platform-specific user identifier (e.g., phone number for WhatsApp)
- `content`: Message text
- `file_id`: Optional file attachment reference

### Output: Produce to `status-updates` Topic

**Status Update Format (JSON):**
```json
{
  "message_id": "msg_550e8400e29b41d4a716446655440000",
  "status": "DELIVERED",
  "timestamp": 1705312802000
}
```

**Valid Status Values:**
- `DELIVERED`: Message successfully delivered to platform
- `READ`: Recipient opened/read message (if platform supports read receipts)

### Health Check Endpoint

Each connector must expose:
```http
GET /health HTTP/1.1
```

**Response (200 OK):**
```json
{
  "status": "UP",
  "platform": "whatsapp",
  "version": "2.0.0",
  "kafka_connected": true,
  "api_connected": false
}
```

---

## Existing Connectors

### 1. WhatsApp Connector

**Location:** `connector-whatsapp/src/main/java/chat4all/connector/`

**Kafka Topic:** `whatsapp-outbound`

**Recipient ID Format:** `whatsapp:+5511999998888` (E.164 phone number)

**Implementation:**
```java
// OutboundMessageConsumer.java
@Override
public void processMessage(MessageEvent event) {
    logger.info("[WhatsApp] Processing message " + event.getMessageId());
    
    // 1. Extract phone number from recipient_id
    String phoneNumber = event.getRecipientId().replace("whatsapp:", "");
    
    // 2. Handle file attachment (if present)
    if (event.getFileId() != null) {
        String downloadUrl = getPresignedUrl(event.getFileId());
        // In production: sendWhatsAppMediaMessage(phoneNumber, downloadUrl);
    } else {
        // In production: sendWhatsAppTextMessage(phoneNumber, event.getContent());
    }
    
    // 3. Simulate delivery (educational: no real API)
    Thread.sleep(2000); // 2 second delay
    
    // 4. Report delivery status
    publishStatusUpdate(event.getMessageId(), MessageStatus.DELIVERED);
    
    logger.info("[WhatsApp] Delivered message " + event.getMessageId());
}
```

**Production Integration:**
Replace simulation with WhatsApp Business API:
```java
// WhatsApp Business API client
WhatsAppClient client = new WhatsAppClient(apiToken);

// Send text message
client.sendMessage(phoneNumber, content);

// Send media message
client.sendMedia(phoneNumber, mediaUrl, caption);
```

**API Documentation:** [WhatsApp Business API](https://developers.facebook.com/docs/whatsapp/cloud-api)

### 2. Instagram Connector

**Location:** `connector-instagram/src/main/java/chat4all/connector/`

**Kafka Topic:** `instagram-outbound`

**Recipient ID Format:** `instagram:@john_doe` (Instagram username)

**Implementation:**
```java
// OutboundMessageConsumer.java
@Override
public void processMessage(MessageEvent event) {
    logger.info("[Instagram] Processing message " + event.getMessageId());
    
    // 1. Extract username from recipient_id
    String username = event.getRecipientId().replace("instagram:", "");
    
    // 2. Handle file attachment (if present)
    if (event.getFileId() != null) {
        String downloadUrl = getPresignedUrl(event.getFileId());
        // In production: sendInstagramDirect(username, downloadUrl);
    } else {
        // In production: sendInstagramDirect(username, event.getContent());
    }
    
    // 3. Simulate delivery (educational: no real API)
    Thread.sleep(2000); // 2 second delay
    
    // 4. Report delivery status
    publishStatusUpdate(event.getMessageId(), MessageStatus.DELIVERED);
    
    logger.info("[Instagram] Delivered message " + event.getMessageId());
}
```

**Production Integration:**
Replace simulation with Instagram Graph API:
```java
// Instagram Graph API client
InstagramClient client = new InstagramClient(accessToken);

// Send direct message
client.sendDirectMessage(userId, content);

// Send media message
client.sendDirectMedia(userId, mediaUrl);
```

**API Documentation:** [Instagram Graph API](https://developers.facebook.com/docs/instagram-api)

---

## Adding a New Connector

### Example: Telegram Connector

#### Step 1: Create Maven Module

```bash
# Create directory structure
mkdir -p connector-telegram/src/main/java/chat4all/connector
mkdir -p connector-telegram/src/test/java/chat4all/connector

# Create pom.xml
cat > connector-telegram/pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    
    <parent>
        <groupId>chat4all</groupId>
        <artifactId>chat4alltijolim</artifactId>
        <version>1.0.0</version>
    </parent>
    
    <artifactId>connector-telegram</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>
    
    <dependencies>
        <!-- Shared models and utilities -->
        <dependency>
            <groupId>chat4all</groupId>
            <artifactId>shared</artifactId>
            <version>1.0.0</version>
        </dependency>
        
        <!-- Kafka client -->
        <dependency>
            <groupId>org.apache.kafka</groupId>
            <artifactId>kafka-clients</artifactId>
        </dependency>
        
        <!-- JSON parsing (optional) -->
        <dependency>
            <groupId>com.google.code.gson</groupId>
            <artifactId>gson</artifactId>
            <version>2.10.1</version>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <!-- Maven Shade Plugin (fat JAR) -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-shade-plugin</artifactId>
                <version>3.5.0</version>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>shade</goal>
                        </goals>
                        <configuration>
                            <transformers>
                                <transformer implementation="org.apache.maven.plugins.shade.resource.ManifestResourceTransformer">
                                    <mainClass>chat4all.connector.Main</mainClass>
                                </transformer>
                            </transformers>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
EOF
```

#### Step 2: Implement Main Class

```java
// connector-telegram/src/main/java/chat4all/connector/Main.java
package chat4all.connector;

import chat4all.shared.Logger;

public class Main {
    private static final Logger logger = new Logger("TelegramConnector");
    
    public static void main(String[] args) {
        logger.info("Starting Telegram Connector...");
        
        // Read configuration from environment variables
        String kafkaBootstrap = System.getenv().getOrDefault(
            "KAFKA_BOOTSTRAP_SERVERS", "localhost:9092");
        String telegramToken = System.getenv("TELEGRAM_BOT_TOKEN");
        
        if (telegramToken == null || telegramToken.isEmpty()) {
            logger.error("TELEGRAM_BOT_TOKEN environment variable not set");
            System.exit(1);
        }
        
        // Initialize Kafka consumer
        OutboundMessageConsumer consumer = new OutboundMessageConsumer(
            kafkaBootstrap, 
            "telegram-outbound", 
            telegramToken
        );
        
        // Register shutdown hook
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            logger.info("Shutting down Telegram Connector...");
            consumer.stop();
        }));
        
        // Start consuming messages
        consumer.start();
    }
}
```

#### Step 3: Implement Kafka Consumer

```java
// connector-telegram/src/main/java/chat4all/connector/OutboundMessageConsumer.java
package chat4all.connector;

import chat4all.shared.Logger;
import chat4all.shared.MessageEvent;
import chat4all.shared.MessageStatus;
import org.apache.kafka.clients.consumer.*;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.time.Duration;
import java.util.Collections;
import java.util.Properties;

public class OutboundMessageConsumer {
    private final Logger logger = new Logger("TelegramConsumer");
    private final KafkaConsumer<String, String> consumer;
    private final StatusUpdateProducer statusProducer;
    private final String telegramToken;
    private volatile boolean running = true;
    
    public OutboundMessageConsumer(String kafkaBootstrap, String topic, String telegramToken) {
        this.telegramToken = telegramToken;
        
        // Configure Kafka consumer
        Properties props = new Properties();
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, kafkaBootstrap);
        props.put(ConsumerConfig.GROUP_ID_CONFIG, "telegram-connector-group");
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, "false");
        
        this.consumer = new KafkaConsumer<>(props);
        this.consumer.subscribe(Collections.singletonList(topic));
        
        // Initialize status producer
        this.statusProducer = new StatusUpdateProducer(kafkaBootstrap);
        
        logger.info("Telegram consumer initialized for topic: " + topic);
    }
    
    public void start() {
        logger.info("Starting message consumption...");
        
        while (running) {
            try {
                ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(1000));
                
                for (ConsumerRecord<String, String> record : records) {
                    processMessage(record.value());
                }
                
                // Commit offsets after processing
                consumer.commitSync();
                
            } catch (Exception e) {
                logger.error("Error processing messages: " + e.getMessage());
            }
        }
        
        logger.info("Consumer stopped");
    }
    
    public void stop() {
        running = false;
        consumer.close();
        statusProducer.close();
    }
    
    private void processMessage(String messageJson) {
        try {
            // 1. Parse message event
            MessageEvent event = MessageEvent.fromJson(messageJson);
            logger.info("[Telegram] Processing message " + event.getMessageId());
            
            // 2. Extract Telegram chat ID from recipient_id
            // Format: telegram:123456789 (numeric chat ID)
            String chatId = event.getRecipientId().replace("telegram:", "");
            
            // 3. Handle file attachment (if present)
            if (event.getFileId() != null) {
                String downloadUrl = getPresignedUrl(event.getFileId());
                sendTelegramMedia(chatId, event.getContent(), downloadUrl);
            } else {
                sendTelegramText(chatId, event.getContent());
            }
            
            // 4. Report delivery status
            statusProducer.publishStatusUpdate(
                event.getMessageId(), 
                MessageStatus.DELIVERED
            );
            
            logger.info("[Telegram] Delivered message " + event.getMessageId());
            
        } catch (Exception e) {
            logger.error("[Telegram] Error processing message: " + e.getMessage());
        }
    }
    
    private void sendTelegramText(String chatId, String text) {
        // Production: Call Telegram Bot API
        // POST https://api.telegram.org/bot{token}/sendMessage
        // { "chat_id": "123456789", "text": "Hello!" }
        
        // Educational simulation: 2 second delay
        try {
            Thread.sleep(2000);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
    
    private void sendTelegramMedia(String chatId, String caption, String fileUrl) {
        // Production: Call Telegram Bot API
        // POST https://api.telegram.org/bot{token}/sendDocument
        // { "chat_id": "123456789", "document": "https://...", "caption": "..." }
        
        // Educational simulation: 3 second delay
        try {
            Thread.sleep(3000);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
    
    private String getPresignedUrl(String fileId) {
        // Query API service to get presigned download URL
        // In production: HTTP GET /v1/files/{fileId}/download
        return "http://minio:9000/chat4all-files/" + fileId + "?X-Amz-Signature=...";
    }
}
```

#### Step 4: Implement Status Producer

```java
// connector-telegram/src/main/java/chat4all/connector/StatusUpdateProducer.java
package chat4all.connector;

import chat4all.shared.Logger;
import chat4all.shared.MessageStatus;
import org.apache.kafka.clients.producer.*;
import org.apache.kafka.common.serialization.StringSerializer;

import java.util.Properties;

public class StatusUpdateProducer {
    private final Logger logger = new Logger("StatusProducer");
    private final KafkaProducer<String, String> producer;
    
    public StatusUpdateProducer(String kafkaBootstrap) {
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, kafkaBootstrap);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.ACKS_CONFIG, "all");
        props.put(ProducerConfig.RETRIES_CONFIG, 3);
        
        this.producer = new KafkaProducer<>(props);
        logger.info("Status producer initialized");
    }
    
    public void publishStatusUpdate(String messageId, MessageStatus status) {
        String statusJson = String.format(
            "{\"message_id\":\"%s\",\"status\":\"%s\",\"timestamp\":%d}",
            messageId, status.getValue(), System.currentTimeMillis()
        );
        
        ProducerRecord<String, String> record = new ProducerRecord<>(
            "status-updates",
            messageId, // Key: message_id (for ordering)
            statusJson
        );
        
        producer.send(record, (metadata, exception) -> {
            if (exception != null) {
                logger.error("Failed to publish status update: " + exception.getMessage());
            } else {
                logger.info("Status update published: " + messageId + " → " + status.getValue());
            }
        });
    }
    
    public void close() {
        producer.flush();
        producer.close();
    }
}
```

#### Step 5: Create Dockerfile

```dockerfile
# connector-telegram/Dockerfile
FROM openjdk:17-slim

WORKDIR /app

# Copy fat JAR
COPY target/connector-telegram-1.0.0.jar /app/connector-telegram.jar

# Expose health check port (optional)
EXPOSE 8080

# Run connector
ENTRYPOINT ["java", "-jar", "connector-telegram.jar"]
```

#### Step 6: Add to Docker Compose

```yaml
# docker-compose.yml (add this service)
services:
  # ... existing services ...
  
  connector-telegram:
    build:
      context: ./connector-telegram
      dockerfile: Dockerfile
    container_name: chat4all-connector-telegram
    environment:
      KAFKA_BOOTSTRAP_SERVERS: kafka:9092
      TELEGRAM_BOT_TOKEN: ${TELEGRAM_BOT_TOKEN}
    depends_on:
      - kafka
    networks:
      - chat4all-network
    restart: unless-stopped
```

#### Step 7: Update Router Worker Routing Logic

```java
// router-worker/src/main/java/chat4all/worker/kafka/MessageRouter.java

public String determineRoutingTopic(String recipientId) {
    if (recipientId == null || !recipientId.contains(":")) {
        return "messages"; // Default: internal routing
    }
    
    String platform = recipientId.split(":")[0];
    
    // Map platform to Kafka topic
    switch (platform) {
        case "whatsapp":
            return "whatsapp-outbound";
        case "instagram":
            return "instagram-outbound";
        case "telegram":  // <-- ADD THIS
            return "telegram-outbound";
        default:
            logger.warn("Unknown platform: " + platform + ", using default routing");
            return "messages";
    }
}
```

#### Step 8: Create Kafka Topic

```bash
# Create telegram-outbound topic
docker-compose exec kafka kafka-topics --create \
  --bootstrap-server localhost:9092 \
  --topic telegram-outbound \
  --partitions 3 \
  --replication-factor 1
```

#### Step 9: Build and Deploy

```bash
# Build connector
mvn clean package -pl connector-telegram -am

# Build Docker image and start
docker-compose up -d --build connector-telegram

# Check logs
docker-compose logs -f connector-telegram
```

#### Step 10: Test the Connector

```bash
# Send message to Telegram user
curl -X POST http://localhost:8082/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "conv_demo_123",
    "sender_id": "user_a",
    "recipient_id": "telegram:123456789",
    "content": "Hello from Chat4All!"
  }'

# Check connector logs
docker-compose logs connector-telegram

# Expected output:
# [Telegram] Processing message msg_abc123...
# [Telegram] Delivered message msg_abc123
```

---

## Best Practices

### 1. Error Handling

Always wrap external API calls in try-catch:

```java
private void sendToExternalAPI(String recipient, String content) {
    int maxRetries = 3;
    int attempt = 0;
    
    while (attempt < maxRetries) {
        try {
            // Call external API
            ExternalAPI.send(recipient, content);
            return; // Success
            
        } catch (RateLimitException e) {
            // Wait and retry
            Thread.sleep(5000);
            attempt++;
            
        } catch (AuthenticationException e) {
            // Fatal error - don't retry
            logger.error("Authentication failed: " + e.getMessage());
            throw e;
            
        } catch (Exception e) {
            // Transient error - retry
            logger.warn("Attempt " + (attempt + 1) + " failed: " + e.getMessage());
            attempt++;
        }
    }
    
    throw new RuntimeException("Failed after " + maxRetries + " attempts");
}
```

### 2. Rate Limiting

Respect platform rate limits:

```java
// Token bucket algorithm
private final RateLimiter rateLimiter = RateLimiter.create(10.0); // 10 requests/second

private void sendMessage(String recipient, String content) {
    // Wait for permit (blocks if rate limit exceeded)
    rateLimiter.acquire();
    
    // Now send message
    externalAPI.send(recipient, content);
}
```

### 3. Graceful Shutdown

Always commit Kafka offsets before shutdown:

```java
Runtime.getRuntime().addShutdownHook(new Thread(() -> {
    logger.info("Shutdown initiated - stopping consumer...");
    
    // Stop consumer loop
    running = false;
    
    // Wait for current message to finish
    Thread.sleep(5000);
    
    // Close resources
    consumer.close();
    statusProducer.close();
    
    logger.info("Shutdown complete");
}));
```

### 4. Health Checks

Implement health endpoint for monitoring:

```java
// Simple HTTP server for health checks
HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);

server.createContext("/health", exchange -> {
    boolean healthy = isKafkaConnected() && isExternalAPIConnected();
    
    String response = String.format(
        "{\"status\":\"%s\",\"kafka\":%b,\"api\":%b}",
        healthy ? "UP" : "DOWN",
        isKafkaConnected(),
        isExternalAPIConnected()
    );
    
    exchange.sendResponseHeaders(healthy ? 200 : 503, response.length());
    exchange.getResponseBody().write(response.getBytes());
    exchange.close();
});

server.start();
```

### 5. Observability

Log key events for debugging:

```java
logger.info("Message received: " + messageId);
logger.info("Routing to platform: " + platform);
logger.info("External API call started");
logger.info("External API call completed in " + duration + "ms");
logger.info("Status update published: " + status);
```

---

## Testing Connectors

### Unit Tests

```java
// connector-telegram/src/test/java/chat4all/connector/OutboundMessageConsumerTest.java
@Test
public void testProcessTextMessage() {
    // Given
    MessageEvent event = new MessageEvent();
    event.setMessageId("msg_123");
    event.setRecipientId("telegram:123456789");
    event.setContent("Hello!");
    
    // When
    consumer.processMessage(event.toJson());
    
    // Then
    verify(statusProducer).publishStatusUpdate("msg_123", MessageStatus.DELIVERED);
}

@Test
public void testProcessMediaMessage() {
    // Given
    MessageEvent event = new MessageEvent();
    event.setMessageId("msg_456");
    event.setRecipientId("telegram:123456789");
    event.setContent("Check this file!");
    event.setFileId("file_abc123");
    
    // When
    consumer.processMessage(event.toJson());
    
    // Then
    verify(telegramAPI).sendDocument(eq("123456789"), anyString(), eq("Check this file!"));
}
```

### Integration Tests

```bash
# Test full flow: API → Kafka → Connector → Status Update
./scripts/test-telegram-connector.sh
```

---

## Troubleshooting

### Issue: Connector not consuming messages

**Symptoms:** No logs, messages stay in Kafka topic

**Diagnosis:**
```bash
# Check consumer group
docker-compose exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group telegram-connector-group \
  --describe

# Check topic messages
docker-compose exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic telegram-outbound \
  --from-beginning
```

**Solution:** Verify `KAFKA_BOOTSTRAP_SERVERS` environment variable is correct.

### Issue: Status updates not appearing

**Symptoms:** Messages sent, but status stays "SENT"

**Diagnosis:**
```bash
# Check status-updates topic
docker-compose exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic status-updates \
  --from-beginning
```

**Solution:** Ensure `StatusUpdateProducer` is correctly configured and publishing.

### Issue: External API authentication failing

**Symptoms:** Connector logs show 401/403 errors

**Diagnosis:**
```bash
# Check environment variables
docker-compose exec connector-telegram env | grep TOKEN
```

**Solution:** Verify API token is correctly set in `docker-compose.yml`.

---

## Related Documentation

- [ADR-003: Connector Architecture](adr/003-connector-architecture.md) - Why microservices?
- [FILE_UPLOAD_FLOW.md](FILE_UPLOAD_FLOW.md) - How file attachments work
- [Kafka Documentation](https://kafka.apache.org/documentation/) - Consumer API

---

## Educational Value

This connector pattern demonstrates:
- **Microservices**: Independent deployment and scaling
- **Event-Driven Architecture**: Kafka-based asynchronous communication
- **Plugin Architecture**: Adding new platforms without modifying core system
- **Separation of Concerns**: Each connector handles one platform
- **Fault Isolation**: One connector failure doesn't affect others
- **Industry Patterns**: Similar to Zapier, IFTTT, Mulesoft ESB

---

**Chat4All Educational Project** | November 2025
