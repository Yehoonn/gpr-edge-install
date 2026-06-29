# GPR Edge RPM spec (Rocky / RHEL / AlmaLinux / CentOS Stream)
# 빌드: installer/linux/build-rpm.sh

%global debug_package %{nil}
# PyInstaller 번들 .so는 시스템 lib와 동일 build-id를 가질 수 있음 → 링크 생성 비활성화
%global _build_id_links none

Name:           gpr-edge
Version:        %{?gpr_version}%{!?gpr_version:1.0.0}
Release:        1%{?dist}
Summary:        GPR Edge Program
License:        Proprietary
URL:            https://github.com/gpr/gpr-edge
BuildArch:      x86_64
AutoReqProv:    no
Requires:       curl
Recommends:     zenity
Recommends:     dialog

%description
주행로봇 Edge 명령을 받아 GPR 데이터를 수집·저장·전달하는
GPR 노트북용 서브 엣지 프로그램입니다.

설치 후 애플리케이션 메뉴의 「GPR Edge 설정」 또는
`sudo gpr-edge-setup`으로 네트워크 설정을 완료하세요.

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a %{_sourcedir}/rpm-payload/. %{buildroot}/

%files
%defattr(-,root,root,-)
/opt/gpr-edge/
/usr/bin/gpr-edge-setup
/usr/share/applications/gpr-edge.desktop
/usr/share/applications/gpr-edge-setup.desktop
/lib/systemd/system/gpr-edge.service

%post
INSTALL_DIR="/opt/gpr-edge"

if [ "$1" -eq 1 ] ; then
  chmod 755 "${INSTALL_DIR}/gpr-edge" 2>/dev/null || true
  chmod -R a+rX "${INSTALL_DIR}/_internal" 2>/dev/null || true
  if command -v restorecon >/dev/null 2>&1; then
    restorecon -Rv "${INSTALL_DIR}" >/dev/null 2>&1 || true
  fi
  chmod 755 "${INSTALL_DIR}/configure.sh" 2>/dev/null || true
  chmod 755 "${INSTALL_DIR}/scripts/"*.sh 2>/dev/null || true
  chmod 755 /usr/bin/gpr-edge-setup 2>/dev/null || true

    if command -v update-desktop-database >/dev/null 2>&1; then
      update-desktop-database /usr/share/applications || true
    fi

    install -d -m 1777 /var/lib/gpr-edge/data /var/lib/gpr-edge/log

    if [ ! -f "${INSTALL_DIR}/config.yaml" ]; then
    echo ""
    echo "GPR Edge: 초기 설정이 필요합니다."
    echo "  메뉴 「GPR Edge 설정」 또는 sudo gpr-edge-setup"
    echo ""
    if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
      if command -v zenity >/dev/null 2>&1; then
        if [ -d /mnt/wslg ]; then
          export GDK_BACKEND="${GDK_BACKEND:-x11}"
          export DISPLAY="${DISPLAY:-:0}"
        fi
        if zenity --question --title="GPR Edge" \
            --text="지금 GPR Edge 네트워크 설정을 진행하시겠습니까?" 2>/dev/null; then
          GPR_EDGE_RUN_HEALTHCHECK=1 "${INSTALL_DIR}/configure.sh" || true
        fi
      fi
    fi
  fi
fi

%preun
if [ "$1" -eq 0 ] ; then
  if pgrep -f "/opt/gpr-edge/gpr-edge" >/dev/null 2>&1; then
    pkill -f "/opt/gpr-edge/gpr-edge" || true
    sleep 1
  fi
fi

%postun
if [ "$1" -eq 0 ] ; then
  rm -rf /opt/gpr-edge/data /opt/gpr-edge/log 2>/dev/null || true
  rm -rf /var/lib/gpr-edge 2>/dev/null || true
fi
