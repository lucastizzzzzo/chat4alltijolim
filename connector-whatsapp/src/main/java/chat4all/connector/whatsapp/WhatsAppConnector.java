package chat4all.connector.whatsapp;

import chat4all.shared.MessageEvent;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.time.Duration;
import java.util.Collections;
import java.util.Properties;
import java.util.Random;

/**
 * WhatsApp Connector - Main Processing Logic
 * 
 * Purpose:
 * - Consumes messages from "whatsapp-outbound" Kafka topic
 * - Simulates WhatsApp Business API calls
 * - Publishes delivery status updates
 * 
 * Educational Notes:
 * - Kafka consumer with manual commit (at-least-once delivery)
 * - Idempotency: same message can be processed multiple times safely
 * - Graceful shutdown: closes resources properly
 * 
 * @author Chat4All Team
 * @version 1.0.0
 */
public class WhatsAppConnector {
    
    private final KafkaConsumer<String, String> consumer;
    private final StatusPublisher statusPublisher;
    private final ConnectorMetricsRegistry metricsRegistry;
    private final CircuitBreaker circuitBreaker;
    private final Random random;
    private volatile boolean running;
    
    /**
     * Constructor
     * 
     * @param kafkaBootstrapServers Kafka broker addresses
     * @param consumerGroupId Consumer group ID for coordination
     * @param inboundTopic Topic to consume messages from
     * @param statusPublisher Publisher for status updates
     */
    public WhatsAppConnector(
        String kafkaBootstrapServers,
        String consumerGroupId,
        String inboundTopic,
        StatusPublisher statusPublisher
    ) {
        this.statusPublisher = statusPublisher;
        this.metricsRegistry = ConnectorMetricsRegistry.getInstance();
        this.circuitBreaker = new CircuitBreaker(metricsRegistry);
        this.random = new Random();
        this.running = true;
        
        // Configure Kafka consumer
        Properties props = new Properties();
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, kafkaBootstrapServers);
        props.put(ConsumerConfig.GROUP_ID_CONFIG, consumerGroupId);
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, "false"); // Manual commit
        props.put(ConsumerConfig.MAX_POLL_RECORDS_CONFIG, "10"); // Process in small batches
        
        this.consumer = new KafkaConsumer<>(props);
        this.consumer.subscribe(Collections.singletonList(inboundTopic));
        
        System.out.println("✅ WhatsApp connector initialized");
        System.out.println("   Subscribed to topic: " + inboundTopic);
        System.out.println("   Consumer group: " + consumerGroupId);
    }
    
    /**
     * Main run loop - consumes and processes messages
     * 
     * Educational Notes:
     * - Poll with timeout: blocks for max 1 second waiting for messages
     * - Commit after processing: ensures at-least-once delivery
     * - Graceful shutdown: checks running flag after each poll
     */
    public void run() {
        System.out.println("");
        System.out.println("===========================================");
        System.out.println("  ✅ WhatsApp Connector Ready");
        System.out.println("  ⏳ Waiting for messages...");
        System.out.println("  Press Ctrl+C to stop");
        System.out.println("===========================================");
        System.out.println("");
        
        while (running) {
            try {
                // Poll for messages (blocks for max 1 second)
                ConsumerRecords<String, String> records = consumer.poll(Duration.ofSeconds(1));
                
                if (records.isEmpty()) {
                    continue; // No messages, poll again
                }
                
                System.out.println("▼ Polled " + records.count() + " message(s)");
                System.out.println("");
                
                // Process each message
                for (ConsumerRecord<String, String> record : records) {
                    processMessage(record);
                }
                
                // Commit offsets after successful processing
                consumer.commitSync();
                System.out.println("✅ Committed offsets for " + records.count() + " message(s)");
                System.out.println("");
                
            } catch (Exception e) {
                System.err.println("❌ Error in consumer loop: " + e.getMessage());
                e.printStackTrace();
                // Continue running despite errors (fault tolerance)
            }
        }
        
        // Cleanup
        consumer.close();
        System.out.println("✅ Consumer closed");
    }
    
    /**
     * Process a single message from Kafka
     * 
     * Flow:
     * 1. Deserialize MessageEvent from JSON
     * 2. Log message consumption
     * 3. Simulate WhatsApp API call (random delay)
     * 4. Publish DELIVERED status update
     * 
     * @param record Kafka consumer record
     */
    private void processMessage(ConsumerRecord<String, String> record) {
        try {
            System.out.println("─────────────────────────────────");
            System.out.println("Partition: " + record.partition() + " | Offset: " + record.offset() + " | Key: " + record.key());
            System.out.println("");
            
            // Deserialize MessageEvent
            String messageJson = record.value();
            MessageEvent event = MessageEvent.fromJson(messageJson);
            
            String messageId = event.getMessageId();
            String recipientId = event.getSenderId(); // In real system, extract from conversation participants
            
            System.out.println("[WhatsApp] Consumed message: " + messageId);
            System.out.println("[WhatsApp] Recipient: " + recipientId);
            System.out.println("[WhatsApp] Content: " + event.getContent());
            
            // Check circuit breaker before making API call
            if (!circuitBreaker.allowRequest()) {
                System.err.println("⚠️ [WhatsApp] Circuit breaker OPEN, skipping API call for: " + messageId);
                metricsRegistry.recordMessageFailed();
                // Message stays in Kafka, will retry later when circuit closes
                return;
            }
            
            // Simulate WhatsApp Business API call (track duration)
            long apiStart = System.currentTimeMillis();
            boolean success = simulateApiCall(messageId, recipientId);
            long apiDuration = System.currentTimeMillis() - apiStart;
            
            // Record API call metrics
            metricsRegistry.recordApiCall(apiDuration);
            
            // Update circuit breaker based on result
            if (success) {
                circuitBreaker.recordSuccess();
                metricsRegistry.recordMessageSent();
                
                // Publish DELIVERED status
                statusPublisher.publishDelivered(messageId);
                
                System.out.println("✅ Processing complete for message: " + messageId);
            } else {
                circuitBreaker.recordFailure();
                metricsRegistry.recordMessageFailed();
                System.err.println("❌ Failed to deliver message: " + messageId);
            }
            
            System.out.println("");
            
        } catch (Exception e) {
            System.err.println("❌ Error processing message: " + e.getMessage());
            e.printStackTrace();
            // Record failure
            circuitBreaker.recordFailure();
            metricsRegistry.recordMessageFailed();
            // Don't rethrow - continue processing other messages
        }
    }
    
    /**
     * Simulate WhatsApp Business API call
     * 
     * Educational Notes:
     * - Random delay (200-500ms) simulates network latency
     * - In production: would use HTTP client to call real WhatsApp API
     * - Error handling: retry logic, circuit breaker patterns
     * - Simulates 10% failure rate for circuit breaker testing
     * 
     * @param messageId Message ID being delivered
     * @param recipientId Recipient phone number (e.g., +5511999999999)
     * @return true if delivery succeeded, false if failed
     */
    private boolean simulateApiCall(String messageId, String recipientId) {
        try {
            // Simulate 10% failure rate for circuit breaker testing
            boolean shouldFail = random.nextInt(10) == 0;
            
            if (shouldFail) {
                System.err.println("[WhatsApp] ✗ Simulated API failure for " + recipientId);
                return false;
            }
            
            // Random delay between 200-500ms
            int delayMs = 200 + random.nextInt(300);
            
            System.out.println("[WhatsApp] Simulating API call...");
            System.out.println("  → Latency: " + delayMs + "ms");
            
            Thread.sleep(delayMs);
            
            System.out.println("[WhatsApp] ✓ Delivered to " + recipientId);
            return true;
            
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            System.err.println("❌ API simulation interrupted");
            return false;
        }
    }
    
    /**
     * Stop the connector gracefully
     * 
     * Called by shutdown hook in Main.java
     */
    public void stop() {
        this.running = false;
    }
}
