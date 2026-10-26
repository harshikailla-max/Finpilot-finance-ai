#!/usr/bin/env python3
"""
FinPilot AI - Secure Backend Server & Reverse Proxy
Handles server-side AI Coach (Google Gemini) and Receipt OCR requests without
exposing secret API keys in the Flutter Web client bundle.
Also serves the Flutter Web production build (build/web) with SPA routing.
"""

import os
import sys
import json
import mimetypes
import shutil
import subprocess
import urllib.request
import urllib.error
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

# Load local .env safely without external dependencies
def load_env():
    env_path = Path(__file__).parent / ".env"
    if not env_path.exists():
        return
    try:
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                k = k.strip()
                v = v.strip().strip("'\"")
                if k and k not in os.environ:
                    os.environ[k] = v
    except Exception as e:
        sys.stderr.write(f"Warning: Failed to load .env: {e}\n")

load_env()

try:
    from azure_receipt_service import analyze_receipt_with_azure
except ImportError:
    from .azure_receipt_service import analyze_receipt_with_azure

def get_ai_key():
    return (os.getenv("GEMINI_API_KEY") or os.getenv("FINPILOT_AI_API_KEY") or "").strip()

def get_ocr_key():
    return os.getenv("FINPILOT_OCR_API_KEY") or ""

def get_azure_endpoint():
    return (
        os.getenv("AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT")
        or os.getenv("DOCUMENT_INTELLIGENCE_ENDPOINT")
        or os.getenv("AZURE_FORM_RECOGNIZER_ENDPOINT")
        or ""
    ).strip().rstrip("/")

def get_azure_key():
    return (
        os.getenv("AZURE_DOCUMENT_INTELLIGENCE_KEY")
        or os.getenv("DOCUMENT_INTELLIGENCE_KEY")
        or os.getenv("AZURE_FORM_RECOGNIZER_KEY")
        or ""
    ).strip()

def http_get_json(url, timeout=10):
    """Performs HTTP GET with Windows SSL bypass via curl if needed."""
    curl_path = shutil.which("curl.exe") or shutil.which("curl")
    if curl_path:
        try:
            cmd = [curl_path]
            if sys.platform.startswith("win"):
                cmd.append("--ssl-no-revoke")
            cmd.extend(["-s", "-w", "\n%{http_code}", url])
            res = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout
            )
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

def call_gemini_api(url, payload_dict, timeout=35):
    """
    Calls Gemini API with robust Windows and Linux SSL/TLS handling.
    Uses curl if available (with --ssl-no-revoke on Windows), falling back to urllib.
    """
    payload_str = json.dumps(payload_dict)
    curl_path = shutil.which("curl.exe") or shutil.which("curl")
    if curl_path:
        try:
            cmd = [curl_path]
            if sys.platform.startswith("win"):
                cmd.append("--ssl-no-revoke")
            cmd.extend([
                "-s",
                "-w", "\n%{http_code}",
                "-X", "POST",
                url,
                "-H", "Content-Type: application/json",
                "--data-binary", "@-"
            ])
            res = subprocess.run(
                cmd,
                input=payload_str,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            out = res.stdout
            lines = out.rsplit("\n", 1)
            code = 200
            if len(lines) > 1 and lines[1].strip().isdigit():
                code = int(lines[1].strip())
            body = lines[0]
            try:
                data = json.loads(body)
            except Exception:
                data = {"raw": body}
            return code, data
        except Exception:
            pass

    req = urllib.request.Request(
        url,
        data=payload_str.encode("utf-8"),
        headers={"Content-Type": "application/json", "User-Agent": "FinPilot-AI/1.0"}
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return resp.status, data
    except urllib.error.HTTPError as e:
        try:
            err_data = json.loads(e.read().decode("utf-8"))
        except Exception:
            err_data = {"error": {"message": str(e)}}
        return e.code, err_data
    except Exception as e:
        return 500, {"error": {"message": str(e)}}

WEB_DIR = Path(__file__).parent / "build" / "web"

class FinPilotHandler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers",
            "Content-Type, Authorization, X-Azure-Key, X-Azure-Endpoint, X-AI-Key"
        )

    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def _send_json(self, status_code, data):
        payload = json.dumps(data).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self._send_cors_headers()
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        url_path = urllib.parse.urlparse(self.path).path

        # Health endpoints
        if url_path in ("/api/health", "/health") or url_path.endswith("/health"):
            self.handle_ai_health()
            return
        elif url_path in ("/api/health/ocr", "/api/health/receipt"):
            self.handle_ocr_health()
            return
        elif url_path.startswith("/api/"):
            self._send_json(404, {"error": "API route not found", "path": url_path})
            return

        # Serve static web files
        self.serve_static(url_path)

    def do_POST(self):
        url_path = urllib.parse.urlparse(self.path).path

        if url_path in ("/api/chat", "/chat") or url_path.endswith("/chat"):
            self.handle_ai_chat()
            return
        elif url_path in ("/api/ocr", "/api/analyze-receipt") or url_path.endswith("/analyze-receipt"):
            self.handle_ocr()
            return
        elif url_path.startswith("/api/"):
            self._send_json(404, {"error": "API route not found", "path": url_path})
            return
        
        self._send_json(405, {"error": "Method Not Allowed"})

    def handle_ai_health(self):
        api_key = get_ai_key().strip()
        default_model = os.environ.get("GEMINI_MODEL", "gemini-3.1-flash-lite")
        if not api_key:
            self._send_json(200, {
                "configured": False,
                "provider": "gemini",
                "model": default_model,
                "status": "unconfigured",
                "message": "AI Backend API key is unconfigured on server. FinPilot's on-device deterministic intelligence engine is active."
            })
            return

        # Safe diagnostic request to official Gemini list models endpoint
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
            safe_msg = "Rate limit or quota exceeded (HTTP 429). Check your Google AI Studio plan."
        elif code == 400:
            status = "invalid_argument"
        elif code == 404:
            status = "not_found"
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

    def handle_ocr_health(self):
        azure_endpoint = get_azure_endpoint()
        azure_key = get_azure_key()
        ocr_key = get_ocr_key().strip()

        if azure_endpoint and azure_key:
            self._send_json(200, {
                "configured": True,
                "provider": "azure-document-intelligence",
                "model": "prebuilt-receipt",
                "tier": "F0",
                "status": "ok",
                "message": "Azure AI Document Intelligence (prebuilt-receipt F0 Free Tier) is active and ready."
            })
        else:
            self._send_json(200, {
                "configured": False,
                "provider": "azure-document-intelligence",
                "model": "prebuilt-receipt",
                "tier": "F0",
                "status": "unconfigured",
                "message": (
                    "Azure Document Intelligence is unconfigured.\n\n"
                    "Configure AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT and "
                    "AZURE_DOCUMENT_INTELLIGENCE_KEY in .env or Vercel Environment Variables."
                ),
                "fallbackAvailable": bool(ocr_key)
            })

    def handle_ai_chat(self):
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length).decode("utf-8")
            data = json.loads(body)
        except Exception as e:
            self._send_json(400, {"isSuccess": False, "errorMessage": f"Invalid JSON payload: {e}"})
            return

        api_key = (get_ai_key() or self.headers.get("X-AI-Key") or data.get("apiKey") or "").strip()
        query = data.get("query", "").strip()
        context_str = data.get("context", "")
        chat_history = data.get("chatHistory", [])

        if not query:
            self._send_json(400, {"isSuccess": False, "errorMessage": "Query cannot be empty"})
            return

        if not api_key:
            self._send_json(200, {
                "isSuccess": False,
                "isConfigured": False,
                "errorType": "unconfigured",
                "errorMessage": (
                    "Google Gemini API key is not configured.\n\n"
                    "To enable the AI Coach:\n"
                    "1. Get a free Gemini API key from https://aistudio.google.com/app/apikey\n"
                    "2. Add FINPILOT_AI_API_KEY=your_key to .env in your project root and restart the server, "
                    "or enter it directly in FinPilot Settings > AI Configuration."
                )
            })
            return

        system_instruction = f"""You are FinPilot AI Coach, an elite personal financial strategist, quantitative wealth advisor, and versatile conversational intelligence operating with the depth, clarity, and analytical precision of ChatGPT.
You are chatting with a user inside the FinPilot AI luxury personal finance platform.

USER LIVE FINANCIAL SNAPSHOT:
{context_str}

CORE CAPABILITIES & DIRECTIVES:
1. True Conversational Intelligence & Seamless Follow-Ups:
   - Engage naturally and adaptively across multi-turn dialogues.
   - Address follow-up questions contextually, remembering figures, calculations, and decisions discussed earlier in the conversation.
   - You can discuss ANY topic requested: personal finance, macroeconomics, markets, career moves, taxation, technology, or general math.
   - Do NOT repeat canned intros, greetings ("Hello! I am FinPilot AI Coach..."), or repetitive disclaimers on every turn.

2. Comprehensive Budgeting Mastery:
   - Provide concrete, tailored budgeting strategies (such as the 50/30/20 rule: 50% Needs, 30% Wants, 20% Savings/Debt; Zero-Based Budgeting; or Envelope Method).
   - Audit spending patterns, highlight unnecessary leaks, and provide actionable category allocations grounded in the user's real financial snapshot.

3. Goal-Driven Saving Plans & Emergency Reserves:
   - Build practical, phased savings blueprints for short-term targets (gadgets, vacations) and long-term milestones (house down payment, retirement).
   - Prioritize a robust 3-to-6 month emergency fund in safe, liquid instruments (liquid mutual funds, sweep-in FDs) before aggressive capital risking.

4. Rigorous Financial Calculations & Mathematical Modeling:
   - Calculate exact figures for compound growth, SIPs (Systematic Investment Plans), loan EMIs, inflation erosion, and debt payoff (Debt Avalanche vs Snowball).
   - When presenting projections, show the underlying numbers and assumptions clearly so the user understands the compounding mechanics.

5. Investment Education & Asset Allocation:
   - Demystify investment instruments clearly: Equity (Direct Stocks, Broad Index Funds, Active Mutual Funds), Fixed Income (PPF, EPF, Debt Funds, FDs), and Commodities (Sovereign Gold Bonds, Physical Gold).
   - Educate on risk tolerance, time horizons, asset allocation (Core & Satellite), and periodic rebalancing.
   - Clarify that all projections and figures are educational and planning insights, not certified SEBI or legal investment advice.

6. Grounded Personalization:
   - When the user asks about their own finances, spending, or savings, reference the exact amounts and categories from their live financial snapshot above.
   - If particular personal records are absent, acknowledge it helpfully and provide a sound benchmark framework.

7. Clean Markdown Presentation:
   - Use clean Markdown with bold key numbers, bullet points, and distinct sections.
   - Conclude strategic advice with a concise, prioritized checklist of next actions.
"""

        # Format multi-turn conversation strictly conforming to Gemini API rules:
        # 1. Must start with role: 'user'
        # 2. Roles must alternate: user <-> model
        # 3. Final turn must be the current query as role: 'user'
        raw_turns = []
        for turn in chat_history[-10:]:
            msg = (turn.get("message") or "").strip()
            if not msg:
                continue
            role = "user" if turn.get("isUser") else "model"
            raw_turns.append({"role": role, "text": msg})

        # Discard leading model turns
        while raw_turns and raw_turns[0]["role"] == "model":
            raw_turns.pop(0)

        # Check if latest turn is already identical to current query
        if raw_turns and raw_turns[-1]["role"] == "user" and raw_turns[-1]["text"] == query:
            raw_turns.pop()

        # Merge adjacent turns with the same role
        merged_turns = []
        for item in raw_turns:
            if merged_turns and merged_turns[-1]["role"] == item["role"]:
                merged_turns[-1]["text"] += f"\n\n{item['text']}"
            else:
                merged_turns.append(dict(item))

        contents = []
        for item in merged_turns:
            contents.append({
                "role": item["role"],
                "parts": [{"text": item["text"]}]
            })

        # Ensure alternating sequence before appending the new query
        if contents and contents[-1]["role"] == "user":
            contents.append({
                "role": "model",
                "parts": [{"text": "Understood. How can I assist you with this?"}]
            })

        contents.append({
            "role": "user",
            "parts": [{"text": query}]
        })

        gemini_payload = {
            "system_instruction": {"parts": [{"text": system_instruction}]},
            "contents": contents,
            "generationConfig": {"temperature": 0.7, "maxOutputTokens": 3072}
        }

        configured_model = os.environ.get("GEMINI_MODEL", "gemini-3.5-flash-lite")
        models_to_try = [configured_model]
        for fallback in ["gemini-3.5-flash-lite", "gemini-3.5-flash", "gemini-flash-latest", "gemini-flash-lite-latest"]:
            if fallback not in models_to_try:
                models_to_try.append(fallback)

        last_code = 500
        last_resp_data = None
        for model_name in models_to_try:
            target_url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={urllib.parse.quote(api_key)}"
            status_code, resp_json = call_gemini_api(target_url, gemini_payload, timeout=35)
            last_code = status_code
            last_resp_data = resp_json

            if status_code == 200:
                candidates = resp_json.get("candidates", [])
                if candidates:
                    parts = candidates[0].get("content", {}).get("parts", [])
                    text_chunks = [p.get("text", "") for p in parts if "text" in p and not p.get("thought", False)]
                    if not text_chunks:
                        text_chunks = [p.get("text", "") for p in parts if "text" in p]
                    answer_text = "".join(text_chunks).strip()
                    if answer_text:
                        self._send_json(200, {
                            "isSuccess": True,
                            "text": answer_text,
                            "model": model_name
                        })
                        return

                self._send_json(200, {
                    "isSuccess": False,
                    "errorType": "empty_response",
                    "errorMessage": "Gemini returned an empty response (possibly blocked by safety filters)."
                })
                return
            elif status_code == 404:
                continue
            else:
                break

        code = last_code
        safe_err = f"Gemini error HTTP {code}"
        error_type = "api_error"
        if isinstance(last_resp_data, dict) and "error" in last_resp_data and "message" in last_resp_data["error"]:
            msg = last_resp_data["error"]["message"]
            if api_key in msg:
                msg = msg.replace(api_key, "[REDACTED_KEY]")
            safe_err = f"{msg} (HTTP {code})"

        if code in (401, 403):
            error_type = "auth_error"
            safe_err = f"Authentication failure (HTTP {code}): Gemini API key is invalid or Generative Language API is disabled."
        elif code == 429:
            error_type = "quota_exceeded"
            safe_err = "Gemini API quota or rate limit exceeded (HTTP 429). Please wait a moment or check your Google AI account."
        elif code == 400:
            error_type = "invalid_request"
            safe_err = f"Invalid request to Gemini API (HTTP 400): {safe_err}"

        self._send_json(200, {
            "isSuccess": False,
            "statusCode": code,
            "errorType": error_type,
            "errorMessage": safe_err
        })

    def handle_ocr(self):
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            if content_length > 15 * 1024 * 1024:
                # Discard remaining incoming bytes so socket doesn't abort on Windows
                remaining = content_length
                while remaining > 0:
                    chunk = self.rfile.read(min(remaining, 65536))
                    if not chunk:
                        break
                    remaining -= len(chunk)

                self._send_json(413, {
                    "isSuccess": False,
                    "statusCode": 413,
                    "errorType": "payloadTooLarge",
                    "errorMessage": "Image payload exceeds 15 MB limit (HTTP 413). Please optimize before uploading."
                })
                return

            body = self.rfile.read(content_length).decode("utf-8")
            data = json.loads(body)
        except Exception as e:
            self._send_json(400, {"isSuccess": False, "errorMessage": f"Invalid payload: {e}"})
            return

        base64_img = data.get("base64Image", "")
        if not base64_img:
            self._send_json(400, {"isSuccess": False, "errorMessage": "Missing base64Image field in request."})
            return

        # 1. Primary: Azure AI Document Intelligence prebuilt-receipt model
        azure_endpoint = (
            get_azure_endpoint()
            or self.headers.get("X-Azure-Endpoint")
            or data.get("azureEndpoint")
            or data.get("endpoint")
            or ""
        ).strip().rstrip("/")

        azure_key = (
            get_azure_key()
            or self.headers.get("X-Azure-Key")
            or data.get("azureKey")
            or data.get("apiKey")
            or ""
        ).strip()

        if azure_endpoint and azure_key:
            result = analyze_receipt_with_azure(
                base64_image=base64_img,
                endpoint=azure_endpoint,
                api_key=azure_key
            )
            status_code = result.get("statusCode", 200) if not result.get("isSuccess") else 200
            self._send_json(status_code, result)
            return

        # 2. Fallback: OCR.space API if configured or default key
        ocr_key = get_ocr_key().strip() or "K86892930388957"

        post_data = urllib.parse.urlencode({
            "apikey": ocr_key,
            "language": "eng",
            "isOverlayRequired": "false",
            "detectOrientation": "true",
            "scale": "true",
            "OCREngine": "2",
            "base64Image": base64_img
        }).encode("utf-8")

        req = urllib.request.Request(
            "https://api.ocr.space/parse/image",
            data=post_data,
            headers={"Content-Type": "application/x-www-form-urlencoded", "User-Agent": "FinPilot-AI/1.0"}
        )

        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                resp_json = json.loads(resp.read().decode("utf-8"))
                self._send_json(200, {
                    "isSuccess": True,
                    "ocrResult": resp_json,
                    "provider": "ocr.space-fallback"
                })
        except urllib.error.HTTPError as e:
            self._send_json(e.code, {
                "isSuccess": False,
                "statusCode": e.code,
                "errorMessage": f"OCR Provider error (HTTP {e.code})"
            })
        except Exception as e:
            self._send_json(500, {
                "isSuccess": False,
                "errorMessage": f"OCR connection error: {str(e)}"
            })

    def serve_static(self, url_path):
        if not WEB_DIR.exists():
            self._send_json(503, {
                "error": "Web build directory (build/web) not found. Run 'flutter build web --release' first."
            })
            return

        clean_path = url_path.lstrip("/")
        if not clean_path:
            clean_path = "index.html"

        file_path = WEB_DIR / clean_path

        # If file doesn't exist, fallback to index.html for Flutter Web SPA routing
        if not file_path.is_file():
            file_path = WEB_DIR / "index.html"

        if not file_path.is_file():
            self._send_json(404, {"error": "File not found"})
            return

        mime_type, _ = mimetypes.guess_type(str(file_path))
        if mime_type is None:
            if file_path.suffix == ".wasm":
                mime_type = "application/wasm"
            elif file_path.suffix == ".js":
                mime_type = "application/javascript"
            elif file_path.suffix == ".json":
                mime_type = "application/json"
            else:
                mime_type = "application/octet-stream"

        try:
            with open(file_path, "rb") as f:
                content = f.read()
            self.send_response(200)
            self.send_header("Content-Type", mime_type)
            self.send_header("Content-Length", str(len(content)))
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(content)
        except Exception as e:
            self._send_json(500, {"error": f"Failed to read file: {e}"})

def run():
    port = int(os.getenv("PORT", 8088))
    server = HTTPServer(("0.0.0.0", port), FinPilotHandler)
    print(f"FinPilot AI Server running on http://localhost:{port}")
    print(f"Serving Flutter Web from: {WEB_DIR}")
    print(f"API Endpoints: /api/health, /api/health/ocr, /api/chat, /api/ocr")
    server.serve_forever()

if __name__ == "__main__":
    run()
