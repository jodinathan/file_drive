#!/usr/bin/env bash
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Uso: $0 NomeDaClasse"
  exit 1
fi

CLASS_NAME="$1"
PROJECT_ROOT=$(pwd)

# Caminho do Analysis Server (Flutter Dart SDK)
ANALYSIS_SERVER="/Users/jonathanrezende/Dart/flutter/bin/cache/dart-sdk/bin/snapshots/analysis_server.dart.snapshot"

if [ ! -f "$ANALYSIS_SERVER" ]; then
  echo "❌ Não encontrou o Analysis Server em: $ANALYSIS_SERVER"
  exit 1
fi

# Arquivos temporários
FIFO_FILE=$(mktemp)
rm -f "$FIFO_FILE"
mkfifo "$FIFO_FILE"

SERVER_OUT=$(mktemp)
trap 'rm -f "$FIFO_FILE" "$SERVER_OUT"; kill $SERVER_PID 2>/dev/null || true' EXIT

# Inicia o servidor LSP
dart --disable-dart-dev "$ANALYSIS_SERVER" --lsp < "$FIFO_FILE" > "$SERVER_OUT" &
SERVER_PID=$!

exec 3>"$FIFO_FILE"
exec 4<"$SERVER_OUT"

send_request() {
  local PAYLOAD="$1"
  local CONTENT_LENGTH
  CONTENT_LENGTH=$(echo -n "$PAYLOAD" | wc -c)
  {
    echo -en "Content-Length: $CONTENT_LENGTH\r\n\r\n"
    echo -n "$PAYLOAD"
  } >&3
}

read_response() {
  while read -r line <&4; do
    if [[ "$line" =~ ^\{ ]]; then
      echo "$line"
      break
    fi
  done
}

# 1️⃣ Handshake
send_request '{"id":1,"method":"server.getVersion"}'
read_response >/dev/null

# 2️⃣ Configura raiz de análise
send_request "{\"id\":2,\"method\":\"analysis.setAnalysisRoots\",\"params\":{\"included\":[\"$PROJECT_ROOT\"],\"excluded\":[]}}"
read_response >/dev/null

# 3️⃣ Aguarda alguns segundos para análise inicial
echo "⏳ Aguardando análise do projeto..."
sleep 3  # aumente se o projeto for grande

# 4️⃣ Busca a classe usando workspace/symbol
send_request "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"workspace/symbol\",\"params\":{\"query\":\"$CLASS_NAME\"}}"
RESULT=$(read_response)

# 5️⃣ Filtra resultados que batem exatamente com o nome da classe
MATCH=$(echo "$RESULT" | jq -r \
  '.result[]? | select(.name=="'"$CLASS_NAME"'") | "\(.location.uri | sub("^file://";"")):\(.location.range.start.line+1)"')

if [ -z "$MATCH" ]; then
  echo "⚠️ Classe '$CLASS_NAME' não encontrada."
else
  echo "$MATCH"
fi

# 6️⃣ Encerra o servidor
send_request '{"id":9,"method":"server.shutdown"}' >/dev/null
