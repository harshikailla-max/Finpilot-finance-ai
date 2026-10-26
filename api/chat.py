"""
Vercel Serverless Function: FinPilot AI Coach (Google Gemini)
Endpoint: POST /api/chat
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
    """Loads local .env safely if present."""
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


class handler(BaseHTTPRequestHandler):
    def _send_cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers",
            "Content-Type, Authorization, X-AI-Key, X-Azure-Key, X-Azure-Endpoint"
        )

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
        # Return health diagnostic on GET
        api_key = get_ai_key()
        model = os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite")
        self._send_json(200, {
            "status": "ok" if api_key else "unconfigured",
            "configured": bool(api_key),
            "endpoint": "/api/chat",
            "model": model,
            "message": "FinPilot AI Coach serverless endpoint is ready." if api_key else "GEMINI_API_KEY is not set."
        })

    def do_POST(self):
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length).decode("utf-8")
            data = json.loads(body)
        except Exception as e:
            self._send_json(400, {"isSuccess": False, "errorMessage": f"Invalid JSON payload: {e}"})
            return

        api_key = (
            get_ai_key()
            or self.headers.get("X-AI-Key")
            or data.get("apiKey")
            or ""
        ).strip()
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
                    "GEMINI_API_KEY is not configured on the server.\n\n"
                    "Please add GEMINI_API_KEY in your Vercel Project Settings > Environment Variables, "
                    "or add it to your local .env file."
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

        # Format multi-turn conversation according to Gemini API rules:
        # 1. Start with role: 'user'
        # 2. Roles must alternate: user <-> model
        # 3. Final turn is current query as role: 'user'
        raw_turns = []
        for turn in chat_history[-10:]:
            msg = (turn.get("message") or "").strip()
            if not msg:
                continue
            role = "user" if turn.get("isUser") else "model"
            raw_turns.append({"role": role, "text": msg})

        # Drop leading model greetings
        while raw_turns and raw_turns[0]["role"] == "model":
            raw_turns.pop(0)

        # Discard duplicate last query
        if raw_turns and raw_turns[-1]["role"] == "user" and raw_turns[-1]["text"] == query:
            raw_turns.pop()

        # Merge adjacent same-role turns
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
            error_type = "invalid_argument"
            safe_err = f"Invalid request to Gemini API (HTTP 400): {safe_err}"

        self._send_json(200, {
            "isSuccess": False,
            "statusCode": code,
            "errorType": error_type,
            "errorMessage": safe_err
        })
