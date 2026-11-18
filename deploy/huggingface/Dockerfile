# Image for a Hugging Face Space (Docker SDK, free CPU hardware).
#
# Not built from the repository root: scripts/build_space.py assembles a
# small folder (app code, templates, weights) next to this file, and that
# folder is what gets uploaded to the Space.
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=7860 \
    # Spaces sits behind one reverse proxy; trust exactly that hop so the
    # rate limit sees each visitor's own address.
    TRUSTED_PROXIES=1 \
    # Ultralytics writes its settings under $HOME; keep that writable.
    # Never pip-install missing packages while serving: the image must
    # already contain everything, and a failure should show up in the logs.
    YOLO_AUTOINSTALL=false \
    HOME=/home/user \
    YOLO_CONFIG_DIR=/home/user/.config/Ultralytics

# OpenCV needs these shared libraries at runtime.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Spaces runs the container as user 1000, which must own the app folder:
# the scan log (SQLite) is written under it.
RUN useradd --create-home --uid 1000 user \
    && install -d -o user -g user /home/user/app
WORKDIR /home/user/app

COPY --chown=user requirements.txt ./
# CPU-only PyTorch first, at the pinned version, in its own layer so a later
# failure does not download it again. The GPU packages that the lock file
# lists for Linux are dropped: the free hardware has no GPU and they would
# add several gigabytes.
RUN pip install --default-timeout=120 --retries 5 \
        --index-url https://download.pytorch.org/whl/cpu \
        "$(grep -E '^torch==' requirements.txt | cut -d' ' -f1)" \
        "$(grep -E '^torchvision==' requirements.txt | cut -d' ' -f1)"
RUN grep -vE '^(nvidia-|cuda-|triton==)' requirements.txt > /tmp/requirements.cpu.txt \
    && pip install --default-timeout=120 --retries 5 -r /tmp/requirements.cpu.txt \
    && rm /tmp/requirements.cpu.txt

COPY --chown=user . .
USER user
RUN mkdir -p instance "$YOLO_CONFIG_DIR"

EXPOSE 7860

# One worker: the detector holds a full model copy per process, and the free
# hardware has 2 vCPUs.
CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT} --workers 1 --threads 2 --timeout 120 'coffee_leaf:create_app()'"]
