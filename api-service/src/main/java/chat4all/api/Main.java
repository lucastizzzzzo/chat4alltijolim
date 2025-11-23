package chat4all.api;

import chat4all.api.auth.JwtAuthenticator;
import chat4all.api.auth.TokenGenerator;
import chat4all.api.cassandra.CassandraConnection;
import chat4all.api.cassandra.CassandraMessageRepository;
import chat4all.api.handler.FileDownloadHandler;
import chat4all.api.handler.FileUploadHandler;
import chat4all.api.http.AuthHandler;
import chat4all.api.http.ConversationsHandler;
import chat4all.api.http.MessagesHandler;
import chat4all.api.kafka.MessageProducer;
import chat4all.api.messages.MessageValidator;
import chat4all.api.repository.FileRepository;
import com.sun.net.httpserver.HttpServer;

import java.net.InetSocketAddress;

/**
 * Main - API Service Entry Point
 * 
 * EDUCATIONAL PURPOSE: HTTP Server Setup (No Framework)
 * ==================
 * 
 * WHY NO SPRING BOOT?
 * - Educational transparency: See exactly how HTTP server works
 * - Minimal dependencies: Only JDK + Kafka client
 * - Learning objective: Understand HTTP fundamentals
 * 
 * ARCHITECTURE:
 * ```
 * Client → HttpServer → Handler → Kafka → Worker
 *                ↓               ↓
 *          [Routes]          Cassandra (read-only)
 *          POST /auth/token → AuthHandler
 *          POST /v1/messages → MessagesHandler → Kafka
 *          GET  /v1/conversations/{id}/messages → ConversationsHandler → Cassandra
 * ```
 * 
 * SERVER CONFIG:
 * - Port: 8080 (default) or PORT env var
 * - Backlog: 0 (system default queue size)
 * - Executor: null (creates default thread pool)
 * 
 * LIFECYCLE:
 * 1. Read config from environment variables
 * 2. Create dependencies (TokenGenerator, MessageProducer, etc.)
 * 3. Create HttpServer and register routes
 * 4. Start server (blocking)
 * 5. Register shutdown hook for graceful cleanup
 * 
 * @author Chat4All Educational Project
 */
public class Main {
    
    /**
     * Main entry point
     * 
     * ENVIRONMENT VARIABLES:
     * - PORT: HTTP server port (default: 8080)
     * - JWT_SECRET: Secret key for JWT signing (default: "dev-secret-change-in-production")
     * - KAFKA_BOOTSTRAP_SERVERS: Kafka brokers (default: "localhost:9092")
     * - KAFKA_TOPIC_MESSAGES: Kafka topic for messages (default: "messages")
     * - CASSANDRA_CONTACT_POINTS: Cassandra hosts (default: "cassandra")
     * - CASSANDRA_PORT: Cassandra port (default: 9042)
     * - CASSANDRA_KEYSPACE: Cassandra keyspace (default: "chat4all")
     * - CASSANDRA_DATACENTER: Cassandra datacenter (default: "dc1")
     * 
     * @param args Command line arguments (unused)
     * @throws Exception if server fails to start
     */
    public static void main(String[] args) throws Exception {
        // 1. Read configuration from environment
        int port = Integer.parseInt(System.getenv().getOrDefault("PORT", "8080"));
        String jwtSecret = System.getenv().getOrDefault("JWT_SECRET", "dev-secret-change-in-production");
        String kafkaBootstrap = System.getenv().getOrDefault("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092");
        String kafkaTopic = System.getenv().getOrDefault("KAFKA_TOPIC_MESSAGES", "messages");
        
        System.out.println("===========================================");
        System.out.println("  Chat4All API Service");
        System.out.println("===========================================");
        System.out.println("Port: " + port);
        System.out.println("Kafka: " + kafkaBootstrap);
        System.out.println("Topic: " + kafkaTopic);
        System.out.println("===========================================");
        
        // 2. Create dependencies
        TokenGenerator tokenGenerator = new TokenGenerator(jwtSecret);
        JwtAuthenticator jwtAuthenticator = new JwtAuthenticator(jwtSecret);
        MessageValidator messageValidator = new MessageValidator();
        MessageProducer messageProducer = new MessageProducer(kafkaBootstrap, kafkaTopic);
        
        // Cassandra connection for read queries (GET messages)
        CassandraConnection cassandraConnection = new CassandraConnection();
        CassandraMessageRepository messageRepository = new CassandraMessageRepository(cassandraConnection.getSession());
        FileRepository fileRepository = new FileRepository(cassandraConnection.getSession());
        
        // 3. Create HTTP handlers
        AuthHandler authHandler = new AuthHandler(tokenGenerator);
        MessagesHandler messagesHandler = new MessagesHandler(messageValidator, messageProducer, jwtAuthenticator, fileRepository);
        ConversationsHandler conversationsHandler = new ConversationsHandler(messageRepository, jwtAuthenticator, fileRepository);
        FileUploadHandler fileUploadHandler = new FileUploadHandler(fileRepository);
        FileDownloadHandler fileDownloadHandler = new FileDownloadHandler(fileRepository);
        
        // 4. Create and configure HTTP server
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        
        // Register routes
        server.createContext("/auth/token", authHandler);
        server.createContext("/v1/messages", messagesHandler);
        server.createContext("/v1/conversations/", conversationsHandler); // Note: trailing slash for path matching
        server.createContext("/v1/files", fileUploadHandler);
        server.createContext("/v1/files/", fileDownloadHandler); // Matches /v1/files/{id}/download
        server.createContext("/health", exchange -> {
            String response = "{\"status\":\"UP\"}";
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, response.length());
            exchange.getResponseBody().write(response.getBytes());
            exchange.getResponseBody().close();
        });
        
        // Use default executor (creates thread pool)
        server.setExecutor(null);
        
        // 5. Register shutdown hook for graceful cleanup
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            System.out.println("\nShutting down API service...");
            server.stop(5); // Wait max 5 seconds for requests to complete
            messageProducer.close();
            cassandraConnection.close();
            System.out.println("API service stopped.");
        }));
        
        // 6. Start server (blocking)
        server.start();
        System.out.println("✓ API service started on port " + port);
        System.out.println("✓ Endpoints:");
        System.out.println("  POST /auth/token                              - Authenticate and get JWT");
        System.out.println("  POST /v1/messages                             - Send message (requires JWT)");
        System.out.println("  GET  /v1/conversations/{id}/messages          - Get message history (requires JWT)");
        System.out.println("  POST /v1/files                                - Upload file (requires JWT)");
        System.out.println("  GET  /v1/files/{id}/download                  - Get download URL (requires JWT)");
        System.out.println("  GET  /health                                  - Health check");
        System.out.println("\nPress Ctrl+C to stop.");
    }
}
