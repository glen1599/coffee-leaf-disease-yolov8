/**
 * Coffee Leaf Disease Detection — front-end controller.
 *
 * Talks to the Flask API: POST /predict (one file), POST /predict/batch
 * (several), POST /predict/camera (base64 frame), GET /api/stats.
 */
(() => {
  "use strict";

  const MAX_BYTES = 10 * 1024 * 1024;
  const MAX_FILES = 8;
  const HISTORY_KEY = "coffee_leaf_history_v3";
  const HISTORY_LIMIT = 8;
  const STAGGER_MS = 70;

  const $ = (selector) => document.querySelector(selector);
  const $$ = (selector) => Array.from(document.querySelectorAll(selector));

  const state = { mode: "upload", files: [], objectUrl: null, stream: null, result: null, batch: [] };

  /* ---------------------------------------------------------------- toasts */
  function toast(message, kind = "info") {
    const host = $("#toasts");
    const el = document.createElement("div");
    el.className = "toast";
    el.dataset.kind = kind;
    el.textContent = message;
    host.appendChild(el);
    requestAnimationFrame(() => (el.dataset.visible = ""));
    setTimeout(() => {
      delete el.dataset.visible;
      setTimeout(() => el.remove(), 340);
    }, 4200);
  }

  /* ------------------------------------------------- entrances (staggered) */
  function armRisers() {
    const risers = $$(".rise");
    if (!("IntersectionObserver" in window)) {
      risers.forEach((el) => (el.dataset.shown = ""));
      return;
    }
    const observer = new IntersectionObserver(
      (entries) => {
        let step = 0;
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.style.setProperty("--delay", `${step++ * STAGGER_MS}ms`);
          entry.target.dataset.shown = "";
          observer.unobserve(entry.target);
        });
      },
      { rootMargin: "0px 0px -6% 0px", threshold: 0.06 }
    );
    risers.forEach((el) => observer.observe(el));
  }

  /* ------------------------------------------------------------------ nav */
  const nav = $("#nav");
  const onScroll = () => {
    if (window.scrollY > 8) nav.dataset.stuck = "";
    else delete nav.dataset.stuck;
  };
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  $("#nav-toggle").addEventListener("click", (event) => {
    const open = nav.toggleAttribute("data-open");
    event.currentTarget.setAttribute("aria-expanded", String(open));
  });
  $$(".nav__links a").forEach((link) =>
    link.addEventListener("click", () => {
      delete nav.dataset.open;
      $("#nav-toggle").setAttribute("aria-expanded", "false");
    })
  );

  /* ---------------------------------------------------------------- theme */
  $("#nav-theme").addEventListener("click", () => {
    const root = document.documentElement;
    const system = window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
    const next = (root.dataset.theme || system) === "dark" ? "light" : "dark";
    root.dataset.theme = next;
    try {
      localStorage.setItem("coffee_leaf_theme", next);
    } catch {
      /* private mode */
    }
  });

  /* ------------------------------------------------ compare (1:1 tracking) */
  const compare = $("#compare");
  const handle = $("#compare-handle");

  function setSplit(clientX) {
    const rect = compare.getBoundingClientRect();
    const percent = Math.min(100, Math.max(0, ((clientX - rect.left) / rect.width) * 100));
    compare.style.setProperty("--split", `${percent.toFixed(2)}%`);
    handle.setAttribute("aria-valuenow", String(Math.round(percent)));
  }

  compare.addEventListener("pointerdown", (event) => {
    compare.setPointerCapture(event.pointerId);
    compare.dataset.dragging = "";
    setSplit(event.clientX);
  });
  compare.addEventListener("pointermove", (event) => {
    if (compare.dataset.dragging !== undefined) setSplit(event.clientX);
  });
  ["pointerup", "pointercancel"].forEach((type) =>
    compare.addEventListener(type, () => delete compare.dataset.dragging)
  );
  handle.addEventListener("keydown", (event) => {
    const step = event.key === "ArrowLeft" ? -5 : event.key === "ArrowRight" ? 5 : 0;
    if (!step) return;
    event.preventDefault();
    const next = Math.min(100, Math.max(0, Number(handle.getAttribute("aria-valuenow")) + step));
    compare.style.setProperty("--split", `${next}%`);
    handle.setAttribute("aria-valuenow", String(next));
  });

  /* ------------------------------------------------------- mode selection */
  const segmented = $("#segmented");
  $$("#segmented button").forEach((tab, index) =>
    tab.addEventListener("click", async () => {
      state.mode = index === 0 ? "upload" : "camera";
      segmented.dataset.active = String(index);
      $$("#segmented button").forEach((other) =>
        other.setAttribute("aria-selected", String(other === tab))
      );
      $("#pane-upload").hidden = index !== 0;
      $("#pane-camera").hidden = index === 0;
      if (index === 0) stopCamera();
      else await startCamera();
      syncRun();
    })
  );

  /* ------------------------------------------------------------ threshold */
  const conf = $("#conf");
  function paintConfidence() {
    const percent = ((conf.value - conf.min) / (conf.max - conf.min)) * 100;
    conf.style.setProperty("--fill", `${percent}%`);
    $("#conf-out").textContent = Number(conf.value).toFixed(2);
  }
  conf.addEventListener("input", paintConfidence);
  paintConfidence();

  /* --------------------------------------------------------------- upload */
  const drop = $("#drop");
  const fileInput = $("#file-input");

  function showPreview() {
    if (!state.files.length) return;
    const [first] = state.files;
    if (state.objectUrl) URL.revokeObjectURL(state.objectUrl);
    state.objectUrl = URL.createObjectURL(first);
    $("#preview-img").src = state.objectUrl;
    $("#preview-name").textContent =
      state.files.length === 1
        ? `${first.name} · ${Math.round(first.size / 1024)} KB`
        : `${first.name} and ${state.files.length - 1} more`;
    drop.dataset.filled = "";
  }

  function setFiles(list) {
    const accepted = [];
    for (const file of list) {
      if (!file.type.startsWith("image/")) {
        toast(`${file.name} is not an image.`, "warning");
        continue;
      }
      if (file.size > MAX_BYTES) {
        toast(`${file.name} is larger than 10 MB.`, "warning");
        continue;
      }
      accepted.push(file);
    }
    if (accepted.length > MAX_FILES) {
      toast(`Only the first ${MAX_FILES} photographs are used.`, "warning");
      accepted.length = MAX_FILES;
    }
    if (!accepted.length) return;
    state.files = accepted;
    showPreview();
    syncRun();
  }

  function clearFiles() {
    state.files = [];
    if (state.objectUrl) URL.revokeObjectURL(state.objectUrl);
    state.objectUrl = null;
    $("#preview-img").removeAttribute("src");
    delete drop.dataset.filled;
    fileInput.value = "";
    syncRun();
  }

  drop.addEventListener("click", (event) => {
    if (!event.target.closest("#preview")) fileInput.click();
  });
  drop.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      fileInput.click();
    }
  });
  ["dragenter", "dragover"].forEach((type) =>
    drop.addEventListener(type, (event) => {
      event.preventDefault();
      drop.dataset.drag = "";
    })
  );
  ["dragleave", "drop"].forEach((type) =>
    drop.addEventListener(type, (event) => {
      event.preventDefault();
      delete drop.dataset.drag;
    })
  );
  drop.addEventListener("drop", (event) => setFiles(event.dataTransfer?.files ?? []));
  fileInput.addEventListener("change", () => setFiles(fileInput.files));
  $("#preview-clear").addEventListener("click", (event) => {
    event.stopPropagation();
    clearFiles();
  });

  $$("[data-sample]").forEach((chip) =>
    chip.addEventListener("click", async () => {
      try {
        const response = await fetch(chip.dataset.sample);
        const blob = await response.blob();
        setFiles([new File([blob], chip.dataset.name, { type: blob.type || "image/jpeg" })]);
      } catch {
        toast("Could not load that sample photograph.", "error");
      }
    })
  );

  /* --------------------------------------------------------------- camera */
  const video = $("#camera-video");

  async function startCamera() {
    if (state.stream) return;
    if (!navigator.mediaDevices?.getUserMedia) {
      $("#camera-note").textContent = "This browser exposes no camera API.";
      return;
    }
    try {
      state.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "environment", width: { ideal: 1280 }, height: { ideal: 960 } },
      });
      video.srcObject = state.stream;
      $("#camera-placeholder").hidden = true;
    } catch {
      toast("Camera access was denied by the browser.", "warning");
    }
    syncRun();
  }

  function stopCamera() {
    if (!state.stream) return;
    state.stream.getTracks().forEach((track) => track.stop());
    state.stream = null;
    video.srcObject = null;
    $("#camera-placeholder").hidden = false;
  }

  function captureFrame() {
    if (!video.videoWidth) return null;
    const canvas = $("#camera-canvas");
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    canvas.getContext("2d").drawImage(video, 0, 0);
    return canvas.toDataURL("image/jpeg", 0.9);
  }

  /* ------------------------------------------------------------------ run */
  const runButton = $("#run");
  const runLabel = $("#run-label");

  function syncRun() {
    const ready = state.mode === "camera" ? Boolean(state.stream) : state.files.length > 0;
    runButton.disabled = !ready;
    runLabel.textContent =
      state.mode === "upload" && state.files.length > 1
        ? `Run detection on ${state.files.length} photographs`
        : "Run detection";
  }

  function setBusy(busy) {
    runButton.classList.toggle("is-busy", busy);
    runButton.disabled = busy;
    if (!busy) syncRun();
  }

  runButton.addEventListener("click", async () => {
    setBusy(true);
    try {
      if (state.mode === "camera") await runCamera();
      else if (state.files.length === 1) await runSingle(state.files[0]);
      else await runBatch();
    } catch {
      toast("Could not reach the server. Is it still running?", "error");
    } finally {
      setBusy(false);
    }
  });

  async function readJson(response) {
    const payload = await response.json().catch(() => null);
    if (!response.ok || !payload || payload.error) {
      toast(payload?.error ?? `The server answered HTTP ${response.status}.`, "error");
      return null;
    }
    return payload;
  }

  async function runSingle(file) {
    const body = new FormData();
    body.append("file", file, file.name);
    body.append("conf", conf.value);
    const payload = await readJson(await fetch("/predict", { method: "POST", body }));
    if (!payload) return;
    state.batch = [];
    renderQueue();
    renderResult(payload);
    saveHistory(payload);
  }

  async function runBatch() {
    const body = new FormData();
    state.files.forEach((file) => body.append("files", file, file.name));
    body.append("conf", conf.value);
    const payload = await readJson(await fetch("/predict/batch", { method: "POST", body }));
    if (!payload) return;

    state.batch = payload.items;
    renderQueue();
    const first = payload.items.find((item) => !item.error);
    if (first) renderResult(first);
    const failed = payload.items.filter((item) => item.error).length;
    toast(
      `${payload.count - failed} of ${payload.count} photographs analysed${failed ? `, ${failed} failed` : ""}.`,
      failed ? "warning" : "success"
    );
  }

  async function runCamera() {
    const frame = captureFrame();
    if (!frame) {
      toast("The camera frame is empty. Try again in a moment.", "warning");
      return;
    }
    const payload = await readJson(
      await fetch("/predict/camera", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ image: frame, conf: Number(conf.value) }),
      })
    );
    if (!payload) return;
    renderResult(payload);
    saveHistory(payload);
  }

  /* --------------------------------------------------------------- render */
  function meterKind(detection) {
    if (detection.label === "sehat") return "";
    if (detection.confidence >= 70) return "high";
    if (detection.confidence >= 40) return "moderate";
    return "";
  }

  function fillList(element, items) {
    element.replaceChildren(
      ...items.map((text) => {
        const li = document.createElement("li");
        li.textContent = text;
        return li;
      })
    );
  }

  function renderResult(payload) {
    state.result = payload;
    $("#result-empty").hidden = true;
    $("#result-body").hidden = false;

    $("#shot-img").src = payload.annotated_image;
    const info = payload.info;
    $("#shot-meta").textContent = `${payload.frame.width}×${payload.frame.height} px · ${payload.total_detections} detection(s) · ${payload.inference_ms} ms`;

    const top = payload.detections.reduce(
      (best, detection) => (!best || detection.confidence > best.confidence ? detection : best),
      null
    );

    $("#verdict-title").textContent = info?.label ?? payload.dominant_class ?? "Nothing detected";
    const pill = $("#verdict-pill");
    pill.textContent = info?.status ?? "No detection";
    pill.className = `pill pill--${info?.severity ?? "none"}`;
    $("#verdict-pathogen").textContent = info ? `Caused by ${info.pathogen}` : "";
    $("#verdict-summary").textContent = info?.summary ?? "";
    fillList($("#verdict-symptoms"), info?.symptoms ?? []);
    fillList($("#verdict-treatment"), info?.treatment ?? []);

    $("#detections-caption").textContent =
      payload.detections.length === 0
        ? "No lesion passed the confidence threshold"
        : `Detections — highest confidence ${top ? `${top.confidence}%` : "—"}`;

    const rows = $("#detection-rows");
    rows.replaceChildren();
    payload.detections
      .slice()
      .sort((a, b) => b.confidence - a.confidence)
      .forEach((detection, index) => {
        const row = document.createElement("tr");
        const name = document.createElement("td");
        name.textContent = detection.label_text ?? detection.label;
        const value = document.createElement("td");
        value.className = "num";
        value.textContent = `${detection.confidence}%`;
        const bar = document.createElement("td");
        bar.innerHTML = '<div class="meter"><i></i></div>';
        rows.append(row);
        row.append(name, value, bar);
        const fill = bar.querySelector("i");
        fill.dataset.kind = meterKind(detection);
        setTimeout(() => (fill.style.width = `${detection.confidence}%`), 40 + index * 60);
      });
  }

  function renderQueue() {
    const host = $("#queue");
    host.replaceChildren();
    if (state.batch.length < 2) return;

    const heading = document.createElement("h4");
    heading.className = "readout__heading";
    heading.textContent = `Batch results (${state.batch.length})`;
    host.appendChild(heading);

    state.batch.forEach((item, index) => {
      const row = document.createElement("button");
      row.type = "button";
      row.className = "queue__row";
      if (item.annotated_image) {
        const thumb = document.createElement("img");
        thumb.src = item.annotated_image;
        thumb.alt = "";
        row.appendChild(thumb);
      }
      const label = document.createElement("b");
      label.textContent = item.filename ?? `Photograph ${index + 1}`;
      const verdict = document.createElement("span");
      verdict.textContent = item.error
        ? item.error
        : `${item.info?.label ?? item.dominant_class} · ${item.inference_ms} ms`;
      row.append(label, verdict);
      if (!item.error) {
        row.addEventListener("click", () => renderResult(item));
      } else {
        row.disabled = true;
      }
      host.appendChild(row);
    });
  }

  /* --------------------------------------------------------------- actions */
  $("#btn-download").addEventListener("click", () => {
    if (!state.result?.annotated_image) return;
    const link = document.createElement("a");
    link.href = state.result.annotated_image;
    link.download = `coffee-leaf-${state.result.dominant_class ?? "result"}.jpg`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    toast("Annotated photograph downloaded.", "success");
  });

  $("#btn-copy").addEventListener("click", async () => {
    if (!state.result) return;
    const { dominant_class, inference_ms, detections, info } = state.result;
    const summary = {
      dominant_class,
      verdict: info?.label ?? null,
      inference_ms,
      detections: detections.map(({ label, confidence, box }) => ({ label, confidence, box })),
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
    state.batch = [];
    $("#result-body").hidden = true;
    $("#result-empty").hidden = false;
    renderQueue();
    clearFiles();
  });

  /* --------------------------------------------------------------- history */
  function thumbnail(dataUrl) {
    return new Promise((resolve) => {
      const image = new Image();
      image.onload = () => {
        const canvas = document.createElement("canvas");
        const scale = Math.min(1, 200 / image.width);
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
      return JSON.parse(localStorage.getItem(HISTORY_KEY) ?? "[]");
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
      annotated_image: payload.annotated_image,
      thumb: await thumbnail(payload.cropped_image || payload.annotated_image),
    };
    const history = [entry, ...readHistory()].slice(0, HISTORY_LIMIT);
    try {
      localStorage.setItem(HISTORY_KEY, JSON.stringify(history));
    } catch {
      try {
        localStorage.setItem(HISTORY_KEY, JSON.stringify(history.slice(0, 3)));
      } catch {
        localStorage.removeItem(HISTORY_KEY);
      }
    }
    renderHistory();
  }

  function relativeTime(timestamp) {
    const seconds = Math.floor((Date.now() - timestamp) / 1000);
    if (seconds < 60) return "just now";
    if (seconds < 3600) return `${Math.floor(seconds / 60)} min ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)} h ago`;
    return new Date(timestamp).toLocaleDateString("en-GB", { day: "numeric", month: "short" });
  }

  function renderHistory() {
    const rail = $("#rail");
    const history = readHistory();
    rail.replaceChildren();
    if (!history.length) {
      const empty = document.createElement("p");
      empty.textContent = "Nothing yet — run a detection and it will appear here.";
      rail.appendChild(empty);
      return;
    }
    history.forEach((entry) => {
      const item = document.createElement("button");
      item.type = "button";
      item.className = "rail__item";
      const thumb = document.createElement("img");
      thumb.src = entry.thumb;
      thumb.alt = "";
      const body = document.createElement("div");
      const label = document.createElement("b");
      label.textContent = entry.info?.label ?? entry.dominant_class ?? "—";
      const meta = document.createElement("small");
      meta.textContent = `${entry.inference_ms} ms · ${relativeTime(entry.at)}`;
      body.append(label, meta);
      item.append(thumb, body);
      item.addEventListener("click", () => renderResult(entry));
      rail.appendChild(item);
    });
  }

  $("#rail-clear").addEventListener("click", () => {
    localStorage.removeItem(HISTORY_KEY);
    renderHistory();
    toast("Local scan history cleared.", "info");
  });

  /* --------------------------------------------------------------- classes */
  const tabs = $$("#explorer-tabs .tab");
  tabs.forEach((tab) =>
    tab.addEventListener("click", () => {
      const key = tab.dataset.class;
      tabs.forEach((other) => other.setAttribute("aria-selected", String(other === tab)));
      $$("#explorer-stage .explorer__pair").forEach(
        (pair) => (pair.hidden = pair.dataset.class !== key)
      );
      $$("#explorer-readout > div").forEach((panel) => (panel.hidden = panel.id !== `panel-${key}`));

      const stage = $("#explorer-stage");
      stage.classList.remove("explorer__stage--swap");
      void stage.offsetWidth; // restart the entrance animation
      stage.classList.add("explorer__stage--swap");
    })
  );

  /* -------------------------------------------------------------- lightbox */
  const lightbox = $("#lightbox");
  document.addEventListener("click", (event) => {
    const target = event.target.closest("[data-zoom]");
    if (!target?.src) return;
    $("#lightbox-img").src = target.src;
    lightbox.dataset.open = "";
  });
  const closeLightbox = () => delete lightbox.dataset.open;
  $("#lightbox-close").addEventListener("click", closeLightbox);
  lightbox.addEventListener("click", (event) => {
    if (event.target === lightbox) closeLightbox();
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeLightbox();
  });

  /* ------------------------------------------------------------------ boot */
  try {
    armRisers();
    renderHistory();
    syncRun();
  } catch (error) {
    // Never leave the page hidden because of a script failure.
    $$(".rise").forEach((el) => (el.dataset.shown = ""));
    console.error(error);
  }
})();
