package chat4all.worker.processing;

import chat4all.shared.MessageEvent;
import chat4all.worker.cassandra.CassandraMessageStore;
import chat4all.worker.cassandra.MessageEntity;
import chat4all.worker.routing.ConnectorRouter;

import java.time.Instant;

/**
 * MessageProcessor - Lógica de negócio para processar mensagens do Kafka
 * 
 * PROPÓSITO EDUCACIONAL: Business Logic + Store-and-Forward Pattern
 * ==================
 * 
 * STORE-AND-FORWARD PATTERN:
 * - Store: Persistir mensagem no banco (SENT)
 * - Forward: Simular entrega ao destinatário
 * - Update: Marcar como DELIVERED
 * 
 * FLUXO DETALHADO:
 * ```
 * Kafka → MessageProcessor → [1] Deduplicação
 *                              ↓ (se nova)
 *                           [2] Save (status=SENT)
 *                              ↓
 *                           [3] Simulate Delivery (sleep)
 *                              ↓
 *                           [4] Update (status=DELIVERED)
 * ```
 * 
 * POR QUE ESSE PADRÃO?
 * - Garante durabilidade: mensagem não se perde se worker crashar
 * - Permite retry: se delivery falhar, retentar depois
 * - Audit trail: saber quando mensagem foi recebida vs entregue
 * 
 * STATUS TRANSITIONS:
 * - SENT: Mensagem persistida, aguardando entrega
 * - DELIVERED: Entrega confirmada (destinatário recebeu)
 * - READ: (futuro) Destinatário leu a mensagem
 * 
 * IDEMPOTÊNCIA:
 * - Processar mesma mensagem 2x não duplica no banco
 * - message_id único previne duplicação
 * 
 * @author Chat4All Educational Project
 */
public class MessageProcessor {
    
    private final CassandraMessageStore messageStore;
    private final ConnectorRouter connectorRouter;
    
    /**
     * Cria MessageProcessor
     * 
     * @param messageStore Store para persistir mensagens
     * @param connectorRouter Router para conectores externos (WhatsApp, Instagram, etc.)
     */
    public MessageProcessor(CassandraMessageStore messageStore, ConnectorRouter connectorRouter) {
        this.messageStore = messageStore;
        this.connectorRouter = connectorRouter;
    }
    
    /**
     * Processa mensagem consumida do Kafka
     * 
     * FLUXO COMPLETO:
     * 
     * [1] DEDUPLICAÇÃO:
     *     - Verifica se message_id já existe no banco
     *     - Se existe: SKIP (mensagem duplicada do Kafka)
     *     - Se não existe: continuar processamento
     * 
     * [2] PERSIST (status=SENT):
     *     - Converter MessageEvent → MessageEntity
     *     - INSERT no Cassandra
     *     - Se falhar: throw exception (Kafka não commitará offset)
     * 
     * [3] SIMULATE DELIVERY:
     *     - Sleep 100ms (simula latência de rede)
     *     - Em produção: chamar API externa, enviar push notification, etc.
     * 
     * [4] UPDATE STATUS (status=DELIVERED):
     *     - UPDATE no Cassandra
     *     - Marca mensagem como entregue
     * 
     * EDUCATIONAL NOTE: Error Handling
     * - Se [2] falhar: exception → Kafka retry
     * - Se [3] falhar: mensagem fica SENT → job async retentar depois
     * - Se [4] falhar: mensagem fica SENT → eventual consistency
     * 
     * KAFKA COMMIT:
     * - Só commitamos offset DEPOIS de process() retornar sem exception
     * - Se crashar no meio: Kafka reenvia (dedup protege duplicação)
     * 
     * @param event MessageEvent do Kafka
     * @return true se processou, false se duplicada/erro
     */
    public boolean process(MessageEvent event) {
        String messageId = event.getMessageId();
        String conversationId = event.getConversationId();
        
        System.out.println("\n▶ Processing message: " + messageId + 
                         " (conv: " + conversationId + ")");
        
        try {
            // [1] DEDUPLICAÇÃO - Verificar se mensagem já existe
            if (messageStore.messageExists(messageId)) {
                System.out.println("⊗ SKIP: Message " + messageId + " already processed (duplicate)");
                return false; // Duplicada, mas não é erro (retorna success para commitar offset)
            }
            
            // [2] PERSIST - Salvar mensagem com status SENT (Phase 2: includes file attachment)
            MessageEntity entity = new MessageEntity(
                event.getConversationId(),
                Instant.ofEpochMilli(event.getTimestamp()),
                event.getMessageId(),
                event.getSenderId(),
                event.getContent(),
                "SENT", // Status inicial
                event.getFileId(), // Phase 2: file attachment
                event.getFileMetadata() // Phase 2: file metadata
            );
            
            boolean saved = messageStore.saveMessage(entity);
            if (!saved) {
                throw new RuntimeException("Failed to save message to Cassandra");
            }
            
            System.out.println("✓ [1/2] Saved with status=SENT");
            
            // DEBUG: Check what we have
            System.out.println("[DEBUG] recipient_id from event: " + event.getRecipientId());
            System.out.println("[DEBUG] sender_id from event: " + event.getSenderId());
            
            // [3] ROUTE OR DELIVER - Check if should route to external connector
            // Use recipient_id if present, otherwise fall back to sender_id (for backward compatibility)
            String recipientId = event.getRecipientId();
            if (recipientId == null || recipientId.isEmpty()) {
                recipientId = event.getSenderId(); // Backward compatibility
                System.out.println("[DEBUG] Using fallback sender_id: " + recipientId);
            } else {
                System.out.println("[DEBUG] Using recipient_id: " + recipientId);
            }
            
            if (connectorRouter != null && connectorRouter.shouldRouteToConnector(recipientId)) {
                // Route to external connector (WhatsApp, Instagram, etc.)
                boolean routed = connectorRouter.routeToConnector(event);
                if (routed) {
                    System.out.println("✓ [2/2] Routed to external connector for recipient: " + recipientId);
                    System.out.println("✓ Processing complete for message: " + messageId + " (routed to connector)");
                    return true;
                } else {
                    System.err.println("⚠ Warning: Failed to route to connector, falling back to local delivery");
                    // Fall through to local delivery
                }
            }
            
            // [4] LOCAL DELIVERY - Simular latência de entrega local
            // Em produção real: chamar API do serviço de push, SMS, etc.
            simulateDelivery(messageId);
            
            System.out.println("✓ [2/2] Simulated delivery");
            
            // [5] UPDATE STATUS - Marcar como DELIVERED
            boolean updated = messageStore.updateMessageStatus(
                messageId, 
                entity.getConversationId(), 
                entity.getTimestamp(), 
                "DELIVERED"
            );
            if (!updated) {
                System.err.println("⚠ Warning: Failed to update status to DELIVERED for " + messageId);
                // Não falhar todo o processamento por isso (eventual consistency)
            } else {
                System.out.println("✓ Status updated to DELIVERED");
            }
            
            System.out.println("✓ Processing complete for message: " + messageId);
            return true;
            
        } catch (RuntimeException e) {
            System.err.println("✗ Error processing message " + messageId + ": " + e.getMessage());
            // Exception causa Kafka retry (não commita offset)
            throw e;
        } catch (Exception e) {
            System.err.println("✗ Error processing message " + messageId + ": " + e.getMessage());
            // Exception causa Kafka retry (não commita offset)
            throw new RuntimeException("Processing failed for message " + messageId, e);
        }
    }
    
    /**
     * Simula entrega da mensagem ao destinatário
     * 
     * EDUCATIONAL PURPOSE: Placeholder for Real Delivery
     * 
     * EM PRODUÇÃO REAL, ISSO SERIA:
     * - Enviar push notification (Firebase, APNs)
     * - Enviar SMS (Twilio, AWS SNS)
     * - Enviar email
     * - Chamar webhook externo
     * - Publicar evento em outro sistema
     * 
     * PARA ESTE PROJETO DIDÁTICO:
     * - Sleep 100ms (simula latência de rede)
     * - Permite demonstrar status transitions (SENT → DELIVERED)
     * 
     * POR QUE NÃO IMPLEMENTAR DELIVERY REAL?
     * - Foco educacional: arquitetura distribuída, não integrações
     * - Simplifica deployment (sem dependências externas)
     * - Estudante pode implementar depois como exercício
     * 
     * LATÊNCIA REALISTA:
     * - Push notification: 50-200ms
     * - SMS: 500-2000ms
     * - Email: 100-500ms
     * - Webhook HTTP: 100-300ms
     * 
     * @param messageId ID da mensagem sendo entregue
     */
    private void simulateDelivery(String messageId) {
        try {
            // Simula latência de entrega (100ms)
            Thread.sleep(100);
            
            // Em produção: log structured com trace_id
            System.out.println("  → Delivered message " + messageId + " (simulated)");
            
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            System.err.println("⚠ Delivery simulation interrupted for " + messageId);
        }
    }
}
