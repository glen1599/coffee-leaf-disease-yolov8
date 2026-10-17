/**
 * Coffee Leaf Disease Detection — front-end controller.
 * Talks to the Flask API: POST /predict (multipart) and POST /predict/camera (JSON).
 */
(() => {
  "use strict";

  const MAX_BYTES = 10 * 1024 * 1024;
  const HISTORY_KEY = "coffee_leaf_history_v2";
  const HISTORY_LIMIT = 10;

  const $ = (selector) => document.querySelector(selector);
  const $$ = (selector) => Array.from(document.querySelectorAll(selector));

  const state = {
    mode: "upload",
    file: null,
    source: null, // ObjectURL / data URL currently previewed
    stream: null,
    result: null,
  };

  /* ------------------------------------------------------------------ toasts */
  function toast(message, kind = "info") {
    const host = $("#toasts");
    if (!host) return;
    const el = document.createElement("div");
    el.className = `toast toast--${kind}`;
    el.textContent = message;
    host.appendChild(el);
    requestAnimationFrame(() => el.classList.add("is-visible"));
    setTimeout(() => {
      el.classList.remove("is-visible");
      setTimeout(() => el.remove(), 300);
    }, 4200);
  }

  /* ----------------------------------------------------------------- header */
  const header = $("#site-header");
  const onScroll = () => header.classList.toggle("is-stuck", window.scrollY > 12);
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  $("#nav-toggle").addEventListener("click", (event) => {
    const open = header.classList.toggle("is-open");
    event.currentTarget.setAttribute("aria-expanded", String(open));
  });
  $$(".nav-links a").forEach((link) =>
    link.addEventListener("click", () => header.classList.remove("is-open"))
  );

  /* ------------------------------------------------------------ reveal on scroll */
  const revealObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          revealObserver.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.12 }
  );
  $$(".reveal").forEach((el) => revealObserver.observe(el));

  /* -------------------------------------------------------------------- tabs */
  $$(".tab").forEach((tab) =>
    tab.addEventListener("click", async () => {
      state.mode = tab.dataset.mode;
      $$(".tab").forEach((other) => {
        const active = other === tab;
        other.classList.toggle("is-active", active);
        other.setAttribute("aria-selected", String(active));
      });
      $("#pane-upload").hidden = state.mode !== "upload";
      $("#pane-camera").hidden = state.mode !== "camera";
      if (state.mode === "camera") await startCamera();
      else stopCamera();
      syncRunButton();
    })
  );

  /* --------------------------------------------------------------- confidence */
  const range = $("#conf-range");
  const rangeOutput = $("#conf-value");
  function paintRange() {
    const pct = ((range.value - range.min) / (range.max - range.min)) * 100;
    range.style.setProperty("--fill", `${pct}%`);
    rangeOutput.textContent = Number(range.value).toFixed(2);
  }
  range.addEventListener("input", paintRange);
  paintRange();

  /* ------------------------------------------------------------------ upload */
  const dropzone = $("#dropzone");
  const fileInput = $("#file-input");
  const preview = $("#preview");

  function setPreview(src, name) {
    $("#preview-img").src = src;
    $("#preview-name").textContent = name;
    dropzone.classList.add("has-preview");
    preview.style.display = "block";
    dropzone.querySelectorAll(":scope > :not(.preview)").forEach((el) => (el.style.display = "none"));
  }

  function clearPreview() {
    if (state.source && state.source.startsWith("blob:")) URL.revokeObjectURL(state.source);
    state.file = null;
    state.source = null;
    $("#preview-img").removeAttribute("src");
    dropzone.classList.remove("has-preview");
    preview.style.display = "none";
    dropzone.querySelectorAll(":scope > :not(.preview)").forEach((el) => (el.style.display = ""));
    fileInput.value = "";
    syncRunButton();
  }

  function acceptFile(file) {
    if (!file.type.startsWith("image/")) {
      toast("Only image files are supported.", "warning");
      return;
    }
    if (file.size > MAX_BYTES) {
      toast("That image is larger than the 10 MB limit.", "warning");
      return;
    }
    state.file = file;
    state.source = URL.createObjectURL(file);
    setPreview(state.source, `${file.name} · ${(file.size / 1024).toFixed(0)} KB`);
    syncRunButton();
  }

  dropzone.addEventListener("click", (event) => {
    if (!event.target.closest("#preview")) fileInput.click();
  });
  dropzone.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      fileInput.click();
    }
  });
  ["dragenter", "dragover"].forEach((type) =>
    dropzone.addEventListener(type, (event) => {
      event.preventDefault();
      dropzone.classList.add("is-drag");
    })
  );
  ["dragleave", "drop"].forEach((type) =>
    dropzone.addEventListener(type, (event) => {
      event.preventDefault();
      dropzone.classList.remove("is-drag");
    })
  );
  dropzone.addEventListener("drop", (event) => {
    const file = event.dataTransfer?.files?.[0];
    if (file) acceptFile(file);
  });
  fileInput.addEventListener("change", () => {
    if (fileInput.files[0]) acceptFile(fileInput.files[0]);
  });
  $("#preview-clear").addEventListener("click", (event) => {
    event.stopPropagation();
    clearPreview();
  });

  $$("[data-sample]").forEach((chip) =>
    chip.addEventListener("click", async () => {
      try {
        const response = await fetch(chip.dataset.sample);
        const blob = await response.blob();
        acceptFile(new File([blob], chip.dataset.name, { type: blob.type || "image/jpeg" }));
      } catch {
        toast("Could not load the sample image.", "error");
      }
    })
  );

  /* ------------------------------------------------------------------ camera */
  const video = $("#camera-video");
  const placeholder = $("#camera-placeholder");

  async function startCamera() {
    if (state.stream) return;
    if (!navigator.mediaDevices?.getUserMedia) {
      $("#camera-note").textContent = "This browser does not expose a camera API.";
      toast("Camera API is unavailable in this browser.", "warning");
      return;
    }
    try {
      state.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "environment", width: { ideal: 1280 }, height: { ideal: 960 } },
      });
      video.srcObject = state.stream;
      placeholder.classList.add("is-hidden");
      $("#camera-note").textContent = "Camera streaming.";
    } catch {
      toast("Camera access was denied by the browser.", "warning");
    }
    syncRunButton();
  }

  function stopCamera() {
    if (!state.stream) return;
    state.stream.getTracks().forEach((track) => track.stop());
    state.stream = null;
    video.srcObject = null;
    placeholder.classList.remove("is-hidden");
  }

  function captureFrame() {
    if (!video.videoWidth) return null;
    const canvas = $("#camera-canvas");
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    canvas.getContext("2d").drawImage(video, 0, 0);
    return canvas.toDataURL("image/jpeg", 0.9);
  }

  /* -------------------------------------------------------------------- run */
  const runButton = $("#run-btn");
  const consoleStatus = $("#console-status");

  function syncRunButton() {
    const ready = state.mode === "camera" ? Boolean(state.stream) : Boolean(state.file);
    runButton.disabled = !ready;
  }

  function setBusy(busy) {
    runButton.classList.toggle("is-loading", busy);
    runButton.disabled = busy;
    consoleStatus.querySelector("span").textContent = busy ? "analysing…" : "idle";
    if (!busy) syncRunButton();
  }

  runButton.addEventListener("click", async () => {
    if (state.mode === "camera" && !state.stream) {
      toast("The camera is not streaming yet.", "warning");
      return;
    }

    setBusy(true);
    const conf = Number(range.value);
    try {
      let response;
      if (state.mode === "camera") {
        const frame = captureFrame();
        if (!frame) throw new Error("empty-frame");
        response = await fetch("/predict/camera", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ image: frame, conf }),
        });
      } else {
        const body = new FormData();
        body.append("file", state.file, state.file.name);
        body.append("conf", String(conf));
        response = await fetch("/predict", { method: "POST", body });
      }

      const payload = await response.json().catch(() => null);
      if (!response.ok || !payload || payload.error) {
        toast(payload?.error || `The server returned HTTP ${response.status}.`, "error");
        return;
      }
      renderResult(payload);
      saveHistory(payload);
    } catch (error) {
      toast(
        error.message === "empty-frame"
          ? "The camera frame is still empty. Try again in a moment."
          : "Could not reach the server. Is it still running?",
        "error"
      );
    } finally {
      setBusy(false);
    }
  });

  /* ---------------------------------------------------------------- render */
  function meterKind(detection) {
    if (detection.label === "sehat") return "";
    if (detection.confidence >= 70) return "is-high";
    if (detection.confidence >= 40) return "is-moderate";
    return "";
  }

  function fillList(element, items) {
    element.innerHTML = "";
    items.forEach((text) => {
      const li = document.createElement("li");
      li.textContent = text;
      element.appendChild(li);
    });
  }

  function renderResult(payload, options = {}) {
    state.result = payload;

    $("#result-empty").hidden = true;
    $("#result-body").hidden = false;

    $("#stage-img").src = payload.annotated_image;
    $("#thumb-original").src = payload.original_image || payload.annotated_image;
    $("#thumb-crop").src = payload.cropped_image || payload.annotated_image;
    $("#stage-caption").textContent = `${payload.frame.width}×${payload.frame.height} px · ${payload.total_detections} detection(s) · ${payload.inference_ms} ms`;

    const info = payload.info;
    const dominant = payload.dominant_class;
    const top = payload.detections.reduce(
      (best, detection) => (best === null || detection.confidence > best.confidence ? detection : best),
      null
    );

    const verdictEl = $("#stat-verdict");
    verdictEl.textContent = info?.label || dominant || "—";
    verdictEl.className = info ? `is-${info.severity}` : "";

    $("#stat-confidence").textContent = top ? `${top.confidence}%` : "—";
    $("#stat-confidence").className = "";
    $("#stat-count").textContent = payload.total_detections;
    $("#stat-count").className = "";
    $("#stat-latency").textContent = `${payload.inference_ms} ms`;
    $("#stat-latency").className = "";

    const verdict = $("#verdict");
    if (info) {
      verdict.hidden = false;
      verdict.className = `verdict is-${info.severity}`;
      $("#verdict-title").textContent = info.label;
      const badge = $("#verdict-badge");
      badge.textContent = info.status;
      badge.className = `badge is-${info.severity}`;
      $("#verdict-pathogen").textContent = info.pathogen;
      $("#verdict-summary").textContent = info.summary;
      fillList($("#verdict-symptoms"), info.symptoms);
      fillList($("#verdict-treatment"), info.treatment);
    } else {
      verdict.hidden = true;
    }

    const list = $("#det-list");
    list.innerHTML = "";
    if (!payload.detections.length) {
      list.innerHTML = '<p style="color:var(--faint);font-size:.85rem;">No leaf detected above the confidence threshold. Try lowering it or use a closer photo.</p>';
    }
    payload.detections.forEach((detection, index) => {
      const row = document.createElement("div");
      row.className = "det";
      row.innerHTML = `
        <div class="det-head">
          <b>${detection.label_text || detection.label}</b>
          <span class="mono">${detection.confidence}%</span>
        </div>
        <div class="meter"><i class="${meterKind(detection)}"></i></div>`;
      list.appendChild(row);
      const bar = row.querySelector("i");
      setTimeout(() => (bar.style.width = `${detection.confidence}%`), 40 + index * 70);
    });

    if (!options.silent) {
      $("#result-body").scrollIntoView({ behavior: "smooth", block: "nearest" });
    }
  }

  /* --------------------------------------------------------------- actions */
  $("#btn-download").addEventListener("click", () => {
    if (!state.result?.annotated_image) return;
    const link = document.createElement("a");
    link.href = state.result.annotated_image;
    link.download = `coffee-leaf-result-${Date.now()}.jpg`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    toast("Annotated result downloaded.", "success");
  });

  $("#btn-copy").addEventListener("click", async () => {
    if (!state.result) return;
    const summary = {
      dominant_class: state.result.dominant_class,
      verdict: state.result.info?.label ?? null,
      inference_ms: state.result.inference_ms,
      detections: state.result.detections.map(({ label, confidence, box }) => ({ label, confidence, box })),
    };
    try {
      await navigator.clipboard.writeText(JSON.stringify(summary, null, 2));
      toast("Detection JSON copied to the clipboard.", "success");
    } catch {
      toast("Clipboard access was blocked by the browser.", "warning");
    }
  });

  $("#btn-reset").addEventListener("click", () => {
    state.result = null;
    $("#result-body").hidden = true;
    $("#result-empty").hidden = false;
    clearPreview();
  });

  /* --------------------------------------------------------------- history */
  function thumbnail(dataUrl) {
    return new Promise((resolve) => {
      const image = new Image();
      image.onload = () => {
        const canvas = document.createElement("canvas");
        const scale = Math.min(1, 220 / image.width);
        canvas.width = Math.round(image.width * scale);
        canvas.height = Math.round(image.height * scale);
        canvas.getContext("2d").drawImage(image, 0, 0, canvas.width, canvas.height);
        resolve(canvas.toDataURL("image/jpeg", 0.6));
      };
      image.onerror = () => resolve("");
      image.src = dataUrl;
    });
  }

  function readHistory() {
    try {
      return JSON.parse(localStorage.getItem(HISTORY_KEY) || "[]");
    } catch {
      return [];
    }
  }

  async function saveHistory(payload) {
    const entry = {
      at: Date.now(),
      mode: state.mode,
      dominant_class: payload.dominant_class,
      info: payload.info,
      detections: payload.detections,
      inference_ms: payload.inference_ms,
      total_detections: payload.total_detections,
      frame: payload.frame,
      thumb: await thumbnail(payload.cropped_image || payload.annotated_image),
      annotated_image: payload.annotated_image,
    };
    const history = [entry, ...readHistory()].slice(0, HISTORY_LIMIT);
    try {
      localStorage.setItem(HISTORY_KEY, JSON.stringify(history));
    } catch {
      // Quota exceeded: keep the entries that still fit.
      try {
        localStorage.setItem(HISTORY_KEY, JSON.stringify(history.slice(0, 4)));
      } catch {
        localStorage.removeItem(HISTORY_KEY);
      }
    }
    renderHistory();
  }

  function relativeTime(timestamp) {
    const seconds = Math.floor((Date.now() - timestamp) / 1000);
    if (seconds < 60) return "just now";
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
    return new Date(timestamp).toLocaleDateString("en-GB", { day: "numeric", month: "short" });
  }

  function renderHistory() {
    const rail = $("#history-rail");
    const history = readHistory();
    rail.innerHTML = "";
    if (!history.length) {
      rail.innerHTML = "<p>No scans yet in this browser.</p>";
      return;
    }
    history.forEach((entry) => {
      const item = document.createElement("button");
      item.type = "button";
      item.className = "history-item";
      item.innerHTML = `
        <img src="${entry.thumb}" alt="">
        <div>
          <b>${entry.info?.label || entry.dominant_class || "—"}</b>
          <small>${entry.mode === "camera" ? "cam" : "file"} · ${relativeTime(entry.at)}</small>
        </div>`;
      item.addEventListener("click", () => {
        renderResult({ ...entry, original_image: "", cropped_image: "" });
        toast("Restored an earlier scan from this browser.", "info");
      });
      rail.appendChild(item);
    });
  }

  $("#history-clear").addEventListener("click", () => {
    localStorage.removeItem(HISTORY_KEY);
    renderHistory();
    toast("Local scan history cleared.", "info");
  });

  /* --------------------------------------------------------------- lightbox */
  const lightbox = $("#lightbox");
  document.addEventListener("click", (event) => {
    const target = event.target.closest("[data-zoom]");
    if (!target?.src) return;
    $("#lightbox-img").src = target.src;
    lightbox.classList.add("is-open");
  });
  const closeLightbox = () => lightbox.classList.remove("is-open");
  $("#lightbox-close").addEventListener("click", closeLightbox);
  lightbox.addEventListener("click", (event) => {
    if (event.target === lightbox) closeLightbox();
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeLightbox();
  });

  /* ----------------------------------------------------------------- status */
  async function pollHealth() {
    const pill = $("#status-pill");
    const text = $("#status-text");
    try {
      const response = await fetch("/health", { cache: "no-store" });
      const data = await response.json();
      pill.classList.remove("is-offline");
      text.textContent = data.using_fallback_weights ? "fallback model" : "model ready";
      if (data.using_fallback_weights) pill.classList.add("is-offline");
    } catch {
      pill.classList.add("is-offline");
      text.textContent = "offline";
    }
  }
  pollHealth();
  window.addEventListener("online", pollHealth);
  window.addEventListener("offline", () => {
    $("#status-pill").classList.add("is-offline");
    $("#status-text").textContent = "offline";
  });

  /* ------------------------------------------------------------------- boot */
  renderHistory();
  syncRunButton();
})();
