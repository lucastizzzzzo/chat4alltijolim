package chat4all.api.metrics;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.binder.jvm.ClassLoaderMetrics;
import io.micrometer.core.instrument.binder.jvm.JvmGcMetrics;
import io.micrometer.core.instrument.binder.jvm.JvmMemoryMetrics;
import io.micrometer.core.instrument.binder.jvm.JvmThreadMetrics;
import io.micrometer.core.instrument.binder.system.ProcessorMetrics;
import io.micrometer.prometheus.PrometheusConfig;
import io.micrometer.prometheus.PrometheusMeterRegistry;

/**
 * MetricsRegistry - Centralized metrics management
 * 
 * PURPOSE: Expose Prometheus metrics for observability
 * Implements: Seção 2.4 (Observabilidade) do esqueleto.md
 * 
 * METRICS EXPOSED:
 * - http_requests_total{method, path, status} - Total HTTP requests
 * - http_request_duration_seconds{method, path} - HTTP request latency
 * - messages_accepted_total - Messages accepted by API
 * - messages_rejected_total{reason} - Messages rejected
 * - files_uploaded_total{size_bucket} - Files uploaded by size
 * - kafka_publish_duration_seconds - Time to publish to Kafka
 * 
 * EDUCATIONAL NOTES:
 * - Micrometer: Vendor-neutral metrics facade (like SLF4J for logging)
 * - Prometheus format: Counter, Gauge, Timer, Summary, Histogram
 * - JVM metrics: Memory, GC, threads, CPU
 * 
 * @author Chat4All Educational Project
 */
public class MetricsRegistry {
    
    private static MetricsRegistry instance;
    private final PrometheusMeterRegistry prometheusRegistry;
    
    // HTTP metrics
    private final Counter httpRequestsTotal;
    private final Timer httpRequestDuration;
    
    // Message metrics
    private final Counter messagesAcceptedTotal;
    private final Counter messagesRejectedTotal;
    
    // File metrics
    private final Counter filesUploadedTotal;
    
    // Kafka metrics
    private final Timer kafkaPublishDuration;
    
    /**
     * Private constructor (Singleton pattern)
     */
    private MetricsRegistry() {
        // Create Prometheus registry
        this.prometheusRegistry = new PrometheusMeterRegistry(PrometheusConfig.DEFAULT);
        
        // Register JVM metrics
        new ClassLoaderMetrics().bindTo(prometheusRegistry);
        new JvmMemoryMetrics().bindTo(prometheusRegistry);
        new JvmGcMetrics().bindTo(prometheusRegistry);
        new JvmThreadMetrics().bindTo(prometheusRegistry);
        new ProcessorMetrics().bindTo(prometheusRegistry);
        
        // Initialize application metrics
        this.httpRequestsTotal = Counter.builder("http_requests_total")
                .description("Total HTTP requests")
                .tag("service", "api-service")
                .register(prometheusRegistry);
        
        this.httpRequestDuration = Timer.builder("http_request_duration_seconds")
                .description("HTTP request duration in seconds")
                .tag("service", "api-service")
                .register(prometheusRegistry);
        
        this.messagesAcceptedTotal = Counter.builder("messages_accepted_total")
                .description("Total messages accepted by API")
                .tag("service", "api-service")
                .register(prometheusRegistry);
        
        this.messagesRejectedTotal = Counter.builder("messages_rejected_total")
                .description("Total messages rejected")
                .tag("service", "api-service")
                .register(prometheusRegistry);
        
        this.filesUploadedTotal = Counter.builder("files_uploaded_total")
                .description("Total files uploaded")
                .tag("service", "api-service")
                .register(prometheusRegistry);
        
        this.kafkaPublishDuration = Timer.builder("kafka_publish_duration_seconds")
                .description("Time to publish message to Kafka")
                .tag("service", "api-service")
                .register(prometheusRegistry);
    }
    
    /**
     * Get singleton instance
     * 
     * @return MetricsRegistry instance
     */
    public static synchronized MetricsRegistry getInstance() {
        if (instance == null) {
            instance = new MetricsRegistry();
        }
        return instance;
    }
    
    /**
     * Get Prometheus registry (for scraping endpoint)
     * 
     * @return PrometheusMeterRegistry
     */
    public PrometheusMeterRegistry getPrometheusRegistry() {
        return prometheusRegistry;
    }
    
    /**
     * Get MeterRegistry (for custom metrics)
     * 
     * @return MeterRegistry
     */
    public MeterRegistry getMeterRegistry() {
        return prometheusRegistry;
    }
    
    /**
     * Record HTTP request
     * 
     * @param method HTTP method (GET, POST, etc.)
     * @param path Request path
     * @param status HTTP status code
     * @param durationMs Request duration in milliseconds
     */
    public void recordHttpRequest(String method, String path, int status, long durationMs) {
        httpRequestsTotal.increment();
        
        Counter.builder("http_requests_by_status_total")
                .description("HTTP requests by status code")
                .tag("method", method)
                .tag("path", sanitizePath(path))
                .tag("status", String.valueOf(status))
                .register(prometheusRegistry)
                .increment();
        
        Timer.builder("http_request_duration_by_path_seconds")
                .description("HTTP request duration by path")
                .tag("method", method)
                .tag("path", sanitizePath(path))
                .register(prometheusRegistry)
                .record(java.time.Duration.ofMillis(durationMs));
    }
    
    /**
     * Record message accepted
     */
    public void recordMessageAccepted() {
        messagesAcceptedTotal.increment();
    }
    
    /**
     * Record message rejected
     * 
     * @param reason Rejection reason (validation_failed, auth_failed, etc.)
     */
    public void recordMessageRejected(String reason) {
        messagesRejectedTotal.increment();
        
        Counter.builder("messages_rejected_by_reason_total")
                .description("Messages rejected by reason")
                .tag("reason", reason)
                .register(prometheusRegistry)
                .increment();
    }
    
    /**
     * Record file uploaded
     * 
     * @param sizeBytes File size in bytes
     */
    public void recordFileUploaded(long sizeBytes) {
        filesUploadedTotal.increment();
        
        String sizeBucket = getSizeBucket(sizeBytes);
        Counter.builder("files_uploaded_by_size_total")
                .description("Files uploaded by size bucket")
                .tag("size_bucket", sizeBucket)
                .register(prometheusRegistry)
                .increment();
    }
    
    /**
     * Record Kafka publish
     * 
     * @param durationMs Publish duration in milliseconds
     */
    public void recordKafkaPublish(long durationMs) {
        kafkaPublishDuration.record(java.time.Duration.ofMillis(durationMs));
    }
    
    /**
     * Sanitize path for metrics (remove IDs)
     * Example: /v1/conversations/abc123/messages -> /v1/conversations/{id}/messages
     * 
     * @param path Request path
     * @return Sanitized path
     */
    private String sanitizePath(String path) {
        return path.replaceAll("/[a-f0-9-]{36}", "/{id}")  // UUID
                   .replaceAll("/[a-zA-Z0-9_-]{20,}", "/{id}");  // Any long ID
    }
    
    /**
     * Get size bucket for file size
     * 
     * @param sizeBytes File size in bytes
     * @return Size bucket (small, medium, large, xlarge)
     */
    private String getSizeBucket(long sizeBytes) {
        if (sizeBytes < 1024 * 1024) {  // < 1MB
            return "small";
        } else if (sizeBytes < 10 * 1024 * 1024) {  // < 10MB
            return "medium";
        } else if (sizeBytes < 100 * 1024 * 1024) {  // < 100MB
            return "large";
        } else {
            return "xlarge";
        }
    }
    
    /**
     * Scrape metrics in Prometheus format
     * 
     * @return Metrics in Prometheus exposition format
     */
    public String scrape() {
        return prometheusRegistry.scrape();
    }
}
