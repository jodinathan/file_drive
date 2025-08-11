#!/bin/bash

# Script para configurar OAuth no macOS
# Este script substitui os placeholders pelo clientId real

set -e

echo "🔧 Configurando OAuth para macOS..."

# Verifica se a variável de ambiente GOOGLE_CLIENT_ID está definida
if [ -z "$GOOGLE_CLIENT_ID" ]; then
    echo "❌ Erro: Variável de ambiente GOOGLE_CLIENT_ID não está definida"
    echo "📝 Configure com: export GOOGLE_CLIENT_ID=\"sua_client_id.apps.googleusercontent.com\""
    exit 1
fi

# Extrai o número do client ID (parte antes do hífen)
CLIENT_NUMBER=$(echo "$GOOGLE_CLIENT_ID" | cut -d'-' -f1)

if [ -z "$CLIENT_NUMBER" ]; then
    echo "❌ Erro: Não foi possível extrair o número do clientId"
    exit 1
fi

# Caminho do arquivo Info.plist
PLIST_FILE="macos/Runner/Info.plist"

if [ ! -f "$PLIST_FILE" ]; then
    echo "❌ Erro: Arquivo $PLIST_FILE não encontrado"
    exit 1
fi

# Substitui o placeholder pelo valor real
SCHEME="com.googleusercontent.apps.$CLIENT_NUMBER"

echo "📱 Configurando scheme: $SCHEME"

# Faz backup do arquivo original
cp "$PLIST_FILE" "$PLIST_FILE.backup"

# Substitui o placeholder
sed -i.tmp "s/com\.googleusercontent\.apps\.YOUR_CLIENT_ID_NUMBER/$SCHEME/g" "$PLIST_FILE"
rm "$PLIST_FILE.tmp"

echo "✅ Configuração concluída!"
echo "📄 Backup salvo em: $PLIST_FILE.backup"
echo "🔗 Scheme configurado: $SCHEME"