<!--
SYNC IMPACT REPORT - Constitution v1.0.0
========================================
Version Change: INITIAL → 1.0.0
Rationale: First constitution ratification for Chat4All project

Modified/Added Sections:
  ✅ Added: I. Didactic Simplicity (educational implementation focus)
  ✅ Added: II. Minimal Dependencies (reduce external library complexity)
  ✅ Added: III. Test-First Discipline (standardized testing requirement)
  ✅ Added: IV. Horizontal Scalability (architectural requirement)
  ✅ Added: V. Cassandra-First Data Storage (mandated database choice)
  ✅ Added: VI. Incremental Delivery (phase-based implementation)

Templates Requiring Updates:
  ✅ .specify/templates/plan-template.md - Verified alignment with Technical Context
  ✅ .specify/templates/spec-template.md - Aligned with test-first and user story prioritization
  ✅ .specify/templates/tasks-template.md - Aligned with incremental phases and testing discipline

Follow-up TODOs:
  - None: All placeholders filled

Notes:
  - Project scoped to entrega1.md (Weeks 3-4: Basic API, Kafka, text persistence)
  - Target audience: 7th semester Information Systems students
  - Focus on distributed systems learning objectives
-->

# Chat4All Constitution

## Core Principles

### I. Didactic Simplicity

**Purpose**: This is an educational project for 7th semester Information Systems students learning distributed systems concepts.

**Requirements**:
- Code MUST be clear and well-commented to facilitate learning
- Complex distributed systems patterns MUST be demonstrated but not over-engineered
- Architecture decisions MUST be documented with educational rationale
- Implementation MUST prioritize understanding over production optimization
- Each component MUST have a clear, single responsibility that students can grasp

**Rationale**: Students need to understand *why* distributed architecture choices are made. Code serves as both a working system and a teaching tool. Overly clever or production-focused implementations obscure learning objectives.

### II. Minimal Dependencies

**Purpose**: Reduce complexity and focus on core distributed systems concepts rather than framework mastery.

**Requirements**:
- Use standard library and language-native features wherever possible
- Each external dependency MUST be justified in documentation
- Prefer simple, well-established libraries over feature-rich frameworks
- Database driver and Kafka client are acceptable as core infrastructure
- Avoid ORMs, heavy frameworks, or abstraction layers that hide distributed systems concepts
- Students MUST understand what the dependency does and why it's needed

**Rationale**: Heavy dependencies obscure the distributed systems principles students need to learn. Direct implementation of HTTP handling, JSON serialization, and data access patterns teaches more than framework magic. Dependencies should enable distribution (Kafka, Cassandra driver) not replace learning (ORMs, mega-frameworks).

### III. Test-First Discipline (NON-NEGOTIABLE)

**Purpose**: Establish professional testing standards and validate distributed system behavior.

**Requirements**:
- Tests MUST be written BEFORE implementation (Red-Green-Refactor)
- Each user story MUST have independent acceptance tests
- Test coverage MUST include:
  - Unit tests for business logic
  - Integration tests for API endpoints
  - Contract tests for message schemas (Kafka events)
  - End-to-end tests for user journeys
- Tests MUST be runnable in isolation (no shared state)
- All tests MUST pass before code is considered complete
- Test code MUST be as clear and maintainable as production code

**Rationale**: Distributed systems are notoriously difficult to debug. Test-first discipline catches issues early, documents expected behavior, and provides confidence during refactoring. Testing asynchronous message flows and eventual consistency requires deliberate test design.

### IV. Horizontal Scalability

**Purpose**: Demonstrate distributed systems scalability patterns as a core learning objective.

**Requirements**:
- All API services MUST be stateless and horizontally scalable
- Kafka partitioning by `conversation_id` MUST preserve message ordering
- Database schema MUST support sharding (even if not implemented in Phase 1)
- No single points of failure in the data path
- Load balancing MUST be demonstrable (even in local Docker Compose)
- Auto-scaling capability MUST be architecturally possible (documented)
- System MUST handle multiple instances of each service

**Rationale**: Horizontal scalability is a fundamental distributed systems concept. The architecture must demonstrate how to achieve it even if full production scale isn't reached. Students must understand partitioning, stateless design, and load distribution.

### V. Cassandra-First Data Storage

**Purpose**: Use Cassandra as the mandated distributed database, embracing its strengths and constraints.

**Requirements**:
- Cassandra MUST be the primary data store for messages and metadata
- Schema design MUST follow Cassandra best practices (query-driven data modeling)
- Partition keys MUST distribute data evenly (e.g., by `conversation_id`)
- Eventually consistent reads are acceptable and MUST be documented
- No SQL joins—denormalization is expected and MUST be justified
- Replication factor MUST be configurable (minimum 2 for learning purposes)

**Rationale**: Cassandra teaches distributed database concepts: eventual consistency, partition keys, denormalization, and distributed writes. These concepts are essential for understanding NoSQL at scale. Using Cassandra's patterns correctly is more important than achieving SQL-like features.

### VI. Incremental Delivery

**Purpose**: Build and validate the system in manageable, independently testable phases.

**Requirements**:
- Implementation MUST follow the phased plan in `entrega1.md`
- Phase 1 (Weeks 3-4): Basic API + Kafka + Text Persistence
  - POST /v1/messages (send text)
  - GET /v1/conversations/{id}/messages (list messages)
  - Kafka topic with `conversation_id` partitioning
  - Cassandra storage with SENT/DELIVERED status
  - Simple JWT authentication
- Each phase MUST be independently deployable and testable
- No work on file upload (2GB) or connectors until Phase 1 is complete
- Docker Compose MUST provide one-command local deployment

**Rationale**: Large distributed systems are overwhelming. Breaking into phases allows students to master one concept at a time: first the event-driven messaging flow, then file handling, then external connectors. Each phase delivers working functionality.

## Technical Standards

### Technology Stack

**Language**: Python 3.11+ (or Go 1.21+ if team preference—document choice)

**Core Infrastructure** (mandated):
- **Message Broker**: Apache Kafka
- **Database**: Apache Cassandra
- **Authentication**: Simple JWT (library: PyJWT or golang-jwt)
- **API**: REST with native HTTP libraries (avoid heavy frameworks)

**Testing** (mandated):
- Python: pytest (unit, integration, contract)
- Go: standard testing package + testify (if needed)
- Contract tests: validate JSON schemas

**Deployment**:
- Docker + Docker Compose (for local dev and demo)
- Each service as a separate container
- Documented scaling procedure (adding instances)

### Code Quality Standards

**Code Style**:
- Follow language conventions (PEP 8 for Python, Go fmt for Go)
- Maximum function complexity: 10 cyclomatic complexity
- Clear variable names (no abbreviations unless standard in domain)

**Documentation**:
- Every module: purpose, inputs, outputs
- Every public function: docstring with parameters and return value
- Architecture decisions: ADR (Architecture Decision Record) format in `/docs/adr/`

**Error Handling**:
- All errors MUST be handled explicitly (no silent failures)
- Errors MUST be logged with context (trace_id, conversation_id)
- External failures (Kafka, Cassandra) MUST trigger retries with exponential backoff

### Performance Targets

**Latency** (for Weeks 3-4 scope):
- API acceptance: < 200ms p95 (validation + Kafka publish)
- Worker processing: < 500ms p95 (consume + Cassandra write)

**Throughput** (demonstrable at scale):
- 1,000 messages/second per API instance (local test)
- Linear scaling with additional API instances

**Note**: Full production targets (10^6–10^7 msgs/min) are aspirational—Phase 1 focuses on demonstrating scalability patterns, not achieving production load.

## Development Workflow

### Implementation Process

1. **Specification Review**: Read user story, clarify acceptance criteria
2. **Test Writing**: Write failing tests for the user story
3. **Implementation**: Write minimum code to pass tests
4. **Refactoring**: Clean up code while keeping tests green
5. **Documentation**: Update README, add comments, document decisions
6. **Integration**: Merge to main branch (after tests pass)

### Branching Strategy

- `main`: Always deployable, all tests passing
- `feature/###-name`: Feature branches from main
- `hotfix/###-name`: Critical fixes

### Definition of Done

A task is complete when:
- ✅ All tests written and passing
- ✅ Code reviewed (self-review for solo work, document rationale)
- ✅ Documentation updated (README, inline comments)
- ✅ Locally deployable via Docker Compose
- ✅ Demonstrates the learning objective (e.g., horizontal scaling, partitioning)

## Governance

### Constitutional Authority

This constitution defines the **non-negotiable standards** for the Chat4All project. All implementation decisions must align with these principles. Deviations require explicit justification and documentation.

### Amendment Process

Amendments to this constitution require:
1. Written proposal with rationale
2. Impact analysis on existing code and templates
3. Update to constitution version (semantic versioning):
   - **MAJOR**: Fundamental principle change (e.g., switching databases)
   - **MINOR**: New principle or significant clarification
   - **PATCH**: Wording improvements, typo fixes
4. Synchronization of all dependent templates and documentation

### Compliance Verification

- All pull requests MUST reference the relevant constitutional principles
- Code reviews MUST verify alignment with Test-First Discipline and Minimal Dependencies
- Architecture decisions MUST document how they support Horizontal Scalability
- Any complexity (e.g., additional dependencies) MUST be justified against these principles

### Educational Context

Remember: This is a **learning project**. When in doubt:
- Choose the clearer implementation over the clever one
- Document the "why" as much as the "what"
- Demonstrate distributed systems concepts explicitly
- Validate that a 7th semester student could understand the code

**Version**: 1.0.0 | **Ratified**: 2025-11-17 | **Last Amended**: 2025-11-17
