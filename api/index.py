"""
Vercel Serverless Function Fallback Entrypoint
Delegates requests cleanly to chat and health handlers.
"""

from .chat import handler as ChatHandler
from .health import handler as HealthHandler


class handler(ChatHandler):
    def do_GET(self):
        # Health check on GET
        h = HealthHandler(self.request, self.client_address, self.server)
        h.rfile = self.rfile
        h.wfile = self.wfile
        h.headers = self.headers
        h.path = self.path
        h.do_GET()
