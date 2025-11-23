package chat4all.api.repository;

import chat4all.shared.FileEvent;
import com.datastax.oss.driver.api.core.CqlSession;
import com.datastax.oss.driver.api.core.cql.PreparedStatement;
import com.datastax.oss.driver.api.core.cql.ResultSet;
import com.datastax.oss.driver.api.core.cql.Row;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * FileRepository - Data access layer for file metadata
 * 
 * Purpose: Persist and query file metadata in Cassandra
 * 
 * Educational notes:
 * - Repository pattern: Separate data access from business logic
 * - Prepared statements: Prevent SQL injection, improve performance
 * - Optional<T>: Explicit handling of "not found" scenarios
 * - Cassandra data model: file_id as PRIMARY KEY for direct lookups
 * - Secondary index: files_by_conversation for conversation queries
 * 
 * Why Cassandra for metadata?
 * - Fast lookups by file_id (primary key)
 * - Efficient queries by conversation_id (secondary index)
 * - Decoupled from object storage (MinIO stores binary data)
 * - Metadata changes without re-uploading files
 * 
 * Data Separation Pattern:
 * - Cassandra: Structured metadata (filename, size, checksum, timestamps)
 * - MinIO: Unstructured binary data (actual file content)
 * - Benefit: Query metadata without loading file content
 * 
 * @since Phase 2 (File Upload API)
 */
public class FileRepository {
    
    private final CqlSession session;
    private final PreparedStatement insertStatement;
    private final PreparedStatement findByIdStatement;
    private final PreparedStatement findByConversationStatement;
    
    /**
     * Initialize repository with Cassandra session
     * 
     * Educational note: Prepared statements
     * - Parsed once, executed many times (performance)
     * - Parameterized queries prevent injection
     * - Cached in Cassandra server
     * 
     * @param session Active Cassandra session
     */
    public FileRepository(CqlSession session) {
        this.session = session;
        
        // Prepare INSERT statement for file metadata
        this.insertStatement = session.prepare(
                "INSERT INTO files (file_id, conversation_id, uploader_id, filename, " +
                "size_bytes, mimetype, checksum, storage_path, uploaded_at) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
        );
        
        // Prepare SELECT by file_id (primary key - fast)
        this.findByIdStatement = session.prepare(
                "SELECT file_id, conversation_id, uploader_id, filename, size_bytes, " +
                "mimetype, checksum, storage_path, uploaded_at " +
                "FROM files WHERE file_id = ?"
        );
        
        // Prepare SELECT by conversation_id (secondary index)
        this.findByConversationStatement = session.prepare(
                "SELECT file_id, conversation_id, uploader_id, filename, size_bytes, " +
                "mimetype, checksum, storage_path, uploaded_at " +
                "FROM files WHERE conversation_id = ?"
        );
        
        System.out.println("[FileRepository] Initialized with prepared statements");
    }
    
    /**
     * Save file metadata to Cassandra
     * 
     * Educational note: Transaction vs write operation
     * - Cassandra: No multi-row transactions (eventual consistency)
     * - Single row writes are atomic
     * - file_id must be unique (PRIMARY KEY constraint)
     * 
     * Flow:
     * 1. File uploaded to MinIO → get storage_path
     * 2. Calculate checksum during upload
     * 3. Save metadata to Cassandra
     * 4. Return FileEvent to caller
     * 
     * @param fileEvent File metadata to persist
     * @return The saved FileEvent (same instance)
     * @throws RuntimeException if write fails
     */
    public FileEvent save(FileEvent fileEvent) {
        try {
            session.execute(insertStatement.bind(
                    fileEvent.getFileId(),
                    fileEvent.getConversationId(),
                    fileEvent.getUploaderId(),
                    fileEvent.getFilename(),
                    fileEvent.getSizeBytes(),
                    fileEvent.getMimetype(),
                    fileEvent.getChecksum(),
                    fileEvent.getStoragePath(),
                    fileEvent.getUploadedAt()
            ));
            
            System.out.println("[FileRepository] Saved metadata for file: " + fileEvent.getFileId());
            return fileEvent;
            
        } catch (Exception e) {
            String errorMsg = "Failed to save file metadata: " + e.getMessage();
            System.err.println("[FileRepository] ERROR: " + errorMsg);
            throw new RuntimeException(errorMsg, e);
        }
    }
    
    /**
     * Find file metadata by file_id (PRIMARY KEY lookup - O(1))
     * 
     * Educational note: Optional<T> pattern
     * - Explicit "not found" handling (no null checks)
     * - Functional style: map(), orElse(), ifPresent()
     * - Compiler-enforced null safety
     * 
     * @param fileId Unique file identifier
     * @return Optional containing FileEvent if found, empty otherwise
     */
    public Optional<FileEvent> findById(String fileId) {
        try {
            ResultSet rs = session.execute(findByIdStatement.bind(fileId));
            Row row = rs.one();
            
            if (row == null) {
                System.out.println("[FileRepository] File not found: " + fileId);
                return Optional.empty();
            }
            
            FileEvent fileEvent = mapRowToFileEvent(row);
            System.out.println("[FileRepository] Found file: " + fileId);
            return Optional.of(fileEvent);
            
        } catch (Exception e) {
            System.err.println("[FileRepository] Error finding file by id: " + e.getMessage());
            return Optional.empty();
        }
    }
    
    /**
     * Find all files in a conversation (uses secondary index)
     * 
     * Educational note: Secondary index performance
     * - Slower than primary key lookup (requires index scan)
     * - Good for: Low-cardinality queries (few files per conversation)
     * - Bad for: High-cardinality queries (millions of files)
     * - Alternative: Use conversation_id as partition key (different table design)
     * 
     * @param conversationId Conversation identifier
     * @return List of FileEvents (empty if none found)
     */
    public List<FileEvent> findByConversationId(String conversationId) {
        try {
            ResultSet rs = session.execute(findByConversationStatement.bind(conversationId));
            List<FileEvent> files = new ArrayList<>();
            
            for (Row row : rs) {
                files.add(mapRowToFileEvent(row));
            }
            
            System.out.println("[FileRepository] Found " + files.size() + 
                    " files for conversation: " + conversationId);
            return files;
            
        } catch (Exception e) {
            System.err.println("[FileRepository] Error finding files by conversation: " + e.getMessage());
            return new ArrayList<>();
        }
    }
    
    /**
     * Map Cassandra row to FileEvent object
     * 
     * Educational note: Data mapping
     * - Convert database types to domain types
     * - Handle null values with defaults
     * - Cassandra Instant → Java Instant (timestamp conversion)
     * 
     * @param row Cassandra result row
     * @return FileEvent domain object
     */
    private FileEvent mapRowToFileEvent(Row row) {
        return new FileEvent(
                row.getString("file_id"),
                row.getString("conversation_id"),
                row.getString("uploader_id"),
                row.getString("filename"),
                row.getLong("size_bytes"),
                row.getString("mimetype"),
                row.getString("checksum"),
                row.getString("storage_path"),
                row.getInstant("uploaded_at")
        );
    }
    
    /**
     * Generate unique file_id using UUID v4
     * 
     * Educational note: UUID for distributed systems
     * - No coordination needed (unlike sequential IDs)
     * - 128-bit random identifier
     * - Collision probability: negligible (2^122 unique IDs)
     * 
     * @return Unique file identifier
     */
    public static String generateFileId() {
        return UUID.randomUUID().toString();
    }
}
