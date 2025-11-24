# ADR 002: Object Storage for File Management

**Status**: Accepted  
**Date**: 2025-11-23  
**Decision Makers**: Chat4All Team  
**Technical Story**: Phase 5-6 - File Storage Implementation

## Context

The Chat4All system requires support for file sharing with the following requirements:
- Store files up to 2GB in size
- Support images, documents, videos, and other media types
- Enable file downloads via temporary URLs
- Scale to handle thousands of concurrent users
- Maintain data durability and availability

We evaluated three approaches for file storage:
1. **Database BLOBs** (storing files directly in Cassandra)
2. **Local Filesystem** (storing files on API server disk)
3. **Object Storage** (MinIO/S3-compatible service)

## Decision

We have decided to use **MinIO Object Storage** (S3-compatible) for file management.

## Rationale

### Why NOT Database BLOBs (Cassandra)?

**Performance Issues:**
- Large BLOBs (>1MB) degrade Cassandra read/write performance
- BLOBs increase compaction overhead and disk usage
- Range queries become expensive with large objects
- Memory pressure from loading entire BLOBs into memory

**Operational Complexity:**
- Backup/restore becomes slow with large BLOBs
- Replication bandwidth increases significantly
- Cannot leverage CDN for file delivery
- Difficult to implement streaming for large files

**Cost:**
- SSD storage for Cassandra is expensive
- Need more nodes to handle storage requirements
- Cannot use cheaper object storage tiers

**Example from Production:**
```
1000 users × 100 files × 5MB average = 500GB
Cassandra SSD: $0.10/GB/month = $50/month
Object Storage: $0.02/GB/month = $10/month
Savings: 80% reduction in storage costs
```

### Why NOT Local Filesystem?

**Scalability Issues:**
- Cannot scale horizontally (each server has different files)
- Requires sticky sessions or file replication
- Single point of failure per server
- Complex backup/disaster recovery

**Operational Challenges:**
- Manual capacity planning for each server
- Difficult to balance storage across servers
- No built-in redundancy or replication
- Complex cleanup and lifecycle management

### Why Object Storage (MinIO)?

**Scalability:**
- ✅ Horizontal scaling by adding storage nodes
- ✅ Handles petabytes of data seamlessly
- ✅ Automatic load balancing across nodes
- ✅ Built-in erasure coding for redundancy

**Performance:**
- ✅ Optimized for large object storage
- ✅ Parallel multipart uploads for large files
- ✅ CDN-friendly with presigned URLs
- ✅ Streaming support for videos

**Cost Efficiency:**
- ✅ Use commodity hardware or cheap object storage
- ✅ Automatic data tiering (hot/cold storage)
- ✅ Pay only for storage used
- ✅ No need for expensive SSDs

**Operational Benefits:**
- ✅ S3-compatible API (industry standard)
- ✅ Built-in versioning and lifecycle policies
- ✅ Easy backup/restore with bucket replication
- ✅ Web console for debugging and monitoring
- ✅ Access control with bucket policies

**MinIO Specific Advantages:**
- ✅ Self-hosted (no vendor lock-in)
- ✅ Kubernetes-native deployment
- ✅ High performance (C++ core)
- ✅ Compatible with AWS S3 SDKs
- ✅ Free and open source

## Implementation Details

### Architecture:

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│  API Client │─────▶│  API Service │─────▶│    MinIO    │
│             │◀─────│              │◀─────│   Storage   │
└─────────────┘      └──────────────┘      └─────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │  Cassandra   │
                     │  (Metadata)  │
                     └──────────────┘
```

### Data Flow:

**Upload:**
1. Client → API: POST /v1/files (multipart form)
2. API validates file size and type
3. API generates unique file_id (UUID)
4. API uploads to MinIO bucket: `chat4all-files/{conversation_id}/{file_id}.ext`
5. API stores metadata in Cassandra: file_id, checksum, size, storage_path
6. API returns file_id to client

**Download:**
1. Client → API: GET /v1/files/{file_id}/download
2. API queries Cassandra for storage_path
3. API generates presigned URL (1 hour expiry)
4. Client downloads directly from MinIO using presigned URL

### Security:

- **Presigned URLs**: Temporary access tokens, auto-expire
- **Bucket Policies**: Deny public access, API-only access
- **TLS/SSL**: Encrypted data in transit
- **Checksums**: SHA-256 validation for integrity
- **Authentication**: JWT required for file operations

## Consequences

### Positive:

✅ **Performance**: Offloads large file I/O from API servers and database  
✅ **Scalability**: Can handle millions of files and petabytes of data  
✅ **Cost**: 80% cheaper than database storage  
✅ **Flexibility**: Easy to add CDN, implement caching, lifecycle policies  
✅ **Standards**: S3-compatible API means easy migration to AWS/GCP/Azure  
✅ **Tooling**: Rich ecosystem of S3 tools and libraries  

### Negative:

⚠️ **Complexity**: Adds another service to deploy and monitor  
⚠️ **Consistency**: Files and metadata in separate systems (eventual consistency)  
⚠️ **Network**: Additional network hop for file operations  
⚠️ **Dependencies**: System depends on MinIO availability  

### Mitigations:

**For Complexity:**
- Use Docker Compose for local development
- Use Kubernetes Helm charts for production
- MinIO has good monitoring and health check endpoints

**For Consistency:**
- Use transactions in Cassandra to ensure metadata consistency
- Implement cleanup jobs to remove orphaned files
- Add retry logic for MinIO operations

**For Network Latency:**
- Deploy MinIO close to API servers (same datacenter)
- Use presigned URLs for direct client-to-MinIO downloads
- Implement caching for frequently accessed files

**For Dependencies:**
- Monitor MinIO health in API service
- Implement circuit breakers for MinIO calls
- Return graceful errors when MinIO is unavailable
- Set up MinIO in HA mode with multiple replicas

## Alternatives Considered

### 1. AWS S3 (Rejected)
- **Pros**: Fully managed, proven at scale, global CDN
- **Cons**: Vendor lock-in, egress costs, requires internet access
- **Reason**: Educational project, want self-hosted solution

### 2. Ceph (Rejected)
- **Pros**: S3-compatible, proven in production, highly scalable
- **Cons**: Complex setup, requires multiple nodes, steep learning curve
- **Reason**: Too complex for educational project scope

### 3. Hybrid Approach: Small files in DB, large files in Object Storage (Rejected)
- **Pros**: Optimizes for both small and large files
- **Cons**: Complex implementation, two code paths, difficult to maintain
- **Reason**: Added complexity not justified for educational scope

## References

- [MinIO Official Documentation](https://min.io/docs/)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/best-practices.html)
- [Cassandra BLOB Performance](https://cassandra.apache.org/doc/latest/cassandra/cql/types.html#blob)
- [Object Storage vs Block Storage](https://www.ibm.com/cloud/learn/object-storage)

## Related ADRs

- ADR 001: No Frameworks (established vanilla Java approach)
- ADR 004: Presigned URLs (security model for downloads)

## Educational Value

This decision demonstrates:
- **Separation of Concerns**: Different data types need different storage solutions
- **CAP Theorem**: Trading consistency for availability/partition tolerance
- **Cost Optimization**: Choosing right tool for the job saves money
- **Industry Standards**: S3 API is the de facto standard for object storage
- **System Design**: How to architect multi-tier storage systems
