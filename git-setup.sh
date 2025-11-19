#!/bin/bash

# Git Quick Start - Chat4All
# Comandos úteis para commitar o projeto

echo "========================================"
echo "  Git Setup - Chat4All"
echo "========================================"
echo ""

# Verificar se já é um repositório Git
if [ -d .git ]; then
    echo "✓ Já é um repositório Git"
else
    echo "→ Inicializando repositório Git..."
    git init
    echo "✓ Git inicializado"
fi

echo ""
echo "→ Verificando status..."
git status --short

echo ""
echo "========================================"
echo "  Comandos Sugeridos"
echo "========================================"
echo ""
echo "1. Adicionar todos os arquivos:"
echo "   git add ."
echo ""
echo "2. Commit inicial:"
echo "   git commit -m 'feat: implementação completa da Entrega 1 - MVP funcional'"
echo ""
echo "3. Adicionar repositório remoto (substituir URL):"
echo "   git remote add origin https://github.com/seu-usuario/chat4alltijolim.git"
echo ""
echo "4. Push para GitHub:"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "========================================"
echo "  Arquivos Importantes"
echo "========================================"
echo ""
echo "✓ README.md - Documentação completa"
echo "✓ CONTRIBUTING.md - Guia de contribuição"
echo "✓ .gitignore - Arquivos ignorados"
echo "✓ docker-compose.yml - Infraestrutura"
echo "✓ demo-simple.sh - Demo funcional"
echo "✓ test-*.sh - Scripts de teste"
echo ""
echo "========================================"
echo "  Arquivos que NÃO serão commitados"
echo "========================================"
echo ""
echo "✗ target/ - Build artifacts"
echo "✗ *.class, *.jar - Compilados"
echo "✗ .idea/, *.iml - IDE configs"
echo "✗ *.log - Logs"
echo "✗ .env - Variáveis de ambiente"
echo ""
echo "========================================"
echo "  Estatísticas do Projeto"
echo "========================================"
echo ""

# Contar linhas de código Java
JAVA_LINES=$(find . -name "*.java" -not -path "*/target/*" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
echo "→ Linhas de código Java: ${JAVA_LINES:-0}"

# Contar arquivos
JAVA_FILES=$(find . -name "*.java" -not -path "*/target/*" | wc -l)
echo "→ Arquivos Java: $JAVA_FILES"

# Contar módulos
MODULES=$(find . -name "pom.xml" | wc -l)
echo "→ Módulos Maven: $MODULES"

echo ""
echo "========================================"
echo "  Ready to commit!"
echo "========================================"
