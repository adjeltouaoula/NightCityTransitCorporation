#!/usr/bin/env python3
"""Generate NCTC bay-arrival spline CR2W JSON from the validated H2 template.

The validated H2 spline is expressed in bay-local coordinates:
  (-22m, +4.2m), (-10m, +4.2m), (0m, +4.2m),
  (25%, ~59.5%), (50%, ~19.0%), (75%, 0), (100%, 0)
where longitudinal 0 is P1 / the physical bay entrance and positive lateral
points toward the adjacent road. The last longitudinal point is min(20m, 65%
of bay length), matching the validated H2 curve almost exactly.
"""

from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path
from typing import Any


def walk_replace(value: Any, replacements: dict[str, str]) -> Any:
    if isinstance(value, dict):
        return {k: walk_replace(v, replacements) for k, v in value.items()}
    if isinstance(value, list):
        return [walk_replace(v, replacements) for v in value]
    if isinstance(value, str):
        out = value
        for old, new in replacements.items():
            out = out.replace(old, new)
        return out
    return value


def find_spline(obj: Any) -> dict[str, Any] | None:
    if isinstance(obj, dict):
        if obj.get("$type") == "Spline" and isinstance(obj.get("points"), list):
            return obj
        for value in obj.values():
            found = find_spline(value)
            if found is not None:
                return found
    elif isinstance(obj, list):
        for value in obj:
            found = find_spline(value)
            if found is not None:
                return found
    return None


def vec3(point: dict[str, float]) -> tuple[float, float, float]:
    return float(point["x"]), float(point["y"]), float(point["z"])


def generate_bay(sector_template: dict[str, Any], block_template: dict[str, Any], bay: dict[str, Any], out: Path) -> None:
    stop_id = int(bay["stopId"])
    p1x, p1y, p1z = vec3(bay["p1"])
    p2x, p2y, p2z = vec3(bay["p2"])
    sx, sy, _ = vec3(bay["spawn"])
    width = float(bay["width"])

    dx, dy = p2x - p1x, p2y - p1y
    bay_length = math.hypot(dx, dy)
    if bay_length < 8.0:
        raise ValueError(f"stop {stop_id}: bay too short ({bay_length:.2f}m)")
    fx, fy = dx / bay_length, dy / bay_length
    rx, ry = -fy, fx

    # The survey spawn is on the road before the stop. Its sign relative to the
    # bay right axis tells us which side contains the road without assuming a
    # global curb side.
    spawn_lateral = (sx - p1x) * rx + (sy - p1y) * ry
    side_sign = -1.0 if spawn_lateral < -0.50 else 1.0

    # Exactly reproduces H2 (4.2m), while allowing a slightly wider road offset
    # for a physically wider authored bay.
    road_offset = max(4.20, width * 0.50 + 2.75)
    service_depth = min(20.0, bay_length * 0.65)
    recipe = [
        (-22.0, road_offset),
        (-10.0, road_offset),
        (0.0, road_offset),
        (service_depth * 0.25, road_offset * (2.5 / 4.2)),
        (service_depth * 0.50, road_offset * (0.8 / 4.2)),
        (service_depth * 0.75, 0.0),
        (service_depth, 0.0),
    ]

    prefix = f"nctc\\bays\\stop_{stop_id}"
    node_ref = f"$/nctc/bays/stop_{stop_id}/arrival_spline"
    replacements = {
        "nctc\\bays\\h2": prefix,
        "$/nctc/bays/h2/arrival_spline": node_ref,
    }
    sector = walk_replace(copy.deepcopy(sector_template), replacements)
    block = walk_replace(copy.deepcopy(block_template), replacements)

    root = sector["Data"]["RootChunk"]
    node_data = root["nodeData"]["Data"][0]
    node_data["Position"]["X"] = p1x
    node_data["Position"]["Y"] = p1y
    node_data["Position"]["Z"] = p1z
    node_data["Pivot"]["X"] = p1x
    node_data["Pivot"]["Y"] = p1y
    node_data["Pivot"]["Z"] = p1z
    node_data["QuestPrefabRefHash"]["$storage"] = "string"
    node_data["QuestPrefabRefHash"]["$value"] = node_ref
    root["nodeRefs"][0]["$storage"] = "string"
    root["nodeRefs"][0]["$value"] = node_ref

    spline = find_spline(sector)
    if spline is None:
        raise ValueError("validated template contains no Spline")
    points = spline["points"]
    if len(points) != 7:
        raise ValueError(f"validated template has {len(points)} points; expected 7")

    world_points: list[tuple[float, float, float]] = []
    for point, (longitudinal, lateral) in zip(points, recipe):
        lateral *= side_sign
        lx = fx * longitudinal + rx * lateral
        ly = fy * longitudinal + ry * lateral
        point["position"]["X"] = lx
        point["position"]["Y"] = ly
        point["position"]["Z"] = 0.0
        # Preserve the validated curve semantics: automatic tangents enabled,
        # explicit tangent vectors neutral.
        tangent_data = point.get("tangents", {}).get("Elements", [])
        for tangent in tangent_data:
            tangent["X"] = 0.0
            tangent["Y"] = 0.0
            tangent["Z"] = 0.0
        world_points.append((p1x + lx, p1y + ly, p1z))

    min_x = min(p[0] for p in world_points) - 8.0
    max_x = max(p[0] for p in world_points) + 8.0
    min_y = min(p[1] for p in world_points) - 8.0
    max_y = max(p[1] for p in world_points) + 8.0
    node_data["Bounds"]["Min"]["X"] = min_x
    node_data["Bounds"]["Min"]["Y"] = min_y
    node_data["Bounds"]["Min"]["Z"] = p1z - 3.0
    node_data["Bounds"]["Max"]["X"] = max_x
    node_data["Bounds"]["Max"]["Y"] = max_y
    node_data["Bounds"]["Max"]["Z"] = p1z + 5.0

    bay_dir = out / f"stop_{stop_id}"
    bay_dir.mkdir(parents=True, exist_ok=True)
    (bay_dir / "h2_arrival.streamingsector.json").write_text(
        json.dumps(sector, indent=2), encoding="utf-8", newline="\n"
    )
    (bay_dir / "all.streamingblock.json").write_text(
        json.dumps(block, indent=2), encoding="utf-8", newline="\n"
    )
    report = {
        "stopId": stop_id,
        "label": bay.get("label", ""),
        "nodeRef": node_ref,
        "bayLength": bay_length,
        "width": width,
        "roadSideSign": side_sign,
        "roadOffset": road_offset,
        "serviceDepth": service_depth,
        "recipe": [{"longitudinal": a, "lateral": b * side_sign} for a, b in recipe],
        "worldPoints": [{"x": x, "y": y, "z": z} for x, y, z in world_points],
    }
    (bay_dir / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8", newline="\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sector-template", required=True, type=Path)
    parser.add_argument("--block-template", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    sector_template = json.loads(args.sector_template.read_text(encoding="utf-8"))
    block_template = json.loads(args.block_template.read_text(encoding="utf-8"))
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    args.out.mkdir(parents=True, exist_ok=True)
    for bay in manifest["bays"]:
        generate_bay(sector_template, block_template, bay, args.out)


if __name__ == "__main__":
    main()
