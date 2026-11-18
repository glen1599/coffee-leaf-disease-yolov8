# Deploy API ke Hugging Face Spaces

> [!IMPORTANT]
> Sejak 2026, Hugging Face hanya mengizinkan Docker Space di hardware CPU dasar
> untuk akun berlangganan **PRO** (atau organisasi Team/Enterprise). Akun gratis
> mendapat galat pembayaran (HTTP 402) saat membuat Space.
> Untuk hosting gratis, pakai [Render](DEPLOY_RENDER.md).

Panduan ini memasang server Flask (web demo + API `/api/v1`) di
[Hugging Face Spaces](https://huggingface.co/spaces) dengan hardware CPU dasar
(2 vCPU, 16 GB RAM).

Aplikasi HP **tidak butuh** server untuk mendeteksi penyakit: model berjalan
di HP. Server dipakai untuk dua hal: demo web yang bisa dibuka siapa saja,
dan memperbarui teks Info Penyakit di HP saat ada internet.

## Dibanding Render

| | Hugging Face Spaces (PRO) | Render (gratis) |
|---|---|---|
| RAM | 16 GB | 512 MB |
| Mode server | Biasa (Ultralytics + PyTorch) | Ringan (ONNX Runtime saja) |
| Biaya | Langganan PRO | Gratis |
| Kekurangan | Berbayar | Tidur setelah 15 menit sepi; lambat di 0,1 CPU |

## Isi yang diunggah

`scripts/build_space.py` menyusun folder `build/space/` berisi hanya yang
dibutuhkan server:

```
build/space/
├── Dockerfile          ← dari deploy/huggingface/Dockerfile (port 7860, user 1000)
├── README.md           ← kartu Space (judul, sdk: docker, app_port: 7860)
├── app.py
├── coffee_leaf/        ← kode server
├── templates/, static/ ← halaman web demo
├── models/best.pt      ← bobot hasil training
├── models/best.onnx    ← ekspor ONNX (dipakai lebih dulu, lebih cepat di CPU)
├── requirements.txt
└── LICENSE
```

Aplikasi Flutter, dataset, dan tes tidak ikut.

Dockerfile Space memasang PyTorch versi CPU dan membuang paket GPU (NVIDIA,
CUDA) dari `requirements.txt`, karena hardware gratis tidak punya GPU.
Variabel `TRUSTED_PROXIES=1` membuat batas 30 permintaan/menit berlaku per
pengunjung, bukan untuk semua orang sekaligus (di balik proxy, semua
permintaan terlihat datang dari alamat proxy).

## Langkah-langkah

### 1. Akun dan login (dilakukan pemilik akun)

1. Buat akun di <https://huggingface.co/join> dan verifikasi email.
2. Pasang CLI Hugging Face sebagai alat terpisah (server tidak membutuhkannya,
   jadi tidak dipasang di `.venv` proyek):

   ```bash
   uv tool install huggingface_hub
   ```

   Tanpa `uv`: `pipx install huggingface_hub`. Kalau perintah `hf` belum
   dikenali, buka tab terminal baru atau jalankan `uv tool update-shell`.

3. Login. Perintah ini membuka browser; token tersimpan di komputer Anda
   sendiri:

   ```bash
   hf auth login
   ```

### 2. Siapkan folder

Dari folder proyek:

```bash
python scripts/build_space.py
```

Kalau `models/best.onnx` belum ada (file ini tidak masuk git), buat dulu:

```bash
yolo export model=models/best.pt format=onnx opset=12 simplify=True
```

Tanpa file ONNX, server tetap jalan dengan PyTorch, hanya lebih lambat.

### 3. Buat Space dan unggah

Ganti `NAMA_AKUN` dengan nama akun Hugging Face Anda:

```bash
hf repos create NAMA_AKUN/cek-daun-kopi-api --type space --sdk docker --public
```

```bash
hf upload NAMA_AKUN/cek-daun-kopi-api build/space . --type space
```

Space harus **public** supaya aplikasi HP bisa memanggilnya tanpa token.

Hugging Face lalu membangun image (±5–10 menit, lihat tab *Logs* di halaman
Space). Setelah statusnya *Running*, alamat API-nya:

```
https://NAMA_AKUN-cek-daun-kopi-api.hf.space
```

### 4. Periksa

```bash
curl https://NAMA_AKUN-cek-daun-kopi-api.hf.space/api/v1/health
```

```bash
curl -F "file=@static/img/samples/coffee_leaf_rust.jpg" https://NAMA_AKUN-cek-daun-kopi-api.hf.space/api/v1/predict
```

Jawaban `health` harus berisi `"status": "ok"` dan
`"using_fallback_weights": false`.

### 5. Sambungkan aplikasi HP

Alamat di atas menjadi nilai bawaan `API_BASE_URL` di
`mobile/lib/config/app_config.dart`, atau diberikan saat build:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://NAMA_AKUN-cek-daun-kopi-api.hf.space
```

## Memperbarui server

Setelah kode atau model berubah, ulangi langkah 2 dan perintah `hf upload`
di langkah 3. Space dibangun ulang otomatis.

## Uji di komputer sendiri sebelum mengunggah

Dengan Docker:

```bash
python scripts/build_space.py
```

```bash
docker build -t cek-daun-kopi-space build/space
```

```bash
docker run --rm -p 7860:7860 cek-daun-kopi-space
```

Lalu buka <http://localhost:7860> atau panggil
<http://localhost:7860/api/v1/health>.

## Batasan

- **Tidur saat sepi.** Space gratis berhenti setelah beberapa waktu tanpa
  pengunjung. Permintaan pertama sesudahnya menunggu Space menyala lagi.
  Aplikasi HP tidak terpengaruh karena deteksi berjalan di HP.
- **Log pemindaian tidak permanen.** Statistik di `/api/stats` disimpan di
  disk container dan hilang saat Space dimulai ulang.
- **Satu worker.** Satu proses memegang satu salinan model; cukup untuk demo,
  bukan untuk ratusan pengguna bersamaan.
