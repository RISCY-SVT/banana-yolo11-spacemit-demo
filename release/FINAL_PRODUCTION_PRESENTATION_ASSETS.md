# Final Production Presentation Assets

This file indexes the assets used by `FINAL_PRODUCTION_PRESENTATION_EN.md` and `FINAL_PRODUCTION_PRESENTATION_RU.md`.

## Asset Table

| Evidence | Asset | Source |
| --- | --- | --- |
| Primary dynamic640 still image | `release/assets/dynamic640_primary_day4.jpg` | Day 4 final acceptance output |
| Vendor320 trusted visual still image | `release/assets/vendor320_trusted_day4.jpg` | Day 4 final acceptance output |
| Normal camera still | `release/assets/camera_default_day4.jpg` | Day 4 final acceptance output |
| Fast-live camera still | `release/assets/camera_fast_day4.jpg` | Day 4 final acceptance output |
| Architecture diagram | `release/assets/architecture_diagram.svg` | generated from release docs |
| Runtime/model policy diagram | `release/assets/runtime_policy_diagram.svg` | generated from frozen policy |
| Forward FPS chart | `release/assets/chart_forward_fps.png` | generated from `docs/FPS_SUMMARY.md` / `release/FPS_SUMMARY.md` values |
| Full-image FPS chart | `release/assets/chart_full_image_fps.png` | generated from `docs/FPS_SUMMARY.md` / `release/FPS_SUMMARY.md` values |
| Camera FPS chart | `release/assets/chart_camera_fps.png` | generated from `docs/FPS_SUMMARY.md` / `release/FPS_SUMMARY.md` values |


## Chart Sources

Charts are generated from authoritative values in `docs/FPS_SUMMARY.md` and the release copy `release/FPS_SUMMARY.md`; the source CSV is `release/assets/fps_chart_source.csv`.

## PPTX/PDF Status

PPTX/PDF files were not generated in this environment because reliable slide tooling is not installed (`python-pptx` and `pandoc` are unavailable). The Markdown decks are slide-structured and ready for later conversion.

## SHA256 Manifest

See `release/assets/ASSET_MANIFEST.md`.
