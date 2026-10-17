"""Development entrypoint.

Run locally with ``python app.py``.
In production serve the factory instead: ``gunicorn "coffee_leaf:create_app()"``.
"""

from __future__ import annotations

import logging
import os

from coffee_leaf import create_app
from coffee_leaf.config import APP_NAME, APP_VERSION

app = create_app()

if __name__ == "__main__":
    host = os.getenv("HOST", "127.0.0.1")
    port = int(os.getenv("PORT", "5000"))
    debug = os.getenv("FLASK_DEBUG", "0") == "1"

    logging.getLogger(__name__).info("%s v%s -> http://%s:%s", APP_NAME, APP_VERSION, host, port)
    app.run(host=host, port=port, debug=debug)
