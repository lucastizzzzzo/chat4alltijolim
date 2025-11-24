package chat4all.api.cassandra;

import com.datastax.oss.driver.api.core.CqlSession;
import com.datastax.oss.driver.api.core.cql.PreparedStatement;
import com.datastax.oss.driver.api.core.cql.ResultSet;
import com.datastax.oss.driver.api.core.cql.Row;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * CassandraMessageRepository - Repository para queries READ-ONLY de mensagens
 * 
 * PROPÓSITO EDUCACIONAL: Query-Driven Design + Pagination
 * ==================
 * 
 * CASSANDRA QUERY PATTERNS:
 * 
 * PRIMARY KEY = (conversation_id, timestamp)
 *   ↓
 * Partition Key: conversation_id → Distribui dados entre nós
 * Clustering Key: timestamp → Ordena dentro da partição
 * 
 * QUERY EFICIENTE:
 * ```sql
 * SELECT * FROM messages 
 * WHERE conversation_id = 'conv_123'  ← Partition key (obrigatório!)
 * ORDER BY timestamp ASC              ← Clustering key (grátis!)
 * LIMIT 50;                           ← Pagination
 * ```
 * 
 * QUERY INEFICIENTE (AVOID):
 * ```sql
 * SELECT * FROM messages 
 * WHERE sender_id = 'user_a';  ← Não é partition key! (full scan)
 * ```
 * 
 * PAGINATION STRATEGIES:
 * 
 * 1. LIMIT/OFFSET (implementado aqui para simplicidade):
 *    - Simples de entender
 *    - Problema: OFFSET alto = lento (Cassandra lê e descarta rows)
 *    - OK para Fase 1 educacional
 * 
 * 2. CURSOR-BASED (produção real):
 *    - Usa último timestamp como cursor
 *    - WHERE timestamp > ? LIMIT 50
 *    - Mais eficiente, sem OFFSET
 * 
 * @author Chat4All Educational Project
 */
public class CassandraMessageRepository {
    
    private final CqlSession session;
    private final PreparedStatement getMessagesStatement;
    
    /**
     * Cria repository com PreparedStatement
     * 
     * EDUCATIONAL NOTE: Pagination no Cassandra
     * 
     * Cassandra não tem OFFSET nativo!
     * Para simular offset, lemos LIMIT + OFFSET rows e descartamos as primeiras OFFSET.
     * 
     * Produção real: usar paging state (cursor automático do driver).
     * 
     * @param session CqlSession do CassandraConnection
     */
    public CassandraMessageRepository(CqlSession session) {
        this.session = session;
        
        // Query otimizada: usa partition key + clustering key (Phase 2: includes file fields)
        this.getMessagesStatement = session.prepare(
            "SELECT conversation_id, timestamp, message_id, sender_id, content, status, file_id, file_metadata " +
            "FROM messages " +
            "WHERE conversation_id = ? " +
            "ORDER BY timestamp ASC"
            // LIMIT aplicado dinamicamente no bind
        );
        
        System.out.println("✓ CassandraMessageRepository initialized");
    }
    
    /**
     * Busca mensagens de uma conversação com paginação
     * 
     * FLUXO:
     * 1. Query Cassandra: WHERE conversation_id = ? ORDER BY timestamp
     * 2. Fetch LIMIT + OFFSET rows (não há OFFSET nativo)
     * 3. Descartar primeiras OFFSET rows (simula pagination)
     * 4. Retornar até LIMIT rows
     * 
     * COMPLEXITY:
     * - Best case (offset=0): O(limit)
     * - Worst case (offset alto): O(limit + offset)
     * 
     * EDUCATIONAL NOTE: Cursor-based pagination seria O(limit) sempre:
     * ```java
     * WHERE conversation_id = ? AND timestamp > lastTimestamp LIMIT ?
     * ```
     * 
     * FORMATO DE RETORNO:
     * ```json
     * [
     *   {
     *     "message_id": "msg_123",
     *     "conversation_id": "conv_abc",
     *     "sender_id": "user_a",
     *     "content": "Hello!",
     *     "timestamp": 1700000000000,
     *     "status": "DELIVERED"
     *   }
     * ]
     * ```
     * 
     * @param conversationId ID da conversação (partition key)
     * @param limit Máximo de mensagens a retornar (default: 50, max: 100)
     * @param offset Quantas mensagens pular (default: 0)
     * @return Lista de mensagens como Maps (JSON-ready)
     */
    public List<Map<String, Object>> getMessages(String conversationId, int limit, int offset) {
        List<Map<String, Object>> messages = new ArrayList<>();
        
        // Validação de parâmetros
        if (conversationId == null || conversationId.trim().isEmpty()) {
            throw new IllegalArgumentException("conversation_id cannot be null or empty");
        }
        
        // Limites de segurança (evitar queries muito grandes)
        int safeLimit = Math.min(Math.max(limit, 1), 100); // Entre 1 e 100
        int safeOffset = Math.max(offset, 0); // >= 0
        
        try {
            // Fetch limit + offset rows (Cassandra não tem OFFSET nativo)
            int fetchSize = safeLimit + safeOffset;
            
            ResultSet rs = session.execute(getMessagesStatement.bind(conversationId));
            
            // Processar resultados
            int rowIndex = 0;
            for (Row row : rs) {
                // Simular OFFSET: pular primeiras N rows
                if (rowIndex < safeOffset) {
                    rowIndex++;
                    continue;
                }
                
                // Parar após LIMIT rows
                if (messages.size() >= safeLimit) {
                    break;
                }
                
                // Converter Row → Map (JSON-ready)
                Map<String, Object> message = new HashMap<>();
                message.put("message_id", row.getString("message_id"));
                message.put("conversation_id", row.getString("conversation_id"));
                message.put("sender_id", row.getString("sender_id"));
                message.put("content", row.getString("content"));
                message.put("status", row.getString("status"));
                
                // Timestamp: converter para epoch millis (compatível com frontend)
                Instant timestamp = row.getInstant("timestamp");
                if (timestamp != null) {
                    message.put("timestamp", timestamp.toEpochMilli());
                }
                
                // Phase 2: File attachment metadata
                String fileId = row.getString("file_id");
                if (fileId != null && !fileId.isEmpty()) {
                    message.put("file_id", fileId);
                    
                    // File metadata map
                    Map<String, String> fileMetadata = row.getMap("file_metadata", String.class, String.class);
                    if (fileMetadata != null && !fileMetadata.isEmpty()) {
                        message.put("file_metadata", fileMetadata);
                    }
                }
                
                messages.add(message);
                rowIndex++;
            }
            
            System.out.println("✓ Retrieved " + messages.size() + " messages for conversation " + conversationId +
                             " (limit=" + safeLimit + ", offset=" + safeOffset + ")");
            
            return messages;
            
        } catch (Exception e) {
            System.err.println("✗ Failed to retrieve messages for " + conversationId + ": " + e.getMessage());
            throw new RuntimeException("Failed to query messages", e);
        }
    }
    
    /**
     * Get message by ID (Phase 8: Status Lifecycle)
     * 
     * @param messageId Message ID to query
     * @return Map with message data, or null if not found
     */
    public Map<String, Object> getMessageById(String messageId) {
        String query = "SELECT conversation_id, timestamp, message_id, sender_id, content, status, " +
                      "delivered_at, read_at, file_id, file_metadata " +
                      "FROM chat4all.messages WHERE message_id = ? ALLOW FILTERING";
        
        PreparedStatement statement = session.prepare(query);
        ResultSet resultSet = session.execute(statement.bind(messageId));
        Row row = resultSet.one();
        
        if (row == null) {
            return null;
        }
        
        Map<String, Object> message = new HashMap<>();
        message.put("conversation_id", row.getString("conversation_id"));
        message.put("timestamp", row.getInstant("timestamp"));
        message.put("message_id", row.getString("message_id"));
        message.put("sender_id", row.getString("sender_id"));
        message.put("content", row.getString("content"));
        message.put("status", row.getString("status"));
        message.put("delivered_at", row.getInstant("delivered_at"));
        message.put("read_at", row.getInstant("read_at"));
        message.put("file_id", row.getString("file_id"));
        
        return message;
    }
    
    /**
     * Update message status to READ (Phase 8: Status Lifecycle)
     * 
     * EDUCATIONAL NOTE: Two-step process required for Cassandra
     * 1. Query by message_id (secondary index) to get full primary key
     * 2. Update using conversation_id + timestamp (partition + clustering key)
     * 
     * @param messageId Message ID to update
     * @param status New status ("READ")
     * @param readAt Read timestamp (epoch millis)
     */
    public void updateMessageStatus(String messageId, String status, long readAt) {
        // Step 1: Query to get primary key components
        String selectQuery = "SELECT conversation_id, timestamp FROM chat4all.messages " +
                           "WHERE message_id = ? ALLOW FILTERING";
        PreparedStatement selectStmt = session.prepare(selectQuery);
        ResultSet resultSet = session.execute(selectStmt.bind(messageId));
        Row row = resultSet.one();
        
        if (row == null) {
            System.err.println("✗ Message not found: " + messageId);
            return;
        }
        
        String conversationId = row.getString("conversation_id");
        Instant messageTimestamp = row.getInstant("timestamp");
        
        // Step 2: Update using full primary key
        String update = "UPDATE chat4all.messages " +
                       "SET status = ?, read_at = ? " +
                       "WHERE conversation_id = ? AND timestamp = ?";
        
        PreparedStatement updateStmt = session.prepare(update);
        Instant readAtInstant = Instant.ofEpochMilli(readAt);
        
        session.execute(updateStmt.bind(status, readAtInstant, conversationId, messageTimestamp));
        
        System.out.println("✓ Updated message status: " + messageId + " → " + status);
    }
    
    /**
     * Conta total de mensagens em uma conversação
     * 
     * EDUCATIONAL NOTE: COUNT Query Performance
     * 
     * Cassandra COUNT(*) é LENTO!
     * - Precisa escanear toda a partição
     * - Não há contador mágico pré-calculado
     * 
     * Produção real: manter counter separado em outra tabela
     * ```sql
     * CREATE TABLE conversation_stats (
     *   conversation_id TEXT PRIMARY KEY,
     *   message_count COUNTER
     * );
     * UPDATE conversation_stats SET message_count = message_count + 1 WHERE ...;
     * ```
     * 
     * Fase 1: Simplificação - não implementamos count (client pode inferir se retornou < limit)
     * 
     * @param conversationId ID da conversação
     * @return Total de mensagens (aproximado)
     */
    public long countMessages(String conversationId) {
        // Simplified: retorna -1 (não implementado para Fase 1)
        // Em produção: usar COUNTER table
        return -1;
    }
}
