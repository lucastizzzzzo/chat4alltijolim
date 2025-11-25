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
        System.out.println("[FileDownloadHandler] URLs will be rewritten for external access");
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
            String path = exchange.getRequestURI().getPath();
            
            // Check if this is a content request (proxy) or download (presigned URL)
            boolean isProxyRequest = path.contains("/content");
            
            // Extract file_id from path
            String fileId = extractFileIdFromPath(path, isProxyRequest);
            
            if (fileId == null || fileId.isEmpty()) {
                sendErrorResponse(exchange, 400, "Missing file_id in URL path");
                return;
            }
            
            System.out.println("[FileDownloadHandler] Requesting " + 
                (isProxyRequest ? "proxied download" : "presigned URL") + " for file: " + fileId);
            
            // Query file metadata from Cassandra
            Optional<FileEvent> fileEventOpt = fileRepository.findById(fileId);
            
            if (!fileEventOpt.isPresent()) {
                System.out.println("[FileDownloadHandler] File not found: " + fileId);
                sendErrorResponse(exchange, 404, "File not found");
                return;
            }
            
            FileEvent fileEvent = fileEventOpt.get();
            
            // Handle proxy request (stream directly from MinIO)
            if (isProxyRequest) {
                proxyFileContent(exchange, fileEvent);
                return;
            }
            
            // Handle presigned URL request (original behavior)
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
     * - URL format: /v1/files/{file_id}/download or /v1/files/{file_id}/content
     * - Split by "/" and get 3rd segment (index 2)
     * - Robust parsing handles trailing slashes
     * 
     * Examples:
     * - /v1/files/abc123/download → "abc123"
     * - /v1/files/abc123/content → "abc123"
     * 
     * @param path URL path
     * @param isProxyRequest whether this is a /content request
     * @return file_id or null if invalid path
     */
    private String extractFileIdFromPath(String path, boolean isProxyRequest) {
        // Remove leading/trailing slashes and split
        String[] segments = path.replaceAll("^/|/$", "").split("/");
        
        System.out.println("[FileDownloadHandler] Path: " + path);
        System.out.println("[FileDownloadHandler] Segments: " + String.join(", ", segments));
        System.out.println("[FileDownloadHandler] isProxyRequest: " + isProxyRequest);
        
        // Expected: ["v1", "files", "{file_id}", "download" or "content"]
        String expectedSuffix = isProxyRequest ? "content" : "download";
        if (segments.length >= 4 && "v1".equals(segments[0]) && 
            "files".equals(segments[1]) && expectedSuffix.equals(segments[3])) {
            System.out.println("[FileDownloadHandler] Extracted file_id: " + segments[2]);
            return segments[2];
        }
        
        System.out.println("[FileDownloadHandler] Failed to extract file_id from path");
        return null;
    }
    
    /**
     * Proxy file content directly from MinIO
     * 
     * This method downloads the file from MinIO and streams it directly to the client.
     * Used as a workaround for presigned URL issues in development environments.
     * 
     * @param exchange HTTP exchange
     * @param fileEvent File metadata
     */
    private void proxyFileContent(HttpExchange exchange, FileEvent fileEvent) throws IOException {
        try {
            // Get file from MinIO
            java.io.InputStream stream = minioClient.getObject(
                io.minio.GetObjectArgs.builder()
                    .bucket(bucketName)
                    .object(fileEvent.getStoragePath())
                    .build()
            );
            
            // Set response headers
            exchange.getResponseHeaders().set("Content-Type", fileEvent.getMimetype());
            exchange.getResponseHeaders().set("Content-Disposition", 
                "attachment; filename=\"" + fileEvent.getFilename() + "\"");
            exchange.getResponseHeaders().set("Content-Length", String.valueOf(fileEvent.getSizeBytes()));
            
            // Stream file to client
            exchange.sendResponseHeaders(200, fileEvent.getSizeBytes());
            try (java.io.OutputStream os = exchange.getResponseBody()) {
                byte[] buffer = new byte[8192];
                int bytesRead;
                while ((bytesRead = stream.read(buffer)) != -1) {
                    os.write(buffer, 0, bytesRead);
                }
            }
            stream.close();
            
            System.out.println("[FileDownloadHandler] Proxied file: " + fileEvent.getFilename());
            
        } catch (Exception e) {
            System.err.println("[FileDownloadHandler] Error proxying file: " + e.getMessage());
            sendErrorResponse(exchange, 500, "Failed to download file from storage");
        }
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
        
        // Don't rewrite hostname - let clients handle it
        // URL contains internal hostname (minio:9000)
        // External clients should replace with localhost:9000
        
        System.out.println("[FileDownloadHandler] Presigned URL generated for: " + storagePath);
        System.out.println("[FileDownloadHandler] URL (truncated): " + url.substring(0, Math.min(100, url.length())) + "...");
        
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
