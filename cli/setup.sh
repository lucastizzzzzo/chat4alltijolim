#!/bin/bash
# Quick setup script para Chat4All CLI

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 Chat4All CLI - Quick Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 não encontrado. Por favor instale Python 3.8+"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
echo "✓ Python encontrado: $PYTHON_VERSION"

# Install dependencies
echo ""
echo "📦 Instalando dependências..."
pip3 install -q -r cli/requirements.txt || pip install -q -r cli/requirements.txt

# Make executable
chmod +x cli/chat4all-cli.py

echo "✓ Dependências instaladas"
echo ""

# Check if Docker is running
if ! docker-compose ps &> /dev/null; then
    echo "⚠  Docker Compose não está rodando"
    echo ""
    echo "Para iniciar a infraestrutura:"
    echo "  docker-compose up -d"
    echo ""
else
    # Check API Service
    if curl -s http://localhost:8082/health > /dev/null 2>&1; then
        echo "✓ API Service está online"
    else
        echo "⚠  API Service offline (esperando inicialização...)"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Setup completo!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Para executar o CLI:"
echo "  ./cli/chat4all-cli.py"
echo ""
echo "Ou adicione ao PATH:"
echo "  export PATH=\$PATH:\$PWD/cli"
echo "  chat4all-cli.py"
echo ""
