"""Local-only transport fixture for the real FTHTTPClient diagnostics callback."""
import http.server
import subprocess
import sys
import threading
class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        data = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        assert data == b"hello"
        assert self.headers.get("X-FT-SDK-Internal-Request") == "true"
        self.send_response(200)
        self.send_header("Content-Length", "2")
        self.end_headers()
        self.wfile.write(b"ok")
    def log_message(self, *_):
        pass
with http.server.HTTPServer(("127.0.0.1", 0), Handler) as server:
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        result = subprocess.run([sys.argv[1], f"http://127.0.0.1:{server.server_port}/"], timeout=30)
    finally:
        server.shutdown()
    sys.exit(result.returncode)
