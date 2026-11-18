# Deploy API ke Render (gratis)

Panduan ini memasang server Flask (web demo + API `/api/v1`) di
[Render](https://render.com) dengan paket gratis.

Aplikasi HP **tidak butuh** server untuk mendeteksi penyakit: model berjalan
di HP. Server dipakai untuk dua hal: demo web yang bisa dibuka siapa saja,
dan memperbarui teks Info Penyakit di HP saat ada internet.

## Server versi ringan

Paket gratis Render hanya memberi RAM 512 MB dan sebagian kecil dari satu
CPU. PyTorch dan Ultralytics saja sudah lebih besar dari itu, jadi server
dijalankan dalam mode ringan:

| | Mode biasa (`ultralytics`) | Mode ringan (`onnx`) |
|---|---|---|
| Mesin | Ultralytics + PyTorch | ONNX Runtime saja |
| Ukuran image Docker | ±2,4 GB | ±570 MB |
| Memori saat jalan | >1 GB | ±180 MB |
| Hasil deteksi | acuan | sama persis (diuji di `tests/test_onnx_detector.py`) |

Mode dipilih dengan variabel `DETECTOR_BACKEND`. Bawaannya `ultralytics`,
jadi menjalankan proyek di komputer tetap seperti biasa. Image Render
(`deploy/render/Dockerfile`) memakai `onnx`.

Pada uji dengan batas yang sama seperti paket gratis (512 MB, 0,1 CPU), satu
pemeriksaan foto butuh 3–9 detik dan server siap dalam ±20 detik setelah
menyala.

## Isi yang dipakai Render

- `render.yaml` di akar repositori: satu web service gratis, Docker,
  health check ke `/api/v1/health`.
- `deploy/render/Dockerfile`: hanya kode server, halaman web, dan model ONNX.
  Modelnya diambil dari `mobile/assets/models/best.onnx`, salinan yang memang
  masuk git (file `models/best.onnx` tidak).
- `deploy/render/requirements.txt`: Flask, Gunicorn, NumPy, OpenCV (headless),
  ONNX Runtime. Dibuat dari `deploy/render/requirements.in`.

## Langkah-langkah

### 1. Kode harus ada di GitHub

Render membangun langsung dari repositori GitHub. Pastikan branch yang berisi
`render.yaml` sudah di-push.

### 2. Akun Render (dilakukan pemilik akun)

1. Daftar di <https://dashboard.render.com/register>. Paling mudah dengan
   tombol **GitHub**, supaya Render langsung bisa membaca repositori Anda.
2. Saat Render meminta akses GitHub, izinkan setidaknya repositori
   `coffee-leaf-disease-yolov8`.

### 3. Buat layanan dari Blueprint

1. Di dashboard Render, klik **New** → **Blueprint**.
2. Pilih repositori `coffee-leaf-disease-yolov8` dan branch yang berisi
   `render.yaml`.
3. Render membaca `render.yaml` dan menampilkan satu layanan,
   `cek-daun-kopi-api`, paket **Free**. Klik **Apply** / **Deploy Blueprint**.
4. Tunggu build selesai (±5 menit, lihat tab **Logs**). Status berubah menjadi
   **Live**.

Alamat layanan tampil di bagian atas halamannya, biasanya:

```
https://cek-daun-kopi-api.onrender.com
```

Kalau nama itu sudah dipakai orang lain, Render menambahkan akhiran acak.
Pakai alamat yang tertulis di dashboard.

### 4. Periksa

```bash
curl https://cek-daun-kopi-api.onrender.com/api/v1/health
```

```bash
curl -F "file=@static/img/samples/coffee_leaf_rust.jpg" https://cek-daun-kopi-api.onrender.com/api/v1/predict
```

Jawaban `health` harus berisi `"status": "ok"`, `"runtime": "onnxruntime"`, dan
`"using_fallback_weights": false`.

### 5. Sambungkan aplikasi HP

Alamat tadi menjadi nilai bawaan `API_BASE_URL` di
`mobile/lib/config/app_config.dart`, atau diberikan saat build:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://cek-daun-kopi-api.onrender.com
```

## Memperbarui server

`autoDeploy` aktif: setiap push ke branch yang dipakai Blueprint membuat Render
membangun dan memasang versi baru dengan sendirinya.

## Uji di komputer sendiri

```bash
docker build -f deploy/render/Dockerfile -t cek-daun-kopi-lite .
```

Jalankan dengan batas yang sama seperti paket gratis Render:

```bash
docker run --rm --memory 512m --cpus 0.1 -p 10000:10000 cek-daun-kopi-lite
```

Lalu buka <http://localhost:10000>.

Tanpa Docker, mode ringan juga bisa dicoba langsung:

```bash
DETECTOR_BACKEND=onnx PORT=5050 python app.py
```

## Batasan paket gratis

- **Tidur saat sepi.** Layanan berhenti setelah 15 menit tanpa pengunjung.
  Permintaan pertama sesudahnya menunggu ±1 menit. Aplikasi HP tidak
  terpengaruh karena deteksi berjalan di HP.
- **Lambat untuk foto besar.** Dengan sebagian kecil CPU, satu pemeriksaan di
  web demo butuh beberapa detik.
- **Log pemindaian tidak permanen.** Statistik di `/api/stats` disimpan di
  disk container dan hilang saat layanan dimulai ulang atau tidur.
- **750 jam per bulan** untuk semua layanan gratis di satu akun; cukup untuk
  satu layanan yang menyala terus.

## Alternatif: Hugging Face Spaces

Sejak 2026, Docker Space di hardware CPU gratis hanya bisa dibuat oleh akun
berlangganan PRO. Paketnya tetap tersedia di `deploy/huggingface/`; lihat
[DEPLOY_HUGGINGFACE.md](DEPLOY_HUGGINGFACE.md).
