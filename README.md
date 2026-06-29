# GPR Edge Linux 설치 파일

GPR 노트북(Linux)에 **Python 없이** GPR Edge를 설치하기 위한 **배포 전용 저장소**입니다.

> 이 저장소는 **설치 파일만** 포함합니다. 소스 코드·빌드 스크립트·개발 문서는 [gpr-edge](https://github.com/Geosoft-kr/gpr-gpr-edge) 저장소를 참고하세요.

---

## GPR Edge란?

주행로봇 Edge의 명령을 받아 GPR 장비를 제어하고, 데이터를 수집·저장한 뒤 **`GET /result`로 zip 결과를 제공**하는 GPR 노트북용 서브 엣지 프로그램입니다.

| 단계 | 설명 |
|------|------|
| 명령 수신 | 주행로봇 Edge에서 `start` / `stop` HTTP 명령 수신 |
| GPR 시작 | `start` 수신 시 GPR 장비 작동 및 백그라운드 데이터 수집 |
| 데이터 저장 | 샘플별 JSON 파일 + `manifest.json` 생성 |
| 상태 응답 | `GET /health` 및 주행로봇 Edge 콜백으로 상태 전송 |
| 탐사 종료 | `stop` 수신 시 장비 정지·manifest 생성, 주행로봇이 `GET /result`로 다운로드 |

---

## 포함 파일

| 파일 | 대상 | 설치 방법 |
|------|------|-----------|
| `gpr-edge-1.0.0-1.el10.x86_64.rpm` | Rocky / RHEL **데스크톱 (GUI)** | 파일 더블클릭 → **설치** |
| `gpr-edge-linux-x64-1.0.0.tar.gz` | Rocky Server, SSH 현장 등 **CLI / Server** | `sudo ./install.sh --cli` |

---

## 설치 방식 선택

| | **tar.gz + install.sh** | **.rpm** |
|---|---|---|
| 대상 | CLI / Server (GUI 없음) | Rocky / RHEL 데스크톱 (GUI) |
| 현장 설치 | `sudo ./install.sh --cli` | 파일 **더블클릭** |
| 설정 | 터미널 입력 | 메뉴 **「GPR Edge 설정」** |
| 실행 | systemd (`gpr-edge`) | 메뉴 **「GPR Edge」** |
| 제거 | `sudo ./uninstall.sh -y` | `sudo dnf remove gpr-edge` |

**GUI 없는 현장 (Rocky Server, SSH)** → **tar.gz**  
**데스크톱 더블클릭 (Rocky Desktop)** → **.rpm**

---

## 빠른 설치

### 방식 A — tar.gz (CLI / Server)

**01. 사전 준비 (Rocky / RHEL)**

```bash
sudo dnf install -y tar curl
```

**02. 파일 받기**

```bash
git clone https://github.com/Yehoonn/gpr-edge-install.git
cd gpr-edge-install
tar xzf gpr-edge-linux-x64-1.0.0.tar.gz
cd gpr-edge-linux-x64
chmod +x install.sh uninstall.sh gpr-edge/gpr-edge
chmod -R a+rX gpr-edge/_internal
```

USB로 tar.gz만 복사한 경우:

```bash
mkdir -p /svc/gpr && cd /svc/gpr
tar xzf gpr-edge-linux-x64-1.0.0.tar.gz
cd gpr-edge-linux-x64
chmod +x install.sh uninstall.sh
```

**03. 설치**

```bash
sudo ./install.sh --cli
```

터미널에서 ID·IP·Port를 순서대로 입력합니다.

| 항목 | 예시 |
|------|------|
| GPR Edge ID | `GPR-EDGE-001` |
| GPR IP | `192.168.100.20` |
| Robot ID | `ROBOT-001` |
| Robot IP | `192.168.100.10` |
| GPR API Port | `8000` |
| Robot API Port | `8080` |
| GPR Serial Port | `/dev/ttyUSB0` |

**04. 확인**

```bash
systemctl status gpr-edge
curl http://127.0.0.1:8000/health
```

성공 응답 예:

```json
{
  "status": "success",
  "code": "20000001",
  "data": { "state": "idle", "collecting": false }
}
```

---

### 방식 B — .rpm (Rocky / RHEL 데스크톱)

1. **`gpr-edge-1.0.0-1.el10.x86_64.rpm`** 파일을 더블클릭합니다.
2. 소프트웨어 설치 창에서 **설치**를 누릅니다.
3. 「지금 GPR Edge 네트워크 설정을 진행하시겠습니까?」가 뜨면 **예** → ID·IP 입력.
4. 애플리케이션 메뉴 **「GPR Edge」** 더블클릭으로 실행.

CLI로 설치할 경우:

```bash
sudo dnf install -y ./gpr-edge-1.0.0-1.el10.x86_64.rpm
```

설정을 다시 바꿀 때는 메뉴 **「GPR Edge 설정」** 을 사용합니다.

---

## 재설정

**tar.gz 설치:**

```bash
cd gpr-edge-linux-x64
sudo ./install.sh --reconfigure --cli
sudo systemctl restart gpr-edge
```

**rpm 설치 (어디서든):**

```bash
sudo GPR_EDGE_SETUP_UI=read gpr-edge-setup
sudo systemctl restart gpr-edge
```

---

## 제거

**tar.gz:**

```bash
cd gpr-edge-linux-x64
sudo ./uninstall.sh -y
```

**rpm:**

```bash
sudo dnf remove gpr-edge
```

---

## 설치 후 경로

| 경로 | 내용 |
|------|------|
| `/opt/gpr-edge/` | 프로그램 (읽기 전용) |
| `/opt/gpr-edge/config.yaml` | 설정 |
| `/var/lib/gpr-edge/data` | 탐사 데이터 |
| `/var/lib/gpr-edge/log` | 로그 |

> 데이터·로그는 `/opt`가 아니라 **`/var/lib/gpr-edge/`** 에 저장됩니다.

---

## install.sh 옵션 (tar.gz)

| 옵션 | 설명 |
|------|------|
| `--cli` | GUI 없이 터미널 입력만 |
| `--reconfigure` | 재설치 없이 설정만 갱신 |
| `--no-service` | systemd 등록 생략 |
| `--skip-healthcheck` | 설치 후 헬스체크 생략 |
| `--no-firewall` | 방화벽 규칙 추가 생략 |

---

## 자주 발생하는 문제

### `gpr-edge 바이너리 없음`

**소스 저장소(gpr-edge)** 를 clone한 경우가 아닌지 확인하세요. 이 저장소([gpr-edge-install](https://github.com/Yehoonn/gpr-edge-install))의 tar.gz를 사용해야 합니다.

### `Permission denied` / 서비스 `203/EXEC`

```bash
sudo chmod +x /opt/gpr-edge/gpr-edge
sudo chmod -R a+rX /opt/gpr-edge/_internal
command -v restorecon >/dev/null && sudo restorecon -Rv /opt/gpr-edge
sudo systemctl restart gpr-edge
```

### 헬스체크 실패 (외부 PC에서)

- 접속 주소: `http://{GPR IP}:{port}/health` (`127.0.0.1`은 로컬 전용)
- 방화벽: Rocky/RHEL → `sudo firewall-cmd --permanent --add-port=8000/tcp && sudo firewall-cmd --reload`
- 리스닝 확인: `ss -tlnp | grep 8000` → `0.0.0.0:8000`이면 외부 접속 가능

### 터미널 한글이 ■ 로 보일 때

설치는 정상일 수 있습니다. `systemctl status gpr-edge`가 `active (running)`이면 OK입니다. 한글 locale이 없으면 install.sh 메시지가 영어로 출력됩니다.

---

## 상세 문서

| 문서 | 내용 |
|------|------|
| [linux-install-tar.md](https://github.com/Geosoft-kr/gpr-gpr-edge/blob/main/docs/linux-install-tar.md) | tar.gz + install.sh CLI 설치 (배포판별 명령, 트러블슈팅) |
| [linux-installer.md](https://github.com/Geosoft-kr/gpr-gpr-edge/blob/main/docs/linux-installer.md) | Linux 설치 전체 (.rpm / .deb / tar.gz, 빌드, systemd) |
| [README.md (gpr-edge)](https://github.com/Geosoft-kr/gpr-gpr-edge/blob/main/README.md) | 앱 개요, API, 설정, 개발 환경 |

---

## Windows 설치

Windows용 설치 프로그램(`GPR-Edge-Setup-*.exe`)은 이 저장소에 포함되어 있지 않습니다. [gpr-edge](https://github.com/Geosoft-kr/gpr-gpr-edge) 저장소의 [windows-installer.md](https://github.com/Geosoft-kr/gpr-gpr-edge/blob/main/docs/windows-installer.md)를 참고하세요.
