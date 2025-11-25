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
        """Envia mensagem com arquivo anexado - faz upload automático"""
        if not self.token:
            print(f"{Colors.RED}❌ Você precisa autenticar primeiro (opção 1){Colors.ENDC}")
            return
        
        print(f"\n{Colors.BOLD}📎 Enviar Mensagem com Arquivo{Colors.ENDC}")
        
        file_path = input(f"{Colors.CYAN}Caminho do arquivo:{Colors.ENDC} ").strip()
        conversation_id = input(f"{Colors.CYAN}Conversation ID:{Colors.ENDC} ").strip()
        recipient_id = input(f"{Colors.CYAN}Recipient ID:{Colors.ENDC} ").strip()
        content = input(f"{Colors.CYAN}Mensagem:{Colors.ENDC} ").strip()
        
        if not all([file_path, conversation_id, recipient_id, content]):
            print(f"{Colors.RED}❌ Todos os campos são obrigatórios{Colors.ENDC}")
            return
        
        if not os.path.exists(file_path):
            print(f"{Colors.RED}❌ Arquivo não encontrado: {file_path}{Colors.ENDC}")
            return
        
        try:
            # 1. Upload do arquivo primeiro
            print(f"{Colors.YELLOW}Fazendo upload do arquivo...{Colors.ENDC}")
            with open(file_path, 'rb') as f:
                files = {'file': f}
                data = {'conversation_id': conversation_id}
                
                upload_response = requests.post(
                    f"{self.api_url}/v1/files",
                    headers={"Authorization": f"Bearer {self.token}"},
                    files=files,
                    data=data,
                    timeout=300
                )
                
                if upload_response.status_code != 201:
                    print(f"{Colors.RED}❌ Erro no upload: {upload_response.status_code}{Colors.ENDC}")
                    return
                
                upload_data = upload_response.json()
                file_id = upload_data.get('file_id')
                print(f"{Colors.GREEN}✓ Upload concluído! File ID: {file_id}{Colors.ENDC}")
            
            # 2. Enviar mensagem com o file_id
            payload = {
                "conversation_id": conversation_id,
                "sender_id": self.current_user,
                "recipient_id": recipient_id,
                "content": content,
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
        except Exception as e:
            print(f"{Colors.RED}❌ Erro: {e}{Colors.ENDC}")
    
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
            params = {"limit": limit}
            
            response = requests.get(
                f"{self.api_url}/v1/conversations/{conversation_id}/messages",
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
        """Download de arquivo - Lista arquivos da conversa para escolher"""
        if not self.token:
            print(f"{Colors.RED}❌ Você precisa autenticar primeiro (opção 1){Colors.ENDC}")
            return
        
        print(f"\n{Colors.BOLD}📥 Download de Arquivo{Colors.ENDC}")
        
        conversation_id = input(f"{Colors.CYAN}Conversation ID:{Colors.ENDC} ").strip()
        
        if not conversation_id:
            print(f"{Colors.RED}❌ Conversation ID é obrigatório{Colors.ENDC}")
            return
        
        try:
            # 1. Listar mensagens da conversa para encontrar arquivos
            print(f"{Colors.YELLOW}Buscando arquivos na conversa...{Colors.ENDC}")
            
            response = requests.get(
                f"{self.api_url}/v1/conversations/{conversation_id}/messages",
                headers={"Authorization": f"Bearer {self.token}"},
                params={"limit": 50},
                timeout=10
            )
            
            if response.status_code != 200:
                print(f"{Colors.RED}❌ Erro ao listar mensagens: {response.status_code}{Colors.ENDC}")
                return
            
            data = response.json()
            messages = data.get("messages", [])
            
            # Filtrar mensagens com arquivos
            files_info = []
            for msg in messages:
                if msg.get('file_id'):
                    files_info.append({
                        'file_id': msg['file_id'],
                        'filename': msg.get('file_metadata', {}).get('filename', 'unknown'),
                        'size': msg.get('file_metadata', {}).get('size_bytes', 0),
                        'sender': msg.get('sender_id', 'unknown'),
                        'timestamp': msg.get('timestamp', 0)
                    })
            
            if not files_info:
                print(f"{Colors.YELLOW}Nenhum arquivo encontrado nesta conversa{Colors.ENDC}")
                return
            
            # 2. Exibir lista de arquivos
            print(f"\n{Colors.GREEN}📎 Arquivos disponíveis:{Colors.ENDC}\n")
            for idx, file_info in enumerate(files_info, 1):
                timestamp = datetime.fromtimestamp(file_info['timestamp'] / 1000)
                size_bytes = int(file_info['size']) if file_info['size'] else 0
                size_kb = size_bytes / 1024
                print(f"  {Colors.BOLD}{idx}.{Colors.ENDC} {file_info['filename']}")
                print(f"     📅 {timestamp.strftime('%d/%m/%Y %H:%M')}")
                print(f"     👤 {file_info['sender']}")
                print(f"     💾 {size_kb:.2f} KB")
                print()
            
            # 3. Usuário escolhe arquivo(s)
            choice = input(f"{Colors.CYAN}Escolha o(s) número(s) (ex: 1 ou 1,3,5):{Colors.ENDC} ").strip()
            
            if not choice:
                print(f"{Colors.YELLOW}Cancelado{Colors.ENDC}")
                return
            
            # Parse escolhas
            try:
                indices = [int(x.strip()) for x in choice.split(',')]
                selected_files = [files_info[i-1] for i in indices if 1 <= i <= len(files_info)]
            except (ValueError, IndexError):
                print(f"{Colors.RED}❌ Escolha inválida{Colors.ENDC}")
                return
            
            if not selected_files:
                print(f"{Colors.RED}❌ Nenhum arquivo válido selecionado{Colors.ENDC}")
                return
            
            # 4. Download dos arquivos selecionados
            for file_info in selected_files:
                file_id = file_info['file_id']
                filename = file_info['filename']
                
                print(f"\n{Colors.YELLOW}Baixando: {filename}...{Colors.ENDC}")
                
                # Use direct proxy endpoint instead of presigned URL
                # This avoids signature issues with hostname substitution
                response = requests.get(
                    f"{self.api_url}/v1/files/{file_id}/content",
                    headers={"Authorization": f"Bearer {self.token}"},
                    timeout=300,
                    stream=True
                )
                
                if response.status_code == 200:
                    # Salvar em ~/Downloads
                    downloads_dir = os.path.expanduser("~/Downloads")
                    os.makedirs(downloads_dir, exist_ok=True)
                    output_path = os.path.join(downloads_dir, filename)
                    
                    with open(output_path, 'wb') as f:
                        for chunk in response.iter_content(chunk_size=8192):
                            if chunk:
                                f.write(chunk)
                    
                    file_size = os.path.getsize(output_path) / 1024
                    print(f"{Colors.GREEN}✓ Arquivo salvo: {output_path}{Colors.ENDC}")
                    print(f"  Tamanho: {file_size:.2f} KB")
                else:
                    print(f"{Colors.RED}❌ Erro no download: {response.status_code}{Colors.ENDC}")
        
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
