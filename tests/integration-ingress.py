"""Run in disposable Alpine with nginx, python3 and py3-websocket-client."""
import base64
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.request
import websocket

ROOT = Path(__file__).resolve().parents[1]


class Backend(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        if self.headers.get("Upgrade", "").lower() == "websocket":
            assert self.path == "/"
            assert self.headers["Sec-WebSocket-Protocol"] == "notify"
            key = self.headers["Sec-WebSocket-Key"] + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
            accept = base64.b64encode(hashlib.sha1(key.encode()).digest()).decode()
            self.send_response(101)
            self.send_header("Upgrade", "websocket")
            self.send_header("Connection", "Upgrade")
            self.send_header("Sec-WebSocket-Accept", accept)
            self.send_header("Sec-WebSocket-Protocol", "notify")
            self.end_headers()
            self.connection.recv(4096)
            payload = b'{"notify":["player"]}'
            self.connection.sendall(bytes([0x81, len(payload)]) + payload)
            return
        body = (b'{"websocket_port":3688}' if self.path == "/api/config"
                else b'<html><head><title>OwnTone</title></head><body></body></html>')
        self.send_response(200)
        self.send_header("Content-Type", "application/json" if self.path == "/api/config" else "text/html")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


servers = [ThreadingHTTPServer(("127.0.0.1", port), Backend) for port in (3688, 3689)]
for server in servers:
    threading.Thread(target=server.serve_forever, daemon=True).start()

with tempfile.TemporaryDirectory() as tmp:
    config = (ROOT / "ingress.conf").read_text()
    assert "allow 172.30.32.2;" in config and "deny all;" in config
    # Simulate Supervisor on loopback; use a second loopback source for denial.
    config = config.replace("allow 172.30.32.2;", "allow 127.0.0.1;")
    config = config.replace("/usr/local/share/owntone-addon/ingress-websocket.js",
                            str(ROOT / "ingress-websocket.js"))
    config_path = Path(tmp) / "nginx.conf"
    config_path.write_text(config)
    subprocess.run(["nginx", "-t", "-c", str(config_path)], check=True)
    proxy = subprocess.Popen(["nginx", "-c", str(config_path), "-g", "daemon off;"])
    try:
        for _ in range(50):
            try:
                with socket.create_connection(("127.0.0.1", 3692), timeout=0.1):
                    break
            except OSError:
                time.sleep(0.1)
        with urllib.request.urlopen("http://127.0.0.1:3692/") as response:
            html = response.read().decode()
            assert html.count('<script src="./ingress-websocket.js"></script>') == 1
            assert html.index("ingress-websocket.js") < html.index("<title>")
        with urllib.request.urlopen("http://127.0.0.1:3692/ingress-websocket.js") as response:
            assert "javascript" in response.headers["Content-Type"]
            assert response.headers["Cache-Control"] == "no-store"
        with urllib.request.urlopen("http://127.0.0.1:3692/api/config") as response:
            assert json.load(response) == {"websocket_port": 3688}
        with socket.create_connection(("127.0.0.1", 3692), source_address=("127.0.0.2", 0)) as denied:
            denied.sendall(b"GET / HTTP/1.0\r\nX-Forwarded-For: 172.30.32.2\r\n\r\n")
            assert b"403 Forbidden" in denied.recv(4096)
        ws = websocket.create_connection("ws://127.0.0.1:3692/ws", subprotocols=["notify"], timeout=3)
        ws.send(json.dumps({"notify": ["player"]}))
        assert json.loads(ws.recv()) == {"notify": ["player"]}
        ws.close()
        print("Ingress HTTP, script injection, API, access restrictions and WebSocket notifications passed")
    finally:
        proxy.terminate()
        proxy.wait(timeout=5)
        for server in servers:
            server.shutdown()
