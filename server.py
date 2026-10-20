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
    return os.getenv("FINPILOT_AI_API_KEY") or os.getenv("GEMINI_API_KEY") or ""

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
        if url_path == "/api/health":
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

        if url_path == "/api/chat":
            self.handle_ai_chat()
            return
        elif url_path in ("/api/ocr", "/api/analyze-receipt"):
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
        req = urllib.request.Request(health_url, headers={"User-Agent": "FinPilot-AI/1.0"})

        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                if resp.status == 200:
                    self._send_json(200, {
                        "configured": True,
                        "status": "ok",
                        "provider": "gemini",
                        "model": default_model,
                        "message": f"Successfully connected to Google Gemini API ({default_model})."
                    })
                    return
        except urllib.error.HTTPError as e:
            code = e.code
            safe_msg = f"HTTP {code}"
            status = "error"
            try:
                err_body = json.loads(e.read().decode("utf-8"))
                if "error" in err_body and "message" in err_body["error"]:
                    msg = err_body["error"]["message"]
                    # Clean out any accidental key reflection
                    if api_key in msg:
                        msg = msg.replace(api_key, "[REDACTED_KEY]")
                    safe_msg = msg
            except Exception:
                pass

            if code in (401, 403):
                status = "auth_failed"
                safe_msg = f"Authentication failure ({code}): API key invalid, unauthorized, or Gemini API not enabled in Google Cloud Console."
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
                "model": "gemini-1.5-flash",
                "message": safe_msg
            })
        except urllib.error.URLError as e:
            self._send_json(200, {
                "configured": True,
                "status": "network_error",
                "provider": "gemini",
                "model": "gemini-1.5-flash",
                "message": f"Network error reaching Google Gemini API: {e.reason}"
            })
        except Exception as e:
            self._send_json(200, {
                "configured": True,
                "status": "error",
                "provider": "gemini",
                "model": "gemini-1.5-flash",
                "message": f"Connection check error: {str(e)}"
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

        system_instruction = f"""You are FinPilot AI Coach, an elite personal financial strategist and versatile AI advisor operating at the conversational depth, analytical brilliance, and nuanced reasoning of ChatGPT.
You are chatting with a user inside the FinPilot AI luxury personal finance platform.

You think deeply before providing each response. When asked any financial, analytical, or strategic question, reason carefully step-by-step through the underlying numbers, economic principles, tax laws, behavioral factors, and risk tradeoffs. Provide comprehensive, dynamic, personalized analysis rather than generic or fixed answers.

USER LIVE FINANCIAL SNAPSHOT:
{context_str}

CORE CAPABILITIES & DIRECTIVES:
1. Deep Reasoning & Thoughtful Deliberation ("Think Before Answering"):
   - Dissect the user's inquiry systematically. Break complex trade-offs into clear logical components (e.g. Old vs New Tax Regime, Debt vs Equity asset allocation, Prepaying Home Loan vs SIP investing, Term Insurance vs ULIP).
   - Show the math: when relevant, calculate explicit numbers, compounding outcomes, tax brackets, and net cash flows.
   - Address hidden trade-offs, liquidity risks, opportunity costs, inflation impacts, and long-term consequences.

2. True Conversational Intelligence (Like ChatGPT):
   - You are not limited to canned scripts or fixed answers. Never give robotic, templated replies. Answer dynamically to what the user actually asks.
   - Handle questions across ANY topic: personal finance, macroeconomic trends, Indian & global markets, real estate, taxation, career advice, technology, startups, math, or everyday conversation.
   - Maintain multi-turn context naturally. Reference previous points discussed when relevant.

3. Context-Aware Personalization:
   - When the user asks about their own money, spending, savings, or goals, ground your answers in their live financial records above (quote exact ₹ amounts).
   - If specific personal data is missing from the snapshot, acknowledge what's missing politely and offer a well-reasoned benchmark or framework.

4. Actionable & Engaging Structure:
   - Structure answers with clean Markdown headings, bullet points, and bold emphasis.
   - Conclude complex advice with a clear, prioritized checklist of next actions.
   - Clarify that calculations and models are educational and planning estimates and do not constitute certified SEBI/CA legal advice.
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

        configured_model = os.environ.get("GEMINI_MODEL", "gemini-3.1-flash-lite")
        models_to_try = [configured_model]
        for fallback in ["gemini-3.1-flash-lite", "gemini-3.5-flash-lite", "gemini-3.5-flash", "gemini-3.8-flash"]:
            if fallback not in models_to_try:
                models_to_try.append(fallback)

        last_error = None
        for model_name in models_to_try:
            target_url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={urllib.parse.quote(api_key)}"
            req = urllib.request.Request(
                target_url,
                data=json.dumps(gemini_payload).encode("utf-8"),
                headers={"Content-Type": "application/json", "User-Agent": "FinPilot-AI/1.0"}
            )

            try:
                with urllib.request.urlopen(req, timeout=30) as resp:
                    resp_json = json.loads(resp.read().decode("utf-8"))
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
            except urllib.error.HTTPError as e:
                if e.code == 404:
                    # Model not found on this API tier; try next model in list
                    last_error = e
                    continue
                else:
                    last_error = e
                    break
            except Exception as e:
                last_error = e
                break

        if isinstance(last_error, urllib.error.HTTPError):
            code = last_error.code
            safe_err = f"Gemini error HTTP {code}"
            error_type = "api_error"
            try:
                err_data = json.loads(last_error.read().decode("utf-8"))
                if "error" in err_data and "message" in err_data["error"]:
                    msg = err_data["error"]["message"]
                    if api_key in msg:
                        msg = msg.replace(api_key, "[REDACTED_KEY]")
                    safe_err = f"{msg} (HTTP {code})"
            except Exception:
                pass

            if code in (401, 403):
                error_type = "auth_error"
                safe_err = f"Authentication failure (HTTP {code}): Gemini API key is invalid or Generative Language API is disabled in Google Cloud Console."
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
        elif isinstance(last_error, urllib.error.URLError):
            self._send_json(200, {
                "isSuccess": False,
                "errorType": "network_timeout",
                "errorMessage": f"Network error reaching Google Gemini API: {last_error.reason}"
            })
        elif last_error is not None:
            self._send_json(200, {
                "isSuccess": False,
                "errorType": "server_error",
                "errorMessage": f"Connection error: {str(last_error)}"
            })

    def handle_ocr(self):
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            if content_length > 4 * 1024 * 1024:
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
                    "errorMessage": "Image payload exceeds 4 MB Document Intelligence limit (HTTP 413). Please optimize before uploading."
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
        ocr_key = get_ocr_key().strip() or "K83315608288957"

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
