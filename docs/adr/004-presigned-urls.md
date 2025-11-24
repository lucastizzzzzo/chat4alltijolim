# ADR 004: Presigned URLs for Secure File Downloads

**Status**: Accepted  
**Date**: 2025-11-23  
**Decision Makers**: Chat4All Team  
**Technical Story**: Phase 5 - File Download Security

## Context

The Chat4All system stores files in MinIO object storage and needs to provide secure download access to authorized users. We need to solve:

1. **Authentication**: Only authorized users should download files
2. **Authorization**: Users should only access files from their conversations
3. **Performance**: Downloads should be fast and not bottleneck the API server
4. **Scalability**: System should handle thousands of concurrent downloads
5. **Security**: Prevent unauthorized access, hotlinking, and abuse
6. **Cost**: Minimize bandwidth costs through API server

We evaluated three approaches:
1. **Proxy Downloads** - API server streams files from MinIO to client
2. **Public URLs** - Make all files publicly accessible
3. **Presigned URLs** - Generate temporary URLs with embedded authentication

## Decision

We have decided to use **Presigned URLs** (also called signed URLs or temporary URLs) for file downloads.

## Rationale

### Why NOT Proxy Downloads?

**Performance Bottleneck:**
```
┌────────┐      ┌─────────┐      ┌────────┐
│ Client │─────▶│   API   │─────▶│ MinIO  │
│        │◀─────│ (proxy) │◀─────│        │
└────────┘      └─────────┘      └────────┘
   100Mbps         1Gbps           10Gbps

Problem: API becomes bandwidth bottleneck
- API must stream every byte through its network
- Cannot serve more concurrent downloads than API bandwidth allows
- Doubles network traffic (MinIO→API→Client vs MinIO→Client)
```

**Scalability Issues:**
- ❌ API server memory used for buffering file streams
- ❌ Thread pool exhaustion under heavy download load
- ❌ Cannot leverage CDN (files must go through API)
- ❌ Difficult to implement resume/range requests

**Cost Implications:**
```
1000 users × 10 downloads/day × 5MB/file = 50GB/day
Through API: 50GB egress from API server
Direct: 50GB egress from MinIO only
Savings: 50% reduction in API server bandwidth costs
```

**Operational Complexity:**
- Must handle connection timeouts and retries
- Complex error handling for interrupted downloads
- Need to implement chunked transfer encoding
- Cannot use standard HTTP caching headers effectively

### Why NOT Public URLs?

**Security Vulnerabilities:**
- ❌ Anyone with URL can access file (no authentication)
- ❌ URLs can be shared publicly (privacy violation)
- ❌ No way to revoke access once URL is shared
- ❌ Cannot audit who accessed files

**Abuse Scenarios:**
```
1. User A shares file in private conversation
2. User A shares public URL on social media
3. File gets 10,000 downloads from unauthorized users
4. Storage costs increase, privacy violated
```

**Compliance Issues:**
- ❌ GDPR requires access control for personal data
- ❌ Cannot delete files (URLs might be cached)
- ❌ No audit trail of file access
- ❌ Cannot implement rate limiting per user

### Why Presigned URLs?

**Security Benefits:**
- ✅ URLs contain cryptographic signature (HMAC)
- ✅ Tampering detection (signature invalidates if URL modified)
- ✅ Time-limited access (expires after 1 hour)
- ✅ Cannot share permanent access
- ✅ Automatic revocation after expiry

**Performance Advantages:**
- ✅ Direct client-to-storage connection (no proxy)
- ✅ Full network speed (10Gbps from MinIO)
- ✅ CDN-compatible (can cache presigned URLs)
- ✅ Parallel downloads and range requests supported

**Scalability:**
- ✅ API only generates URL (fast, < 1ms)
- ✅ No streaming overhead on API server
- ✅ MinIO handles all download traffic
- ✅ Can serve millions of concurrent downloads

**Cost Efficiency:**
- ✅ Reduces API server bandwidth by 50%
- ✅ Lower API server resource requirements
- ✅ Can use CDN for frequently accessed files
- ✅ Pay only for MinIO bandwidth (cheaper)

## Implementation Details

### Architecture:

```
┌─────────────┐  1. Request download    ┌──────────────┐
│   Client    │────────────────────────▶│ API Service  │
│             │  GET /v1/files/{id}     │              │
│             │  Authorization: JWT     │              │
│             │                         │ 2. Validate  │
│             │                         │    JWT       │
│             │                         │              │
│             │◀────────────────────────│ 3. Check     │
│             │  {download_url: ...}    │    ownership │
│             │                         │              │
│             │                         │ 4. Generate  │
│             │                         │    presigned │
│             │                         │    URL       │
└─────────────┘                         └──────┬───────┘
       │                                       │
       │ 5. HTTP GET with                     │
       │    presigned URL                     │
       │                                       ▼
       │                              ┌──────────────┐
       │                              │  Cassandra   │
       │                              │  (metadata)  │
       │                              └──────────────┘
       │
       ▼
┌─────────────┐
│    MinIO    │  6. Validates signature
│   Storage   │  7. Returns file data
└─────────────┘
```

### Presigned URL Generation:

```java
// API Service code
String getPresignedDownloadUrl(String fileId, long expirySeconds) {
    // 1. Query metadata from Cassandra
    String storagePath = repository.getStoragePath(fileId);
    
    // 2. Generate presigned URL with MinIO SDK
    GetPresignedObjectUrlArgs args = GetPresignedObjectUrlArgs.builder()
        .bucket("chat4all-files")
        .object(storagePath)
        .expiry((int) expirySeconds)  // 3600 seconds = 1 hour
        .method(Method.GET)
        .build();
    
    // 3. MinIO generates URL with HMAC signature
    String presignedUrl = minioClient.getPresignedObjectUrl(args);
    
    // Example URL format:
    // http://minio:9000/chat4all-files/conv123/file456.jpg?
    //   X-Amz-Algorithm=AWS4-HMAC-SHA256&
    //   X-Amz-Credential=minioadmin/20231123/us-east-1/s3/aws4_request&
    //   X-Amz-Date=20231123T120000Z&
    //   X-Amz-Expires=3600&
    //   X-Amz-SignedHeaders=host&
    //   X-Amz-Signature=abc123def456...
    
    return presignedUrl;
}
```

### Security Properties:

**Signature Validation:**
```
HMAC-SHA256(
    AccessKey + SecretKey + 
    Timestamp + Expiry + 
    Bucket + Object + 
    HTTP Method
) = Signature

If any parameter changes → Signature becomes invalid
MinIO rejects request with 403 Forbidden
```

**Time-based Expiry:**
```
URL generated at: 2023-11-23 12:00:00
Expiry: 3600 seconds (1 hour)
Valid until: 2023-11-23 13:00:00

After 13:00:00:
- MinIO checks timestamp in URL
- Compares with current time
- Returns 403 Forbidden if expired
```

**Tampering Protection:**
```
Original URL:  /file.jpg?X-Amz-Expires=3600&X-Amz-Signature=abc123
Tampered URL:  /file.jpg?X-Amz-Expires=7200&X-Amz-Signature=abc123
                                     ^^^^
                                Changed expiry

Result: Signature no longer matches, MinIO returns 403
```

### Authorization Flow:

```java
// API Service endpoint
@POST("/v1/files/{file_id}/download")
public Response getDownloadUrl(String fileId, String jwtToken) {
    // 1. Validate JWT
    Claims claims = jwtAuthenticator.validateToken(jwtToken);
    String userId = claims.getSubject();
    
    // 2. Check file ownership
    FileMetadata file = repository.getFileMetadata(fileId);
    if (!file.hasAccess(userId)) {
        return Response.forbidden("Access denied");
    }
    
    // 3. Generate presigned URL (valid for 1 hour)
    String downloadUrl = minioClient.getPresignedUrl(
        file.getStoragePath(),
        3600  // seconds
    );
    
    // 4. Return URL to client
    return Response.ok(Map.of(
        "download_url", downloadUrl,
        "expires_in", 3600,
        "filename", file.getFilename()
    ));
}
```

### Expiry Strategy:

| Use Case | Expiry Time | Rationale |
|----------|-------------|-----------|
| **Chat Files** | 1 hour | Balance between convenience and security |
| **Public Share** | 24 hours | Long enough for sharing, short enough for revocation |
| **Temporary Export** | 15 minutes | Quick download, minimal attack window |
| **Backup Download** | 7 days | Long-running backup jobs |

**Current Implementation**: 1 hour (3600 seconds)

## Consequences

### Positive:

✅ **Security**: Cryptographic signatures prevent unauthorized access  
✅ **Performance**: Direct downloads at full network speed  
✅ **Scalability**: API server not involved in data transfer  
✅ **Cost**: 50% reduction in API server bandwidth costs  
✅ **Simplicity**: Standard S3-compatible feature, well-tested  
✅ **CDN-Ready**: Can cache presigned URLs (within expiry window)  
✅ **Audit Trail**: Can log URL generation (who accessed what file)  

### Negative:

⚠️ **URL Sharing**: Users can share URLs within expiry window  
⚠️ **Expiry Management**: Need to handle expired URL errors gracefully  
⚠️ **Clock Sync**: Requires synchronized clocks (NTP)  
⚠️ **Network Topology**: URLs may not work across network boundaries  

### Mitigations:

**For URL Sharing:**
- Keep expiry window short (1 hour)
- Log URL generation with user_id for audit
- Implement rate limiting on URL generation
- Consider adding IP binding for high-security files

**For Expiry Management:**
```javascript
// Client-side code
async function downloadFile(fileId) {
    let url = cachedUrls.get(fileId);
    
    // Check if URL is expired or missing
    if (!url || isExpired(url)) {
        // Generate new presigned URL
        url = await api.getDownloadUrl(fileId);
        cachedUrls.set(fileId, url);
    }
    
    // Download from presigned URL
    return fetch(url);
}
```

**For Clock Sync:**
- Use NTP on all servers
- Monitor clock drift with health checks
- Set conservative expiry margins

**For Network Topology:**
```
Development: MinIO on localhost:9000
  → Presigned URLs use http://localhost:9000
  → Works for local testing

Production: MinIO behind CDN
  → Presigned URLs use https://cdn.example.com
  → Configure MinIO with public endpoint
  → URLs work globally
```

## Alternatives Considered

### 1. Session-based Downloads (Rejected)
```java
// Store file access tokens in session
session.put("file_" + fileId, "allowed");
return "/api/download/" + fileId;  // Proxied through API
```
**Pros**: Simple session management  
**Cons**: Still requires API proxy, session state complexity  
**Reason**: Doesn't solve performance bottleneck

### 2. Signed Cookies (Rejected)
```http
Set-Cookie: minio-access=signature; Domain=minio.example.com
```
**Pros**: No URL modification needed  
**Cons**: Cookie management complexity, CORS issues  
**Reason**: Presigned URLs are standard S3 feature

### 3. OAuth Tokens (Rejected)
```http
GET /file.jpg
Authorization: Bearer oauth-token
```
**Pros**: Standard OAuth flow  
**Cons**: MinIO doesn't support OAuth natively, requires custom auth layer  
**Reason**: Adds complexity without benefits over presigned URLs

### 4. API Gateway with Token Translation (Rejected)
```
Client → API Gateway (validates JWT) → MinIO
```
**Pros**: Centralized auth  
**Cons**: Gateway becomes bottleneck, defeats purpose  
**Reason**: Back to proxy download problem

## Security Considerations

### Attack Scenarios and Mitigations:

**1. URL Replay Attack:**
- **Attack**: Attacker copies presigned URL and uses repeatedly
- **Mitigation**: URLs expire after 1 hour, automatic revocation
- **Impact**: Low (attacker has limited time window)

**2. URL Sharing:**
- **Attack**: User shares presigned URL with unauthorized party
- **Mitigation**: Short expiry, audit logging, user education
- **Impact**: Medium (within expiry window only)

**3. Clock Skew:**
- **Attack**: Attacker manipulates system clock to extend URL validity
- **Mitigation**: MinIO uses its own clock, NTP synchronization
- **Impact**: Low (would require compromising MinIO server)

**4. Signature Brute Force:**
- **Attack**: Attacker tries to guess valid signatures
- **Mitigation**: HMAC-SHA256 with 256-bit keys (2^256 combinations)
- **Impact**: None (cryptographically infeasible)

### Best Practices:

✅ **Always validate JWT before generating presigned URL**  
✅ **Log all presigned URL generations for audit**  
✅ **Use HTTPS in production (TLS encryption)**  
✅ **Set appropriate expiry based on use case**  
✅ **Implement rate limiting on URL generation**  
✅ **Monitor for suspicious download patterns**  
✅ **Use Content-Disposition header to prevent XSS**  

## Production Considerations

### CDN Integration:
```
Client → CloudFlare CDN → MinIO
              ↑
         Cache presigned URLs
         (respect X-Amz-Expires)
```

### Monitoring:
- Track presigned URL generation rate
- Alert on expired URL errors (may indicate clock issues)
- Monitor download bandwidth per user
- Alert on unusual download patterns

### Disaster Recovery:
- Presigned URLs use MinIO access keys
- If keys are rotated, all active URLs invalidate
- Plan key rotation during low-traffic periods
- Communicate with users before planned key rotation

## References

- [AWS S3 Presigned URLs Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/PresignedUrlUploadObject.html)
- [MinIO Presigned URL API](https://min.io/docs/minio/linux/developers/java/API.html#getpresignedobjecturl)
- [HMAC-SHA256 Security](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.198-1.pdf)
- [URL Signing Best Practices](https://cloud.google.com/cdn/docs/using-signed-urls)

## Related ADRs

- ADR 002: Object Storage Choice (presigned URLs are MinIO feature)
- ADR 001: No Frameworks (implementation in vanilla Java)

## Educational Value

This decision demonstrates:
- **Security Engineering**: Using cryptographic signatures for authorization
- **Scalability Patterns**: Offloading bandwidth from application servers
- **System Design**: Separating control plane (API) from data plane (storage)
- **Industry Standards**: S3 presigned URLs are used by AWS, GCP, Azure
- **Trade-offs**: Balancing security, performance, and convenience
- **Cloud Architecture**: How modern applications handle file downloads
