"""Localised content for the JSON API and the mobile app.

``coffee_leaf.config.DISEASE_INFO`` stays the source of truth: it decides which
classes exist, how severe each one is and how many symptoms and treatment
steps it has. This module only adds the Indonesian wording for the same
entries -- a faithful translation, never new agronomic advice. A test keeps
the two in step (``tests/test_api_v1.py``).
"""

from __future__ import annotations

from typing import Any

from .config import (
    CONFIDENCE_HIGH,
    CONFIDENCE_MEDIUM,
    DISEASE_INFO,
    MODEL_METRICS,
)

LANGUAGES = ("id", "en")
DEFAULT_LANGUAGE = "id"

# --- Indonesian knowledge base ------------------------------------------------
# Same keys and the same list lengths as ``DISEASE_INFO``.
DISEASE_INFO_ID: dict[str, dict[str, Any]] = {
    "bercak_phoma": {
        "label": "Bercak Phoma",
        "status": "Patogen terdeteksi",
        "pathogen": "Phoma spp. (jamur)",
        "summary": (
            "Infeksi jamur yang menimbulkan bercak mati berwarna cokelat sampai hitam. "
            "Jika dibiarkan, bercak menyatu dan mematikan jaringan daun secara permanen."
        ),
        "symptoms": [
            "Bercak bulat cokelat tua dengan bagian tengah abu-abu lebih terang",
            "Bercak membesar dan menyatu di helai daun",
            "Daun rontok sebelum waktunya pada serangan berat",
        ],
        "treatment": [
            "Semprot fungisida berbahan mankozeb atau klorotalonil dengan selang 7-10 hari.",
            "Pangkas dan musnahkan daun yang terinfeksi; bakar sisa tanaman yang dibuang.",
            "Perbaiki drainase tanah untuk menurunkan kelembapan di sekitar tajuk.",
            "Hindari penyiraman dari atas karena menyebarkan spora antartanaman.",
        ],
    },
    "karat_daun": {
        "label": "Karat Daun",
        "status": "Patogen terdeteksi",
        "pathogen": "Hemileia vastatrix (jamur)",
        "summary": (
            "Infeksi karat yang ganas. Bintil spora berwarna kuning-jingga muncul di sisi "
            "bawah daun dan bisa membuat daun rontok massal serta hasil panen turun."
        ),
        "symptoms": [
            "Bintil bertepung kuning-jingga di sisi bawah daun",
            "Bercak kuning pucat di sisi atas daun",
            "Daun rontok, dimulai dari cabang bawah",
        ],
        "treatment": [
            "Semprot fungisida sistemik golongan triazol (misalnya triadimefon) begitu "
            "gejala pertama terlihat.",
            "Pisahkan dan musnahkan tanaman yang terinfeksi berat, jauh dari blok utama.",
            "Jarangkan tajuk supaya udara dan sinar matahari lebih mudah masuk.",
            "Tanam varietas kopi tahan karat pada musim tanam berikutnya.",
        ],
    },
    "pengorok_daun": {
        "label": "Pengorok Daun",
        "status": "Hama terdeteksi",
        "pathogen": "Pectinifera spp. (larva)",
        "summary": (
            "Larva membuat terowongan di dalam jaringan daun dan meninggalkan alur putih "
            "berkelok yang merusak klorofil serta menurunkan kemampuan fotosintesis."
        ),
        "symptoms": [
            "Alur putih atau bening yang berkelok-kelok di helai daun",
            "Permukaan daun melepuh dan berubah bentuk di sepanjang alur",
            "Tanaman kurang subur dan luas daun berkurang pada cabang yang terserang",
        ],
        "treatment": [
            "Semprot insektisida sistemik berbahan abamektin sesuai dosis anjuran.",
            "Pasang perangkap lekat kuning untuk mengendalikan populasi lalat dewasa.",
            "Pangkas daun yang masih ada alur aktifnya dan musnahkan larva di dalamnya.",
            "Tingkatkan pengamatan di blok yang terserang menjadi seminggu sekali.",
        ],
    },
    "sehat": {
        "label": "Daun Sehat",
        "status": "Tidak ada patogen",
        "pathogen": "Tidak ada",
        "summary": (
            "Bentuk daun utuh dan sehat. Klorofil tersebar merata tanpa tanda patogen, "
            "spora jamur, atau kerusakan akibat hama."
        ),
        "symptoms": [
            "Warna hijau merata",
            "Tidak ada bercak, alur, atau bintil spora",
            "Helai dan tulang daun utuh",
        ],
        "treatment": [
            "Pertahankan jadwal penyiraman biasa sesuai kelembapan tanah.",
            "Lanjutkan pemupukan NPK secara rutin.",
            "Lakukan pemangkasan rutin untuk menjaga bentuk tajuk.",
            "Terus pantau hama dan penyakit secara berkala.",
        ],
    },
}

# --- Short labels ---------------------------------------------------------------
SEVERITY_LABELS = {
    "none": {"id": "Sehat", "en": "Healthy"},
    "moderate": {"id": "Perlu perhatian", "en": "Needs attention"},
    "high": {"id": "Berbahaya", "en": "Dangerous"},
}

CONFIDENCE_LABELS = {
    "high": {"id": "Sangat yakin", "en": "Very confident"},
    "medium": {"id": "Cukup yakin", "en": "Fairly confident"},
    "low": {"id": "Kurang yakin", "en": "Not confident"},
}

# From the responsible-use notes in docs/MODEL_CARD.md.
DISCLAIMER = {
    "id": (
        "Saran ini bersifat umum. Tanyakan dulu ke penyuluh pertanian setempat sebelum menyemprot."
    ),
    "en": (
        "The treatment text is generic. Confirm with a local extension officer before spraying."
    ),
}

# --- Messages -------------------------------------------------------------------
# Keyed by the machine-readable code the API returns next to the text.
MESSAGES = {
    "missing_file": {
        "id": 'Tidak ada foto yang dikirim. Sertakan foto pada kolom "file".',
        "en": 'No image was uploaded. Send the photo in the "file" field.',
    },
    "unsupported_format": {
        "id": "Format file tidak didukung. Gunakan: {allowed}.",
        "en": "Unsupported format. Allowed: {allowed}.",
    },
    "invalid_image": {
        "id": "File tidak bisa dibaca sebagai foto. Coba foto lain.",
        "en": "The uploaded file is not a decodable image.",
    },
    "file_too_large": {
        "id": "Ukuran foto melebihi batas {limit} MB.",
        "en": "File exceeds the {limit} MB upload limit.",
    },
    "invalid_language": {
        "id": "Bahasa tidak didukung. Gunakan: {allowed}.",
        "en": "Unsupported language. Allowed: {allowed}.",
    },
    "rate_limited": {
        "id": "Terlalu banyak permintaan. Tunggu sebentar, lalu coba lagi.",
        "en": "Too many requests. Please wait a moment.",
    },
    "inference_failed": {
        "id": "Server gagal memeriksa foto. Coba lagi sebentar lagi.",
        "en": "Internal inference error. Please try again.",
    },
    "out_of_memory": {
        "id": "Server kehabisan memori. Coba foto yang lebih kecil.",
        "en": "Server ran out of memory. Try a smaller image.",
    },
    "not_found": {
        "id": "Alamat tidak ditemukan.",
        "en": "Not found.",
    },
    "method_not_allowed": {
        "id": "Metode tidak diizinkan untuk alamat ini.",
        "en": "Method not allowed for this address.",
    },
    "no_leaf_detected": {
        "id": (
            "Daun kopi tidak terlihat. Pastikan satu daun memenuhi foto, cahayanya "
            "terang, dan gambarnya tidak buram."
        ),
        "en": (
            "No coffee leaf was detected. Make sure a single leaf fills the photo, "
            "in bright light and in focus."
        ),
    },
}


def message(code: str, lang: str = DEFAULT_LANGUAGE, **values: Any) -> str:
    """Return the text for ``code`` in ``lang``, with ``values`` filled in."""
    return MESSAGES[code][lang].format(**values)


def confidence_level(percent: float) -> str:
    """Map a detection score in percent onto ``high`` / ``medium`` / ``low``."""
    if percent >= CONFIDENCE_HIGH:
        return "high"
    if percent >= CONFIDENCE_MEDIUM:
        return "medium"
    return "low"


def confidence_payload(percent: float, lang: str = DEFAULT_LANGUAGE) -> dict[str, Any]:
    """Describe a detection score as a number, a band and plain words."""
    level = confidence_level(percent)
    return {"value": percent, "level": level, "label": CONFIDENCE_LABELS[level][lang]}


def class_name(class_id: str, lang: str = DEFAULT_LANGUAGE) -> str:
    """Display name of a model class, or the raw key for an unknown class."""
    if class_id not in DISEASE_INFO:
        return class_id
    source = DISEASE_INFO_ID if lang == "id" else DISEASE_INFO
    return str(source[class_id]["label"])


def disease_payload(class_id: str, lang: str = DEFAULT_LANGUAGE) -> dict[str, Any] | None:
    """Serialise one knowledge-base entry, or ``None`` for an unknown class."""
    base = DISEASE_INFO.get(class_id)
    if base is None:
        return None
    text = DISEASE_INFO_ID[class_id] if lang == "id" else base
    severity = str(base["severity"])
    return {
        "id": class_id,
        "name": text["label"],
        "status": text["status"],
        "severity": severity,
        "severity_label": SEVERITY_LABELS[severity][lang],
        "pathogen": text["pathogen"],
        "summary": text["summary"],
        "symptoms": list(text["symptoms"]),
        "treatment": list(text["treatment"]),
    }


def diseases_payload(lang: str = DEFAULT_LANGUAGE) -> list[dict[str, Any]]:
    """Serialise the whole knowledge base in the order it is declared."""
    return [entry for key in DISEASE_INFO if (entry := disease_payload(key, lang)) is not None]


def mobile_bundle() -> dict[str, Any]:
    """Everything the mobile app ships offline, in every supported language.

    ``scripts/export_mobile_content.py`` writes this to the app's assets so the
    phone and the server can never disagree about the content.
    """
    return {
        "default_language": DEFAULT_LANGUAGE,
        "languages": list(LANGUAGES),
        "diseases": {lang: diseases_payload(lang) for lang in LANGUAGES},
        "severity_labels": SEVERITY_LABELS,
        "confidence": {
            "high_from": CONFIDENCE_HIGH,
            "medium_from": CONFIDENCE_MEDIUM,
            "labels": CONFIDENCE_LABELS,
        },
        "messages": {"no_leaf_detected": MESSAGES["no_leaf_detected"]},
        "disclaimer": DISCLAIMER,
        "metrics": MODEL_METRICS,
    }
