# Deploy API ke PythonAnywhere (gratis, tanpa kartu kredit)

Panduan ini memasang server Flask (web demo + API `/api/v1`) di
[PythonAnywhere](https://www.pythonanywhere.com) dengan akun gratis
(Beginner).

Aplikasi HP **tidak butuh** server untuk mendeteksi penyakit: model berjalan
di HP. Server dipakai untuk dua hal: demo web yang bisa dibuka siapa saja,
dan memperbarui teks Info Penyakit di HP saat ada internet.

## Kenapa versi ringan

Akun gratis PythonAnywhere memberi disk 512 MB dan jatah 100 detik CPU per
hari. PyTorch saja sudah lebih besar dari 512 MB, jadi server berjalan dalam
mode ringan (`DETECTOR_BACKEND=onnx`): model ONNX dijalankan dengan ONNX
Runtime saja. Hasil deteksinya sama persis dengan mode biasa
(`tests/test_onnx_detector.py`).

Yang terpasang di akun:

| Bagian | Ukuran |
|---|---|
| Kode yang dibutuhkan server (bukan seluruh repositori) | ±37 MB |
| Paket Python (`deploy/lite/requirements.txt`) | ±255 MB |
| **Total** | **±290 MB dari 512 MB** |

## Langkah-langkah

### 1. Buat akun

Daftar di <https://www.pythonanywhere.com/registration/register/beginner/>.
Nama akun menjadi alamat server: `NAMA_AKUN.pythonanywhere.com`.

### 2. Buat web app (tab **Web**)

1. Buka tab **Web**, klik **Add a new web app**, lalu **Next**.
2. Pilih **Manual configuration** (bukan "Flask").
3. Pilih **Python 3.11**, lalu **Next**.

PythonAnywhere membuat file WSGI kosong untuk web app itu. Skrip di langkah 3
akan mengisinya.

### 3. Pasang server (tab **Consoles**)

Buka tab **Consoles**, klik **Bash**, lalu jalankan dua perintah ini:

```bash
curl -fsSLo setup.sh https://raw.githubusercontent.com/glen1599/coffee-leaf-disease-yolov8/feat/mobile-app/deploy/pythonanywhere/setup.sh
```

```bash
bash setup.sh
```

Skrip itu (`deploy/pythonanywhere/setup.sh`):

1. mengambil kode dari GitHub, hanya folder yang dibutuhkan server;
2. memasang paket Python di `~/.virtualenvs/cek-daun-kopi`;
3. menulis file WSGI web app Anda (versi lamanya disimpan sebagai `.bak`);
4. mencoba server sekali: harus menulis `health: ok` dan
   `sample photo: Karat Daun 86.3 %`.

Prosesnya ±3–5 menit, sebagian besar untuk mengunduh paket.

### 4. Nyalakan

Kembali ke tab **Web**, klik tombol hijau **Reload**.

Opsional, supaya file gambar dan CSS dilayani langsung tanpa memakai jatah
CPU: di bagian **Static files** tambahkan URL `/static/` dengan directory
`/home/NAMA_AKUN/coffee-leaf-disease-yolov8/static`, lalu **Reload** lagi.

### 5. Periksa

Buka di browser:

```
https://NAMA_AKUN.pythonanywhere.com/api/v1/health
```

Jawabannya harus berisi `"status": "ok"` dan `"runtime": "onnxruntime"`.
Halaman web demo ada di `https://NAMA_AKUN.pythonanywhere.com/`.

Kalau yang muncul halaman error, buka tab **Web** → **Log files** → **Error
log**; baris terakhir menjelaskan penyebabnya.

### 6. Sambungkan aplikasi HP

Alamat tadi menjadi nilai bawaan `API_BASE_URL` di
`mobile/lib/config/app_config.dart`, atau diberikan saat build:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://NAMA_AKUN.pythonanywhere.com
```

## Memperbarui server

Setelah ada perubahan yang sudah di-push ke GitHub, buka konsol Bash lalu
jalankan lagi:

```bash
bash setup.sh
```

lalu klik **Reload** di tab **Web**. Skrip memakai branch `feat/mobile-app`;
untuk branch lain jalankan `BRANCH=main bash setup.sh`.

## Batasan akun gratis

- **Perpanjang tiap 3 bulan.** Web app gratis berhenti kalau tidak
  diperpanjang. Di tab **Web** ada tombol **Run until 3 months from today**;
  PythonAnywhere mengirim email pengingat sebelumnya.
- **100 detik CPU per hari.** Satu pemeriksaan foto memakai sebagian kecil
  detik, jadi cukup untuk ratusan pemeriksaan sehari. Kalau habis, server
  tetap jalan tetapi lebih lambat sampai jatah diisi ulang.
- **Satu web app** per akun gratis, dengan alamat `NAMA_AKUN.pythonanywhere.com`.
- **Batas permintaan per pengunjung** memakai alamat dari header
  `X-Forwarded-For` (`TRUSTED_PROXIES=1`). Kalau proxy PythonAnywhere tidak
  mengirim header itu, semua pengunjung berbagi satu jatah 30 permintaan per
  menit; untuk demo, ini tidak jadi masalah.

## Pilihan hosting lain

- [Render](DEPLOY_RENDER.md): pakai Docker dan memperbarui otomatis setiap
  push, tetapi meminta kartu kredit untuk verifikasi.
- [Hugging Face Spaces](DEPLOY_HUGGINGFACE.md): server mode biasa dengan RAM
  besar, tetapi Docker Space kini butuh langganan PRO.
