#!/usr/bin/env bash
# GPR Edge Linux 제거
# 사용: sudo ./uninstall.sh        — 확인 후 제거
#       sudo ./uninstall.sh -y      — 확인 없이 제거
#       ./uninstall.sh              — dry-run (제거 대상만 출력)

set -euo pipefail

INSTALL_DIR="/opt/gpr-edge"
RUNTIME_DIR="/var/lib/gpr-edge"
UNIT="gpr-edge.service"
ASSUME_YES=0
DRY_RUN=0

usage() {
  cat <<EOF
Usage: sudo $0 [-y] [--install-dir PATH]

  -y, --yes           확인 없이 제거
  --install-dir PATH  설치 경로 (기본: /opt/gpr-edge)
  -n, --dry-run       제거 대상만 출력 (sudo 불필요)
  -h, --help          도움말
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1; shift ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

items=(
  "/etc/systemd/system/${UNIT}"
  "/usr/local/bin/gpr-edge-setup"
  "/usr/share/applications/gpr-edge.desktop"
  "/usr/share/applications/gpr-edge-setup.desktop"
  "${INSTALL_DIR}"
  "${RUNTIME_DIR}"
)

echo "GPR Edge 제거 대상:"
for path in "${items[@]}"; do
  [[ -e "$path" ]] && echo "  - $path"
done

if [[ "$DRY_RUN" == "1" ]]; then
  echo ""
  echo "dry-run — 실제 제거하지 않았습니다."
  exit 0
fi

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "ERROR: root 권한이 필요합니다. sudo ./uninstall.sh" >&2
  exit 1
fi

if [[ "$ASSUME_YES" != "1" ]]; then
  read -r -p "위 항목을 제거하시겠습니까? [y/N] " ans
  case "${ans:-N}" in
    y|Y|yes|YES) ;;
    *) echo "취소됨."; exit 0 ;;
  esac
fi

if systemctl is-active --quiet "$UNIT" 2>/dev/null; then
  systemctl stop "$UNIT" || true
fi
if systemctl is-enabled --quiet "$UNIT" 2>/dev/null; then
  systemctl disable "$UNIT" || true
fi

rm -f "/etc/systemd/system/${UNIT}"
rm -f /usr/local/bin/gpr-edge-setup
rm -f /usr/share/applications/gpr-edge.desktop
rm -f /usr/share/applications/gpr-edge-setup.desktop
rm -rf "$INSTALL_DIR" "$RUNTIME_DIR"

if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications 2>/dev/null || true
fi

echo "GPR Edge 제거 완료."
