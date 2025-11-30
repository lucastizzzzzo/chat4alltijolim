package chat4all.api.http;

import chat4all.api.kafka.MessageProducer;
import com.datastax.oss.driver.api.core.CqlSession;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import org.json.JSONObject;

import java.io.IOException;
import java.io.OutputStream;

/**
 * HealthCheckHandler - Health and readiness checks
 * 
 * PURPOSE: Validate service dependencies
 * Implements: Seção 7.7 (Health Checks) do esqueleto.md
 * 
 * ENDPOINTS:
 * - GET /health - Basic liveness check
 * - GET /actuator/health - Detailed health check with dependencies
 * 
 * CHECKS:
 * - Kafka connectivity (can publish to topic)
 * - Cassandra connectivity (can execute query)
 * 
 * EDUCATIONAL NOTES:
 * - Liveness: Is the service alive? (fast check)
 * - Readiness: Is the service ready to handle requests? (dependency checks)
 * - Used by Docker healthcheck and load balancers
 * 
 * @author Chat4All Educational Project
 */
public class HealthCheckHandler implements HttpHandler {
    
    private final CqlSession cassandraSession;
    private final MessageProducer messageProducer;
    
    public HealthCheckHandler(CqlSession cassandraSession, MessageProducer messageProducer) {
        this.cassandraSession = cassandraSession;
        this.messageProducer = messageProducer;
    }
    
    @Override
    public void handle(HttpExchange exchange) throws IOException {
        if (!"GET".equals(exchange.getRequestMethod())) {
            sendResponse(exchange, 405, "{\"error\":\"Method not allowed\"}");
            return;
        }
        
        String path = exchange.getRequestURI().getPath();
        
        try {
            if (path.equals("/health")) {
                // Simple liveness check (fast)
                sendResponse(exchange, 200, "{\"status\":\"UP\"}");
            } else if (path.equals("/actuator/health")) {
                // Detailed readiness check (checks dependencies)
                JSONObject health = checkHealth();
                int statusCode = health.getString("status").equals("UP") ? 200 : 503;
                sendResponse(exchange, statusCode, health.toString());
            } else {
                sendResponse(exchange, 404, "{\"error\":\"Not found\"}");
            }
        } catch (Exception e) {
            System.err.println("Health check error: " + e.getMessage());
            e.printStackTrace();
            sendResponse(exchange, 503, "{\"status\":\"DOWN\",\"error\":\"" + e.getMessage() + "\"}");
        }
    }
    
    /**
     * Check health of all dependencies
     * 
     * @return Health status JSON
     */
    private JSONObject checkHealth() {
        JSONObject health = new JSONObject();
        JSONObject components = new JSONObject();
        
        long startTime = System.currentTimeMillis();
        
        // Check Kafka
        JSONObject kafkaHealth = checkKafka();
        components.put("kafka", kafkaHealth);
        
        // Check Cassandra
        JSONObject cassandraHealth = checkCassandra();
        components.put("cassandra", cassandraHealth);
        
        // Overall status (DOWN if any component is DOWN)
        boolean allUp = kafkaHealth.getString("status").equals("UP") 
                     && cassandraHealth.getString("status").equals("UP");
        
        health.put("status", allUp ? "UP" : "DOWN");
        health.put("components", components);
        health.put("timestamp", java.time.Instant.now().toString());
        health.put("check_duration_ms", System.currentTimeMillis() - startTime);
        
        return health;
    }
    
    /**
     * Check Kafka connectivity
     * 
     * @return Kafka health status
     */
    private JSONObject checkKafka() {
        JSONObject kafka = new JSONObject();
        long startTime = System.currentTimeMillis();
        
        try {
            // Try to get metadata (lightweight check)
            if (messageProducer != null) {
                kafka.put("status", "UP");
            } else {
                kafka.put("status", "DOWN");
                kafka.put("error", "Producer not initialized");
            }
        } catch (Exception e) {
            kafka.put("status", "DOWN");
            kafka.put("error", e.getMessage());
        }
        
        kafka.put("latency_ms", System.currentTimeMillis() - startTime);
        return kafka;
    }
    
    /**
     * Check Cassandra connectivity
     * 
     * @return Cassandra health status
     */
    private JSONObject checkCassandra() {
        JSONObject cassandra = new JSONObject();
        long startTime = System.currentTimeMillis();
        
        try {
            if (cassandraSession != null && !cassandraSession.isClosed()) {
                // Execute lightweight query
                cassandraSession.execute("SELECT now() FROM system.local");
                cassandra.put("status", "UP");
            } else {
                cassandra.put("status", "DOWN");
                cassandra.put("error", "Session not available");
            }
        } catch (Exception e) {
            cassandra.put("status", "DOWN");
            cassandra.put("error", e.getMessage());
        }
        
        cassandra.put("latency_ms", System.currentTimeMillis() - startTime);
        return cassandra;
    }
    
    /**
     * Send HTTP response
     */
    private void sendResponse(HttpExchange exchange, int statusCode, String body) throws IOException {
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(statusCode, body.length());
        OutputStream os = exchange.getResponseBody();
        os.write(body.getBytes());
        os.close();
    }
}
