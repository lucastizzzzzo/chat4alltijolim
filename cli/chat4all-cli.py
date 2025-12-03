#!/usr/bin/env python3
"""
Chat4All CLI - Interface de linha de comando interativa
Facilita o uso da API sem precisar usar curl diretamente
"""

import requests
import json
import sys
import os
import time
import uuid
import threading
import base64
from datetime import datetime
from typing import Optional, Dict, Any, List, Set
import websocket  # websocket-client library

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
    def __init__(self, api_url: str = "http://localhost:8080", websocket_url: str = "ws://localhost:8085"):
        self.api_url = api_url
        self.websocket_url = websocket_url
        self.token: Optional[str] = None
        self.current_user: Optional[str] = None  # Username
        self.current_user_id: Optional[str] = None  # UUID do usuário
        self.current_conversation: Optional[str] = None
        
        # Sistema de notificações (WebSocket-based)
        self.notification_enabled = False
        self.ws: Optional[websocket.WebSocketApp] = None
        self.ws_thread: Optional[threading.Thread] = None
        self.stop_notifications = threading.Event()
        self.conversation_names: Dict[str, str] = {}  # Cache de nomes de conversas
    
    def print_header(self):
        """Exibe cabeçalho do CLI"""
        print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")
        print(f"{Colors.BOLD}{Colors.CYAN}  📱 Chat4All CLI - Sistema de Mensagens Distribuído{Colors.ENDC}")
        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}\n")
    
    def print_menu(self):
        """Exibe menu principal"""
        print(f"{Colors.BOLD}Menu Principal:{Colors.ENDC}")
        print(f"  {Colors.GREEN}1.{Colors.ENDC} Registrar novo usuário")
        print(f"  {Colors.GREEN}2.{Colors.ENDC} Autenticar (login)")
        print(f"  {Colors.GREEN}3.{Colors.ENDC} Listar minhas conversas")
        print(f"  {Colors.GREEN}4.{Colors.ENDC} Criar nova conversa")
        print(f"  {Colors.GREEN}5.{Colors.ENDC} Enviar mensagem")
        print(f"  {Colors.GREEN}6.{Colors.ENDC} Enviar mensagem com arquivo")
        print(f"  {Colors.GREEN}7.{Colors.ENDC} Listar mensagens de uma conversa")
        print(f"  {Colors.GREEN}8.{Colors.ENDC} Upload de arquivo")
        print(f"  {Colors.GREEN}9.{Colors.ENDC} Download de arquivo")
        print(f"  {Colors.GREEN}10.{Colors.ENDC} Minhas identidades (WhatsApp/Instagram)")
        print(f"  {Colors.GREEN}11.{Colors.ENDC} Status da infraestrutura")
        print(f"  {Colors.GREEN}12.{Colors.ENDC} {'🔔 Desativar' if self.notification_enabled else '🔕 Ativar'} notificações em tempo real")
        print(f"  {Colors.GREEN}13.{Colors.ENDC} Limpar tela")
        print(f"  {Colors.RED}0.{Colors.ENDC} Sair\n")
    
    def register_user(self):
        """Registra novo usuário no sistema com opção de vincular WhatsApp/Instagram"""
        print(f"\n{Colors.BOLD}📝 Registrar Novo Usuário{Colors.ENDC}")
        
        # Coletar informações básicas
        username = input(f"{Colors.CYAN}Username (único):{Colors.ENDC} ").strip()
        if not username:
            print(f"{Colors.RED}❌ Username é obrigatório{Colors.ENDC}")
            return
        
        password = input(f"{Colors.CYAN}Password:{Colors.ENDC} ").strip()
        if not password:
            print(f"{Colors.RED}❌ Password é obrigatório{Colors.ENDC}")
            return
        
        email = input(f"{Colors.CYAN}Email:{Colors.ENDC} ").strip()
        if not email:
            print(f"{Colors.RED}❌ Email é obrigatório{Colors.ENDC}")
            return
        
        # Perguntar sobre WhatsApp
        link_whatsapp = input(f"\n{Colors.CYAN}Vincular WhatsApp? (s/N):{Colors.ENDC} ").strip().lower()
        whatsapp_number = None
        if link_whatsapp in ['s', 'y', 'sim', 'yes']:
            whatsapp_number = input(f"{Colors.CYAN}Número WhatsApp (formato: +5562996991812):{Colors.ENDC} ").strip()
            if not whatsapp_number.startswith('+'):
                print(f"{Colors.YELLOW}⚠️  Formato recomendado: +[código país][número]{Colors.ENDC}")
        
        # Perguntar sobre Instagram
        link_instagram = input(f"{Colors.CYAN}Vincular Instagram? (s/N):{Colors.ENDC} ").strip().lower()
        instagram_handle = None
        if link_instagram in ['s', 'y', 'sim', 'yes']:
            instagram_handle = input(f"{Colors.CYAN}Instagram handle (formato: @username):{Colors.ENDC} ").strip()
            if not instagram_handle.startswith('@'):
                instagram_handle = '@' + instagram_handle
        
        try:
            # 1. Registrar usuário
            print(f"\n{Colors.YELLOW}⏳ Registrando usuário...{Colors.ENDC}")
            
            response = requests.post(
                f"{self.api_url}/auth/register",
                json={
                    "username": username,
                    "password": password,
                    "email": email
                },
                timeout=10
            )
            
            if response.status_code == 201:
                user_data = response.json()
                user_id = user_data.get('user_id')
                
                print(f"{Colors.GREEN}✅ Usuário registrado com sucesso!{Colors.ENDC}")
                print(f"{Colors.CYAN}   User ID:{Colors.ENDC} {user_id}")
                print(f"{Colors.CYAN}   Username:{Colors.ENDC} {username}")
                print(f"{Colors.CYAN}   Email:{Colors.ENDC} {email}")
                
                # 2. Fazer login automaticamente
                print(f"\n{Colors.YELLOW}⏳ Fazendo login automático...{Colors.ENDC}")
                
                login_response = requests.post(
                    f"{self.api_url}/auth/token",
                    json={
                        "username": username,
                        "password": password
                    },
                    timeout=10
                )
                
                if login_response.status_code == 200:
                    token_data = login_response.json()
                    self.token = token_data.get('access_token')
                    self.current_user = username
                    
                    # Decodificar JWT para extrair user_id do campo 'sub'
                    token_payload = self._decode_jwt(self.token)
                    if token_payload:
                        self.current_user_id = token_payload.get("sub")
                    
                    print(f"{Colors.GREEN}✅ Login realizado com sucesso!{Colors.ENDC}")
                    
                    # 3. Vincular WhatsApp se solicitado
                    if whatsapp_number:
                        print(f"\n{Colors.YELLOW}⏳ Vinculando WhatsApp...{Colors.ENDC}")
                        
                        whatsapp_response = requests.post(
                            f"{self.api_url}/v1/users/identities",
                            headers={"Authorization": f"Bearer {self.token}"},
                            json={
                                "platform": "whatsapp",
                                "value": whatsapp_number
                            },
                            timeout=10
                        )
                        
                        if whatsapp_response.status_code == 201:
                            print(f"{Colors.GREEN}✅ WhatsApp {whatsapp_number} vinculado!{Colors.ENDC}")
                        else:
                            error_msg = whatsapp_response.json().get('error', 'Erro desconhecido')
                            print(f"{Colors.RED}❌ Erro ao vincular WhatsApp: {error_msg}{Colors.ENDC}")
                    
                    # 4. Vincular Instagram se solicitado
                    if instagram_handle:
                        print(f"\n{Colors.YELLOW}⏳ Vinculando Instagram...{Colors.ENDC}")
                        
                        instagram_response = requests.post(
                            f"{self.api_url}/v1/users/identities",
                            headers={"Authorization": f"Bearer {self.token}"},
                            json={
                                "platform": "instagram",
                                "value": instagram_handle
                            },
                            timeout=10
                        )
                        
                        if instagram_response.status_code == 201:
                            print(f"{Colors.GREEN}✅ Instagram {instagram_handle} vinculado!{Colors.ENDC}")
                        else:
                            error_msg = instagram_response.json().get('error', 'Erro desconhecido')
                            print(f"{Colors.RED}❌ Erro ao vincular Instagram: {error_msg}{Colors.ENDC}")
                    
                    print(f"\n{Colors.GREEN}{Colors.BOLD}🎉 Conta configurada com sucesso!{Colors.ENDC}")
                    print(f"{Colors.CYAN}Você já está autenticado e pode começar a usar o sistema.{Colors.ENDC}")
                    
                else:
                    print(f"{Colors.RED}❌ Erro no login automático{Colors.ENDC}")
                    print(f"{Colors.CYAN}Use a opção 2 para fazer login manualmente.{Colors.ENDC}")
                    
            elif response.status_code == 409:
                error_msg = response.json().get('error', 'Username ou email já existem')
                print(f"{Colors.RED}❌ {error_msg}{Colors.ENDC}")
                
            elif response.status_code == 400:
                error_msg = response.json().get('error', 'Dados inválidos')
                print(f"{Colors.RED}❌ {error_msg}{Colors.ENDC}")
                
            else:
                print(f"{Colors.RED}❌ Erro ao registrar: {response.status_code}{Colors.ENDC}")
                if response.text:
                    print(f"{Colors.RED}  {response.text}{Colors.ENDC}")
                    
        except requests.exceptions.RequestException as e:
            print(f"{Colors.RED}❌ Erro de conexão: {e}{Colors.ENDC}")
    
    def list_conversations(self):
        """Lista conversas do usuário"""
        if not self.token:
            print(f"{Colors.RED}❌ Você precisa autenticar primeiro (opção 2){Colors.ENDC}")
            return
        
        print(f"\n{Colors.BOLD}💬 Minhas Conversas{Colors.ENDC}")
        
        # Mostrar conversas criadas nesta sessão
        if self.conversation_names:
            print(f"\n{Colors.GREEN}✓ Conversas criadas nesta sessão:{Colors.ENDC}\n")
            
            for i, (conv_id, info) in enumerate(self.conversation_names.items(), 1):
                name = info.get('name', 'Sem nome')
                members = info.get('members', [])
                created = info.get('created_at', '')
                
                print(f"{Colors.BOLD}{i}.{Colors.ENDC} {name}")
                print(f"   {Colors.CYAN}ID:{Colors.ENDC} {conv_id}")
                if members:
                    print(f"   {Colors.CYAN}Membros ({len(members)}):{Colors.ENDC}")
                    for member in members[:5]:  # Mostrar até 5
                        print(f"     • {member}")
                    if len(members) > 5:
                        print(f"     ... e mais {len(members) - 5}")
                print()
        else:
            print(f"\n{Colors.YELLOW}Nenhuma conversa criada nesta sessão.{Colors.ENDC}")
            print(f"{Colors.CYAN}💡 Use a opção 4 para criar uma nova conversa!{Colors.ENDC}\n")
    
    def create_conversation(self):
        """Cria nova conversa com ID gerado automaticamente e opção de adicionar membros"""
        if not self.token:
            print(f"{Colors.RED}❌ Você precisa autenticar primeiro (opção 2){Colors.ENDC}")
            return
        
        print(f"\n{Colors.BOLD}➕ Criar Nova Conversa{Colors.ENDC}")
        
        conv_name = input(f"{Colors.CYAN}Nome da conversa (ex: Festa de Ano Novo):{Colors.ENDC} ").strip()
        
        if not conv_name:
            print(f"{Colors.RED}❌ Nome da conversa é obrigatório{Colors.ENDC}")
            return
        
        # Gerar ID amigável baseado no nome + timestamp
        safe_name = conv_name.lower().replace(' ', '_').replace('/', '_')[:30]
        timestamp = int(time.time())
        conv_id = f"conv_{safe_name}_{timestamp}"
        
        print(f"\n{Colors.GREEN}✓ ID gerado automaticamente:{Colors.ENDC} {Colors.BOLD}{conv_id}{Colors.ENDC}")
        
        # Perguntar se quer adicionar membros
        add_members = input(f"\n{Colors.CYAN}Adicionar membros agora? (s/N):{Colors.ENDC} ").strip().lower()
        
        members = []
        if add_members == 's':
            print(f"\n{Colors.CYAN}💡 Digite os IDs dos membros (formato: instagram:@usuario ou whatsapp:+55...):{Colors.ENDC}")
            print(f"{Colors.CYAN}   Digite 'fim' quando terminar{Colors.ENDC}\n")
            
            while True:
                member = input(f"{Colors.CYAN}Membro {len(members) + 1} (ou 'fim'):{Colors.ENDC} ").strip()
                if member.lower() == 'fim':
                    break
                if member:
                    members.append(member)
                    print(f"{Colors.GREEN}  ✓ Adicionado: {member}{Colors.ENDC}")
        
        # Salvar na memória para uso posterior
        self.current_conversation = conv_id
        self.conversation_names[conv_id] = {
            'name': conv_name,
            'members': members,
            'created_at': datetime.now().isoformat()
        }
        
        print(f"\n{Colors.GREEN}✅ Conversa criada com sucesso!{Colors.ENDC}")
        print(f"  {Colors.BOLD}Nome:{Colors.ENDC} {conv_name}")
        print(f"  {Colors.BOLD}ID:{Colors.ENDC} {conv_id}")
        if members:
            print(f"  {Colors.BOLD}Membros:{Colors.ENDC} {len(members)}")
            for m in members:
                print(f"    • {m}")
        print(f"\n{Colors.YELLOW}💡 Agora você pode enviar mensagens nesta conversa (opção 5){Colors.ENDC}")
        print(f"{Colors.YELLOW}   O ID foi selecionado automaticamente.{Colors.ENDC}")
    
    def _decode_jwt(self, token: str) -> Optional[Dict]:
        """Decodifica JWT para extrair o user_id do campo 'sub'"""
        try:
            # JWT tem 3 partes separadas por '.': header.payload.signature
            parts = token.split('.')
            if len(parts) != 3:
                return None
            
            # Decodificar payload (segunda parte)
            payload = parts[1]
            # Adicionar padding se necessário
            padding = 4 - len(payload) % 4
            if padding != 4:
                payload += '=' * padding
            
            decoded = base64.urlsafe_b64decode(payload)
            return json.loads(decoded)
        except Exception as e:
            print(f"{Colors.RED}Erro ao decodificar token: {e}{Colors.ENDC}")
            return None
    
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
                
                # Decodificar JWT para extrair user_id do campo 'sub'
                token_payload = self._decode_jwt(self.token)
                if token_payload:
                    self.current_user_id = token_payload.get("sub")  # 'sub' contém o user_id
                
                print(f"{Colors.GREEN}✓ Autenticado com sucesso!{Colors.ENDC}")
                print(f"  Usuário: {Colors.BOLD}{username}{Colors.ENDC}")
                if self.current_user_id:
                    print(f"  User ID: {self.current_user_id[:20]}...")
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
            print(f"{Colors.RED}❌ Você precisa autenticar primeiro (opção 2){Colors.ENDC}")
            return
        
        print(f"\n{Colors.BOLD}📨 Enviar Mensagem{Colors.ENDC}")
        
        # Usar conversa atual se existir, senão pedir
        if self.current_conversation:
            print(f"{Colors.GREEN}✓ Usando conversa atual:{Colors.ENDC} {Colors.BOLD}{self.current_conversation}{Colors.ENDC}")
            use_current = input(f"{Colors.CYAN}Usar esta conversa? (S/n):{Colors.ENDC} ").strip().lower()
            
            if use_current in ['', 's', 'y', 'sim', 'yes']:
                conversation_id = self.current_conversation
            else:
                conversation_id = input(f"{Colors.CYAN}Conversation ID:{Colors.ENDC} ").strip()
        else:
            conversation_id = input(f"{Colors.CYAN}Conversation ID:{Colors.ENDC} ").strip()
            print(f"{Colors.YELLOW}💡 Dica: Crie uma conversa primeiro (opção 4) para não precisar digitar o ID{Colors.ENDC}")
        
        recipient_id = input(f"{Colors.CYAN}Recipient ID (ex: whatsapp:+5511999998888 ou instagram:@usuario):{Colors.ENDC} ").strip()
        content = input(f"{Colors.CYAN}Mensagem:{Colors.ENDC} ").strip()
        
        if not all([conversation_id, recipient_id, content]):
            print(f"{Colors.RED}❌ Todos os campos são obrigatórios{Colors.ENDC}")
            return
        
        try:
            payload = {
                "conversation_id": conversation_id,
                "recipient_id": recipient_id,
                "content": content
            }
            
            # Não enviar sender_id - API extrai do token JWT
            
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
                "recipient_id": recipient_id,
                "content": content,
                "file_id": file_id
            }
            
            # Não enviar sender_id - API extrai do token JWT
            
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
        """Lista mensagens de uma conversa ou de todas as conversas"""
        if not self.token:
            print(f"{Colors.RED}❌ Você precisa autenticar primeiro (opção 1){Colors.ENDC}")
            return
        
        print(f"\n{Colors.BOLD}💬 Listar Mensagens{Colors.ENDC}")
        
        conversation_id = input(f"{Colors.CYAN}Conversation ID (deixe vazio para ver TODAS):{Colors.ENDC} ").strip()
        limit = input(f"{Colors.CYAN}Limite por conversa (padrão 10):{Colors.ENDC} ").strip() or "10"
        
        # Se não especificar conversation_id, mostra mensagem instrucional
        if not conversation_id:
            print(f"\n{Colors.YELLOW}📋 Mostrando mensagens de TODAS as suas conversas...{Colors.ENDC}\n")
            self._show_recent_conversations()
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
                    print(f"  {Colors.CYAN}Conversa:{Colors.ENDC} {msg.get('conversation_id')}")
                    print(f"  {Colors.CYAN}Mensagem:{Colors.ENDC} {msg.get('content')}")
                    print(f"  {Colors.CYAN}Status:{Colors.ENDC} {status_color}{msg.get('status')}{Colors.ENDC}")
                    
                    if msg.get('file_id'):
                        print(f"  {Colors.CYAN}📎 Arquivo:{Colors.ENDC} {msg.get('file_id')}")
                    
                    print(f"  {Colors.CYAN}ID:{Colors.ENDC} {msg.get('message_id')}")
                    print()
                
            else:
                print(f"{Colors.RED}❌ Erro ao listar: {response.status_code}{Colors.ENDC}")
        except requests.exceptions.RequestException as e:
            print(f"{Colors.RED}❌ Erro de conexão: {e}{Colors.ENDC}")
    
    def _show_recent_conversations(self):
        """Mostra conversas recentes com mensagens"""
        print(f"{Colors.YELLOW}💡 Dica: Use a opção 3 para ver a lista de conversas primeiro{Colors.ENDC}\n")
        print(f"{Colors.CYAN}Conversas recentes que você criou nesta sessão:{Colors.ENDC}\n")
        
        if self.conversation_names:
            for conv_id, info in self.conversation_names.items():
                print(f"{Colors.BOLD}• {info.get('name', conv_id)}{Colors.ENDC}")
                print(f"  ID: {conv_id}")
                members = info.get('members', [])
                if members:
                    print(f"  Membros: {', '.join(members[:3])}")
                print()
        else:
            print(f"{Colors.YELLOW}Nenhuma conversa criada nesta sessão.{Colors.ENDC}")
            print(f"{Colors.CYAN}Use a opção 4 para criar uma nova conversa!{Colors.ENDC}")
    
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
    
    def list_identities(self):
        """Lista identidades vinculadas (WhatsApp/Instagram)"""
        if not self.token:
            print(f"{Colors.RED}❌ Você precisa autenticar primeiro (opção 2){Colors.ENDC}")
            return
        
        print(f"\n{Colors.BOLD}🔗 Minhas Identidades Vinculadas{Colors.ENDC}")
        
        try:
            response = requests.get(
                f"{self.api_url}/v1/users/identities",
                headers={"Authorization": f"Bearer {self.token}"},
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                identities = data.get("identities", [])
                
                if not identities:
                    print(f"\n{Colors.YELLOW}Nenhuma identidade vinculada ainda.{Colors.ENDC}")
                    print(f"{Colors.CYAN}💡 Dica: Vincule WhatsApp ou Instagram ao registrar um novo usuário (opção 1){Colors.ENDC}")
                    return
                
                print(f"\n{Colors.GREEN}✓ Encontradas {len(identities)} identidades:{Colors.ENDC}\n")
                
                for identity in identities:
                    platform = identity.get('platform', 'unknown')
                    value = identity.get('value', 'N/A')
                    verified = identity.get('verified', False)
                    linked_at = identity.get('linked_at', 'N/A')
                    
                    # Ícones por plataforma
                    icon = "📱" if platform == "whatsapp" else "📷" if platform == "instagram" else "🔗"
                    verified_badge = "✓" if verified else "⏳"
                    
                    print(f"{icon} {Colors.BOLD}{platform.capitalize()}{Colors.ENDC}")
                    print(f"   Valor: {value}")
                    print(f"   Status: {verified_badge} {'Verificado' if verified else 'Não verificado'}")
                    print(f"   Vinculado em: {linked_at[:19] if len(linked_at) > 19 else linked_at}")
                    print()
                
                # Mostrar opções
                print(f"{Colors.CYAN}💡 Com essas identidades, você pode:{Colors.ENDC}")
                print(f"   • Receber mensagens de WhatsApp em {[i['value'] for i in identities if i['platform']=='whatsapp']}")
                print(f"   • Receber mensagens de Instagram em {[i['value'] for i in identities if i['platform']=='instagram']}")
                print(f"   • Ser encontrado por outros usuários usando essas identidades")
                
            elif response.status_code == 401:
                print(f"{Colors.RED}❌ Token expirado. Faça login novamente (opção 2){Colors.ENDC}")
                self.token = None
                self.current_user = None
                self.current_user_id = None
                
            else:
                print(f"{Colors.RED}❌ Erro ao listar identidades: {response.status_code}{Colors.ENDC}")
                if response.text:
                    print(f"{Colors.RED}  {response.text}{Colors.ENDC}")
                    
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
    
    def _poll_new_messages(self):
        """
        WebSocket connection handler for real-time notifications
        Replaces the old HTTP polling mechanism
        """
        def on_message(ws, message):
            """Callback quando recebe mensagem do WebSocket"""
            try:
                notification = json.loads(message)
                notif_type = notification.get("type")
                
                if notif_type == "connected":
                    print(f"\n{Colors.GREEN}✓ WebSocket conectado{Colors.ENDC}")
                    return
                
                if notif_type == "pong":
                    # Resposta ao ping, ignorar
                    return
                
                if notif_type == "new_message":
                    # Nova mensagem recebida
                    message_id = notification.get("message_id")
                    sender_id = notification.get("sender_id")
                    conversation_id = notification.get("conversation_id")
                    content = notification.get("content", "")
                    file_id = notification.get("file_id")
                    
                    # Ignorar se for do próprio usuário
                    if sender_id == self.current_user_id:
                        return
                    
                    # Mostrar notificação
                    self._show_notification({
                        "message_id": message_id,
                        "sender_id": sender_id,
                        "conversation_id": conversation_id,
                        "content": content,
                        "file_id": file_id,
                        "timestamp": notification.get("timestamp", int(time.time() * 1000))
                    })
                    
            except Exception as e:
                print(f"{Colors.RED}Erro processando notificação: {e}{Colors.ENDC}")
        
        def on_error(ws, error):
            """Callback em caso de erro"""
            if self.notification_enabled:
                print(f"\n{Colors.RED}✗ WebSocket error: {error}{Colors.ENDC}")
        
        def on_close(ws, close_status_code, close_msg):
            """Callback quando conexão fecha"""
            if self.notification_enabled:
                print(f"\n{Colors.YELLOW}⚠ WebSocket desconectado. Tentando reconectar...{Colors.ENDC}")
                # Tentar reconectar
                time.sleep(2)
                if self.notification_enabled:
                    self._start_websocket()
        
        def on_open(ws):
            """Callback quando conexão abre"""
            print(f"{Colors.GREEN}✓ Conectado ao servidor de notificações{Colors.ENDC}")
            
            # Iniciar thread de ping/pong para manter conexão viva
            def ping_thread():
                while self.notification_enabled and ws.sock and ws.sock.connected:
                    try:
                        ws.send(json.dumps({"type": "ping"}))
                        time.sleep(30)  # Ping a cada 30 segundos
                    except:
                        break
            
            threading.Thread(target=ping_thread, daemon=True).start()
        
        # Criar WebSocketApp
        # WebSocket precisa do user_id na URL
        ws_url = f"{self.websocket_url}?userId={self.current_user_id}"
        print(f"{Colors.CYAN}Conectando ao WebSocket: {ws_url}{Colors.ENDC}")
        
        self.ws = websocket.WebSocketApp(
            ws_url,
            on_message=on_message,
            on_error=on_error,
            on_close=on_close,
            on_open=on_open
        )
        
        # Executar (blocking call)
        self.ws.run_forever()
    
    def _start_websocket(self):
        """Inicia thread de WebSocket"""
        if self.ws_thread and self.ws_thread.is_alive():
            return
        
        self.ws_thread = threading.Thread(
            target=self._poll_new_messages,
            daemon=True
        )
        self.ws_thread.start()
    
    def _show_notification(self, message: Dict):
        """Exibe notificação de nova mensagem no terminal"""
        sender = message.get('sender_id', 'Desconhecido')[:20]
        content = message.get('content', '(sem conteúdo)')[:60]
        timestamp = datetime.fromtimestamp(message.get('timestamp', 0) / 1000)
        has_file = message.get('file_id') is not None
        conversation_id = message.get('conversation_id', 'N/A')[:30]
        
        # Criar notificação visual com borda
        print(f"\n{Colors.YELLOW}{'═' * 70}{Colors.ENDC}")
        print(f"{Colors.BOLD}{Colors.CYAN}🔔 NOVA MENSAGEM RECEBIDA!{Colors.ENDC}")
        print(f"{Colors.YELLOW}{'═' * 70}{Colors.ENDC}")
        print(f"  {Colors.BOLD}Conversa:{Colors.ENDC} {conversation_id}...")
        print(f"  {Colors.BOLD}De:{Colors.ENDC} {sender}")
        print(f"  {Colors.BOLD}Mensagem:{Colors.ENDC} {content}{'...' if len(message.get('content', '')) > 60 else ''}")
        if has_file:
            print(f"  {Colors.CYAN}📎 Mensagem com arquivo anexado{Colors.ENDC}")
        print(f"  {Colors.BOLD}Horário:{Colors.ENDC} {timestamp.strftime('%H:%M:%S')}")
        print(f"{Colors.YELLOW}{'═' * 70}{Colors.ENDC}")
        print(f"{Colors.CYAN}💡 Use a opção 7 para ver a conversa completa{Colors.ENDC}\n")
        
        # Tocar beep se terminal suportar
        print("\a", end="")  # ASCII bell
    
    def toggle_notifications(self):
        """Ativa/desativa sistema de notificações em tempo real (WebSocket)"""
        if not self.token:
            print(f"\n{Colors.RED}❌ Você precisa autenticar primeiro (opção 2){Colors.ENDC}")
            return
        
        if self.notification_enabled:
            # Desativar notificações
            print(f"\n{Colors.YELLOW}🔕 Desativando notificações...{Colors.ENDC}")
            self.notification_enabled = False
            self.stop_notifications.set()
            
            if self.ws:
                self.ws.close()
                self.ws = None
            
            if self.ws_thread:
                self.ws_thread.join(timeout=5)
                self.ws_thread = None
            
            print(f"{Colors.GREEN}✓ Notificações desativadas{Colors.ENDC}")
        else:
            # Ativar notificações
            print(f"\n{Colors.CYAN}🔔 Ativando notificações em tempo real...{Colors.ENDC}")
            print(f"{Colors.YELLOW}Conectando ao servidor de notificações via WebSocket{Colors.ENDC}")
            
            # Iniciar WebSocket
            self.stop_notifications.clear()
            self.notification_enabled = True
            self._start_websocket()
            
            print(f"{Colors.GREEN}✓ Notificações ativadas!{Colors.ENDC}")
            print(f"{Colors.CYAN}Você será notificado em tempo real quando receber novas mensagens.{Colors.ENDC}")
    
    def _initialize_seen_messages(self):
        """Deprecated - não mais necessário com WebSocket"""
        pass
    
    def run(self):
        """Loop principal do CLI"""
        self.print_header()
        
        while True:
            status_parts = []
            
            if self.current_user:
                status_parts.append(f"{Colors.GREEN}👤 Logado como: {Colors.BOLD}{self.current_user}{Colors.ENDC}")
                if self.current_conversation:
                    conv_short = self.current_conversation[:40] + ('...' if len(self.current_conversation) > 40 else '')
                    status_parts.append(f"{Colors.CYAN}💬 Conversa: {Colors.BOLD}{conv_short}{Colors.ENDC}")
                if self.notification_enabled:
                    status_parts.append(f"{Colors.GREEN}🔔 Notificações: ATIVAS{Colors.ENDC}")
            else:
                status_parts.append(f"{Colors.YELLOW}⚠ Não autenticado{Colors.ENDC}")
            
            if status_parts:
                print(f"\n{' | '.join(status_parts)}")
            
            self.print_menu()
            
            choice = input(f"{Colors.BOLD}Escolha uma opção:{Colors.ENDC} ").strip()
            
            if choice == "1":
                self.register_user()
            elif choice == "2":
                self.authenticate()
            elif choice == "3":
                self.list_conversations()
            elif choice == "4":
                self.create_conversation()
            elif choice == "5":
                self.send_message()
            elif choice == "6":
                self.send_message_with_file()
            elif choice == "7":
                self.list_messages()
            elif choice == "8":
                self.upload_file()
            elif choice == "9":
                self.download_file()
            elif choice == "10":
                self.list_identities()
            elif choice == "11":
                self.check_infrastructure()
            elif choice == "12":
                self.toggle_notifications()
            elif choice == "13":
                os.system('clear' if os.name != 'nt' else 'cls')
                self.print_header()
            elif choice == "0":
                # Parar notificações antes de sair
                if self.notification_enabled:
                    self.notification_enabled = False
                    self.stop_notifications.set()
                    if self.ws:
                        self.ws.close()
                    if self.ws_thread:
                        self.ws_thread.join(timeout=2)
                
                print(f"\n{Colors.CYAN}Até logo! 👋{Colors.ENDC}\n")
                sys.exit(0)
            else:
                print(f"{Colors.RED}❌ Opção inválida{Colors.ENDC}")
            
            # Não pausar se notificações estão ativas (para não perder notificações)
            if not self.notification_enabled:
                input(f"\n{Colors.YELLOW}Pressione ENTER para continuar...{Colors.ENDC}")

def main():
    """Ponto de entrada do CLI"""
    api_url = os.getenv("CHAT4ALL_API_URL", "http://localhost:8080")
    websocket_url = os.getenv("CHAT4ALL_WEBSOCKET_URL", "ws://localhost:8085")
    
    cli = Chat4AllCLI(api_url, websocket_url)
    
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
