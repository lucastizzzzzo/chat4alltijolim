#!/usr/bin/env python3
"""
Cassandra Query Viewer - Interface simples para visualizar dados do Chat4All
"""

from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider
from datetime import datetime
from typing import Optional
import sys

class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def connect_cassandra():
    """Conecta ao Cassandra"""
    try:
        cluster = Cluster(['localhost'], port=9042)
        session = cluster.connect('chat4all')
        return session, cluster
    except Exception as e:
        print(f"{Colors.RED}❌ Erro ao conectar: {e}{Colors.ENDC}")
        print(f"\n{Colors.YELLOW}Certifique-se que o Cassandra está rodando:{Colors.ENDC}")
        print("  docker-compose ps cassandra")
        return None, None

def print_header(title: str):
    """Imprime cabeçalho formatado"""
    print(f"\n{Colors.CYAN}{'='*80}{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.CYAN}  {title}{Colors.ENDC}")
    print(f"{Colors.CYAN}{'='*80}{Colors.ENDC}\n")

def list_messages_by_conversation(session, conversation_id: str):
    """Lista mensagens de uma conversação"""
    print_header(f"📬 Mensagens da Conversa: {conversation_id}")
    
    query = """
        SELECT message_id, sender_id, content, status, timestamp, delivered_at, read_at
        FROM messages
        WHERE conversation_id = %s
    """
    
    try:
        rows = session.execute(query, [conversation_id])
        
        count = 0
        for row in rows:
            count += 1
            
            # Formatar timestamp
            ts = row.timestamp
            timestamp_str = ts.strftime('%Y-%m-%d %H:%M:%S') if ts else 'N/A'
            
            # Formatar delivered_at
            delivered = row.delivered_at
            delivered_str = delivered.strftime('%Y-%m-%d %H:%M:%S') if delivered else 'Não entregue'
            
            # Formatar read_at
            read = row.read_at
            read_str = read.strftime('%Y-%m-%d %H:%M:%S') if read else 'Não lida'
            
            # Cor do status
            status_colors = {
                'SENT': Colors.YELLOW,
                'DELIVERED': Colors.BLUE,
                'READ': Colors.GREEN
            }
            status_color = status_colors.get(row.status, Colors.ENDC)
            
            print(f"{Colors.BOLD}Mensagem #{count}{Colors.ENDC}")
            print(f"  {Colors.CYAN}ID:{Colors.ENDC} {row.message_id}")
            print(f"  {Colors.CYAN}De:{Colors.ENDC} {row.sender_id}")
            print(f"  {Colors.CYAN}Conteúdo:{Colors.ENDC} {row.content}")
            print(f"  {Colors.CYAN}Status:{Colors.ENDC} {status_color}{row.status}{Colors.ENDC}")
            print(f"  {Colors.CYAN}Enviada em:{Colors.ENDC} {timestamp_str}")
            print(f"  {Colors.CYAN}Entregue em:{Colors.ENDC} {delivered_str}")
            print(f"  {Colors.CYAN}Lida em:{Colors.ENDC} {read_str}")
            print()
        
        if count == 0:
            print(f"{Colors.YELLOW}Nenhuma mensagem encontrada para esta conversa.{Colors.ENDC}")
        else:
            print(f"{Colors.GREEN}✓ Total: {count} mensagens{Colors.ENDC}")
            
    except Exception as e:
        print(f"{Colors.RED}❌ Erro na query: {e}{Colors.ENDC}")

def list_all_conversations(session):
    """Lista todas as conversações com contagem de mensagens"""
    print_header("💬 Todas as Conversações")
    
    query = "SELECT DISTINCT conversation_id FROM messages"
    
    try:
        rows = session.execute(query)
        
        conversations = []
        for row in rows:
            conv_id = row.conversation_id
            
            # Contar mensagens
            count_query = "SELECT COUNT(*) FROM messages WHERE conversation_id = %s"
            count_result = session.execute(count_query, [conv_id])
            count = count_result.one().count
            
            conversations.append((conv_id, count))
        
        if not conversations:
            print(f"{Colors.YELLOW}Nenhuma conversa encontrada.{Colors.ENDC}")
            return
        
        print(f"{Colors.BOLD}{'Conversation ID':<50} {'Mensagens'}{Colors.ENDC}")
        print(f"{Colors.CYAN}{'-'*60}{Colors.ENDC}")
        
        for conv_id, count in sorted(conversations, key=lambda x: x[1], reverse=True):
            print(f"{conv_id:<50} {Colors.GREEN}{count:>8}{Colors.ENDC}")
        
        print(f"\n{Colors.GREEN}✓ Total: {len(conversations)} conversas{Colors.ENDC}")
        
    except Exception as e:
        print(f"{Colors.RED}❌ Erro na query: {e}{Colors.ENDC}")

def list_messages_by_status(session, status: str):
    """Lista mensagens por status"""
    print_header(f"📊 Mensagens com Status: {status}")
    
    query = """
        SELECT message_id, conversation_id, content, timestamp
        FROM messages
        WHERE status = %s
        ALLOW FILTERING
    """
    
    try:
        rows = session.execute(query, [status])
        
        count = 0
        for row in rows:
            count += 1
            ts = row.timestamp.strftime('%Y-%m-%d %H:%M:%S') if row.timestamp else 'N/A'
            
            print(f"{Colors.BOLD}{count}.{Colors.ENDC} [{ts}]")
            print(f"   Conversa: {row.conversation_id}")
            print(f"   Conteúdo: {row.content[:60]}...")
            print()
        
        if count == 0:
            print(f"{Colors.YELLOW}Nenhuma mensagem com status {status}.{Colors.ENDC}")
        else:
            print(f"{Colors.GREEN}✓ Total: {count} mensagens{Colors.ENDC}")
            
    except Exception as e:
        print(f"{Colors.RED}❌ Erro na query: {e}{Colors.ENDC}")

def show_statistics(session):
    """Mostra estatísticas gerais"""
    print_header("📊 Estatísticas do Sistema")
    
    try:
        # Total de mensagens
        total_query = "SELECT COUNT(*) FROM messages"
        total = session.execute(total_query).one().count
        
        # Mensagens por status
        statuses = ['SENT', 'DELIVERED', 'READ']
        status_counts = {}
        
        for status in statuses:
            query = "SELECT COUNT(*) FROM messages WHERE status = %s ALLOW FILTERING"
            count = session.execute(query, [status]).one().count
            status_counts[status] = count
        
        print(f"{Colors.BOLD}Total de Mensagens:{Colors.ENDC} {Colors.GREEN}{total}{Colors.ENDC}")
        print()
        print(f"{Colors.BOLD}Por Status:{Colors.ENDC}")
        print(f"  {Colors.YELLOW}SENT:{Colors.ENDC}      {status_counts['SENT']:>6}")
        print(f"  {Colors.BLUE}DELIVERED:{Colors.ENDC} {status_counts['DELIVERED']:>6}")
        print(f"  {Colors.GREEN}READ:{Colors.ENDC}      {status_counts['READ']:>6}")
        
        # Calcular porcentagens
        if total > 0:
            print()
            print(f"{Colors.BOLD}Taxa de Sucesso:{Colors.ENDC}")
            delivered_rate = (status_counts['DELIVERED'] + status_counts['READ']) / total * 100
            read_rate = status_counts['READ'] / total * 100
            print(f"  Entregues: {delivered_rate:.1f}%")
            print(f"  Lidas:     {read_rate:.1f}%")
        
    except Exception as e:
        print(f"{Colors.RED}❌ Erro ao calcular estatísticas: {e}{Colors.ENDC}")

def interactive_menu(session):
    """Menu interativo"""
    while True:
        print(f"\n{Colors.BOLD}Menu:{Colors.ENDC}")
        print("  1. Listar todas as conversações")
        print("  2. Ver mensagens de uma conversa específica")
        print("  3. Ver mensagens por status (SENT/DELIVERED/READ)")
        print("  4. Ver estatísticas gerais")
        print("  0. Sair")
        
        choice = input(f"\n{Colors.CYAN}Escolha uma opção:{Colors.ENDC} ").strip()
        
        if choice == '1':
            list_all_conversations(session)
        
        elif choice == '2':
            conv_id = input(f"{Colors.CYAN}Conversation ID:{Colors.ENDC} ").strip()
            if conv_id:
                list_messages_by_conversation(session, conv_id)
        
        elif choice == '3':
            status = input(f"{Colors.CYAN}Status (SENT/DELIVERED/READ):{Colors.ENDC} ").strip().upper()
            if status in ['SENT', 'DELIVERED', 'READ']:
                list_messages_by_status(session, status)
            else:
                print(f"{Colors.RED}Status inválido!{Colors.ENDC}")
        
        elif choice == '4':
            show_statistics(session)
        
        elif choice == '0':
            print(f"\n{Colors.GREEN}👋 Até logo!{Colors.ENDC}\n")
            break
        
        else:
            print(f"{Colors.RED}Opção inválida!{Colors.ENDC}")

def main():
    """Função principal"""
    print(f"{Colors.CYAN}{'='*80}{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.CYAN}  🗄️  Cassandra Query Viewer - Chat4All{Colors.ENDC}")
    print(f"{Colors.CYAN}{'='*80}{Colors.ENDC}")
    
    # Conectar
    print(f"\n{Colors.YELLOW}Conectando ao Cassandra...{Colors.ENDC}")
    session, cluster = connect_cassandra()
    
    if not session:
        sys.exit(1)
    
    print(f"{Colors.GREEN}✓ Conectado!{Colors.ENDC}")
    
    # Menu interativo ou query direta
    if len(sys.argv) > 1:
        # Modo query direta
        conv_id = sys.argv[1]
        list_messages_by_conversation(session, conv_id)
    else:
        # Modo interativo
        interactive_menu(session)
    
    # Cleanup
    cluster.shutdown()

if __name__ == "__main__":
    main()
