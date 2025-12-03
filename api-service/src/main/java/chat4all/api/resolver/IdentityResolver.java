package chat4all.api.resolver;

import com.datastax.oss.driver.api.core.CqlSession;
import com.datastax.oss.driver.api.core.cql.PreparedStatement;
import com.datastax.oss.driver.api.core.cql.ResultSet;
import com.datastax.oss.driver.api.core.cql.Row;

import java.util.Optional;

/**
 * IdentityResolver - Resolve identidades para user_id
 * 
 * PROPÓSITO: Permitir enviar mensagens usando:
 * - username (ex: "user_a")
 * - whatsapp (ex: "whatsapp:+5562996991812")
 * - instagram (ex: "instagram:@usuario")
 * 
 * Consulta a tabela user_identities para resolver o user_id real.
 * 
 * EXEMPLOS:
 * - resolveToUserId("user_a") → "uuid-do-user-a"
 * - resolveToUserId("whatsapp:+5562996991812") → "uuid-do-dono-desse-numero"
 * - resolveToUserId("instagram:@joao") → "uuid-do-joao"
 * - resolveToUserId("uuid-direto") → "uuid-direto" (passthrough)
 */
public class IdentityResolver {
    
    private final CqlSession session;
    private final PreparedStatement getUserByUsername;
    private final PreparedStatement getUserByIdentity;
    
    public IdentityResolver(CqlSession session) {
        this.session = session;
        
        // Query 1: Buscar por username
        this.getUserByUsername = session.prepare(
            "SELECT user_id FROM chat4all.users WHERE username = ? ALLOW FILTERING"
        );
        
        // Query 2: Buscar por identidade externa (WhatsApp/Instagram)
        this.getUserByIdentity = session.prepare(
            "SELECT user_id FROM chat4all.user_identities WHERE identity_value = ? ALLOW FILTERING"
        );
        
        System.out.println("✓ IdentityResolver initialized");
    }
    
    /**
     * Resolve recipient identifier para user_id
     * 
     * LÓGICA:
     * 1. Se começa com "whatsapp:" ou "instagram:" → busca em user_identities
     * 2. Se parece UUID (contém hifens) → retorna direto (já é user_id)
     * 3. Caso contrário → assume username, busca em users
     * 
     * @param recipientIdentifier Pode ser: username, whatsapp:+55..., instagram:@..., ou user_id
     * @return user_id resolvido ou o identificador original se for externo
     */
    public String resolveToUserId(String recipientIdentifier) {
        if (recipientIdentifier == null || recipientIdentifier.trim().isEmpty()) {
            return recipientIdentifier;
        }
        
        String identifier = recipientIdentifier.trim();
        
        // Caso 1: WhatsApp ou Instagram - buscar em user_identities
        if (identifier.startsWith("whatsapp:") || identifier.startsWith("instagram:")) {
            Optional<String> userId = lookupByIdentity(identifier);
            if (userId.isPresent()) {
                System.out.println("[IdentityResolver] Resolved " + identifier + " → " + userId.get());
                return userId.get();
            } else {
                // Identidade externa não vinculada a nenhum usuário
                // Retorna como está para rotear ao conector externo
                System.out.println("[IdentityResolver] External identity (not linked): " + identifier);
                return identifier;
            }
        }
        
        // Caso 2: Parece UUID (contém hifens) - assumir que já é user_id
        if (identifier.contains("-") && identifier.length() > 30) {
            System.out.println("[IdentityResolver] Direct user_id: " + identifier);
            return identifier;
        }
        
        // Caso 3: Username - buscar em users
        Optional<String> userId = lookupByUsername(identifier);
        if (userId.isPresent()) {
            System.out.println("[IdentityResolver] Resolved username " + identifier + " → " + userId.get());
            return userId.get();
        }
        
        // Não encontrado - retornar como está
        System.out.println("[IdentityResolver] Could not resolve: " + identifier + " (keeping as-is)");
        return identifier;
    }
    
    /**
     * Busca user_id por username na tabela users
     */
    private Optional<String> lookupByUsername(String username) {
        try {
            ResultSet rs = session.execute(getUserByUsername.bind(username));
            Row row = rs.one();
            
            if (row != null) {
                return Optional.of(row.getString("user_id"));
            }
        } catch (Exception e) {
            System.err.println("[IdentityResolver] Error looking up username " + username + ": " + e.getMessage());
        }
        
        return Optional.empty();
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
