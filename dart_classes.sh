#!/usr/bin/env bash
set -euo pipefail

#########################
# Configuração do servidor
#########################
PROJECT_ROOT=$(pwd)
ANALYSIS_SERVER="/Users/jonathanrezende/Dart/flutter/bin/cache/dart-sdk/bin/snapshots/analysis_server.dart.snapshot"

if [ ! -f "$ANALYSIS_SERVER" ]; then
  echo "❌ Não encontrou o Analysis Server em: $ANALYSIS_SERVER"
  exit 1
fi

#########################
# Infra de IPC (FIFO + arquivos)
#########################
FIFO_FILE=$(mktemp)
rm -f "$FIFO_FILE"
mkfifo "$FIFO_FILE"

SERVER_OUT=$(mktemp)
trap 'rm -f "$FIFO_FILE" "$SERVER_OUT"; kill $SERVER_PID 2>/dev/null || true' EXIT

# Inicia o servidor LSP (stdin = FIFO, stdout = SERVER_OUT)
dart --disable-dart-dev "$ANALYSIS_SERVER" --lsp < "$FIFO_FILE" > "$SERVER_OUT" &
SERVER_PID=$!

# Abrimos FD 3 para escrever no FIFO, e FD 4 para ler do arquivo de saída
exec 3>"$FIFO_FILE"
exec 4<"$SERVER_OUT"

#########################
# Utilitários LSP
#########################
send_request() {
  local PAYLOAD="$1"
  local CONTENT_LENGTH
  CONTENT_LENGTH=$(printf "%s" "$PAYLOAD" | wc -c | tr -d ' ')
  {
    printf "Content-Length: %s\r\n\r\n" "$CONTENT_LENGTH"
    printf "%s" "$PAYLOAD"
  } >&3
  echo "[DEBUG ENVIADO] $PAYLOAD" >&2
}

# Lê UMA mensagem LSP completa do FD 4, respeitando Content-Length, e imprime o JSON no stdout
read_message() {
  local HEADER LENGTH
  while IFS= read -r HEADER <&4; do
    # Cabeçalho vazio indica fim dos headers
    if [[ -z "$HEADER" ]]; then
      continue
    fi
    if [[ "$HEADER" =~ ^Content-Length:\ ([0-9]+) ]]; then
      LENGTH="${BASH_REMATCH[1]}"
      # Pode haver Content-Type, então consome headers até linha em branco:
      while IFS= read -r HEADER <&4; do
        [[ -z "$HEADER" ]] && break
      done
      # Lê exatamente LENGTH bytes do corpo da mensagem do FD4
      local BODY
      BODY=$(dd bs=1 count="$LENGTH" <&4 2>/dev/null || true)
      echo "[DEBUG RECEBIDO] ${#BODY} bytes" >&2
      echo "$BODY"
      return 0
    fi
    # se não achar Content-Length, continua lendo próximas linhas de header
  done
  return 1
}

# Envia uma request com ID e espera a resposta com o mesmo ID.
# Imprime o JSON de resposta no stdout.
request_and_wait() {
  local ID="$1"
  local PAYLOAD="$2"
  send_request "$PAYLOAD"
  while true; do
    local MSG
    MSG=$(read_message) || continue
    # Se for resposta do mesmo id, retorna
    if echo "$MSG" | jq -e --argjson ID "$ID" '.id? == $ID' >/dev/null 2>&1; then
      echo "$MSG"
      return 0
    else
      # Eventos intermediários (status, publishDiagnostics, etc.)
      local EV
      EV=$(echo "$MSG" | jq -r '.method? // empty' 2>/dev/null || true)
      if [ -n "${EV:-}" ]; then
        echo "[DEBUG EVENTO] $EV" >&2
      else
        echo "[DEBUG IGNORADO] $(echo "$MSG" | jq -c 'del(.params?.items?[:] | .[]? )' 2>/dev/null || echo "$MSG")" >&2
      fi
    fi
  done
}

new_id() { awk -v min=1000 -v max=999999 'BEGIN{srand(); print int(min+rand()*(max-min+1))}'; }

#########################
# Handshake LSP
#########################
INIT_ID=$(new_id)
INIT_RESP=$(request_and_wait "$INIT_ID" "$(jq -nc \
  --arg root "file://$PROJECT_ROOT" \
  --argjson pid $$ \
  '{jsonrpc:"2.0",id:'"$INIT_ID"',method:"initialize",params:{processId:$pid,rootUri:$root,capabilities:{}}}')")

# Notificação "initialized"
send_request '{"jsonrpc":"2.0","method":"initialized","params":{}}'

# analysis.setAnalysisRoots
ROOT_ID=$(new_id)
_=$(request_and_wait "$ROOT_ID" "$(jq -nc \
  --arg inc "$PROJECT_ROOT" \
  '{jsonrpc:"2.0",id:'"$ROOT_ID"',method:"analysis.setAnalysisRoots",params:{included:[$inc],excluded:[]}}')")

echo "✅ Analysis Server pronto. Coletando classes…"

#########################
# Coleta de classes (varre várias queries)
#########################
# Consultas para cobrir convenções de nomes de classes (Dart: PascalCase; privadas começam com "_")
QUERIES=("_" "A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z" \
         "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z")

declare -A SEEN
CLASSES_TSV=$(mktemp)  # formato: name<TAB>uri<TAB>line<TAB>character

for Q in "${QUERIES[@]}"; do
  WS_ID=$(new_id)
  RESP=$(request_and_wait "$WS_ID" "$(jq -nc --arg q "$Q" \
    '{jsonrpc:"2.0",id:'"$WS_ID"',method:"workspace/symbol",params:{query:$q}}')")

  # Filtra apenas classes (kind == 5)
  # Gera linhas TSV: name\turi\tline\tcharacter
  while IFS=$'\t' read -r NAME URI LINE CHAR; do
    [ -z "${NAME:-}" ] && continue
    KEY="$NAME|$URI|$LINE|$CHAR"
    if [[ -z "${SEEN[$KEY]+x}" ]]; then
      SEEN[$KEY]=1
      printf "%s\t%s\t%s\t%s\n" "$NAME" "$URI" "$LINE" "$CHAR" >> "$CLASSES_TSV"
    fi
  done < <(echo "$RESP" | jq -r '.result[]? | select(.kind==5) |
           [.name, .location.uri, .location.range.start.line, .location.range.start.character] | @tsv' 2>/dev/null || true)
done

TOTAL_CLASSES=$(wc -l < "$CLASSES_TSV" | tr -d ' ')
echo "📚 Classes coletadas: $TOTAL_CLASSES"

if [ "$TOTAL_CLASSES" -eq 0 ]; then
  echo "⚠️ Nenhuma classe encontrada via workspace/symbol. Tente ajustar as QUERIES."
  # Encerra com elegância
  SHUT_ID=$(new_id)
  _=$(request_and_wait "$SHUT_ID" '{"jsonrpc":"2.0","id":'"$SHUT_ID"',"method":"server.shutdown"}')
  exit 0
fi

#########################
# Para cada classe, conta referências
#########################
RESULTS_TSV=$(mktemp) # formato: count<TAB>name<TAB>filepath:line

# Itera por cada classe encontrada
while IFS=$'\t' read -r NAME URI LINE CHAR; do
  FILEPATH=$(echo "$URI" | sed 's|^file://||')
  # Request de referências (inclui posição da definição)
  REF_ID=$(new_id)
  REQ=$(jq -nc \
    --arg uri "$URI" \
    --argjson l "$LINE" \
    --argjson c "$CHAR" \
    '{jsonrpc:"2.0",id:'"$REF_ID"',"method":"textDocument/references",
      params:{textDocument:{uri:$uri},position:{line:$l,character:$c},context:{includeDeclaration:false}}}')
  RESP=$(request_and_wait "$REF_ID" "$REQ")
  COUNT=$(echo "$RESP" | jq '(.result // []) | length' 2>/dev/null || echo 0)

  printf "%s\t%s\t%s:%s\n" "$COUNT" "$NAME" "$FILEPATH" "$((LINE+1))" >> "$RESULTS_TSV"
done < "$CLASSES_TSV"

#########################
# Saída ordenada (mais usados primeiro)
#########################
echo
echo "================  USOS POR CLASSE  ================"
echo "usos | Classe | Caminho:linha"
echo "---------------------------------------------------"
# sort numérico desc pela primeira coluna; limita a 500 linhas para visual
awk -F'\t' '{printf "%5d | %s | %s\n", $1, $2, $3}' "$RESULTS_TSV" | sort -r -n -k1,1

#########################
# Encerramento
#########################
SHUT_ID=$(new_id)
_=$(request_and_wait "$SHUT_ID" '{"jsonrpc":"2.0","id":'"$SHUT_ID"',"method":"server.shutdown"}')
echo "✅ Analysis Server encerrado."
