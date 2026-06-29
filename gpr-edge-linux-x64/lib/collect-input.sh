#!/usr/bin/env bash
# 설정 값 입력 (zenity GUI → dialog → 터미널 read 순 fallback)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

collect_with_browser() {
  local script="${LINUX_DIR}/scripts/configure-web.py"
  local out
  out="$(mktemp /tmp/gpr-edge-setup-XXXXXX.json)"
  if [[ ! -f "$script" ]]; then
    script="${SCRIPT_DIR}/../scripts/configure-web.py"
  fi
  command -v python3 >/dev/null 2>&1 || return 1
  [[ -f "$script" ]] || return 1

  log "브라우저 설정 마법사를 시작합니다 (WSL/zenity 미지원 환경)"
  python3 "$script" --output "$out" || { rm -f "$out"; return 1; }

  # shellcheck disable=SC1090
  eval "$(python3 - <<PY
import json, shlex
d = json.load(open(${out@Q}))
for k, v in d.items():
    print(f"export {k}={shlex.quote(str(v))}")
PY
)"
  rm -f "$out"
  export GPR_EDGE_ID GPR_IP ROBOT_ID ROBOT_IP GPR_API_PORT ROBOT_API_PORT SERIAL_PORT
  return 0
}

collect_with_zenity() {
  local page1 page2
  configure_gui_environment
  page1="$(zenity --forms --title="GPR Edge 설정 (1/2)" \
    --text="장비 식별 정보를 입력하세요.\n다음 페이지에서 네트워크·포트를 설정합니다." \
    --add-entry="GPR Edge ID (예: GPR-EDGE-001)" \
    --add-entry="GPR IP (예: 192.168.100.20)" \
    --add-entry="Robot ID (예: ROBOT-001)" \
    --separator="|" \
    --width=480 --height=280 \
    2>/dev/null)" || return 1

  page2="$(zenity --forms --title="GPR Edge 설정 (2/2)" \
    --text="네트워크 및 API 포트를 입력하세요.\n값은 config.yaml 및 device.json에 저장됩니다." \
    --add-entry="Robot IP (예: 192.168.100.10)" \
    --add-entry="GPR API Port (예: 8000)" \
    --add-entry="Robot API Port (예: 8080)" \
    --add-entry="GPR 시리얼 포트 (예: /dev/ttyUSB0)" \
    --separator="|" \
    --width=480 --height=320 \
    2>/dev/null)" || return 1

  IFS='|' read -r GPR_EDGE_ID GPR_IP ROBOT_ID <<< "$page1"
  IFS='|' read -r ROBOT_IP GPR_API_PORT ROBOT_API_PORT SERIAL_PORT <<< "$page2"
  export GPR_EDGE_ID GPR_IP ROBOT_ID ROBOT_IP GPR_API_PORT ROBOT_API_PORT SERIAL_PORT
  return 0
}

collect_with_dialog() {
  local tmp
  tmp="$(mktemp)"
  dialog --clear --backtitle "GPR Edge 설정" \
    --title "GPR Edge 설정 (1/2)" \
    --form "장비 식별 정보" 12 60 0 \
    "GPR Edge ID:" 1 1 "GPR-EDGE-001" 1 25 30 0 \
    "GPR IP:" 2 1 "192.168.100.20" 2 25 30 0 \
    "Robot ID:" 3 1 "ROBOT-001" 3 25 30 0 \
    2> "$tmp" || { rm -f "$tmp"; return 1; }

  mapfile -t page1 < "$tmp"
  dialog --clear --backtitle "GPR Edge 설정" \
    --title "GPR Edge 설정 (2/2)" \
    --form "네트워크·포트" 14 60 0 \
    "Robot IP:" 1 1 "192.168.100.10" 1 25 30 0 \
    "GPR API Port:" 2 1 "8000" 2 25 30 0 \
    "Robot API Port:" 3 1 "8080" 3 25 30 0 \
    "Serial Port:" 4 1 "$(detect_serial_port)" 4 25 30 0 \
    2> "$tmp" || { rm -f "$tmp"; return 1; }

  mapfile -t page2 < "$tmp"
  rm -f "$tmp"
  GPR_EDGE_ID="${page1[0]:-GPR-EDGE-001}"
  GPR_IP="${page1[1]:-192.168.100.20}"
  ROBOT_ID="${page1[2]:-ROBOT-001}"
  ROBOT_IP="${page2[0]:-192.168.100.10}"
  GPR_API_PORT="${page2[1]:-8000}"
  ROBOT_API_PORT="${page2[2]:-8080}"
  SERIAL_PORT="${page2[3]:-$(detect_serial_port)}"
  export GPR_EDGE_ID GPR_IP ROBOT_ID ROBOT_IP GPR_API_PORT ROBOT_API_PORT SERIAL_PORT
  return 0
}

collect_with_read() {
  local default_serial
  default_serial="$(detect_serial_port)"
  echo "=== GPR Edge 설정 (터미널) ==="
  read -r -p "GPR Edge ID [GPR-EDGE-001]: " GPR_EDGE_ID
  GPR_EDGE_ID="${GPR_EDGE_ID:-GPR-EDGE-001}"
  read -r -p "GPR IP [192.168.100.20]: " GPR_IP
  GPR_IP="${GPR_IP:-192.168.100.20}"
  read -r -p "Robot ID [ROBOT-001]: " ROBOT_ID
  ROBOT_ID="${ROBOT_ID:-ROBOT-001}"
  read -r -p "Robot IP [192.168.100.10]: " ROBOT_IP
  ROBOT_IP="${ROBOT_IP:-192.168.100.10}"
  read -r -p "GPR API Port [8000]: " GPR_API_PORT
  GPR_API_PORT="${GPR_API_PORT:-8000}"
  read -r -p "Robot API Port [8080]: " ROBOT_API_PORT
  ROBOT_API_PORT="${ROBOT_API_PORT:-8080}"
  read -r -p "GPR Serial Port [${default_serial}]: " SERIAL_PORT
  SERIAL_PORT="${SERIAL_PORT:-$default_serial}"
  export GPR_EDGE_ID GPR_IP ROBOT_ID ROBOT_IP GPR_API_PORT ROBOT_API_PORT SERIAL_PORT
}

collect_config_inputs() {
  if [[ "${GPR_EDGE_SETUP_UI:-}" == "read" ]]; then
    collect_with_read
    return 0
  fi

  if [[ "${GPR_EDGE_SETUP_UI:-}" == "browser" ]] || { is_wslg && [[ "${GPR_EDGE_SETUP_UI:-}" != "zenity" ]]; }; then
    if collect_with_browser; then
      return 0
    fi
    warn "브라우저 설정을 사용할 수 없습니다. dialog 또는 터미널로 진행합니다."
  fi

  if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
    configure_gui_environment
    if command -v zenity >/dev/null 2>&1 && zenity_gui_works; then
      if collect_with_zenity; then
        return 0
      fi
    elif is_wslg; then
      warn "WSLg에서 zenity 창이 표시되지 않습니다."
    fi
    if command -v dialog >/dev/null 2>&1; then
      if collect_with_dialog; then
        return 0
      fi
    fi
  fi
  collect_with_read
}
