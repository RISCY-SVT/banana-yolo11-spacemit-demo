#!/usr/bin/env python3
"""@file prepare_and_eval_coco.py
@brief Prepare COCO val2017 inputs and run official pycocotools COCOeval.
@details The preparation command derives the model class-index to COCO
category-id map from the annotation category names and the repository label
file. The evaluation command consumes board-generated COCO detection JSON and
writes machine-readable plus Markdown summaries.
"""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
from pathlib import Path
from typing import Any


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_labels(path: Path) -> list[str]:
    return [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def cmd_prepare(args: argparse.Namespace) -> int:
    annotation_path = Path(args.annotation)
    labels_path = Path(args.labels)
    image_list_path = Path(args.image_list)
    category_map_path = Path(args.category_map)
    provenance_path = Path(args.provenance)
    image_root = Path(args.image_root)

    annotations = load_json(annotation_path)
    labels = read_labels(labels_path)
    categories = annotations["categories"]
    name_to_id = {category["name"]: int(category["id"]) for category in categories}

    missing_labels = [name for name in labels if name not in name_to_id]
    if missing_labels:
        raise SystemExit(f"labels not found in COCO categories: {missing_labels}")

    images = sorted(annotations["images"], key=lambda item: int(item["id"]))
    image_list_path.parent.mkdir(parents=True, exist_ok=True)
    with image_list_path.open("w", encoding="utf-8") as handle:
        handle.write("# image_id\tfile_name\twidth\theight\n")
        for image in images:
            handle.write(
                f"{int(image['id'])}\t{image['file_name']}\t{int(image['width'])}\t{int(image['height'])}\n"
            )

    category_map_path.parent.mkdir(parents=True, exist_ok=True)
    with category_map_path.open("w", encoding="utf-8") as handle:
        handle.write("# class_index\tcategory_id\tname\n")
        for index, name in enumerate(labels):
            handle.write(f"{index}\t{name_to_id[name]}\t{name}\n")

    image_files = sorted(image_root.glob("*.jpg"))
    image_list_digest = hashlib.sha256()
    for path in image_files:
        image_list_digest.update(path.name.encode("utf-8"))
        image_list_digest.update(b"\n")

    provenance = {
        "annotation": str(annotation_path),
        "annotation_sha256": sha256_file(annotation_path),
        "labels": str(labels_path),
        "labels_sha256": sha256_file(labels_path),
        "image_root": str(image_root),
        "image_count_in_annotations": len(images),
        "image_count_on_disk": len(image_files),
        "image_list_sha256": image_list_digest.hexdigest(),
        "category_count": len(categories),
        "model_label_count": len(labels),
        "image_list": str(image_list_path),
        "category_map": str(category_map_path),
    }
    write_text(provenance_path, json.dumps(provenance, indent=2, sort_keys=True) + "\n")
    return 0


def coco_stats_to_dict(stats: list[float]) -> dict[str, float]:
    keys = [
        "AP_50_95",
        "AP50",
        "AP75",
        "AP_small",
        "AP_medium",
        "AP_large",
        "AR1",
        "AR10",
        "AR100",
        "AR_small",
        "AR_medium",
        "AR_large",
    ]
    return {key: float(value) for key, value in zip(keys, stats)}


def cmd_evaluate(args: argparse.Namespace) -> int:
    try:
        from pycocotools.coco import COCO
        from pycocotools.cocoeval import COCOeval
    except Exception as exc:  # pragma: no cover - environment guard
        raise SystemExit(f"pycocotools is required for official COCOeval: {exc}") from exc

    annotation_path = Path(args.annotation)
    predictions_path = Path(args.predictions)
    summary_json_path = Path(args.summary_json)
    summary_md_path = Path(args.summary_md)
    stdout_path = Path(args.stdout)

    predictions = load_json(predictions_path)
    coco_gt = COCO(str(annotation_path))
    if predictions:
        coco_dt = coco_gt.loadRes(str(predictions_path))
    else:
        empty_path = predictions_path.with_suffix(".empty.json")
        write_text(empty_path, "[]\n")
        coco_dt = coco_gt.loadRes(str(empty_path))

    coco_eval = COCOeval(coco_gt, coco_dt, "bbox")
    if args.eval_max_det:
        coco_eval.params.maxDets = [1, 10, int(args.eval_max_det)]
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        coco_eval.evaluate()
        coco_eval.accumulate()
        coco_eval.summarize()
    eval_stdout = buffer.getvalue()
    write_text(stdout_path, eval_stdout)

    image_ids = set()
    for item in predictions:
        image_ids.add(int(item["image_id"]))
    stats = coco_stats_to_dict(list(coco_eval.stats))
    summary = {
        "annotation": str(annotation_path),
        "predictions": str(predictions_path),
        "annotation_sha256": sha256_file(annotation_path),
        "predictions_sha256": sha256_file(predictions_path),
        "evaluated_image_count": len(coco_eval.params.imgIds),
        "images_with_predictions": len(image_ids),
        "detection_count": len(predictions),
        "prediction_max_det": args.prediction_max_det,
        "eval_max_dets": list(coco_eval.params.maxDets),
        "stats": stats,
    }
    write_text(summary_json_path, json.dumps(summary, indent=2, sort_keys=True) + "\n")

    lines = [
        f"# COCO mAP Summary: {args.name}",
        "",
        f"- Annotation: `{annotation_path}`",
        f"- Predictions: `{predictions_path}`",
        f"- Evaluated images: {summary['evaluated_image_count']}",
        f"- Images with predictions: {summary['images_with_predictions']}",
        f"- Detections: {summary['detection_count']}",
        f"- Prediction max detections per image: {summary['prediction_max_det']}",
        f"- COCOeval maxDets: {summary['eval_max_dets']}",
        "",
        "| Metric | Value |",
        "|---|---:|",
    ]
    for key, value in stats.items():
        lines.append(f"| {key} | {value:.6f} |")
    lines.extend(["", "## COCOeval Output", "", "```text", eval_stdout.rstrip(), "```", ""])
    write_text(summary_md_path, "\n".join(lines))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    prepare = sub.add_parser("prepare", help="prepare image list and category map")
    prepare.add_argument("--annotation", required=True)
    prepare.add_argument("--labels", required=True)
    prepare.add_argument("--image-root", required=True)
    prepare.add_argument("--image-list", required=True)
    prepare.add_argument("--category-map", required=True)
    prepare.add_argument("--provenance", required=True)
    prepare.set_defaults(func=cmd_prepare)

    evaluate = sub.add_parser("evaluate", help="run pycocotools COCOeval")
    evaluate.add_argument("--name", required=True)
    evaluate.add_argument("--annotation", required=True)
    evaluate.add_argument("--predictions", required=True)
    evaluate.add_argument("--summary-json", required=True)
    evaluate.add_argument("--summary-md", required=True)
    evaluate.add_argument("--stdout", required=True)
    evaluate.add_argument("--eval-max-det", type=int, default=100)
    evaluate.add_argument("--prediction-max-det", type=int, default=300)
    evaluate.set_defaults(func=cmd_evaluate)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
