#!/usr/bin/env bash
# GPR Edge Linux 설치 (방식 D: install.sh — CLI / Server / GUI 공통)
# 사용: sudo ./install.sh
#       sudo ./install.sh --cli          # 터미널 입력만 (GUI 없음)
#       sudo ./install.sh --no-service   # systemd 등록 생략
#
# tar.gz 배포 패키지 루트에서 실행하세요.

set -euo pipefail

LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "${LINUX_DIR}/lib/common.sh"
# shellcheck source=lib/collect-input.sh
source "${LINUX_DIR}/lib/collect-input.sh"

INSTALL_DIR="/opt/gpr-edge"
BUNDLE_DIR=""
SKIP_HEALTHCHECK=0
CONFIGURE_FIREWALL=1
REGISTER_SERVICE=1
FORCE_CLI=0
RECONFIGURE=0

usage() {
  cat <<EOF
Usage: sudo $0 [options]

GPR Edge를 ${INSTALL_DIR} 에 설치하고 (선택) systemd 서비스를 등록합니다.
GUI 없는 Rocky Server 현장에서는 --cli 옵션을 권장합니다.

Options:
  --install-dir PATH    설치 경로 (기본: /opt/gpr-edge)
  --bundle-dir PATH     PyInstaller 번들 (기본: ./gpr-edge)
  --cli                 터미널 read 로 설정 (zenity/dialog 사용 안 함)
  --no-service          systemd 서비스 등록·기동 생략
  --skip-healthcheck    설치 후 헬스체크 생략
  --no-firewall         firewalld/UFW 규칙 추가 생략
  --reconfigure         설치 없이 설정만 다시 저장
  -h, --help            도움말

예:
  sudo ./install.sh
  sudo ./install.sh --cli
  sudo ./install.sh --cli --no-service
  sudo ./install.sh --reconfigure

설치 확인:
  systemctl status gpr-edge
  curl http://127.0.0.1:8000/health

재설정:
  sudo gpr-edge-setup
  sudo GPR_EDGE_SETUP_UI=read gpr-edge-setup
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    --bundle-dir) BUNDLE_DIR="$2"; shift 2 ;;
    --cli) FORCE_CLI=1; shift ;;
    --no-service) REGISTER_SERVICE=0; shift ;;
    --skip-healthcheck) SKIP_HEALTHCHECK=1; shift ;;
    --no-firewall) CONFIGURE_FIREWALL=0; shift ;;
    --reconfigure) RECONFIGURE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

require_root

resolve_bundle_dir() {
  if [[ -n "$BUNDLE_DIR" ]]; then
    return 0
  fi
  if [[ -d "${LINUX_DIR}/gpr-edge" ]]; then
    BUNDLE_DIR="${LINUX_DIR}/gpr-edge"
  elif [[ -d "${PROJECT_ROOT}/dist/gpr-edge" ]]; then
    BUNDLE_DIR="${PROJECT_ROOT}/dist/gpr-edge"
  elif [[ -x "${INSTALL_DIR}/gpr-edge" ]]; then
    BUNDLE_DIR="$INSTALL_DIR"
  else
    die "PyInstaller 번들을 찾을 수 없습니다. --bundle-dir 옵션을 사용하세요."
  fi
}

install_support_files() {
  install_launcher_scripts "$INSTALL_DIR" "${LINUX_DIR}/scripts"
  install -m 755 "${LINUX_DIR}/configure.sh" "${INSTALL_DIR}/configure.sh"
  mkdir -p "${INSTALL_DIR}/templates" "${INSTALL_DIR}/lib" "${INSTALL_DIR}/desktop"
  cp -a "${LINUX_DIR}/templates/." "${INSTALL_DIR}/templates/"
  cp -a "${LINUX_DIR}/lib/." "${INSTALL_DIR}/lib/"
  cp -a "${LINUX_DIR}/desktop/." "${INSTALL_DIR}/desktop/"

  install -d /usr/local/bin
  cat > /usr/local/bin/gpr-edge-setup <<EOF
#!/usr/bin/env bash
exec ${INSTALL_DIR}/configure.sh "\$@"
EOF
  chmod 755 /usr/local/bin/gpr-edge-setup

  if [[ -d /usr/share/applications ]]; then
    install_desktop_entry "$INSTALL_DIR" "${LINUX_DIR}/desktop" || true
  fi
}

stop_existing_gpr_edge() {
  local install_dir="$1"
  if systemctl is-active --quiet gpr-edge.service 2>/dev/null; then
    systemctl stop gpr-edge.service || true
    sleep 1
  fi
  if pgrep -f "${install_dir}/gpr-edge" >/dev/null 2>&1; then
    log "기존 gpr-edge 프로세스 종료 중..."
    pkill -f "${install_dir}/gpr-edge" || true
    sleep 1
  fi
}

show_service_failure() {
  warn "서비스 기동 실패. 최근 로그:"
  journalctl -u gpr-edge.service -n 30 --no-pager 2>/dev/null || true
  echo ""
  warn "수동 실행 테스트: ${INSTALL_DIR}/gpr-edge --config ${INSTALL_DIR}/config.yaml"
}

install_systemd_service() {
  local unit="/etc/systemd/system/gpr-edge.service"
  cat > "$unit" <<EOF
[Unit]
Description=GPR Edge Program
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
Environment=GPR_EDGE_RUNTIME_DIR=/var/lib/gpr-edge
ExecStart=${INSTALL_DIR}/gpr-edge --config ${INSTALL_DIR}/config.yaml
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable gpr-edge.service
  log "systemd 서비스 등록: gpr-edge.service"
}

start_service() {
  stop_existing_gpr_edge "$INSTALL_DIR"
  if ss -tlnp 2>/dev/null | grep -q ":${GPR_API_PORT} "; then
    warn "포트 ${GPR_API_PORT} 이(가) 이미 사용 중입니다:"
    ss -tlnp | grep ":${GPR_API_PORT} " || true
  fi
  systemctl restart gpr-edge.service
  sleep 3
  if systemctl is-active --quiet gpr-edge.service; then
    log "서비스 기동 완료: systemctl status gpr-edge"
  else
    show_service_failure
  fi
}

run_healthcheck() {
  local port="$1"
  log "헬스체크: http://127.0.0.1:${port}/health"
  if wait_for_health "$port" 30 "${INSTALL_DIR}/scripts"; then
    log "헬스체크 성공."
  else
    warn "헬스체크 실패. 로그: /var/lib/gpr-edge/log"
  fi
}

if [[ "$RECONFIGURE" == "1" ]]; then
  [[ -d "$INSTALL_DIR" ]] || die "설치 디렉터리 없음: ${INSTALL_DIR}. 먼저 install.sh 를 실행하세요."
  if [[ "$FORCE_CLI" == "1" ]]; then
    export GPR_EDGE_SETUP_UI=read
  fi
  GPR_EDGE_INSTALL_DIR="$INSTALL_DIR" "${INSTALL_DIR}/configure.sh"
  if [[ "$REGISTER_SERVICE" == "1" ]] && systemctl is-enabled gpr-edge.service >/dev/null 2>&1; then
    systemctl restart gpr-edge.service || true
  fi
  exit 0
fi

resolve_bundle_dir
[[ -x "${BUNDLE_DIR}/gpr-edge" ]] || die "gpr-edge 바이너리 없음: ${BUNDLE_DIR}/gpr-edge"

log "GPR Edge Linux 설치 (install.sh)"
log "  번들: ${BUNDLE_DIR}"
log "  설치: ${INSTALL_DIR}"

if [[ "$FORCE_CLI" == "1" ]] || [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  export GPR_EDGE_SETUP_UI=read
  log "설정: 터미널 입력 (CLI)"
fi

collect_config_inputs

mkdir -p "$INSTALL_DIR"
cp -a "${BUNDLE_DIR}/." "${INSTALL_DIR}/"
ensure_binary_permissions "$INSTALL_DIR"
install_support_files
write_config_files "$INSTALL_DIR" "${LINUX_DIR}/templates"
ensure_runtime_dirs

if [[ "$CONFIGURE_FIREWALL" == "1" ]]; then
  maybe_configure_firewall "$GPR_API_PORT"
fi
maybe_add_dialout_group

if [[ "$REGISTER_SERVICE" == "1" ]]; then
  install_systemd_service
  start_service
fi

log ""
log "=========================================="
log " 설치 완료"
log "=========================================="
log "  설정: ${INSTALL_DIR}/config.yaml"
log "  데이터: /var/lib/gpr-edge/data"
log "  로그:   /var/lib/gpr-edge/log"
if [[ "$REGISTER_SERVICE" == "1" ]]; then
  log "  서비스: systemctl status gpr-edge"
  log "  헬스:   curl http://127.0.0.1:${GPR_API_PORT}/health"
else
  log "  실행:   ${INSTALL_DIR}/scripts/gpr-edge-launcher.sh"
fi
log "  재설정: sudo gpr-edge-setup"
log "  제거:   sudo ./uninstall.sh"

if [[ "$SKIP_HEALTHCHECK" == "0" ]]; then
  if [[ "$REGISTER_SERVICE" == "1" ]]; then
    run_healthcheck "$GPR_API_PORT"
  else
    log "헬스체크 (포그라운드)..."
    "${INSTALL_DIR}/gpr-edge" --config "${INSTALL_DIR}/config.yaml" &
    SERVER_PID=$!
    sleep 3
    run_healthcheck "$GPR_API_PORT" || true
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
fi
