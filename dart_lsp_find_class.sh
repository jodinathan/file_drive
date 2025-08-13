#!/usr/bin/env bash
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Uso: $0 NomeDaClasse"
  exit 1
fi

CLASS_NAME="$1"
PROJECT_ROOT=$(pwd)

# Caminho correto do Analysis Server no seu setup
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

# Inicia o servidor
dart --disable-dart-dev "$ANALYSIS_SERVER" < "$FIFO_FILE" > "$SERVER_OUT" &
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

# Handshake
send_request '{"id":"1","method":"server.getVersion"}'
read_response >/dev/null

# Configura raiz de análise
send_request "{\"id\":\"2\",\"method\":\"analysis.setAnalysisRoots\",\"params\":{\"included\":[\"$PROJECT_ROOT\"],\"excluded\":[]}}"
read_response >/dev/null

# Busca pela classe
send_request "{\"id\":\"3\",\"method\":\"search.findTopLevelDeclarations\",\"params\":{\"pattern\":\"^$CLASS_NAME\$\"}}"
RESULT=$(read_response)

RESULT_ID=$(echo "$RESULT" | jq -r '.result.id')
if [ "$RESULT_ID" = "null" ]; then
  echo "⚠️ Classe '$CLASS_NAME' não encontrada."
  exit 0
fi

# Espera pelo evento com os resultados
while read -r line <&4; do
  if [[ "$line" =~ ^\{ ]] && echo "$line" | jq -e '.event=="search.results"' >/dev/null; then
    if echo "$line" | jq -e ".params.id==\"$RESULT_ID\"" >/dev/null; then
      echo "$line" | jq -r '.params.results[] | "\(.location.file):\(.location.startLine)"'
      break
    fi
  fi
done

# Encerra o servidor
send_request '{"id":"9","method":"server.shutdown"}' >/dev/null
