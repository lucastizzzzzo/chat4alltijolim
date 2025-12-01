#!/bin/bash
# Gerador de Relatório HTML - Dados do Cassandra

OUTPUT_FILE="/tmp/cassandra-report.html"

echo "🔍 Gerando relatório HTML com dados do Cassandra..."

cat > "$OUTPUT_FILE" << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Chat4All - Cassandra Database Viewer</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .header p { opacity: 0.9; }
        .content { padding: 30px; }
        .section {
            margin-bottom: 40px;
            border-bottom: 2px solid #f0f0f0;
            padding-bottom: 20px;
        }
        .section:last-child { border-bottom: none; }
        .section h2 {
            color: #667eea;
            margin-bottom: 20px;
            font-size: 1.8em;
            border-left: 5px solid #667eea;
            padding-left: 15px;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 25px;
            border-radius: 10px;
            text-align: center;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        .stat-card h3 { font-size: 2.5em; margin-bottom: 10px; }
        .stat-card p { opacity: 0.9; font-size: 1.1em; }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        th {
            background: #667eea;
            color: white;
            padding: 15px;
            text-align: left;
            font-weight: 600;
        }
        td {
            padding: 15px;
            border-bottom: 1px solid #f0f0f0;
        }
        tr:hover { background: #f9f9f9; }
        .message-card {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 20px;
            margin-bottom: 15px;
            border-radius: 5px;
        }
        .message-card .meta {
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
            font-size: 0.9em;
            color: #666;
        }
        .message-card .content {
            font-size: 1.1em;
            color: #333;
            margin-bottom: 10px;
        }
        .badge {
            display: inline-block;
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 600;
        }
        .badge-sent { background: #ffc107; color: #000; }
        .badge-delivered { background: #2196F3; color: white; }
        .badge-read { background: #4CAF50; color: white; }
        .refresh-btn {
            background: #667eea;
            color: white;
            border: none;
            padding: 12px 30px;
            border-radius: 25px;
            font-size: 1em;
            cursor: pointer;
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
            transition: all 0.3s;
        }
        .refresh-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 7px 20px rgba(102, 126, 234, 0.6);
        }
        .timestamp { color: #999; font-size: 0.9em; }
        .footer {
            text-align: center;
            padding: 20px;
            background: #f8f9fa;
            color: #666;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🗄️ Chat4All - Cassandra Viewer</h1>
            <p>Visualização em tempo real dos dados do banco de dados</p>
            <p class="timestamp">Gerado em: <span id="timestamp"></span></p>
        </div>
        
        <div class="content">
            <!-- ESTATÍSTICAS -->
            <div class="section">
                <h2>📊 Estatísticas Gerais</h2>
                <div class="stats">
EOF

# Obter estatísticas
TOTAL_MESSAGES=$(docker exec chat4all-cassandra cqlsh -e "SELECT COUNT(*) FROM chat4all.messages;" 2>/dev/null | grep -E '^\s*[0-9]+' | tr -d ' ')
SENT_COUNT=$(docker exec chat4all-cassandra cqlsh -e "SELECT COUNT(*) FROM chat4all.messages WHERE status='SENT' ALLOW FILTERING;" 2>/dev/null | grep -E '^\s*[0-9]+' | tr -d ' ')
DELIVERED_COUNT=$(docker exec chat4all-cassandra cqlsh -e "SELECT COUNT(*) FROM chat4all.messages WHERE status='DELIVERED' ALLOW FILTERING;" 2>/dev/null | grep -E '^\s*[0-9]+' | tr -d ' ')
READ_COUNT=$(docker exec chat4all-cassandra cqlsh -e "SELECT COUNT(*) FROM chat4all.messages WHERE status='READ' ALLOW FILTERING;" 2>/dev/null | grep -E '^\s*[0-9]+' | tr -d ' ')

cat >> "$OUTPUT_FILE" << EOF
                    <div class="stat-card">
                        <h3>$TOTAL_MESSAGES</h3>
                        <p>Total de Mensagens</p>
                    </div>
                    <div class="stat-card">
                        <h3>$SENT_COUNT</h3>
                        <p>Mensagens Enviadas</p>
                    </div>
                    <div class="stat-card">
                        <h3>$DELIVERED_COUNT</h3>
                        <p>Mensagens Entregues</p>
                    </div>
                    <div class="stat-card">
                        <h3>$READ_COUNT</h3>
                        <p>Mensagens Lidas</p>
                    </div>
                </div>
            </div>

            <!-- CONVERSAÇÕES -->
            <div class="section">
                <h2>💬 Conversações</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Conversation ID</th>
                            <th>Mensagens</th>
                        </tr>
                    </thead>
                    <tbody>
EOF

# Listar conversações
docker exec chat4all-cassandra cqlsh -e "SELECT DISTINCT conversation_id FROM chat4all.messages;" 2>/dev/null | \
    grep -E '^[a-z0-9_-]+' | while read -r conv_id; do
    
    conv_count=$(docker exec chat4all-cassandra cqlsh -e "SELECT COUNT(*) FROM chat4all.messages WHERE conversation_id='$conv_id';" 2>/dev/null | grep -E '^\s*[0-9]+' | tr -d ' ')
    
    cat >> "$OUTPUT_FILE" << EOF
                        <tr>
                            <td><strong>$conv_id</strong></td>
                            <td>$conv_count mensagens</td>
                        </tr>
EOF
done

cat >> "$OUTPUT_FILE" << 'EOF'
                    </tbody>
                </table>
            </div>

            <!-- ÚLTIMAS MENSAGENS -->
            <div class="section">
                <h2>📬 Últimas 20 Mensagens</h2>
EOF

# Listar últimas 20 mensagens
docker exec chat4all-cassandra cqlsh -e "
SELECT conversation_id, message_id, sender_id, content, status, timestamp 
FROM chat4all.messages 
LIMIT 20;" 2>/dev/null | tail -n +4 | head -n -2 | while IFS='|' read -r conv_id msg_id sender content status timestamp; do
    
    # Limpar espaços
    conv_id=$(echo "$conv_id" | xargs)
    msg_id=$(echo "$msg_id" | xargs)
    sender=$(echo "$sender" | xargs)
    content=$(echo "$content" | xargs)
    status=$(echo "$status" | xargs)
    timestamp=$(echo "$timestamp" | xargs)
    
    # Definir classe do badge baseado no status
    badge_class="badge-sent"
    case "$status" in
        "DELIVERED") badge_class="badge-delivered" ;;
        "READ") badge_class="badge-read" ;;
    esac
    
    cat >> "$OUTPUT_FILE" << EOF
                <div class="message-card">
                    <div class="meta">
                        <span><strong>De:</strong> $sender</span>
                        <span><strong>Conversa:</strong> $conv_id</span>
                        <span class="badge $badge_class">$status</span>
                    </div>
                    <div class="content">$content</div>
                    <div class="meta">
                        <span><strong>ID:</strong> <code>$msg_id</code></span>
                        <span class="timestamp">$timestamp</span>
                    </div>
                </div>
EOF
done

cat >> "$OUTPUT_FILE" << 'EOF'
            </div>
        </div>

        <div class="footer">
            <button class="refresh-btn" onclick="location.reload()">🔄 Atualizar Dados</button>
            <p style="margin-top: 15px;">Chat4All - Sistema de Mensagens Distribuído | Cassandra NoSQL Database</p>
        </div>
    </div>

    <script>
        // Atualizar timestamp
        document.getElementById('timestamp').textContent = new Date().toLocaleString('pt-BR');
        
        // Auto-refresh a cada 30 segundos (opcional)
        // setTimeout(() => location.reload(), 30000);
    </script>
</body>
</html>
EOF

echo ""
echo "✅ Relatório gerado com sucesso!"
echo ""
echo "📂 Arquivo: $OUTPUT_FILE"
echo ""
echo "🌐 Para visualizar, abra no navegador:"
echo "   file://$OUTPUT_FILE"
echo ""
echo "   OU execute:"
echo "   xdg-open $OUTPUT_FILE"
echo ""
