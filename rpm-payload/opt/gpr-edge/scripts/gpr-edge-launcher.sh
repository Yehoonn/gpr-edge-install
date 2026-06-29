#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$INSTALL_DIR"

CONFIG="${INSTALL_DIR}/config.yaml"
BINARY="${INSTALL_DIR}/gpr-edge"
HEALTH_SCRIPT="${INSTALL_DIR}/scripts/health-check.sh"
RUNTIME_DIR="${GPR_EDGE_RUNTIME_DIR:-/var/lib/gpr-edge}"
LOG_DIR="${RUNTIME_DIR}/log"

export GPR_EDGE_RUNTIME_DIR="$RUNTIME_DIR"

ensure_runtime_dirs() {
  if [[ -d "$RUNTIME_DIR/data" && -d "$LOG_DIR" ]]; then
    return 0
  fi
  if command -v pkexec >/dev/null 2>&1; then
    pkexec /bin/sh -c "install -d -m 1777 '${RUNTIME_DIR}/data' '${LOG_DIR}'" || return 1
  elif [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    install -d -m 1777 "${RUNTIME_DIR}/data" "${LOG_DIR}"
  else
    sudo install -d -m 1777 "${RUNTIME_DIR}/data" "${LOG_DIR}"
  fi
}

ensure_first_run_config() {
  if [[ -f "$CONFIG" ]]; then
    return 0
  fi

  echo "GPR Edge: 초기 네트워크 설정이 필요합니다."
  if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && command -v zenity >/dev/null 2>&1; then
    zenity --info --title="GPR Edge" \
      --text="GPR Edge 네트워크·장비 설정 화면이 열립니다.\n관리자 암호를 입력해 주세요." \
      2>/dev/null || true
  fi

  if command -v pkexec >/dev/null 2>&1; then
    pkexec /usr/bin/gpr-edge-setup || return 1
  elif [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    /usr/bin/gpr-edge-setup || return 1
  else
    sudo /usr/bin/gpr-edge-setup || return 1
  fi

  [[ -f "$CONFIG" ]] || {
    echo "설정 파일이 없습니다. 메뉴 「GPR Edge 설정」을 실행하세요." >&2
    return 1
  }
}

if [[ ! -x "$BINARY" ]]; then
  echo "gpr-edge binary not found: ${BINARY}" >&2
  read -r -p "Press Enter to close..."
  exit 1
fi

ensure_runtime_dirs || {
  echo "런타임 디렉터리 생성 실패: ${RUNTIME_DIR}" >&2
  read -r -p "Press Enter to close..."
  exit 1
}

ensure_first_run_config || {
  read -r -p "Press Enter to close..."
  exit 1
}

if pgrep -f "${INSTALL_DIR}/gpr-edge" >/dev/null 2>&1; then
  PORT="$(grep -E '^[[:space:]]*port:' "$CONFIG" | head -1 | awk '{print $2}')"
  echo "GPR Edge is already running."
  echo "Health: http://127.0.0.1:${PORT}/health"
  read -r -p "Press Enter to close..."
  exit 0
fi

"${BINARY}" --config "$CONFIG" &
SERVER_PID=$!
sleep 3

PORT="$(grep -E '^[[:space:]]*port:' "$CONFIG" | head -1 | awk '{print $2}')"
if "$HEALTH_SCRIPT" "$PORT" 30; then
  echo "GPR Edge is ready. Health: http://127.0.0.1:${PORT}/health"
else
  echo "Health check failed. See ${LOG_DIR} for details." >&2
  kill "$SERVER_PID" 2>/dev/null || true
  read -r -p "Press Enter to close..."
  exit 1
fi

read -r -p "Press Enter to close..."
wait "$SERVER_PID" 2>/dev/null || true
