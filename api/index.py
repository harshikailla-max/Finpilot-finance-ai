"""
Vercel Serverless Function Entrypoint for FinPilot AI
Proxies AI Coach and OCR requests securely in the cloud.
"""

import os
import sys
from pathlib import Path

# Add project root to sys.path so it can import FinPilotHandler
sys.path.insert(0, str(Path(__file__).parent.parent))

from server import FinPilotHandler

class handler(FinPilotHandler):
    """Vercel serverless request handler subclass."""
    pass
