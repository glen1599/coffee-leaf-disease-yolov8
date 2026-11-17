# Cek Daun Kopi (mobile)

Aplikasi Flutter (Android dan iOS) untuk memeriksa penyakit daun kopi langsung
di HP, tanpa internet. Model YOLOv8n yang sama dengan versi web
(`models/best.onnx`) dijalankan di perangkat dengan ONNX Runtime.

> Masih dalam pengerjaan. Yang sudah ada: mesin deteksi di perangkat, model
> data, penyimpanan riwayat, dan klien API, semuanya dengan tes. Layar aplikasi
> menyusul. README lengkap ditulis di tahap akhir.

## Menjalankan tes

```bash
flutter test
```

## Memeriksa kesamaan hasil dengan server

Mesin deteksi di HP harus memberi hasil yang sama dengan server. Dua skrip
menjaganya, dijalankan dari akar repositori:

```bash
# Bandingkan alur acuan (tanpa Ultralytics) dengan server, lalu tulis ulang
# data uji di mobile/test/fixtures
python scripts/export_mobile_fixtures.py

# Jalankan model asli pada foto yang disiapkan oleh kode Dart
(cd mobile && dart run tool/dump_tensors.dart build/parity)
python scripts/export_mobile_fixtures.py --tensors mobile/build/parity
```

Isi `assets/content/diseases.json` dibuat dari kode server, jangan diedit
langsung:

```bash
python scripts/export_mobile_content.py
```
