---
title: Cek Daun Kopi API
colorFrom: green
colorTo: green
sdk: docker
app_port: 7860
pinned: false
license: mit
short_description: Coffee leaf disease detection (YOLOv8) with a JSON API
---

# Cek Daun Kopi: API and web demo

YOLOv8 model that recognises three coffee-leaf conditions (leaf rust, Phoma
leaf spot, leaf miner) and healthy leaves, served by Flask.

- Web demo: the page at the root of this Space.
- JSON API used by the mobile app:
  - `GET /api/v1/health`
  - `GET /api/v1/diseases?lang=id|en`
  - `POST /api/v1/predict` (multipart field `file`, optional `lang`)

Source, model card and the mobile app:
https://github.com/glen1599/coffee-leaf-disease-yolov8

The free hardware sleeps after a period without visitors; the first request
after that takes a minute or so while the Space starts again. The anonymous
scan log is kept on the container's disk and resets when the Space restarts.
