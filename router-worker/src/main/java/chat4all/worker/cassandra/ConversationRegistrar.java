package chat4all.worker.cassandra;

import com.datastax.oss.driver.api.core.CqlSession;
import com.datastax.oss.driver.api.core.cql.PreparedStatement;

import java.time.Instant;
import java.util.Arrays;
import java.util.List;

/**
 * ConversationRegistrar - Registra automaticamente conversas para destinatários
 * 
 * PROPÓSITO: Quando uma mensagem é enviada, garantir que o destinatário
 * veja a conversa na sua lista (tabela conversations_by_user)
 * 
 * CENÁRIO:
 * - UserA cria conversa com instagram:@joaolucas
 * - Instagram:@joaolucas é resolvido para lucas2 (user_id)
 * - Esta classe registra a conversa para lucas2
 * - Lucas2 agora vê a conversa na opção 3 do CLI!
 */
public class ConversationRegistrar {
    
    private final CqlSession session;
    private final PreparedStatement checkConversationExists;
    private final PreparedStatement insertConversationByUser;
    
    public ConversationRegistrar(CqlSession session) {
        this.session = session;
        
        // Verificar se usuário já tem a conversa registrada
        this.checkConversationExists = session.prepare(
            "SELECT conversation_id FROM chat4all.conversations_by_user " +
            "WHERE user_id = ? AND conversation_id = ? LIMIT 1"
        );
        
        // Inserir conversa para usuário
        this.insertConversationByUser = session.prepare(
            "INSERT INTO chat4all.conversations_by_user " +
            "(user_id, conversation_id, type, participant_ids, created_at) " +
            "VALUES (?, ?, ?, ?, ?)"
        );
        
        System.out.println("✓ ConversationRegistrar initialized");
    }
    
    /**
     * Registra uma conversa para um usuário (se ainda não estiver registrada)
     * 
     * @param userId User ID que deve ver a conversa
     * @param conversationId ID da conversa
     * @param senderId ID de quem enviou a mensagem (outro participante)
     * @return true se registrou, false se já existia
     */
    public boolean registerConversationForUser(String userId, String conversationId, String senderId) {
        if (userId == null || conversationId == null) {
            return false;
        }
        
        try {
            // Verificar se já existe
            var rs = session.execute(checkConversationExists.bind(userId, conversationId));
            if (rs.one() != null) {
                // Já registrada
                return false;
            }
            
            // Registrar conversa para o usuário
            List<String> participants = Arrays.asList(userId, senderId);
            session.execute(insertConversationByUser.bind(
                userId,
                conversationId,
                "private",  // Tipo padrão
                participants,
                Instant.now()
            ));
            
            System.out.println("[ConversationRegistrar] ✓ Registered conversation " + conversationId + 
                             " for user " + userId);
            return true;
            
        } catch (Exception e) {
            System.err.println("[ConversationRegistrar] ✗ Failed to register conversation: " + e.getMessage());
            return false;
        }
    }
}
