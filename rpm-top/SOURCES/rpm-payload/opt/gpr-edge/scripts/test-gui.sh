#!/usr/bin/env bash
# WSL / Linux GUI 설정 테스트
# WSLg에서 zenity가 안 보이면 브라우저 마법사를 사용합니다.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../lib/common.sh
source "${LINUX_DIR}/lib/common.sh"
# shellcheck source=../lib/collect-input.sh
source "${LINUX_DIR}/lib/collect-input.sh"

echo "=== GPR Edge UI test ==="
echo "WSLg: $(is_wslg && echo yes || echo no)"
echo ""

if is_wslg; then
  echo "WSL 환경: zenity 대신 **브라우저 설정 화면**을 사용합니다."
  echo "Edge/Chrome에 폼이 열립니다. 값 입력 후 [저장]을 누르세요."
  echo ""
  if collect_with_browser; then
    echo ""
    echo "입력된 값:"
    echo "  GPR_EDGE_ID=$GPR_EDGE_ID"
    echo "  GPR_IP=$GPR_IP"
    echo "  ROBOT_ID=$ROBOT_ID"
    echo "  ROBOT_IP=$ROBOT_IP"
    echo "  GPR_API_PORT=$GPR_API_PORT"
    echo "  ROBOT_API_PORT=$ROBOT_API_PORT"
    echo "  SERIAL_PORT=$SERIAL_PORT"
    echo ""
    echo "브라우저 UI 테스트 성공"
    exit 0
  fi
  die "브라우저 UI 테스트 실패 (python3 필요)"
fi

echo "zenity 테스트..."
configure_gui_environment
if zenity --info --title="GPR Edge" --text="zenity OK" --width=280; then
  echo "zenity OK"
  exit 0
fi

echo "dialog 테스트 (sudo apt install dialog)..."
if command -v dialog >/dev/null 2>&1 && collect_with_dialog; then
  echo "dialog OK"
  exit 0
fi

die "GUI 테스트 실패"
