package chat4all.api.http;

import chat4all.api.metrics.MetricsRegistry;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import java.io.IOException;

/**
 * MetricsInterceptor - HTTP handler wrapper that records metrics
 * 
 * PURPOSE: Automatically record metrics for all HTTP requests
 * Pattern: Decorator pattern
 * 
 * METRICS RECORDED:
 * - Request count by method, path, and status
 * - Request duration
 * 
 * EDUCATIONAL NOTES:
 * - Wraps existing handlers without modifying them
 * - Transparent metrics collection
 * - Follows Single Responsibility Principle
 * 
 * @author Chat4All Educational Project
 */
public class MetricsInterceptor implements HttpHandler {
    
    private final HttpHandler wrappedHandler;
    private final MetricsRegistry metricsRegistry;
    
    public MetricsInterceptor(HttpHandler wrappedHandler) {
        this.wrappedHandler = wrappedHandler;
        this.metricsRegistry = MetricsRegistry.getInstance();
    }
    
    @Override
    public void handle(HttpExchange exchange) throws IOException {
        long startTime = System.currentTimeMillis();
        String method = exchange.getRequestMethod();
        String path = exchange.getRequestURI().getPath();
        
        try {
            // Call wrapped handler
            wrappedHandler.handle(exchange);
            
            // Record metrics (status code set by handler)
            long duration = System.currentTimeMillis() - startTime;
            int status = exchange.getResponseCode();
            metricsRegistry.recordHttpRequest(method, path, status, duration);
            
        } catch (Exception e) {
            // Record error
            long duration = System.currentTimeMillis() - startTime;
            metricsRegistry.recordHttpRequest(method, path, 500, duration);
            throw e;
        }
    }
}
