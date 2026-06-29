#!/usr/bin/env bash
# GPR Edge Linux installer — shared helpers

set -euo pipefail

GPR_EDGE_VERSION="${GPR_EDGE_VERSION:-1.0.0}"
DEFAULT_INSTALL_DIR="/opt/gpr-edge"
DEFAULT_SERIAL_PORT="/dev/ttyUSB0"

# Script location (installer/linux/lib when developing)
LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "${LINUX_DIR}/../.." && pwd)"

log() { printf '[gpr-edge] %s\n' "$*"; }
warn() { printf '[gpr-edge] WARNING: %s\n' "$*" >&2; }
die() { printf '[gpr-edge] ERROR: %s\n' "$*" >&2; exit 1; }

is_wslg() {
  [[ -d /mnt/wslg ]]
}

# WSLg(WSL GUI)에서 zenity가 작업 표시줄 아이콘만 보이고 창이 안 뜨는 경우가 있음.
configure_gui_environment() {
  if is_wslg; then
    export GDK_BACKEND="${GDK_BACKEND:-x11}"
    export DISPLAY="${DISPLAY:-:0}"
    unset WAYLAND_DISPLAY
    log "WSLg 감지 — GDK_BACKEND=${GDK_BACKEND}, WAYLAND 비활성 (zenity 대신 브라우저/dialog 권장)"
  fi
}

# zenity가 실제로 보이는지 빠르게 확인 (WSLg 아이콘만 뜨는 경우 실패)
zenity_gui_works() {
  command -v zenity >/dev/null 2>&1 || return 1
  configure_gui_environment
  local rc=0
  timeout 2 zenity --info --timeout=1 --text="." >/dev/null 2>&1 || rc=$?
  # 0=OK, 5=timeout(창은 떴을 수 있음). 그 외/timeout 명령=실패
  [[ "$rc" == "0" || "$rc" == "5" ]]
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "root 권한이 필요합니다. sudo로 실행하세요."
  fi
}

is_valid_ipv4() {
  local ip="$1"
  local IFS='.'
  local -a parts
  read -r -a parts <<< "$ip"
  [[ ${#parts[@]} -eq 4 ]] || return 1
  local part
  for part in "${parts[@]}"; do
    [[ "$part" =~ ^[0-9]+$ ]] || return 1
    (( part >= 0 && part <= 255 )) || return 1
  done
  return 0
}

is_valid_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] || return 1
  (( port >= 1024 && port <= 65535 ))
}

escape_json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

render_template() {
  local template_file="$1"
  local output_file="$2"
  local content
  content="$(cat "$template_file")"
  content="${content//\{\{GPR_EDGE_ID\}\}/${GPR_EDGE_ID}}"
  content="${content//\{\{GPR_IP\}\}/${GPR_IP}}"
  content="${content//\{\{ROBOT_ID\}\}/${ROBOT_ID}}"
  content="${content//\{\{ROBOT_IP\}\}/${ROBOT_IP}}"
  content="${content//\{\{GPR_API_PORT\}\}/${GPR_API_PORT}}"
  content="${content//\{\{ROBOT_API_PORT\}\}/${ROBOT_API_PORT}}"
  content="${content//\{\{SERIAL_PORT\}\}/${SERIAL_PORT}}"
  printf '%s\n' "$content" > "$output_file"
}

validate_config_inputs() {
  [[ -n "${GPR_EDGE_ID// }" ]] || die "GPR Edge ID를 입력하세요."
  is_valid_ipv4 "$GPR_IP" || die "GPR IP 주소 형식이 올바르지 않습니다."
  [[ -n "${ROBOT_ID// }" ]] || die "Robot ID를 입력하세요."
  is_valid_ipv4 "$ROBOT_IP" || die "Robot IP 주소 형식이 올바르지 않습니다."
  is_valid_port "$GPR_API_PORT" || die "GPR API Port는 1024~65535 범위여야 합니다."
  is_valid_port "$ROBOT_API_PORT" || die "Robot API Port는 1024~65535 범위여야 합니다."
  [[ -n "${SERIAL_PORT// }" ]] || die "시리얼 포트를 입력하세요."
}

write_config_files() {
  local install_dir="$1"
  local template_dir="$2"
  validate_config_inputs
  render_template "${template_dir}/config.yaml.tpl" "${install_dir}/config.yaml"
  render_template "${template_dir}/device.json.tpl" "${install_dir}/device.json"
  chmod 644 "${install_dir}/config.yaml" "${install_dir}/device.json"
}

install_launcher_scripts() {
  local install_dir="$1"
  local scripts_src="$2"
  mkdir -p "${install_dir}/scripts"
  install -m 755 "${scripts_src}/health-check.sh" "${install_dir}/scripts/health-check.sh"
  install -m 755 "${scripts_src}/gpr-edge-launcher.sh" "${install_dir}/scripts/gpr-edge-launcher.sh"
  install -m 755 "${scripts_src}/configure-web.py" "${install_dir}/scripts/configure-web.py"
  if [[ -f "${scripts_src}/test-gui.sh" ]]; then
    install -m 755 "${scripts_src}/test-gui.sh" "${install_dir}/scripts/test-gui.sh"
  fi
}

install_desktop_entry() {
  local install_dir="$1"
  local desktop_src="$2"
  local desktop_dest="/usr/share/applications/gpr-edge.desktop"
  sed "s|@INSTALL_DIR@|${install_dir}|g" "${desktop_src}/gpr-edge.desktop" > "${desktop_dest}"
  chmod 644 "${desktop_dest}"
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications || true
  fi
}

maybe_configure_firewall() {
  local port="$1"
  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi "active"; then
    log "UFW 인바운드 규칙 추가: TCP ${port}"
    ufw allow "${port}/tcp" || warn "UFW 규칙 추가 실패"
  elif command -v firewall-cmd >/dev/null 2>&1; then
    log "firewalld 인바운드 규칙 추가: TCP ${port}"
    firewall-cmd --permanent --add-port="${port}/tcp" || warn "firewalld 규칙 추가 실패"
    firewall-cmd --reload || true
  else
    warn "방화벽 도구(ufw/firewalld)를 찾지 못했습니다. 포트 ${port} 인바운드를 수동으로 허용하세요."
  fi
}

maybe_add_dialout_group() {
  local user_name="${SUDO_USER:-${USER:-}}"
  [[ -n "$user_name" && "$user_name" != "root" ]] || return 0
  if getent group dialout >/dev/null 2>&1; then
    usermod -aG dialout "$user_name" 2>/dev/null || warn "dialout 그룹 추가 실패 (${user_name})"
    log "사용자 ${user_name}를 dialout 그룹에 추가했습니다. 재로그인 후 시리얼 포트를 사용하세요."
  fi
}

ensure_runtime_dirs() {
  local runtime_dir="${GPR_EDGE_RUNTIME_DIR:-/var/lib/gpr-edge}"
  install -d -m 1777 "${runtime_dir}/data" "${runtime_dir}/log"
  log "런타임 디렉터리: ${runtime_dir}/data, ${runtime_dir}/log"
}

ensure_binary_permissions() {
  local install_dir="$1"
  [[ -f "${install_dir}/gpr-edge" ]] || return 0
  chmod 755 "${install_dir}/gpr-edge"
  chmod 755 "${install_dir}/configure.sh" 2>/dev/null || true
  chmod 755 "${install_dir}/scripts/"*.sh 2>/dev/null || true
  if [[ -d "${install_dir}/_internal" ]]; then
    chmod -R a+rX "${install_dir}/_internal"
  fi
  if command -v restorecon >/dev/null 2>&1; then
    restorecon -Rv "${install_dir}" >/dev/null 2>&1 || true
  fi
}

wait_for_health() {
  local port="$1"
  local timeout="${2:-60}"
  local script_dir="$3"
  "${script_dir}/health-check.sh" "$port" "$timeout"
}

detect_serial_port() {
  local candidate
  for candidate in /dev/ttyUSB0 /dev/ttyACM0 /dev/ttyUSB1; do
    if [[ -e "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  printf '%s' "$DEFAULT_SERIAL_PORT"
}
