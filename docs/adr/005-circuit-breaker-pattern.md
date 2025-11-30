# ADR 005: Circuit Breaker Pattern for Connector Resilience

**Status:** Accepted  
**Date:** 2024-11-27  
**Deciders:** Architecture Team  
**Context:** Entrega 3 - Observability and Fault Tolerance

---

## Context and Problem Statement

External messaging platforms (WhatsApp, Instagram, etc.) can experience:
- Temporary outages or high latency
- Rate limiting and throttling
- Network connectivity issues
- API degradation without complete failure

Without protection mechanisms, these failures can:
- Cascade to other system components
- Waste resources on repeated failing requests
- Degrade overall system performance
- Create unpredictable user experience

**Question:** How do we protect the system from cascading failures when external APIs are degraded or unavailable?

---

## Decision Drivers

1. **Resilience:** Prevent cascading failures across system boundaries
2. **Resource Protection:** Avoid wasting threads/connections on failing calls
3. **Fast Failure:** Fail fast when service is known to be down
4. **Automatic Recovery:** Resume normal operation when service recovers
5. **Observability:** Track circuit breaker state changes and metrics
6. **Educational Value:** Demonstrate fault tolerance pattern in distributed systems

---

## Considered Options

### Option 1: No Circuit Breaker (Current Implementation)
**Pros:**
- Simpler implementation
- No additional dependencies
- Suitable for educational mock APIs

**Cons:**
- No protection against cascading failures
- Resources wasted on repeated failures
- Slow failure detection
- Poor user experience during outages

### Option 2: Resilience4j Circuit Breaker
**Pros:**
- Lightweight, no external services required
- Excellent Spring Boot integration
- Rich configuration options
- Built-in metrics and events
- Battle-tested in production systems

**Cons:**
- Additional dependency (~500KB)
- Learning curve for configuration
- In-memory state (lost on restart)

### Option 3: Hystrix (Netflix)
**Pros:**
- Industry standard, proven at scale
- Rich dashboard (Hystrix Dashboard)
- Thread pool isolation

**Cons:**
- **Deprecated** (maintenance mode since 2018)
- Heavy dependency (2MB+)
- Complex configuration
- Overkill for this use case

### Option 4: Custom Implementation
**Pros:**
- Full control over behavior
- No external dependencies
- Tailored to exact needs

**Cons:**
- Reinventing the wheel
- Higher bug risk
- No community support
- Missing edge cases

---

## Decision Outcome

**Chosen option:** **Resilience4j Circuit Breaker** (prepared, not yet implemented)

### Rationale

1. **Industry Standard:** Recommended replacement for deprecated Hystrix
2. **Lightweight:** Minimal overhead, suitable for educational project
3. **Observable:** Integrates natively with Micrometer/Prometheus
4. **Educational:** Demonstrates modern fault tolerance patterns
5. **Production-Ready:** Same library used in real-world systems

### Implementation Status

**Current State (Entrega 3):**
- ✅ Dependency included in `pom.xml`
- ⚠️ Connectors use mock APIs (10% random failure)
- ⚠️ Circuit breaker code commented/not configured
- ✅ Architecture prepared for future implementation

**Reason for Deferral:**
With mock APIs that don't make real HTTP calls, circuit breakers would be demonstrating against artificial failures. For educational integrity, we document the pattern and prepare the architecture, but defer full implementation until real API integration.

---

## Implementation Design

### Configuration (Recommended for Production)

```java
// connector-whatsapp/src/main/java/chat4all/connector/whatsapp/CircuitBreakerConfig.java
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerConfig;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;

public class WhatsAppCircuitBreaker {
    
    private final CircuitBreaker circuitBreaker;
    
    public WhatsAppCircuitBreaker() {
        CircuitBreakerConfig config = CircuitBreakerConfig.custom()
            // Open circuit if 50% of calls fail
            .failureRateThreshold(50)
            
            // Minimum 10 calls before calculating failure rate
            .minimumNumberOfCalls(10)
            
            // Wait 30s before attempting recovery (half-open state)
            .waitDurationInOpenState(Duration.ofSeconds(30))
            
            // Allow 5 calls in half-open to test recovery
            .permittedNumberOfCallsInHalfOpenState(5)
            
            // Sliding window of last 100 calls
            .slidingWindowType(SlidingWindowType.COUNT_BASED)
            .slidingWindowSize(100)
            
            // Consider these exceptions as failures
            .recordExceptions(IOException.class, TimeoutException.class)
            
            .build();
            
        CircuitBreakerRegistry registry = CircuitBreakerRegistry.of(config);
        this.circuitBreaker = registry.circuitBreaker("whatsapp-api");
        
        // Register metrics with Prometheus
        CircuitBreakerMetrics.ofCircuitBreakerRegistry(registry)
            .bindTo(MetricsRegistry.getInstance().getRegistry());
    }
    
    public boolean sendMessage(String messageId, String recipient, String content) {
        return circuitBreaker.executeSupplier(() -> {
            // Real HTTP call here
            return httpClient.post(whatsappApiUrl, buildPayload(messageId, recipient, content));
        });
    }
}
```

### State Machine

```
                 ┌─────────────┐
                 │   CLOSED    │ ← Normal operation
                 │  (Healthy)  │
                 └──────┬──────┘
                        │
                 Failure rate > 50%
                        │
                        ▼
                 ┌─────────────┐
                 │    OPEN     │ ← Failing fast
                 │  (Tripped)  │
                 └──────┬──────┘
                        │
                 After 30s timeout
                        │
                        ▼
                 ┌─────────────┐
                 │  HALF-OPEN  │ ← Testing recovery
                 │  (Testing)  │
                 └──────┬──────┘
                        │
          ┌─────────────┴─────────────┐
          │                           │
     5/5 succeed                 Failures continue
          │                           │
          ▼                           ▼
    [Back to CLOSED]          [Back to OPEN]
```

### Metrics Exposed

```prometheus
# Circuit breaker state (0=closed, 1=open, 2=half-open)
resilience4j_circuitbreaker_state{name="whatsapp-api"} 0

# Total calls
resilience4j_circuitbreaker_calls_total{name="whatsapp-api",kind="successful"} 1523
resilience4j_circuitbreaker_calls_total{name="whatsapp-api",kind="failed"} 47

# Failure rate
resilience4j_circuitbreaker_failure_rate{name="whatsapp-api"} 0.03

# Slow calls
resilience4j_circuitbreaker_slow_calls_total{name="whatsapp-api"} 12
```

### Grafana Dashboard Panel

```json
{
  "title": "Circuit Breaker States",
  "targets": [
    {
      "expr": "resilience4j_circuitbreaker_state",
      "legendFormat": "{{name}}: {{state}}"
    }
  ],
  "valueMaps": [
    {"value": "0", "text": "CLOSED"},
    {"value": "1", "text": "OPEN"},
    {"value": "2", "text": "HALF-OPEN"}
  ]
}
```

---

## Consequences

### Positive

✅ **Fault Isolation:** Failures in external APIs don't cascade to Kafka consumers  
✅ **Fast Failure:** Immediate rejection when circuit is open (no wasted resources)  
✅ **Automatic Recovery:** Self-healing when service recovers  
✅ **Observable:** Circuit state visible in Prometheus/Grafana  
✅ **Configurable:** Tune thresholds per connector (WhatsApp vs Instagram)  
✅ **Educational:** Demonstrates resilience patterns in distributed systems  

### Negative

⚠️ **Additional Complexity:** One more state to understand and monitor  
⚠️ **Configuration Challenge:** Thresholds must be tuned per service  
⚠️ **False Positives:** May open circuit during temporary network blips  
⚠️ **In-Memory State:** Lost on restart (acceptable for this use case)  

### Neutral

📊 **Monitoring Required:** Circuit breaker effectiveness depends on good alerting  
🔧 **Testing Complexity:** Need to simulate API failures in integration tests  

---

## Alternatives Considered

### Retry with Exponential Backoff Only
- Simpler but doesn't prevent resource exhaustion
- No fast-fail mechanism
- Can still cascade failures

### Bulkhead Pattern
- Isolates thread pools per connector
- Complementary to circuit breaker
- More complex, higher resource usage
- Overkill for current scale

### Dead Letter Queue (DLQ) Only
- Handles permanent failures well
- Doesn't protect against cascading failures
- No fast-fail mechanism
- Should be used **in addition** to circuit breaker

---

## Implementation Checklist (Future Work)

- [ ] Remove mock API calls, implement real HTTP client
- [ ] Configure Resilience4j circuit breaker per connector
- [ ] Add circuit breaker metrics to Prometheus
- [ ] Create Grafana dashboard panel for circuit states
- [ ] Add integration tests with simulated API failures
- [ ] Document circuit breaker thresholds in README
- [ ] Configure alerts for "circuit breaker open" state
- [ ] Implement fallback behavior (e.g., mark message as PENDING)

---

## References

- [Resilience4j Documentation](https://resilience4j.readme.io/docs/circuitbreaker)
- [Martin Fowler - Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)
- [Release It! - Michael Nygard](https://pragprog.com/titles/mnee2/release-it-second-edition/)
- [Micrometer Metrics Integration](https://resilience4j.readme.io/docs/micrometer)

---

## Related ADRs

- [ADR 003: Connector Architecture Pattern](003-connector-architecture.md) - Foundation for this pattern
- [ADR 006: Observability Strategy](006-observability-strategy.md) - Metrics and monitoring
