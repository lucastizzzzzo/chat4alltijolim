# ADR 001: No Application Frameworks (No Spring Boot)

**Status**: Accepted  
**Date**: 2025-01-17  
**Context**: Chat4All Educational Distributed Systems Project  
**Decision Makers**: Educational Project Team  
**Impacted Stakeholders**: 7th Semester Information Systems Students

---

## Context and Problem Statement

We need to decide whether to use established Java application frameworks (e.g., Spring Boot, Quarkus, Micronaut) or build the Chat4All messaging platform using minimal dependencies and the Java 17 Standard Library.

This project is **educational** in nature, designed for 7th semester Information Systems students to learn distributed systems concepts. The primary learning objectives are:

1. Understanding **event-driven architecture** (Kafka)
2. Understanding **distributed databases** (Cassandra)
3. Understanding **horizontal scalability** (stateless services)
4. Understanding **asynchronous processing** (producer-consumer pattern)
5. Understanding **microservices communication** (message brokers, not REST)

The choice of framework significantly impacts the **transparency** and **didactic clarity** of the codebase.

---

## Decision Drivers

### Educational Requirements (Constitution I: Didactic Simplicity)

- **Transparency**: Students must see HOW things work, not just THAT they work
- **Minimal "Magic"**: Avoid dependency injection, annotations, auto-configuration that hides internals
- **Clear Execution Flow**: No framework lifecycle hooks obscuring startup sequence
- **Debuggability**: Students should be able to follow code from `main()` to database write

### Project Constraints (Constitution II: Minimal Dependencies)

- Minimize external libraries to reduce cognitive load
- Only essential dependencies: Kafka client, Cassandra driver, JWT library
- Avoid transitive dependency bloat (Spring Boot brings 50+ JARs)

### Performance Requirements

- Support 10^6-10^7 messages/minute throughput
- Low latency (<200ms) for API response
- Horizontal scalability (stateless services)

---

## Considered Options

### Option 1: Use Spring Boot (REJECTED)

**Advantages**:
- Production-ready HTTP server (Tomcat/Jetty embedded)
- Built-in dependency injection (DI)
- Auto-configuration (@SpringBootApplication)
- Extensive ecosystem (Spring Data, Spring Kafka)

**Disadvantages**:
- **Hidden Complexity**: Students don't see HTTP server setup, thread pools, connection pooling
- **Annotation Magic**: @Autowired, @RestController hide wiring logic
- **Transitive Dependencies**: 50+ JARs (spring-boot-starter-web alone is 30+ dependencies)
- **Learning Curve**: Students must learn Spring framework AND distributed systems
- **Overkill**: We need a simple HTTP API (2 endpoints), not a full web framework

### Option 2: Use Quarkus/Micronaut (REJECTED)

**Advantages**:
- Faster startup than Spring Boot (compile-time DI)
- Smaller memory footprint
- Native image support (GraalVM)

**Disadvantages**:
- Same educational issues as Spring Boot (annotations, auto-configuration)
- Less familiar to students (Spring is standard curriculum)
- Still brings significant dependency overhead

### Option 3: Use JDK's Built-in HttpServer (SELECTED ✓)

**Advantages**:
- **Zero External Dependencies**: `com.sun.net.httpserver.HttpServer` is in JDK since Java 6
- **Educational Transparency**: Students see explicit HTTP handling:
  ```java
  HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);
  server.createContext("/v1/messages", new MessagesHandler());
  server.start();
  ```
- **Complete Control**: Explicit routing, request parsing, response writing
- **Minimal Overhead**: No container, no servlet spec, no framework lifecycle
- **Aligns with Constitution**: Only 3 external dependencies (Kafka, Cassandra, JWT)

**Disadvantages**:
- More manual work (JSON parsing, routing, middleware)
- Less production-ready (no advanced features like HTTP/2, connection pooling)
- Fewer community resources (StackOverflow answers mostly target Spring)

---

## Decision

**We will use JDK's `com.sun.net.httpserver.HttpServer` and AVOID Spring Boot (or any application framework).**

### Rationale

This is an **educational project**, not a production system. The didactic value of seeing explicit HTTP handling, manual JSON parsing, and clear execution flow **outweighs** the convenience of Spring Boot.

#### Educational Benefits

1. **Explicit HTTP Handling**:
   ```java
   // Students see EXACTLY how HTTP requests are processed
   public void handle(HttpExchange exchange) throws IOException {
       String method = exchange.getRequestMethod();
       Headers headers = exchange.getRequestHeaders();
       InputStream requestBody = exchange.getRequestBody();
       // ... explicit parsing, validation, response writing
   }
   ```

2. **Clear Kafka Integration**:
   ```java
   // No @KafkaListener magic - explicit consumer loop
   KafkaProducer<String, String> producer = new KafkaProducer<>(props);
   producer.send(new ProducerRecord<>("messages", conversationId, json));
   // Students see partitioning, serialization, acknowledgment
   ```

3. **Manual JSON Parsing**:
   ```java
   // Educational: Students understand JSON structure
   String json = new String(requestBody.readAllBytes(), StandardCharsets.UTF_8);
   MessageEvent event = MessageEvent.fromJson(json);
   // vs. Spring: @RequestBody MessageEvent event (hidden Jackson magic)
   ```

4. **Explicit Dependency Injection**:
   ```java
   // No @Autowired - explicit constructor injection
   public Main() {
       KafkaProducer producer = createKafkaProducer();
       MessagesHandler handler = new MessagesHandler(producer);
       server.createContext("/v1/messages", handler);
   }
   ```

#### Performance Considerations

- **Throughput**: JDK HttpServer supports 10,000+ requests/second (sufficient for educational demo)
- **Scalability**: Stateless design allows horizontal scaling (Docker Compose `--scale`)
- **Bottleneck is Kafka/Cassandra**: HTTP layer is not the limiting factor

---

## Consequences

### Positive

- ✅ Students understand the ENTIRE codebase from `main()` to database
- ✅ Only 3 external dependencies: `kafka-clients`, `cassandra-driver-core`, `java-jwt`
- ✅ Clear execution flow: No Spring lifecycle, no annotation scanning
- ✅ Small JAR size (~5MB vs. ~50MB for Spring Boot)
- ✅ Fast startup (~2 seconds vs. ~10 seconds for Spring Boot)

### Negative

- ❌ More manual code (routing, JSON parsing, validation)
- ❌ No production-ready features (metrics, health checks require manual implementation)
- ❌ Less familiar to students used to Spring Boot in other courses

### Neutral

- 🔶 Students must write more code, but this is EDUCATIONAL (they learn by doing)
- 🔶 We document every decision with comments (e.g., "Why no Jackson? See ADR 001")

---

## Implementation Guidelines

### Manual JSON Parsing

Create `JsonParser.java` with static methods:
```java
public class JsonParser {
    public static Map<String, String> parseRequest(String json) { ... }
    public static String toJson(Map<String, String> data) { ... }
}
```

**Why not Jackson/Gson?**  
- Educational transparency: Students see JSON structure explicitly
- Minimal dependencies (Constitution II)
- Manual parsing teaches string manipulation, escaping, validation

### HTTP Routing

Use explicit `server.createContext()` calls:
```java
server.createContext("/v1/messages", new MessagesHandler(producer));
server.createContext("/v1/conversations", new ConversationsHandler(producer));
server.createContext("/auth/token", new AuthHandler());
```

**Why not Spring MVC @GetMapping?**  
- No hidden routing table
- Students see explicit URL-to-handler mapping

### Dependency Injection

Use **constructor injection** (manual, no framework):
```java
public class MessagesHandler implements HttpHandler {
    private final KafkaProducer<String, String> producer;
    
    public MessagesHandler(KafkaProducer<String, String> producer) {
        this.producer = producer; // Explicit dependency
    }
}
```

**Why not @Autowired?**  
- No "magic" wiring
- Clear dependency graph
- Students see object lifecycle explicitly

---

## Alternatives Considered

### Use Lightweight Framework (Javalin, Spark Java)

**Why rejected:**  
- Still introduces framework abstraction (routing DSL, middleware)
- Adds external dependency
- Educational value is lower than raw HttpServer

### Use Netty for HTTP

**Why rejected:**  
- Netty is low-level (event loop, buffers, channels)
- Too complex for educational purposes
- JDK HttpServer is simpler and sufficient

---

## Related Decisions

- **ADR 002**: Cassandra Schema Design (query-driven modeling)
- **ADR 003**: Kafka Partitioning Strategy (partition by conversation_id)

---

## References

- [JDK HttpServer Documentation](https://docs.oracle.com/en/java/javase/17/docs/api/jdk.httpserver/com/sun/net/httpserver/HttpServer.html)
- [Chat4All Constitution](../../.specify/memory/constitution.md) - Principles I, II
- [Chat4All Implementation Plan](../../specs/001-basic-messaging-api/plan.md) - Section 2.2 (Technology Stack)

---

**Decision Date**: 2025-01-17  
**Last Updated**: 2025-01-17  
**Status**: **ACCEPTED** ✓
