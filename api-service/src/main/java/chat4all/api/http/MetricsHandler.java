package chat4all.api.http;

import chat4all.api.metrics.MetricsRegistry;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import java.io.IOException;
import java.io.OutputStream;

/**
 * MetricsHandler - Prometheus metrics endpoint
 * 
 * PURPOSE: Expose metrics in Prometheus format
 * Endpoint: GET /actuator/prometheus
 * 
 * EDUCATIONAL NOTES:
 * - Prometheus scrapes this endpoint every 15 seconds
 * - Format: text/plain (Prometheus exposition format)
 * - Contains all metrics from MetricsRegistry
 * 
 * @author Chat4All Educational Project
 */
public class MetricsHandler implements HttpHandler {
    
    private final MetricsRegistry metricsRegistry;
    
    public MetricsHandler() {
        this.metricsRegistry = MetricsRegistry.getInstance();
    }
    
    @Override
    public void handle(HttpExchange exchange) throws IOException {
        if (!"GET".equals(exchange.getRequestMethod())) {
            String error = "{\"error\":\"Method not allowed\"}";
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(405, error.length());
            exchange.getResponseBody().write(error.getBytes());
            exchange.getResponseBody().close();
            return;
        }
        
        try {
            // Scrape metrics in Prometheus format
            String metricsText = metricsRegistry.scrape();
            
            // Send response
            exchange.getResponseHeaders().set("Content-Type", "text/plain; version=0.0.4");
            exchange.sendResponseHeaders(200, metricsText.length());
            
            OutputStream os = exchange.getResponseBody();
            os.write(metricsText.getBytes());
            os.close();
            
        } catch (Exception e) {
            System.err.println("Error scraping metrics: " + e.getMessage());
            e.printStackTrace();
            
            String error = "{\"error\":\"Internal server error\"}";
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(500, error.length());
            exchange.getResponseBody().write(error.getBytes());
            exchange.getResponseBody().close();
        }
    }
}
