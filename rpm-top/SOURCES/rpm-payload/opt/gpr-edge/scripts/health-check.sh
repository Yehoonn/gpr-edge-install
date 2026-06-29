#!/usr/bin/env bash
set -euo pipefail

PORT="${1:?port required}"
TIMEOUT="${2:-60}"
URL="http://127.0.0.1:${PORT}/health"
DEADLINE=$((SECONDS + TIMEOUT))

while (( SECONDS < DEADLINE )); do
  if response="$(curl -sf --max-time 2 "$URL" 2>/dev/null)"; then
    if printf '%s' "$response" | grep -q '"status"[[:space:]]*:[[:space:]]*"success"'; then
      echo "Health check OK: ${URL}"
      exit 0
    fi
  fi
  sleep 1
done

echo "Health check failed: ${URL} (timeout ${TIMEOUT}s)" >&2
exit 1
