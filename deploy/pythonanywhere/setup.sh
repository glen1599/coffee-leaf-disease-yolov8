#!/usr/bin/env bash
# Install or update the light server on a PythonAnywhere account.
#
# Run it in a PythonAnywhere Bash console, after creating the web app in the
# Web tab (Manual configuration, Python 3.11):
#
#   curl -fsSLo setup.sh https://raw.githubusercontent.com/glen1599/coffee-leaf-disease-yolov8/feat/mobile-app/deploy/pythonanywhere/setup.sh
#   bash setup.sh
#
# Run it again later to deploy a newer version. Then press Reload in the Web
# tab. Guide: docs/DEPLOY_PYTHONANYWHERE.md
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/glen1599/coffee-leaf-disease-yolov8.git}"
BRANCH="${BRANCH:-feat/mobile-app}"
APP_DIR="${APP_DIR:-$HOME/coffee-leaf-disease-yolov8}"
VENV="${VENV:-$HOME/.virtualenvs/cek-daun-kopi}"
PYTHON="${PYTHON:-python3.11}"
USER_NAME="${USER_NAME:-$(whoami)}"
WSGI_FILE="${WSGI_FILE:-/var/www/${USER_NAME}_pythonanywhere_com_wsgi.py}"

say() { printf '\n==> %s\n' "$*"; }

say "1/4 Code: $BRANCH -> $APP_DIR"
if [ -d "$APP_DIR/.git" ]; then
    git -C "$APP_DIR" fetch --depth 1 origin "$BRANCH"
    git -C "$APP_DIR" reset --hard FETCH_HEAD
else
    # Only the folders the server needs: the free plan has 512 MB of disk.
    git clone --depth 1 --branch "$BRANCH" --single-branch --filter=blob:none --sparse \
        "$REPO_URL" "$APP_DIR"
    git -C "$APP_DIR" sparse-checkout set coffee_leaf templates static deploy mobile/assets/models
fi
mkdir -p "$APP_DIR/instance"

say "2/4 Packages -> $VENV"
if [ ! -x "$VENV/bin/python" ]; then
    "$PYTHON" -m venv "$VENV"
fi
"$VENV/bin/python" -m pip install --quiet --no-cache-dir --upgrade pip
"$VENV/bin/python" -m pip install --quiet --no-cache-dir -r "$APP_DIR/deploy/lite/requirements.txt"
SITE_PACKAGES="$("$VENV/bin/python" -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"

say "3/4 WSGI file"
RENDERED="$APP_DIR/instance/wsgi.py"
sed -e "s|__APP_DIR__|$APP_DIR|" -e "s|__VENV_SITE_PACKAGES__|$SITE_PACKAGES|" \
    "$APP_DIR/deploy/pythonanywhere/wsgi.py" > "$RENDERED"
if [ -f "$WSGI_FILE" ]; then
    cp "$WSGI_FILE" "$WSGI_FILE.bak"
    cp "$RENDERED" "$WSGI_FILE"
    echo "Wrote $WSGI_FILE (previous version kept as .bak)"
else
    echo "No web app yet ($WSGI_FILE not found)."
    echo "Create it in the Web tab (Manual configuration, Python 3.11), then run this script again."
fi

say "4/4 Self-check"
# A throwaway database, so the check does not count as a scan in /api/stats.
CHECK_DB="$(mktemp -d)/check.sqlite3"
DATABASE_PATH="$CHECK_DB" "$VENV/bin/python" - "$RENDERED" <<'PY'
import runpy, sys

app = runpy.run_path(sys.argv[1])["application"]
client = app.test_client()
health = client.get("/api/v1/health").get_json()
assert health["status"] == "ok", health
print("health:", health["status"], "| runtime:", health["model"]["runtime"],
      "| classes:", ", ".join(health["model"]["classes"]))
with open(app.static_folder + "/img/samples/coffee_leaf_rust.jpg", "rb") as photo:
    from io import BytesIO
    answer = client.post("/api/v1/predict", data={"file": (BytesIO(photo.read()), "leaf.jpg")},
                         content_type="multipart/form-data").get_json()
print("sample photo:", answer["disease"]["name"], answer["confidence"]["value"], "%")
PY
rm -rf "$(dirname "$CHECK_DB")"

say "Done. Disk used:"
du -sh "$APP_DIR" "$VENV" 2>/dev/null || true
echo
echo "Last step: open the Web tab and press Reload."
echo "Then visit https://${USER_NAME}.pythonanywhere.com/api/v1/health"
