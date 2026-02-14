#!/usr/bin/env python3
"""
Chao Workstation Listener
Lightweight HTTP server for file operations requested by Chao via Telegram.
Listens on Tailscale interface so only the n8n VPS can reach it.
"""

import json
import os
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

LISTEN_HOST = "100.95.230.36"  # Tailscale IP
LISTEN_PORT = 8786
ALLOWED_BASE = Path("/home/ryan/projects")
LOG_FILE = Path.home() / ".chao-listener.log"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(),
    ],
)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        logging.info("%s %s", self.address_string(), format % args)

    def is_safe_path(self, path_str):
        try:
            return Path(path_str).resolve().is_relative_to(ALLOWED_BASE)
        except (ValueError, RuntimeError):
            return False

    def send_json(self, code, data):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def do_POST(self):
        try:
            body = self.rfile.read(int(self.headers["Content-Length"]))
            req = json.loads(body)
        except (json.JSONDecodeError, TypeError, KeyError):
            self.send_json(400, {"success": False, "error": "Invalid JSON"})
            return

        tool = req.get("tool")
        path_str = req.get("path")

        if not tool or not path_str:
            self.send_json(400, {"success": False, "error": "Missing tool or path"})
            return

        if not self.is_safe_path(path_str):
            logging.warning("Blocked unsafe path: %s", path_str)
            self.send_json(403, {"success": False, "error": f"Path must be under {ALLOWED_BASE}"})
            return

        path = Path(path_str).resolve()
        logging.info("tool=%s path=%s", tool, path)

        handlers = {
            "create_directory": self.handle_create_directory,
            "write_file": self.handle_write_file,
            "read_file": self.handle_read_file,
            "list_files": self.handle_list_files,
            "delete_file": self.handle_delete_file,
            "delete_directory": self.handle_delete_directory,
        }

        handler = handlers.get(tool)
        if not handler:
            self.send_json(400, {"success": False, "error": f"Unknown tool: {tool}"})
            return

        if tool == "write_file":
            result = handler(path, req.get("content", ""))
        else:
            result = handler(path)

        self.send_json(200, result)

    def handle_create_directory(self, path):
        try:
            path.mkdir(parents=True, exist_ok=True)
            return {"success": True, "result": f"Created directory: {path}"}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def handle_write_file(self, path, content):
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
            return {"success": True, "result": f"Wrote {len(content)} bytes to {path}"}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def handle_read_file(self, path):
        try:
            if not path.exists():
                return {"success": False, "error": f"File not found: {path}"}
            if not path.is_file():
                return {"success": False, "error": f"Not a file: {path}"}
            content = path.read_text()
            if len(content) > 50000:
                content = content[:50000] + "\n... (truncated)"
            return {"success": True, "result": content}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def handle_list_files(self, path):
        try:
            if not path.exists():
                return {"success": False, "error": f"Directory not found: {path}"}
            if not path.is_dir():
                return {"success": False, "error": f"Not a directory: {path}"}
            items = []
            for item in sorted(path.iterdir()):
                items.append({"name": item.name, "type": "dir" if item.is_dir() else "file"})
            return {"success": True, "result": json.dumps(items, indent=2)}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def handle_delete_file(self, path):
        try:
            if not path.exists():
                return {"success": False, "error": f"File not found: {path}"}
            if not path.is_file():
                return {"success": False, "error": f"Not a file: {path}"}
            path.unlink()
            return {"success": True, "result": f"Deleted file: {path}"}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def handle_delete_directory(self, path):
        import shutil
        try:
            if not path.exists():
                return {"success": False, "error": f"Directory not found: {path}"}
            if not path.is_dir():
                return {"success": False, "error": f"Not a directory: {path}"}
            if path == Path("/home/ryan/projects"):
                return {"success": False, "error": "Cannot delete the base projects directory"}
            shutil.rmtree(path)
            return {"success": True, "result": f"Deleted directory: {path}"}
        except Exception as e:
            return {"success": False, "error": str(e)}


if __name__ == "__main__":
    server = HTTPServer((LISTEN_HOST, LISTEN_PORT), Handler)
    logging.info("Chao listener starting on %s:%d", LISTEN_HOST, LISTEN_PORT)
    logging.info("Allowed base: %s", ALLOWED_BASE)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logging.info("Shutting down")
        server.shutdown()
