"""
Vercel Serverless Function for Azure AI Document Intelligence Prebuilt Receipt Model.
Endpoint: POST /api/analyze-receipt
"""

import json
import os
import sys
from pathlib import Path
from http.server import BaseHTTPRequestHandler

# Add root directory to sys.path
sys.path.insert(0, str(Path(__file__).parent.parent))

from azure_receipt_service import analyze_receipt_with_azure

class handler(BaseHTTPRequestHandler):
    def _send_cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Azure-Key, X-Azure-Endpoint")

    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors()
        self.end_headers()

    def do_GET(self):
        # Health check
        endpoint = os.getenv("AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT", "").strip()
        key = os.getenv("AZURE_DOCUMENT_INTELLIGENCE_KEY", "").strip()

        data = {
            "configured": bool(endpoint and key),
            "provider": "azure-document-intelligence",
            "model": "prebuilt-receipt",
            "tier": "F0",
            "status": "ok" if (endpoint and key) else "unconfigured",
            "message": (
                "Azure AI Document Intelligence (prebuilt-receipt F0) is configured."
                if (endpoint and key)
                else "Azure Document Intelligence is unconfigured on Vercel."
            )
        }

        payload = json.dumps(data).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self._send_cors()
        self.end_headers()
        self.wfile.write(payload)

    def do_POST(self):
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            if content_length > 15 * 1024 * 1024:
                resp_data = {
                    "isSuccess": False,
                    "statusCode": 413,
                    "errorType": "payloadTooLarge",
                    "errorMessage": "Payload exceeds 15 MB limit (HTTP 413). Please select a compressed image."
                }
                payload = json.dumps(resp_data).encode("utf-8")
                self.send_response(413)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(payload)))
                self._send_cors()
                self.end_headers()
                self.wfile.write(payload)
                return

            body = self.rfile.read(content_length).decode("utf-8")
            req_data = json.loads(body)
        except Exception as e:
            resp_data = {"isSuccess": False, "errorMessage": f"Invalid JSON payload: {e}"}
            payload = json.dumps(resp_data).encode("utf-8")
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self._send_cors()
            self.end_headers()
            self.wfile.write(payload)
            return

        base64_image = req_data.get("base64Image", "")
        if not base64_image:
            resp_data = {"isSuccess": False, "errorMessage": "Missing base64Image field in request body."}
            payload = json.dumps(resp_data).encode("utf-8")
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self._send_cors()
            self.end_headers()
            self.wfile.write(payload)
            return

        endpoint = (
            os.getenv("AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT")
            or os.getenv("DOCUMENT_INTELLIGENCE_ENDPOINT")
            or self.headers.get("X-Azure-Endpoint")
            or req_data.get("endpoint")
            or ""
        ).strip()

        api_key = (
            os.getenv("AZURE_DOCUMENT_INTELLIGENCE_KEY")
            or os.getenv("DOCUMENT_INTELLIGENCE_KEY")
            or self.headers.get("X-Azure-Key")
            or req_data.get("apiKey")
            or ""
        ).strip()

        result = analyze_receipt_with_azure(
            base64_image=base64_image,
            endpoint=endpoint,
            api_key=api_key
        )

        status_code = result.get("statusCode", 200) if not result.get("isSuccess") else 200
        payload = json.dumps(result).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self._send_cors()
        self.end_headers()
        self.wfile.write(payload)
