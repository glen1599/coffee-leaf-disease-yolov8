# Light image for small free hosts such as Render (512 MB RAM).
#
# Runs the ONNX export with ONNX Runtime alone (DETECTOR_BACKEND=onnx): no
# PyTorch, no Ultralytics, same detections. Build from the repository root:
#
#   docker build -f deploy/render/Dockerfile -t cek-daun-kopi-lite .
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    # Render passes its own PORT; this is only the fallback.
    PORT=10000 \
    DETECTOR_BACKEND=onnx \
    # Render's load balancer is one proxy hop in front of the app.
    TRUSTED_PROXIES=1 \
    # The free plan is a fraction of one CPU.
    ONNX_THREADS=1

RUN useradd --create-home --uid 1000 user \
    && install -d -o user -g user /home/user/app
WORKDIR /home/user/app

COPY deploy/render/requirements.txt ./requirements.txt
RUN pip install --default-timeout=120 --retries 5 -r requirements.txt

COPY --chown=user app.py LICENSE ./
COPY --chown=user coffee_leaf ./coffee_leaf
COPY --chown=user templates ./templates
COPY --chown=user static ./static
# The versioned copy of the model (the one the mobile app ships).
COPY --chown=user mobile/assets/models/best.onnx ./models/best.onnx

USER user
RUN mkdir -p instance

EXPOSE 10000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s \
    CMD python -c "import os, urllib.request; urllib.request.urlopen(f'http://127.0.0.1:{os.environ[\"PORT\"]}/api/v1/health')"

CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT} --workers 1 --threads 2 --timeout 120 'coffee_leaf:create_app()'"]
