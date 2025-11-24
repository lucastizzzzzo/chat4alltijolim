#!/usr/bin/env python3
"""
Chat4All CLI - Interface de linha de comando interativa
Facilita o uso da API sem precisar usar curl diretamente
"""

import requests
import json
import sys
import os
from datetime import datetime
from typing import Optional, Dict, Any

class Colors:
    """Códigos de cores ANSI para terminal"""
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

class Chat4AllCLI:
    def __init__(self, api_url: str = "http://localhost:8080"):
        self.api_url = api_url
        self.token: Optional[str] = None
        self.current_user: Optional[str] = None
        self.current_conversation: Optional[str] = None
    
    def print_header(self):
        """Exibe cabeçalho do CLI"""
        print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")
        print(f"{Colors.BOLD}{Colors.CYAN}  📱 Chat4All CLI - Sistema de Mensagens Distribuído{Colors.ENDC}")
        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}\n")
    
    def print_menu(self):
        """Exibe menu principal"""
        print(f"{Colors.BOLD}Menu Principal:{Colors.ENDC}")
        print(f"  {Colors.GREEN}1.{Colors.ENDC} Autenticar (login)")
        print(f"  {Colors.GREEN}2.{Colors.ENDC} Enviar mensagem")
        print(f"  {Colors.GREEN}3.{Colors.ENDC} Enviar mensagem com arquivo")
        print(f"  {Colors.GREEN}4.{Colors.ENDC} Listar mensagens de uma conversa")
        print(f"  {Colors.GREEN}5.{Colors.ENDC} Marcar mensagem como lida")
        print(f"  {Colors.GREEN}6.{Colors.ENDC} Upload de arquivo")
        print(f"  {Colors.GREEN}7.{Colors.ENDC} Download de arquivo")
        print(f"  {Colors.GREEN}8.{Colors.ENDC} Status da infraestrutura")
        print(f"  {Colors.GREEN}9.{Colors.ENDC} Limpar tela")
        print(f"  {Colors.RED}0.{Colors.ENDC} Sair\n")
    
    def authenticate(self):
        """Autentica usuário e obtém JWT token"""
        print(f"\n{Colors.BOLD}🔐 Autenticação{Colors.ENDC}")
        print(f"{Colors.YELLOW}Usuários de demonstração disponíveis:{Colors.ENDC}")
        print(f"  • user_a / pass_a")
        print(f"  • user_b / pass_b")
        
        username = input(f"\n{Colors.CYAN}Username:{Colors.ENDC} ").strip()
        password = input(f"{Colors.CYAN}Password:{Colors.ENDC} ").strip()
        
        if not username or not password:
            print(f"{Colors.RED}❌ Username e password são obrigatórios{Colors.ENDC}")
            return
        
        try:
            response = requests.post(
                f"{self.api_url}/auth/token",
                json={"username": username, "password": password},
                timeout=5
            )
            
            if response.status_code == 200:
                data = response.json()
                self.token = data.get("access_token")
                self.current_user = username
                print(f"{Colors.GREEN}✓ Autenticado com sucesso!{Colors.ENDC}")
                print(f"  Usuário: {Colors.BOLD}{username}{Colors.ENDC}")
                print(f"  Token válido por: 1 hora")
            else:
                print(f"{Colors.RED}❌ Erro na autenticação: {response.status_code}{Colors.ENDC}")
                if response.status_code == 401:
                    print(f"  Credenciais inválidas. Tente user_a/pass_a ou user_b/pass_b")
                else:
                    print(f"  {response.text}")
        except requests.exceptions.ConnectionError:
            print(f"{Colors.RED}❌ Não foi possível conectar à API{Colors.ENDC}")
            print(f"\n{Colors.YELLOW}Verifique se os serviços estão rodando:{Colors.ENDC}")
            print(f"  docker-compose ps")
            print(f"\n{Colors.YELLOW}Se não estiverem, inicie com:{Colors.ENDC}")
            print(f"  docker-compose up -d")
            print(f"\n{Colors.YELLOW}API esperada em:{Colors.ENDC} {self.api_url}")
        except requests.exceptions.RequestException as e:
            print(f"{Colors.RED}❌ Erro de conexão: {e}{Colors.ENDC}")
    
    def send_message(self):
        """Envia mensagem de texto simples"""
        if not self.token:
            print(f"{Colors.RED}❌ Você precisa autenticar primeiro (opção 1){Colors.ENDC}")
            return
        
        print(f"\n{Colors.BOLD}📨 Enviar Mensagem{Colors.ENDC}")
        
        conversation_id = input(f"{Colors.CYAN}Conversation ID:{Colors.ENDC} ").strip()
        recipient_id = input(f"{Colors.CYAN}Recipient ID (ex: whatsapp:+5511999998888 ou instagram:@usuario):{Colors.ENDC} ").strip()
        content = input(f"{Colors.CYAN}Mensagem:{Colors.ENDC} ").strip()
        
        if not all([conversation_id, recipient_id, content]):
            print(f"{Colors.RED}❌ Todos os campos são obrigatórios{Colors.ENDC}")
            return
        
        try:
            payload = {
                "conversation_id": conversation_id,
                "sender_id": self.current_user,
                "recipient_id": recipient_id,
                "content": content
            }
            
            response = requests.post(
                f"{self.api_url}/v1/messages",
                headers={"Authorization": f"Bearer {self.token}"},
                json=payload,
                timeout=10
            )
            
            if response.status_code in [200, 201, 202]:
                data = response.json()
                print(f"{Colors.GREEN}✓ Mensagem enviada com sucesso!{Colors.ENDC}")
                print(f"  Message ID: {Colors.BOLD}{data.get('message_id')}{Colors.ENDC}")
                print(f"  Status: {data.get('status', 'SENT')}")
                if response.status_code == 202:
                    print(f"  {Colors.YELLOW}Processamento assíncrono (aguarde alguns segundos){Colors.ENDC}")
            else:
                print(f"{Colors.RED}❌ Erro ao enviar: {response.status_code}{Colors.ENDC}")
                print(f"  {response.text}")
        except requests.exceptions.RequestException as e:
            print(f"{Colors.RED}❌ Erro de conexão: {e}{Colors.ENDC}")
    
    def send_message_with_file(self):
        """Envia mensagem com arquivo anexado"""
        if not self.token:
            print(f"{Colors.RED}❌ Você precisa autenticar primeiro (opção 1){Colors.ENDC}")
            return
        
        print(f"\n{Colors.BOLD}📎 Enviar Mensagem com Arquivo{Colors.ENDC}")
        
        file_id = input(f"{Colors.CYAN}File ID (faça upload primeiro com opção 6):{Colors.ENDC} ").strip()
        conversation_id = input(f"{Colors.CYAN}Conversation ID:{Colors.ENDC} ").strip()
        recipient_id = input(f"{Colors.CYAN}Recipient ID:{Colors.ENDC} ").strip()
        content = input(f"{Colors.CYAN}Mensagem (opcional):{Colors.ENDC} ").strip()
        
        if not all([file_id, conversation_id, recipient_id]):
            print(f"{Colors.RED}❌ File ID, Conversation ID e Recipient ID são obrigatórios{Colors.ENDC}")
            return
        
        try:
            payload = {
                "conversation_id": conversation_id,
                "sender_id": self.current_user,
                "recipient_id": recipient_id,
                "content": content or f"Arquivo: {file_id}",
                "file_id": file_id
            }
            
            response = requests.post(
                f"{self.api_url}/v1/messages",
                headers={"Authorization": f"Bearer {self.token}"},
                json=payload,
                timeout=10
            )
            
            if response.status_code in [200, 201, 202]:
                data = response.json()
                print(f"{Colors.GREEN}✓ Mensagem com arquivo enviada!{Colors.ENDC}")
                print(f"  Message ID: {Colors.BOLD}{data.get('message_id')}{Colors.ENDC}")
                print(f"  File ID: {file_id}")
                if response.status_code == 202:
                    print(f"  {Colors.YELLOW}Processamento assíncrono (aguarde alguns segundos){Colors.ENDC}")
            else:
                print(f"{Colors.RED}❌ Erro ao enviar: {response.status_code}{Colors.ENDC}")
        except requests.exceptions.RequestException as e:
            print(f"{Colors.RED}❌ Erro de conexão: {e}{Colors.ENDC}")
    
    def list_messages(self):
        """Lista mensagens de uma conversa"""
        if not self.token:
            print(f"{Colors.RED}❌ Você precisa autenticar primeiro (opção 1){Colors.ENDC}")
            return
        
        print(f"\n{Colors.BOLD}💬 Listar Mensagens{Colors.ENDC}")
        
        conversation_id = input(f"{Colors.CYAN}Conversation ID:{Colors.ENDC} ").strip()
        limit = input(f"{Colors.CYAN}Limite (padrão 10):{Colors.ENDC} ").strip() or "10"
        
        if not conversation_id:
            print(f"{Colors.RED}❌ Conversation ID é obrigatório{Colors.ENDC}")
            return
        
        try:
            params = {"conversation_id": conversation_id, "limit": limit}
            
            response = requests.get(
                f"{self.api_url}/v1/messages",
                headers={"Authorization": f"Bearer {self.token}"},
                params=params,
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                messages = data.get("messages", [])
                
                if not messages:
                    print(f"{Colors.YELLOW}Nenhuma mensagem encontrada{Colors.ENDC}")
                    return
                
                print(f"{Colors.GREEN}✓ {len(messages)} mensagens encontradas:{Colors.ENDC}\n")
                
                for msg in messages:
                    timestamp = datetime.fromtimestamp(msg.get('timestamp', 0) / 1000)
                    status_color = {
                        'SENT': Colors.YELLOW,
                        'DELIVERED': Colors.BLUE,
                        'READ': Colors.GREEN
                    }.get(msg.get('status', 'SENT'), Colors.ENDC)
                    
                    print(f"{Colors.BOLD}[{timestamp.strftime('%Y-%m-%d %H:%M:%S')}]{Colors.ENDC}")
                    print(f"  {Colors.CYAN}De:{Colors.ENDC} {msg.get('sender_id')}")
                    print(f"  {Colors.CYAN}Para:{Colors.ENDC} {msg.get('recipient_id')}")
                    print(f"  {Colors.CYAN}Mensagem:{Colors.ENDC} {msg.get('content')}")
                    print(f"  {Colors.CYAN}Status:{Colors.ENDC} {status_color}{msg.get('status')}{Colors.ENDC}")
                    
                    if msg.get('file_id'):
                        print(f"  {Colors.CYAN}Arquivo:{Colors.ENDC} {msg.get('file_id')}")
                    
                    print(f"  {Colors.CYAN}ID:{Colors.ENDC} {msg.get('message_id')}")
                    print()
                
            else:
                print(f"{Colors.RED}❌ Erro ao listar: {response.status_code}{Colors.ENDC}")
        except requests.exceptions.RequestException as e:
            print(f"{Colors.RED}❌ Erro de conexão: {e}{Colors.ENDC}")
    
    def mark_as_read(self):
        """Marca mensagem como lida"""
        if not self.token:
            print(f"{Colors.RED}❌ Você precisa autenticar primeiro (opção 1){Colors.ENDC}")
            return
        
        print(f"\n{Colors.BOLD}✓ Marcar como Lida{Colors.ENDC}")
        
        message_id = input(f"{Colors.CYAN}Message ID:{Colors.ENDC} ").strip()
        
        if not message_id:
            print(f"{Colors.RED}❌ Message ID é obrigatório{Colors.ENDC}")
            return
        
        try:
            response = requests.post(
                f"{self.api_url}/v1/messages/{message_id}/read",
                headers={"Authorization": f"Bearer {self.token}"},
                timeout=10
            )
            
            if response.status_code == 200:
                print(f"{Colors.GREEN}✓ Mensagem marcada como lida!{Colors.ENDC}")
            else:
                print(f"{Colors.RED}❌ Erro: {response.status_code}{Colors.ENDC}")
        except requests.exceptions.RequestException as e:
            print(f"{Colors.RED}❌ Erro de conexão: {e}{Colors.ENDC}")
    
    def upload_file(self):
        """Upload de arquivo"""
        if not self.token:
            print(f"{Colors.RED}❌ Você precisa autenticar primeiro (opção 1){Colors.ENDC}")
            return
        
        print(f"\n{Colors.BOLD}📤 Upload de Arquivo{Colors.ENDC}")
        
        file_path = input(f"{Colors.CYAN}Caminho do arquivo:{Colors.ENDC} ").strip()
        conversation_id = input(f"{Colors.CYAN}Conversation ID:{Colors.ENDC} ").strip()
        
        if not all([file_path, conversation_id]):
            print(f"{Colors.RED}❌ Todos os campos são obrigatórios{Colors.ENDC}")
            return
        
        if not os.path.exists(file_path):
            print(f"{Colors.RED}❌ Arquivo não encontrado: {file_path}{Colors.ENDC}")
            return
        
        file_size = os.path.getsize(file_path)
        print(f"{Colors.YELLOW}Tamanho: {file_size / 1024:.2f} KB{Colors.ENDC}")
        
        try:
            with open(file_path, 'rb') as f:
                files = {'file': f}
                data = {'conversation_id': conversation_id}
                
                print(f"{Colors.YELLOW}Uploading...{Colors.ENDC}")
                
                response = requests.post(
                    f"{self.api_url}/v1/files",
                    headers={"Authorization": f"Bearer {self.token}"},
                    files=files,
                    data=data,
                    timeout=300  # 5 minutos para arquivos grandes
                )
                
                if response.status_code == 201:
                    result = response.json()
                    print(f"{Colors.GREEN}✓ Upload concluído!{Colors.ENDC}")
                    print(f"  File ID: {Colors.BOLD}{result.get('file_id')}{Colors.ENDC}")
                    print(f"  Filename: {result.get('filename')}")
                    print(f"  Size: {result.get('size_bytes')} bytes")
                    print(f"  Checksum: {result.get('checksum', 'N/A')[:20]}...")
                else:
                    print(f"{Colors.RED}❌ Erro no upload: {response.status_code}{Colors.ENDC}")
        except requests.exceptions.RequestException as e:
            print(f"{Colors.RED}❌ Erro de conexão: {e}{Colors.ENDC}")
    
    def download_file(self):
        """Download de arquivo"""
        if not self.token:
            print(f"{Colors.RED}❌ Você precisa autenticar primeiro (opção 1){Colors.ENDC}")
            return
        
        print(f"\n{Colors.BOLD}📥 Download de Arquivo{Colors.ENDC}")
        
        file_id = input(f"{Colors.CYAN}File ID:{Colors.ENDC} ").strip()
        
        if not file_id:
            print(f"{Colors.RED}❌ File ID é obrigatório{Colors.ENDC}")
            return
        
        try:
            # Obter presigned URL
            response = requests.get(
                f"{self.api_url}/v1/files/{file_id}/download",
                headers={"Authorization": f"Bearer {self.token}"},
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                download_url = data.get('download_url')
                filename = data.get('filename', file_id)
                
                print(f"{Colors.GREEN}✓ URL de download gerada{Colors.ENDC}")
                print(f"  URL: {download_url[:80]}...")
                print(f"  Expira em: {data.get('expires_in', 3600)} segundos")
                print(f"\n{Colors.YELLOW}Baixando arquivo...{Colors.ENDC}")
                
                # Download do arquivo
                file_response = requests.get(download_url, timeout=300)
                
                if file_response.status_code == 200:
                    output_path = f"./{filename}"
                    with open(output_path, 'wb') as f:
                        f.write(file_response.content)
                    
                    print(f"{Colors.GREEN}✓ Arquivo salvo: {output_path}{Colors.ENDC}")
                    print(f"  Tamanho: {len(file_response.content) / 1024:.2f} KB")
                else:
                    print(f"{Colors.RED}❌ Erro no download: {file_response.status_code}{Colors.ENDC}")
            else:
                print(f"{Colors.RED}❌ Erro ao gerar URL: {response.status_code}{Colors.ENDC}")
        except requests.exceptions.RequestException as e:
            print(f"{Colors.RED}❌ Erro de conexão: {e}{Colors.ENDC}")
    
    def check_infrastructure(self):
        """Verifica status da infraestrutura"""
        print(f"\n{Colors.BOLD}🔧 Status da Infraestrutura{Colors.ENDC}\n")
        
        services = {
            "API Service": f"{self.api_url}/health",
            "MinIO": "http://localhost:9000/minio/health/live",
        }
        
        print(f"{Colors.YELLOW}Verificando conexão com:{Colors.ENDC} {self.api_url}\n")
        
        for name, url in services.items():
            try:
                response = requests.get(url, timeout=3)
                if response.status_code in [200, 204]:
                    print(f"  {Colors.GREEN}✓{Colors.ENDC} {name}: {Colors.GREEN}Online{Colors.ENDC}")
                else:
                    print(f"  {Colors.YELLOW}⚠{Colors.ENDC} {name}: {Colors.YELLOW}Status {response.status_code}{Colors.ENDC}")
            except:
                print(f"  {Colors.RED}✗{Colors.ENDC} {name}: {Colors.RED}Offline{Colors.ENDC}")
        
        print(f"\n{Colors.YELLOW}Para verificar containers Docker:{Colors.ENDC}")
        print(f"  docker-compose ps")
    
    def run(self):
        """Loop principal do CLI"""
        self.print_header()
        
        while True:
            if self.current_user:
                print(f"\n{Colors.GREEN}👤 Logado como: {Colors.BOLD}{self.current_user}{Colors.ENDC}")
            else:
                print(f"\n{Colors.YELLOW}⚠ Não autenticado{Colors.ENDC}")
            
            self.print_menu()
            
            choice = input(f"{Colors.BOLD}Escolha uma opção:{Colors.ENDC} ").strip()
            
            if choice == "1":
                self.authenticate()
            elif choice == "2":
                self.send_message()
            elif choice == "3":
                self.send_message_with_file()
            elif choice == "4":
                self.list_messages()
            elif choice == "5":
                self.mark_as_read()
            elif choice == "6":
                self.upload_file()
            elif choice == "7":
                self.download_file()
            elif choice == "8":
                self.check_infrastructure()
            elif choice == "9":
                os.system('clear' if os.name != 'nt' else 'cls')
                self.print_header()
            elif choice == "0":
                print(f"\n{Colors.CYAN}Até logo! 👋{Colors.ENDC}\n")
                sys.exit(0)
            else:
                print(f"{Colors.RED}❌ Opção inválida{Colors.ENDC}")
            
            input(f"\n{Colors.YELLOW}Pressione ENTER para continuar...{Colors.ENDC}")

def main():
    """Ponto de entrada do CLI"""
    api_url = os.getenv("CHAT4ALL_API_URL", "http://localhost:8080")
    
    cli = Chat4AllCLI(api_url)
    
    try:
        cli.run()
    except KeyboardInterrupt:
        print(f"\n\n{Colors.CYAN}Interrompido pelo usuário. Até logo! 👋{Colors.ENDC}\n")
        sys.exit(0)
    except Exception as e:
        print(f"\n{Colors.RED}❌ Erro inesperado: {e}{Colors.ENDC}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
