#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT=$(pwd)
ANALYSIS_SERVER="/Users/jonathanrezende/Dart/flutter/bin/cache/dart-sdk/bin/snapshots/analysis_server.dart.snapshot"

if [ ! -f "$ANALYSIS_SERVER" ]; then
  echo "❌ Não encontrou o Analysis Server em: $ANALYSIS_SERVER"
  exit 1
fi

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

# Tail em background para logs contínuos
tail -f "$SERVER_OUT" | while read -r LINE; do
  echo "[DEBUG RECEBIDO] $LINE"
done &

TAIL_PID=$!

send_request() {
  local PAYLOAD="$1"
  local CONTENT_LENGTH
  CONTENT_LENGTH=$(echo -n "$PAYLOAD" | wc -c)
  {
    echo -en "Content-Length: $CONTENT_LENGTH\r\n\r\n"
    echo -n "$PAYLOAD"
  } >&3
  echo "[DEBUG ENVIADO] $PAYLOAD"
}

# Inicialização obrigatória do LSP
INIT_ID=$((RANDOM % 100000))
send_request "{\"jsonrpc\":\"2.0\",\"id\":$INIT_ID,\"method\":\"initialize\",\"params\":{\"processId\":$$,\"rootUri\":\"file://$PROJECT_ROOT\",\"capabilities\":{}}}"
sleep 1

# Configura a raiz de análise
ROOT_ID=$((RANDOM % 100000))
send_request "{\"jsonrpc\":\"2.0\",\"id\":$ROOT_ID,\"method\":\"analysis.setAnalysisRoots\",\"params\":{\"included\":[\"$PROJECT_ROOT\"],\"excluded\":[]}}"
sleep 2

echo "✅ Analysis Server iniciado corretamente. Digite o nome da classe para buscar."

while true; do
  read -rp "Classe para buscar (ou 'exit' para sair): " CLASS_NAME
  [[ "$CLASS_NAME" == "exit" ]] && break

  REQUEST_ID=$((RANDOM % 100000))
  send_request "{\"jsonrpc\":\"2.0\",\"id\":$REQUEST_ID,\"method\":\"workspace/symbol\",\"params\":{\"query\":\"$CLASS_NAME\"}}"

  echo "[DEBUG] Aguardando resposta do Analysis Server para '$CLASS_NAME'..."

  # Loop de leitura até receber resposta com o id correto
  MATCH=""
  while true; do
    # Lê linha a linha do fifo (tail já imprime tudo, mas vamos filtrar)
    read -r LINE <&4 || continue

    # Ignora cabeçalhos
    [[ "$LINE" =~ ^Content-Length: ]] && continue
    [[ "$LINE" =~ ^Content-Type: ]] && continue
    [[ "$LINE" =~ ^$ ]] && continue

    # Verifica se é JSON
    if echo "$LINE" | jq empty >/dev/null 2>&1; then
      # Se tiver o id correto
      if echo "$LINE" | jq -e --argjson ID "$REQUEST_ID" '.id? == $ID' >/dev/null 2>&1; then
        MATCH=$(echo "$LINE" | jq -r \
          '.result[]? | select(.name=="'"$CLASS_NAME"'") | "\(.location.uri | sub("^file://";"")):\(.location.range.start.line+1)"')
        break
      fi
    fi
  done

  if [ -z "$MATCH" ]; then
    echo "⚠️ Classe '$CLASS_NAME' não encontrada."
  else
    echo "$MATCH"
  fi
done

# Encerra o servidor
SHUT_ID=$((RANDOM % 100000))
send_request "{\"jsonrpc\":\"2.0\",\"id\":$SHUT_ID,\"method\":\"server.shutdown\"}"
kill $TAIL_PID 2>/dev/null || true
echo "✅ Analysis Server encerrado."
