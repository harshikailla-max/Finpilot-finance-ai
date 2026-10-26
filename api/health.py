"""
Vercel Serverless Function: AI Backend Health Check
Endpoint: GET /api/health
"""

import json
import os
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler
from pathlib import Path


def load_env():
    for parent in [Path(__file__).parent, Path(__file__).parent.parent]:
        env_file = parent / ".env"
        if env_file.exists():
            try:
                with open(env_file, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            k, v = line.split("=", 1)
                            k = k.strip()
                            v = v.strip().strip("'\"")
                            if k and k not in os.environ:
                                os.environ[k] = v
            except Exception:
                pass


load_env()


def get_ai_key():
    return (
        os.getenv("GEMINI_API_KEY")
        or os.getenv("FINPILOT_AI_API_KEY")
        or ""
    ).strip()


def http_get_json(url, timeout=10):
    curl_path = shutil.which("curl.exe") or shutil.which("curl")
    if curl_path:
        try:
            cmd = [curl_path]
            if sys.platform.startswith("win"):
                cmd.append("--ssl-no-revoke")
            cmd.extend(["-s", "-w", "\n%{http_code}", url])
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
            out = res.stdout
            lines = out.rsplit("\n", 1)
            code = 200
            if len(lines) > 1 and lines[1].strip().isdigit():
                code = int(lines[1].strip())
            body = lines[0]
            try:
                data = json.loads(body)
            except Exception:
                data = {}
            return code, data
        except Exception:
            pass

    req = urllib.request.Request(url, headers={"User-Agent": "FinPilot-AI/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return resp.status, data
    except urllib.error.HTTPError as e:
        try:
            data = json.loads(e.read().decode("utf-8"))
        except Exception:
            data = {}
        return e.code, data
    except Exception as e:
        return 500, {"error": {"message": str(e)}}


class handler(BaseHTTPRequestHandler):
    def _send_cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-AI-Key")

    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors()
        self.end_headers()

    def _send_json(self, status_code, data):
        payload = json.dumps(data).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self._send_cors()
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        api_key = get_ai_key()
        default_model = os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite")

        if not api_key:
            self._send_json(200, {
                "configured": False,
                "provider": "gemini",
                "model": default_model,
                "status": "unconfigured",
                "message": (
                    "GEMINI_API_KEY is not configured on the server.\n"
                    "Configure GEMINI_API_KEY in Vercel Project Settings > Environment Variables."
                )
            })
            return

        health_url = f"https://generativelanguage.googleapis.com/v1beta/models?key={urllib.parse.quote(api_key)}"
        status_code, resp_data = http_get_json(health_url, timeout=10)

        if status_code == 200:
            self._send_json(200, {
                "configured": True,
                "status": "ok",
                "provider": "gemini",
                "model": default_model,
                "message": f"Successfully connected to Google Gemini API ({default_model})."
            })
            return

        code = status_code
        safe_msg = f"HTTP {code}"
        status = "error"
        if isinstance(resp_data, dict) and "error" in resp_data and "message" in resp_data["error"]:
            msg = resp_data["error"]["message"]
            if api_key in msg:
                msg = msg.replace(api_key, "[REDACTED_KEY]")
            safe_msg = msg

        if code in (401, 403):
            status = "auth_failed"
            safe_msg = f"Authentication failure ({code}): API key invalid, unauthorized, or Gemini API not enabled."
        elif code == 429:
            status = "rate_limited"
            safe_msg = "Rate limit or quota exceeded (HTTP 429). Check your Google AI Studio account."
        elif code >= 500:
            status = "server_error"
            safe_msg = f"Google Gemini server error ({code}). Please retry shortly."

        self._send_json(200, {
            "configured": True,
            "status": status,
            "statusCode": code,
            "provider": "gemini",
            "model": default_model,
            "message": safe_msg
        })
