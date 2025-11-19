-- ============================================================================
-- Chat4All Cassandra Schema
-- ============================================================================
-- Purpose: Educational distributed database schema for messaging platform
-- Design principle: Query-driven data modeling (NoSQL best practice)
-- Target: 7th semester students learning distributed systems
-- ============================================================================

-- Create keyspace with SimpleStrategy for local development
-- In production, use NetworkTopologyStrategy with multiple datacenters
CREATE KEYSPACE IF NOT EXISTS chat4all
WITH replication = {
    'class': 'SimpleStrategy',
    'replication_factor': 2
}
AND durable_writes = true;

USE chat4all;

-- ============================================================================
-- MESSAGES TABLE
-- ============================================================================
-- Purpose: Store all messages with efficient query patterns
-- Partition key: conversation_id - distributes messages across nodes
-- Clustering key: timestamp - orders messages chronologically within partition
--
-- Educational notes:
-- - Partition key determines data distribution (critical for scalability)
-- - Same conversation_id → same partition → ordered by timestamp
-- - Enables efficient query: "Get all messages in conversation X"
-- - Denormalization: sender info embedded (no joins in Cassandra)
-- ============================================================================
CREATE TABLE IF NOT EXISTS messages (
    -- Partition key: distributes data across cluster nodes
    conversation_id TEXT,
    
    -- Clustering key: orders data within partition (chronological)
    timestamp TIMESTAMP,
    
    -- Message identification
    message_id TEXT,
    
    -- Sender information (denormalized for query efficiency)
    sender_id TEXT,
    
    -- Message content
    content TEXT,
    
    -- Message status lifecycle: SENT → DELIVERED → READ
    -- Phase 1 scope: SENT and DELIVERED only
    status TEXT,
    
    -- Primary key: (partition_key, clustering_key)
    -- This structure enables:
    -- 1. Even data distribution by conversation_id
    -- 2. Chronological ordering within each conversation
    -- 3. Efficient range queries by timestamp
    PRIMARY KEY (conversation_id, timestamp)
)
WITH CLUSTERING ORDER BY (timestamp ASC)
AND comment = 'Messages table - partitioned by conversation for scalability';

-- Optional: Add index on message_id for deduplication queries
-- Note: Secondary indexes in Cassandra should be used carefully
-- Better approach: query by partition key when possible
CREATE INDEX IF NOT EXISTS messages_by_id ON messages (message_id);

-- ============================================================================
-- CONVERSATIONS TABLE
-- ============================================================================
-- Purpose: Store conversation metadata
-- Partition key: conversation_id - unique identifier per conversation
--
-- Educational notes:
-- - Simple partition key (no clustering key needed)
-- - Denormalized participant list (stored as list, no joins)
-- - Query pattern: "Get conversation by ID"
-- ============================================================================
CREATE TABLE IF NOT EXISTS conversations (
    -- Partition key: unique conversation identifier
    conversation_id TEXT PRIMARY KEY,
    
    -- Conversation type: 'private' (1:1) or 'group' (1:N)
    -- Phase 1: only 'private' supported
    type TEXT,
    
    -- Participant user IDs (denormalized list)
    participant_ids LIST<TEXT>,
    
    -- Creation timestamp
    created_at TIMESTAMP
)
WITH comment = 'Conversations metadata table';

-- ============================================================================
-- USERS TABLE (simplified for Phase 1)
-- ============================================================================
-- Purpose: Store user credentials (hardcoded test users in Phase 1)
-- Partition key: user_id
--
-- Educational notes:
-- - In production, use separate authentication service
-- - Password hashing required (not plain text)
-- - Phase 1: hardcoded users (user_a, user_b) in application code
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
    -- Partition key: unique user identifier
    user_id TEXT PRIMARY KEY,
    
    -- Username for login
    username TEXT,
    
    -- Password hash (bcrypt or similar)
    -- Phase 1: hardcoded in code, not used from DB
    password_hash TEXT,
    
    -- Account creation timestamp
    created_at TIMESTAMP
)
WITH comment = 'Users table - simplified for educational Phase 1';

-- Optional: Add index on username for login queries
CREATE INDEX IF NOT EXISTS users_by_username ON users (username);

-- ============================================================================
-- FILES TABLE (Phase 2: Object Storage)
-- ============================================================================
-- Purpose: Store file metadata (binary data stored in MinIO)
-- Partition key: file_id - unique identifier per file
--
-- Educational notes:
-- - Separation of concerns: metadata in Cassandra, binary in MinIO
-- - file_id links to MinIO object: {conversation_id}/{file_id}.{ext}
-- - Enables queries: "Get file metadata", "List files in conversation"
-- - Checksum for data integrity verification
-- ============================================================================
CREATE TABLE IF NOT EXISTS files (
    -- Partition key: unique file identifier
    file_id TEXT PRIMARY KEY,
    
    -- Conversation context (for organization and queries)
    conversation_id TEXT,
    
    -- Uploader information
    uploader_id TEXT,
    
    -- File metadata
    filename TEXT,
    size_bytes BIGINT,
    mimetype TEXT,
    
    -- Data integrity
    checksum TEXT,  -- SHA256 hash
    
    -- MinIO storage reference
    storage_path TEXT,  -- Format: {conversation_id}/{file_id}.{extension}
    
    -- Timestamp
    uploaded_at TIMESTAMP
)
WITH comment = 'File metadata table - binary data stored in MinIO';

-- Index for querying files by conversation
CREATE INDEX IF NOT EXISTS files_by_conversation ON files (conversation_id);

-- ============================================================================
-- QUERY PATTERNS ENABLED BY THIS SCHEMA
-- ============================================================================
-- 1. Get all messages in a conversation (ordered by time):
--    SELECT * FROM messages WHERE conversation_id = ? ORDER BY timestamp ASC;
--
-- 2. Get recent messages (with pagination):
--    SELECT * FROM messages WHERE conversation_id = ? 
--    AND timestamp > ? LIMIT 50;
--
-- 3. Check if message exists (deduplication):
--    SELECT message_id FROM messages WHERE message_id = ? LIMIT 1;
--
-- 4. Update message status:
--    UPDATE messages SET status = 'DELIVERED' 
--    WHERE conversation_id = ? AND timestamp = ?;
--
-- 5. Get conversation metadata:
--    SELECT * FROM conversations WHERE conversation_id = ?;
-- ============================================================================

-- ============================================================================
-- SCALABILITY CHARACTERISTICS
-- ============================================================================
-- Horizontal scaling:
-- - Add more Cassandra nodes → partitions redistribute automatically
-- - conversation_id as partition key ensures even distribution
-- - Read/write throughput increases linearly with nodes
--
-- Eventual consistency:
-- - Replication factor = 2 → each partition stored on 2 nodes
-- - Consistency level configurable (ONE, QUORUM, ALL)
-- - Phase 1: Accept eventual consistency (typical for messaging)
--
-- No single point of failure:
-- - No master node (peer-to-peer architecture)
-- - Any node can handle any request
-- - Automatic failover if node goes down
-- ============================================================================
