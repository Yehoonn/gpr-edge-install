#!/usr/bin/env bash
# GPR Edge 설정 마법사 (설치 후 재실행 가능)
# 사용: sudo gpr-edge-setup  또는  sudo ./configure.sh

set -euo pipefail

LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${GPR_EDGE_INSTALL_DIR:-${LINUX_DIR}}"

# shellcheck source=lib/common.sh
source "${LINUX_DIR}/lib/common.sh"
# shellcheck source=lib/collect-input.sh
source "${LINUX_DIR}/lib/collect-input.sh"

require_root

[[ -d "$INSTALL_DIR" ]] || die "설치 디렉터리가 없습니다: ${INSTALL_DIR}"

TEMPLATE_DIR="${LINUX_DIR}/templates"
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  TEMPLATE_DIR="${INSTALL_DIR}/templates"
fi
[[ -d "$TEMPLATE_DIR" ]] || die "템플릿 디렉터리를 찾을 수 없습니다."

log "GPR Edge 설정 (설치 경로: ${INSTALL_DIR})"
collect_config_inputs
write_config_files "$INSTALL_DIR" "$TEMPLATE_DIR"
ensure_runtime_dirs
maybe_configure_firewall "$GPR_API_PORT"
maybe_add_dialout_group

log "설정 저장 완료:"
log "  ${INSTALL_DIR}/config.yaml"
log "  ${INSTALL_DIR}/device.json"

if [[ "${GPR_EDGE_RUN_HEALTHCHECK:-0}" == "1" ]]; then
  log "헬스체크 대기 중..."
  if pgrep -f "${INSTALL_DIR}/gpr-edge" >/dev/null 2>&1; then
    wait_for_health "$GPR_API_PORT" 30 "${INSTALL_DIR}/scripts"
  else
    warn "GPR Edge가 실행 중이 아닙니다. 바로가기 또는 gpr-edge-launcher.sh로 기동 후 확인하세요."
  fi
fi
