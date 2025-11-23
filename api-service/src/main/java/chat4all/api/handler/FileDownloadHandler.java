package chat4all.api.handler;

import chat4all.api.repository.FileRepository;
import chat4all.api.storage.MinioClientFactory;
import chat4all.shared.FileEvent;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import io.minio.GetPresignedObjectUrlArgs;
import io.minio.MinioClient;
import io.minio.http.Method;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Optional;
import java.util.concurrent.TimeUnit;

/**
 * FileDownloadHandler - Generates presigned URLs for secure file downloads
 * 
 * Purpose: Provide temporary download URLs without exposing MinIO credentials
 * 
 * Educational notes:
 * - Presigned URLs: S3-style temporary access links
 * - Security: URLs expire after configurable time (default: 1 hour)
 * - No proxying: Client downloads directly from MinIO (scalable)
 * - Signed URLs: Cannot be modified without invalidating signature
 * 
 * Why presigned URLs?
 * - API doesn't proxy file content (saves bandwidth)
 * - Client downloads directly from object storage (faster)
 * - Temporary access (automatic expiration)
 * - No credentials exposed (signature in URL)
 * 
 * Endpoint: GET /v1/files/{file_id}/download
 * 
 * Request:
 *   GET /v1/files/550e8400-e29b-41d4-a716-446655440000/download
 *   Authorization: Bearer <jwt_token>
 * 
 * Response (200 OK):
 * {
 *   "file_id": "550e8400-e29b-41d4-a716-446655440000",
 *   "filename": "document.pdf",
 *   "size_bytes": 1048576,
 *   "mimetype": "application/pdf",
 *   "download_url": "http://localhost:9000/chat4all-files/conv-123/550e8400...?X-Amz-Algorithm=...",
 *   "expires_at": "2025-11-23T17:30:00Z"
 * }
 * 
 * Response (404 Not Found):
 * {
 *   "error": "File not found"
 * }
 * 
 * Security considerations:
 * - URL is valid only for expiration period
 * - Signature cannot be forged without secret key
 * - Each request generates new URL (stateless)
 * - Future: Verify user has permission to access file's conversation
 * 
 * @since Phase 3 (Presigned URLs)
 */
public class FileDownloadHandler implements HttpHandler {
    
    private final FileRepository fileRepository;
    private final MinioClient minioClient;
    private final String bucketName;
    
    // Configuration: URL expiration time (1 hour)
    private static final int EXPIRY_HOURS = 1;
    
    /**
     * Initialize handler with dependencies
     * 
     * Educational note: Dependency injection
     * - Constructor injection for testability
     * - FileRepository for metadata lookup
     * - MinioClient for presigned URL generation
     * 
     * @param fileRepository Repository for file metadata
     */
    public FileDownloadHandler(FileRepository fileRepository) {
        this.fileRepository = fileRepository;
        this.minioClient = MinioClientFactory.getInstance();
        this.bucketName = MinioClientFactory.getBucketName();
        System.out.println("[FileDownloadHandler] Initialized with expiry: " + EXPIRY_HOURS + " hours");
        System.out.println("[FileDownloadHandler] Note: Presigned URLs work within Docker network only");
    }
    
    @Override
    public void handle(HttpExchange exchange) throws IOException {
        System.out.println("[FileDownloadHandler] Received " + exchange.getRequestMethod() + 
                " request from " + exchange.getRemoteAddress());
        
        // Only accept GET requests
        if (!"GET".equals(exchange.getRequestMethod())) {
            sendErrorResponse(exchange, 405, "Method not allowed. Use GET.");
            return;
        }
        
        try {
            // Extract file_id from path: /v1/files/{file_id}/download
            String path = exchange.getRequestURI().getPath();
            String fileId = extractFileIdFromPath(path);
            
            if (fileId == null || fileId.isEmpty()) {
                sendErrorResponse(exchange, 400, "Missing file_id in URL path");
                return;
            }
            
            System.out.println("[FileDownloadHandler] Requesting download for file: " + fileId);
            
            // Query file metadata from Cassandra
            Optional<FileEvent> fileEventOpt = fileRepository.findById(fileId);
            
            if (!fileEventOpt.isPresent()) {
                System.out.println("[FileDownloadHandler] File not found: " + fileId);
                sendErrorResponse(exchange, 404, "File not found");
                return;
            }
            
            FileEvent fileEvent = fileEventOpt.get();
            
            // TODO Phase 4: Verify user has permission to access this file
            // - Extract user_id from JWT token
            // - Verify user is member of file's conversation_id
            // - Return 403 Forbidden if not authorized
            
            // Generate presigned URL (using external client for correct signature)
            String downloadUrl = generatePresignedUrl(fileEvent.getStoragePath());
            
            Instant expiresAt = Instant.now().plus(EXPIRY_HOURS, java.time.temporal.ChronoUnit.HOURS);
            
            System.out.println("[FileDownloadHandler] Generated presigned URL for: " + fileEvent.getFilename());
            System.out.println("[FileDownloadHandler] URL expires at: " + expiresAt);
            
            // Build JSON response
            String jsonResponse = buildSuccessResponse(fileEvent, downloadUrl, expiresAt);
            
            // Send response
            byte[] responseBytes = jsonResponse.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, responseBytes.length);
            OutputStream os = exchange.getResponseBody();
            os.write(responseBytes);
            os.close();
            
        } catch (Exception e) {
            System.err.println("[FileDownloadHandler] Error: " + e.getMessage());
            e.printStackTrace();
            sendErrorResponse(exchange, 500, "Failed to generate download URL: " + e.getMessage());
        }
    }
    
    /**
     * Extract file_id from URL path
     * 
     * Educational note: Path parsing
     * - URL format: /v1/files/{file_id}/download
     * - Split by "/" and get 4th segment (index 3)
     * - Robust parsing handles trailing slashes
     * 
     * Examples:
     * - /v1/files/abc123/download → "abc123"
     * - /v1/files/abc123/download/ → "abc123"
     * 
     * @param path URL path
     * @return file_id or null if invalid path
     */
    private String extractFileIdFromPath(String path) {
        // Remove leading/trailing slashes and split
        String[] segments = path.replaceAll("^/|/$", "").split("/");
        
        // Expected: ["v1", "files", "{file_id}", "download"]
        if (segments.length >= 4 && "v1".equals(segments[0]) && 
            "files".equals(segments[1]) && "download".equals(segments[3])) {
            return segments[2];
        }
        
        return null;
    }
    
    /**
     * Generate presigned URL for file download
     * 
     * Educational note: Presigned URL mechanism
     * - MinIO generates URL with embedded signature
     * - Signature includes: bucket, object, expiry, secret key
     * - URL is valid only for specified duration
     * - Cannot be tampered (signature verification fails)
     * 
     * Flow:
     * 1. MinIO SDK calculates signature using secret key
     * 2. Signature embedded in URL query params (X-Amz-Signature)
     * 3. Client uses URL directly (no additional auth needed)
     * 4. MinIO validates signature on each request
     * 5. After expiry, URL returns 403 Forbidden
     * 
     * Alternative approaches:
     * - Proxy through API (inefficient, high bandwidth)
     * - Long-lived URLs (security risk)
     * - Session-based download tokens (stateful, complex)
     * 
     * @param storagePath Object path in MinIO (e.g., "conv-123/file-id.pdf")
     * @return Presigned URL valid for EXPIRY_HOURS
     * @throws Exception if URL generation fails
     */
    private String generatePresignedUrl(String storagePath) throws Exception {
        // Generate presigned GET URL with expiration
        String url = minioClient.getPresignedObjectUrl(
                GetPresignedObjectUrlArgs.builder()
                        .method(Method.GET)
                        .bucket(bucketName)
                        .object(storagePath)
                        .expiry(EXPIRY_HOURS, TimeUnit.HOURS)
                        .build()
        );
        
        System.out.println("[FileDownloadHandler] Presigned URL generated for: " + storagePath);
        System.out.println("[FileDownloadHandler] URL (truncated): " + url.substring(0, Math.min(100, url.length())) + "...");
        
        // Educational note: Known limitation
        // - URL contains internal hostname (minio:9000)
        // - Works within Docker network but not from external clients
        // - Production solution: Configure MinIO with external domain name
        // - Alternative: Implement download proxy in API (less scalable)
        
        return url;
    }
    
    /**
     * Build JSON success response
     * 
     * Educational note: Response format
     * - Include file metadata for client display
     * - Provide download_url for direct access
     * - Show expires_at for client-side validation
     * 
     * Client usage:
     * 1. GET /v1/files/{id}/download (with JWT)
     * 2. Parse download_url from response
     * 3. Use download_url in <a> tag or fetch()
     * 4. File downloads directly from MinIO (no API proxy)
     * 
     * @param fileEvent File metadata
     * @param downloadUrl Presigned URL
     * @param expiresAt Expiration timestamp
     * @return JSON string
     */
    private String buildSuccessResponse(FileEvent fileEvent, String downloadUrl, Instant expiresAt) {
        // Escape quotes in filename (security: prevent JSON injection)
        String safeFilename = fileEvent.getFilename().replace("\"", "\\\"");
        String safeMimetype = fileEvent.getMimetype().replace("\"", "\\\"");
        
        return "{\n" +
                "  \"file_id\": \"" + fileEvent.getFileId() + "\",\n" +
                "  \"filename\": \"" + safeFilename + "\",\n" +
                "  \"size_bytes\": " + fileEvent.getSizeBytes() + ",\n" +
                "  \"mimetype\": \"" + safeMimetype + "\",\n" +
                "  \"checksum\": \"" + fileEvent.getChecksum() + "\",\n" +
                "  \"download_url\": \"" + downloadUrl + "\",\n" +
                "  \"expires_at\": \"" + expiresAt.toString() + "\"\n" +
                "}";
    }
    
    /**
     * Send error response
     * 
     * @param exchange HTTP exchange
     * @param statusCode HTTP status code
     * @param message Error message
     * @throws IOException if write fails
     */
    private void sendErrorResponse(HttpExchange exchange, int statusCode, String message) 
            throws IOException {
        String json = "{\"error\": \"" + message.replace("\"", "\\\"") + "\"}";
        byte[] bytes = json.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(statusCode, bytes.length);
        OutputStream os = exchange.getResponseBody();
        os.write(bytes);
        os.close();
    }
    
    /**
     * Get environment variable with default fallback
     */
}
