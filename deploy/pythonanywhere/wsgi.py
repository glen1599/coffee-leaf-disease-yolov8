"""WSGI entry point for PythonAnywhere.

``setup.sh`` copies this file over the one PythonAnywhere created for the web
app (``/var/www/<user>_pythonanywhere_com_wsgi.py``), with the two paths
below filled in. The server runs in light mode: ONNX Runtime only, no
PyTorch, which keeps it inside the free plan's 512 MB of disk.
"""

import os
import site
import sys

APP_DIR = "__APP_DIR__"
VENV_SITE_PACKAGES = "__VENV_SITE_PACKAGES__"

# The packages installed by setup.sh, without having to set the virtualenv
# in the Web tab as well.
site.addsitedir(VENV_SITE_PACKAGES)
if APP_DIR not in sys.path:
    sys.path.insert(0, APP_DIR)

os.environ.setdefault("DETECTOR_BACKEND", "onnx")
# The versioned copy of the model (models/best.onnx is not in git).
os.environ.setdefault("ONNX_MODEL_PATH", os.path.join(APP_DIR, "mobile/assets/models/best.onnx"))
# Free accounts are metered in CPU seconds; one thread is plenty.
os.environ.setdefault("ONNX_THREADS", "1")
# PythonAnywhere's front-end proxy is one hop in front of the app.
os.environ.setdefault("TRUSTED_PROXIES", "1")
os.environ.setdefault("DATABASE_PATH", os.path.join(APP_DIR, "instance", "app.sqlite3"))

from coffee_leaf import create_app  # noqa: E402

application = create_app()
