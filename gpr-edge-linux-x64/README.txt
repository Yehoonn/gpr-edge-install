GPR Edge Linux 1.0.0

[GUI 데스크톱] .rpm 더블클릭 설치 (Rocky 권장)

[CLI / Server] tar.gz + install.sh:
  tar xzf gpr-edge-linux-x64-1.0.0.tar.gz
  cd gpr-edge-linux-x64
  chmod +x install.sh uninstall.sh
  sudo ./install.sh --cli

확인:
  systemctl status gpr-edge
  curl http://127.0.0.1:8000/health

재설정:
  sudo gpr-edge-setup
  sudo GPR_EDGE_SETUP_UI=read gpr-edge-setup

제거:
  sudo ./uninstall.sh -y

자세한 내용: docs/linux-installer.md
