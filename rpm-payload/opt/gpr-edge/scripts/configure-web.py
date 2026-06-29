#!/usr/bin/env python3
"""GPR Edge 설정 — 로컬 브라우저 마법사 (WSL 등 zenity 미지원 환경용)."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs

HTML = """<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="utf-8" />
  <title>GPR Edge 설정</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 520px; margin: 2rem auto; padding: 0 1rem; }
    h1 { font-size: 1.25rem; }
    label { display: block; margin-top: 1rem; font-weight: 600; }
    input { width: 100%; padding: 0.5rem; margin-top: 0.25rem; box-sizing: border-box; }
    button { margin-top: 1.5rem; padding: 0.6rem 1.2rem; font-size: 1rem; cursor: pointer; }
    .hint { color: #555; font-size: 0.85rem; margin-top: 0.2rem; }
    section { border: 1px solid #ddd; border-radius: 8px; padding: 1rem; margin-bottom: 1rem; }
    section h2 { margin: 0 0 0.5rem; font-size: 1rem; }
  </style>
</head>
<body>
  <h1>GPR Edge 설정</h1>
  <p>입력한 값은 <code>config.yaml</code> 및 <code>device.json</code>에 저장됩니다.</p>
  <form method="POST" action="/">
    <section>
      <h2>1/2 — 장비 식별</h2>
      <label>GPR Edge ID</label>
      <input name="gpr_edge_id" value="GPR-EDGE-001" required />
      <label>GPR IP 주소</label>
      <input name="gpr_ip" value="192.168.100.20" required />
      <span class="hint">로봇이 접속할 이 노트북 IP</span>
      <label>Robot ID</label>
      <input name="robot_id" value="ROBOT-001" required />
    </section>
    <section>
      <h2>2/2 — 네트워크·포트</h2>
      <label>Robot IP</label>
      <input name="robot_ip" value="192.168.100.10" required />
      <label>GPR API Port</label>
      <input name="gpr_api_port" type="number" value="8000" min="1024" max="65535" required />
      <label>Robot API Port</label>
      <input name="robot_api_port" type="number" value="8080" min="1024" max="65535" required />
      <label>GPR 시리얼 포트</label>
      <input name="serial_port" value="/dev/ttyUSB0" required />
    </section>
    <button type="submit">저장</button>
  </form>
</body>
</html>
"""

DONE = """<!DOCTYPE html>
<html lang="ko"><head><meta charset="utf-8" /><title>완료</title></head>
<body><h1>설정이 저장되었습니다.</h1><p>이 창을 닫고 터미널로 돌아가세요.</p></body></html>
"""


def open_browser(url: str) -> None:
    if sys.platform != "win32" and __import__("pathlib").Path("/mnt/wslg").exists():
        try:
            subprocess.Popen(
                ["cmd.exe", "/c", "start", "", url],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            return
        except OSError:
            pass
    webbrowser.open(url)


def run_server(host: str, port: int, output: str) -> dict[str, str]:
    result: dict[str, str] = {}
    done = threading.Event()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt: str, *args) -> None:  # noqa: ARG002
            return

        def do_GET(self) -> None:  # noqa: N802
            if self.path not in ("/", "/index.html"):
                self.send_error(404)
                return
            body = HTML.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self) -> None:  # noqa: N802
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length).decode("utf-8", errors="replace")
            fields = parse_qs(raw)
            mapping = {
                "gpr_edge_id": "GPR_EDGE_ID",
                "gpr_ip": "GPR_IP",
                "robot_id": "ROBOT_ID",
                "robot_ip": "ROBOT_IP",
                "gpr_api_port": "GPR_API_PORT",
                "robot_api_port": "ROBOT_API_PORT",
                "serial_port": "SERIAL_PORT",
            }
            for form_key, env_key in mapping.items():
                values = fields.get(form_key, [])
                if not values or not str(values[0]).strip():
                    self.send_error(400, f"Missing {form_key}")
                    return
                result[env_key] = str(values[0]).strip()

            with open(output, "w", encoding="utf-8") as handle:
                json.dump(result, handle, ensure_ascii=False, indent=2)

            body = DONE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            done.set()

    url = f"http://{host}:{port}/"
    server = HTTPServer((host, port), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    print(f"[gpr-edge] 브라우저에서 설정 페이지를 엽니다: {url}", flush=True)
    open_browser(url)
    done.wait(timeout=600)
    server.shutdown()
    if not result:
        raise SystemExit("설정이 제출되지 않았습니다 (시간 초과 또는 취소).")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description="GPR Edge browser setup wizard")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--output", required=True, help="JSON output path")
    args = parser.parse_args()
    run_server(args.host, args.port, args.output)


if __name__ == "__main__":
    main()
