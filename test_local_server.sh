#!/bin/bash

# Script para testar o Local Server Provider
# Inicia o servidor local e permite testes de upload/download

set -e

SERVER_DIR="example/server"
STORAGE_DIR="./storage"
PORT=8080

echo "🚀 Local File Server Test Script"
echo "================================"

# Verificar se estamos no diretório correto
if [ ! -d "$SERVER_DIR" ]; then
    echo "❌ Erro: Execute este script da raiz do projeto file_drive"
    exit 1
fi

# Função para limpar o servidor ao sair
cleanup() {
    echo ""
    echo "🛑 Parando servidor..."
    if [ ! -z "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null || true
    fi
    echo "✅ Servidor parado"
}

# Configurar trap para cleanup
trap cleanup EXIT

# Criar diretório de storage se não existir
if [ ! -d "$STORAGE_DIR" ]; then
    mkdir -p "$STORAGE_DIR"
    echo "📁 Diretório de storage criado: $STORAGE_DIR"
fi

# Verificar se config.dart existe
if [ ! -f "$SERVER_DIR/lib/config.dart" ]; then
    echo "⚠️  config.dart não encontrado, criando a partir do exemplo..."
    cp "$SERVER_DIR/lib/config.example.dart" "$SERVER_DIR/lib/config.dart"
    echo "✅ config.dart criado"
fi

echo ""
echo "📋 Informações do Servidor:"
echo "   • Porta: $PORT"
echo "   • Storage: $(realpath $STORAGE_DIR)"
echo "   • URL: http://localhost:$PORT"
echo "   • Health: http://localhost:$PORT/health"
echo "   • OAuth: http://localhost:$PORT/auth/google"
echo ""

# Adicionar arquivos de teste se não existirem
echo "📝 Criando arquivos de teste..."
mkdir -p "$STORAGE_DIR/Documents"
mkdir -p "$STORAGE_DIR/Images"

# Arquivo de teste 1
if [ ! -f "$STORAGE_DIR/test_file.txt" ]; then
    cat > "$STORAGE_DIR/test_file.txt" << 'EOF'
Local File Server Test
======================

Este é um arquivo de teste para demonstrar o Local Server Provider.

Recursos testáveis:
✅ Listagem de arquivos
✅ Download de arquivos
✅ Upload de arquivos
✅ Criação de pastas
✅ Exclusão de arquivos

Server URL: http://localhost:8080
Storage Path: ./storage

EOF
fi

# Arquivo JSON de teste
if [ ! -f "$STORAGE_DIR/Documents/config.json" ]; then
    cat > "$STORAGE_DIR/Documents/config.json" << 'EOF'
{
  "server": "Local File Server",
  "version": "1.0.0",
  "features": [
    "file_listing",
    "file_download", 
    "file_upload",
    "folder_creation",
    "file_deletion"
  ],
  "test_data": {
    "created": "2025-08-13",
    "purpose": "Testing file operations",
    "status": "active"
  }
}
EOF
fi

# Arquivo de imagem simulado
if [ ! -f "$STORAGE_DIR/Images/sample.txt" ]; then
    cat > "$STORAGE_DIR/Images/sample.txt" << 'EOF'
Esta pasta é para imagens.
Faça upload de arquivos PNG, JPG ou GIF aqui através do widget!

Tipos suportados:
- PNG
- JPEG 
- GIF
- PDF
- DOCX
- XLSX
- TXT
- JSON
EOF
fi

echo "✅ Arquivos de teste criados"

echo ""
echo "🔧 Instalando dependências do servidor..."
cd "$SERVER_DIR"
dart pub get

echo ""
echo "🚀 Iniciando servidor local..."
dart run lib/main.dart &
SERVER_PID=$!

echo "⏳ Aguardando servidor inicializar..."
sleep 3

# Testar se servidor está funcionando
echo "🔍 Testando servidor..."
if curl -s http://localhost:$PORT/health > /dev/null; then
    echo "✅ Servidor funcionando!"
    
    echo ""
    echo "📱 Para testar no Flutter:"
    echo "   1. Execute o app exemplo: cd ../app && flutter run"
    echo "   2. Selecione 'Local Server' nos providers"
    echo "   3. Faça autenticação OAuth (ou use token de teste)"
    echo "   4. Teste upload, download e navegação"
    echo ""
    echo "🧪 Token de teste disponível: test_token_dev"
    echo "🔗 Health check: http://localhost:$PORT/health"
    echo ""
    echo "Pressione Ctrl+C para parar o servidor"
    
    # Manter servidor rodando
    wait $SERVER_PID
else
    echo "❌ Erro: Servidor não está respondendo"
    exit 1
fi