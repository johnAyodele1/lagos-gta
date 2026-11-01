#!/usr/bin/env python3
"""Inspect bundled GLB assets without a 3D runtime and write a reproducible manifest."""
from __future__ import annotations
import argparse
import json
import struct
from pathlib import Path

GLB_MAGIC = b"glTF"
JSON_CHUNK = 0x4E4F534A

def read_glb(path: Path) -> dict:
    data = path.read_bytes()
    if len(data) < 20 or data[:4] != GLB_MAGIC:
        raise ValueError(f"{path} is not a GLB file")
    version, declared_length = struct.unpack_from("<II", data, 4)
    if version != 2 or declared_length != len(data):
        raise ValueError(f"{path} has invalid GLB header (version={version}, length={declared_length})")
    chunk_length, chunk_type = struct.unpack_from("<II", data, 12)
    if chunk_type != JSON_CHUNK or 20 + chunk_length > len(data):
        raise ValueError(f"{path} has no valid first JSON chunk")
    document = json.loads(data[20:20 + chunk_length].decode("utf-8").rstrip(" \t\r\n\0"))
    return {"bytes": len(data), "document": document}

def inspect(path: Path, require_rig: bool) -> dict:
    result = read_glb(path)
    doc = result["document"]
    animations = [str(item.get("name", f"animation_{i}")) for i, item in enumerate(doc.get("animations", []))]
    skins = doc.get("skins", [])
    mesh_count = len(doc.get("meshes", []))
    primitive_count = 0
    triangles = 0
    accessors = doc.get("accessors", [])
    for mesh in doc.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            primitive_count += 1
            if int(primitive.get("mode", 4)) != 4:
                continue
            if "indices" in primitive:
                count = int(accessors[int(primitive["indices"])].get("count", 0))
            else:
                position = primitive.get("attributes", {}).get("POSITION")
                count = int(accessors[int(position)].get("count", 0)) if position is not None else 0
            triangles += count // 3
    report = {
        "file": path.name,
        "size_bytes": result["bytes"],
        "mesh_count": mesh_count,
        "primitive_count": primitive_count,
        "triangle_count": triangles,
        "material_count": len(doc.get("materials", [])),
        "image_count": len(doc.get("images", [])),
        "skin_count": len(skins),
        "joint_count": sum(len(skin.get("joints", [])) for skin in skins),
        "animation_names": animations,
        "node_names": [str(node.get("name", "")) for node in doc.get("nodes", []) if node.get("name")],
    }
    if require_rig and (not skins or not animations):
        raise ValueError(f"{path} must contain a skin and baked animation clips; got {len(skins)} skins and {len(animations)} animations")
    return report

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--characters", type=Path, default=Path("assets/models/characters/ara"))
    parser.add_argument("--architecture", type=Path, default=Path("assets/models/architecture"))
    parser.add_argument("--output", type=Path, default=Path("assets/models/asset_manifest.json"))
    args = parser.parse_args()
    reports = []
    for path in sorted(args.characters.glob("*.glb")):
        reports.append(inspect(path, require_rig=True))
    for path in sorted(args.architecture.glob("*.glb")):
        reports.append(inspect(path, require_rig=False))
    if not reports:
        raise RuntimeError("No GLB assets were found to inspect")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({"schema_version": 1, "assets": reports}, indent=2) + "\n", encoding="utf-8")
    for item in reports:
        print(f"{item['file']}: {item['triangle_count']:,} triangles, {item['skin_count']} skins, animations={item['animation_names']}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
