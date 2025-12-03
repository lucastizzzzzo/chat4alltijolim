package chat4all.worker.resolver;

import com.datastax.oss.driver.api.core.CqlSession;
import com.datastax.oss.driver.api.core.cql.PreparedStatement;
import com.datastax.oss.driver.api.core.cql.ResultSet;
import com.datastax.oss.driver.api.core.cql.Row;

import java.util.Optional;

/**
 * IdentityResolver - Resolve identidades externas para user_id interno
 * 
 * PROPÓSITO: Quando router-worker recebe recipientId como "instagram:@joaolucas",
 * precisa descobrir qual user_id real deve receber a notificação.
 * 
 * EXEMPLO:
 * - Usuário envia mensagem para "instagram:@joaolucas"
 * - IdentityResolver busca em user_identities
 * - Encontra que @joaolucas está vinculado ao user_id "18bc6e00-aa13..."
 * - Notificação vai para "18bc6e00-aa13..." (lucas2)
 * - Lucas2 recebe notificação no CLI!
 */
public class IdentityResolver {
    
    private final CqlSession session;
    private final PreparedStatement getUserByIdentity;
    
    public IdentityResolver(CqlSession session) {
        this.session = session;
        
        // Buscar user_id por identidade externa (WhatsApp/Instagram)
        this.getUserByIdentity = session.prepare(
            "SELECT user_id FROM chat4all.user_identities WHERE identity_value = ? ALLOW FILTERING"
        );
        
        System.out.println("✓ IdentityResolver (router-worker) initialized");
    }
    
    /**
     * Resolve recipient identifier para user_id real
     * 
     * CASOS:
     * 1. instagram:@usuario → busca em user_identities → retorna user_id
     * 2. whatsapp:+55... → busca em user_identities → retorna user_id
     * 3. UUID direto → retorna como está (já é user_id)
     * 4. Não encontrado → retorna null (identidade externa não vinculada)
     * 
     * @param recipientIdentifier Pode ser: instagram:@..., whatsapp:+..., ou user_id
     * @return user_id resolvido ou null se não encontrado
     */
    public String resolveToUserId(String recipientIdentifier) {
        if (recipientIdentifier == null || recipientIdentifier.trim().isEmpty()) {
            return recipientIdentifier;
        }
        
        String identifier = recipientIdentifier.trim();
        
        // Caso 1: WhatsApp ou Instagram - buscar em user_identities
        if (identifier.startsWith("whatsapp:") || identifier.startsWith("instagram:")) {
            // Extrair valor sem prefixo para buscar
            String identityValue = identifier.substring(identifier.indexOf(':') + 1);
            
            Optional<String> userId = lookupByIdentity(identityValue);
            if (userId.isPresent()) {
                System.out.println("[IdentityResolver] Resolved " + identifier + " → " + userId.get());
                return userId.get();
            } else {
                // Identidade externa não vinculada a nenhum usuário
                System.out.println("[IdentityResolver] External identity not linked: " + identifier);
                return null; // Não enviar notificação para identidade externa
            }
        }
        
        // Caso 2: Parece UUID (contém hifens) - assumir que já é user_id
        if (identifier.contains("-") && identifier.length() > 30) {
            System.out.println("[IdentityResolver] Direct user_id: " + identifier);
            return identifier;
        }
        
        // Caso 3: Não reconhecido
        System.out.println("[IdentityResolver] Unknown format: " + identifier);
        return identifier; // Retornar como está (pode ser username)
    }
    
    /**
     * Busca user_id por identity_value (whatsapp/instagram) na tabela user_identities
     */
    private Optional<String> lookupByIdentity(String identityValue) {
        try {
            ResultSet rs = session.execute(getUserByIdentity.bind(identityValue));
            Row row = rs.one();
            
            if (row != null) {
                return Optional.of(row.getString("user_id"));
            }
        } catch (Exception e) {
            System.err.println("[IdentityResolver] Error looking up identity " + identityValue + ": " + e.getMessage());
        }
        
        return Optional.empty();
    }
}
