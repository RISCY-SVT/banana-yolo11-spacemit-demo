#!/usr/bin/env python3
"""Inspect an ONNX model and print likely output/truncate candidates."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import onnx


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True)
    parser.add_argument("--tail", type=int, default=30)
    args = parser.parse_args()

    model = onnx.load(args.model)
    graph = model.graph

    print("MODEL", Path(args.model).resolve())
    print("INPUTS")
    for value in graph.input:
        dims = [d.dim_value if d.dim_value else d.dim_param for d in value.type.tensor_type.shape.dim]
        print(json.dumps({"name": value.name, "shape": dims}))

    print("OUTPUTS")
    for value in graph.output:
        dims = [d.dim_value if d.dim_value else d.dim_param for d in value.type.tensor_type.shape.dim]
        print(json.dumps({"name": value.name, "shape": dims}))

    print("TAIL_NODES")
    for node in graph.node[-args.tail:]:
        print(json.dumps({
            "name": node.name,
            "op_type": node.op_type,
            "inputs": list(node.input),
            "outputs": list(node.output),
        }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

