#!/usr/bin/env python3
"""Extract every fully-authored NCTC bus bay from a network JSON.

A buildable bay requires:
- capture.berth  -> surveyed P1
- capture.berth2 -> surveyed P2
- capture.spawn  -> upstream road reference
- width, either capture.bayWidth or the distance bayWidthA <-> bayWidthB

The output manifest is deterministic and stop-ID sorted. Adding another complete
bay to the canonical network therefore requires no REDscript or workflow edit.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


def has_position(value: Any) -> bool:
    return isinstance(value, dict) and isinstance(value.get("x"), (int, float)) and isinstance(value.get("y"), (int, float))


def point3(value: dict[str, Any]) -> dict[str, float]:
    return {
        "x": float(value["x"]),
        "y": float(value["y"]),
        "z": float(value.get("z", 0.0)),
    }


def resolve_width(capture: dict[str, Any]) -> float | None:
    raw = capture.get("bayWidth")
    if isinstance(raw, (int, float)) and 2.0 <= float(raw) <= 5.0:
        return float(raw)
    a = capture.get("bayWidthA")
    b = capture.get("bayWidthB")
    if has_position(a) and has_position(b):
        width = math.hypot(float(a["x"]) - float(b["x"]), float(a["y"]) - float(b["y"]))
        if 2.0 <= width <= 5.0:
            return width
    return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--network", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    network = json.loads(args.network.read_text(encoding="utf-8"))
    stops = {int(s["id"]): s for s in network.get("stops", []) if isinstance(s, dict) and isinstance(s.get("id"), int)}
    bays: dict[int, dict[str, Any]] = {}

    for capture in network.get("captures", []):
        if not isinstance(capture, dict):
            continue
        stop_id = capture.get("stopId")
        if not isinstance(stop_id, int) or stop_id < 1:
            continue
        if not has_position(capture.get("berth")) or not has_position(capture.get("berth2")):
            continue
        if not has_position(capture.get("spawn")):
            raise SystemExit(f"stop {stop_id}: P1/P2 bay has no valid spawn")
        width = resolve_width(capture)
        if width is None:
            raise SystemExit(f"stop {stop_id}: P1/P2 bay has no valid 2-5 m width")

        entry = {
            "stopId": stop_id,
            "label": str(stops.get(stop_id, {}).get("name") or capture.get("stopName") or f"stop {stop_id}"),
            "line": int(capture.get("line", 0) or 0),
            "p1": point3(capture["berth"]),
            "p2": point3(capture["berth2"]),
            "spawn": point3(capture["spawn"]),
            "width": width,
            "sourceEventId": int(capture.get("eventId", 0) or 0),
        }
        previous = bays.get(stop_id)
        if previous is not None:
            comparable = (previous["p1"], previous["p2"], previous["spawn"], round(previous["width"], 4))
            candidate = (entry["p1"], entry["p2"], entry["spawn"], round(entry["width"], 4))
            if comparable != candidate:
                raise SystemExit(f"stop {stop_id}: conflicting complete bay captures")
            if entry["sourceEventId"] <= previous["sourceEventId"]:
                continue
        bays[stop_id] = entry

    if not bays:
        raise SystemExit("network contains no complete P1 + P2 + width bus bays")

    manifest = {
        "schemaVersion": 2,
        "generatedFrom": args.network.as_posix(),
        "bayCount": len(bays),
        "bays": [bays[k] for k in sorted(bays)],
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"extracted {len(bays)} complete bays: " + ", ".join(str(k) for k in sorted(bays)))


if __name__ == "__main__":
    main()
