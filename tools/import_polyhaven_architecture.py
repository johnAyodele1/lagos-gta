#!/usr/bin/env python3
"""Download the CC0 Poly Haven modular apartment facade source package.

The 90 MiB ceiling stays below GitHub's 100 MiB single-file hard limit.

The API is used only during asset import. The game ships the resulting local GLB
and never makes a runtime request to Poly Haven.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath
from urllib.parse import urlparse

ASSET_ID = "modular_urban_apartments_facade"
API_URL = f"https://api.polyhaven.com/files/{ASSET_ID}"
USER_AGENT = "LagosGTA-AssetImporter/1.0 (https://github.com/johnAyodele1/lagos-gta)"
MAX_DOWNLOAD_BYTES = 90 * 1024 * 1024


def request_bytes(url: str, limit: int = MAX_DOWNLOAD_BYTES) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=90) as response:
        declared_size = response.headers.get("Content-Length")
        if declared_size and int(declared_size) > limit:
            raise RuntimeError(f"Asset exceeds {limit} byte import limit: {declared_size}")
        data = response.read(limit + 1)
    if len(data) > limit:
        raise RuntimeError(f"Asset exceeds {limit} byte import limit")
    return data


def collect_downloads(value: object, path: tuple[str, ...] = ()) -> list[dict[str, object]]:
    found: list[dict[str, object]] = []
    if isinstance(value, dict):
        url = value.get("url")
        size = value.get("size")
        if isinstance(url, str) and isinstance(size, int):
            found.append({
                "url": url,
                "size": size,
                "md5": value.get("md5"),
                "path": "/".join(path).lower(),
            })
        for key, child in value.items():
            found.extend(collect_downloads(child, path + (str(key),)))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            found.extend(collect_downloads(child, path + (str(index),)))
    return found


def safe_extract(archive: Path, destination: Path) -> None:
    with zipfile.ZipFile(archive) as zipped:
        for item in zipped.infolist():
            target = (destination / item.filename).resolve()
            if not target.is_relative_to(destination.resolve()):
                raise RuntimeError(f"Unsafe path in source archive: {item.filename}")
        zipped.extractall(destination)



def resolve_gltf_dependencies(scene_path: Path, metadata: object) -> None:
    """Fetch external GLTF buffers/textures omitted from Poly Haven's scene ZIP."""
    scene = json.loads(scene_path.read_text(encoding="utf-8"))
    entries = collect_downloads(metadata)
    by_basename: dict[str, list[dict[str, object]]] = {}
    for entry in entries:
        basename = PurePosixPath(urlparse(str(entry["url"])).path).name
        if basename:
            by_basename.setdefault(basename, []).append(entry)

    uris: list[str] = []
    for section in ("buffers", "images"):
        for item in scene.get(section, []):
            uri = item.get("uri")
            if isinstance(uri, str) and not uri.startswith("data:"):
                uris.append(uri)

    for uri in uris:
        target = (scene_path.parent / uri).resolve()
        if not target.is_relative_to(scene_path.parent.resolve()):
            raise RuntimeError(f"Unsafe external GLTF dependency path: {uri}")
        if target.is_file():
            continue
        basename = PurePosixPath(uri).name
        matches = by_basename.get(basename, [])
        if not matches:
            raise RuntimeError(f"Poly Haven API did not provide the GLTF dependency: {uri}")
        selected = min(matches, key=lambda item: int(item["size"]))
        payload = request_bytes(str(selected["url"]))
        expected_md5 = selected.get("md5")
        if expected_md5 and hashlib.md5(payload).hexdigest().lower() != str(expected_md5).lower():
            raise RuntimeError(f"MD5 mismatch for GLTF dependency: {basename}")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(payload)
        print(f"Resolved GLTF dependency: {uri} ({len(payload):,} bytes)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    request = urllib.request.Request(API_URL, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=45) as response:
        metadata = json.loads(response.read().decode("utf-8"))

    candidates = [
        item for item in collect_downloads(metadata)
        if "gltf" in str(item["path"])
        and urlparse(str(item["url"])).path.lower().endswith((".zip", ".gltf", ".glb"))
        and int(item["size"]) <= MAX_DOWNLOAD_BYTES
    ]
    if not candidates:
        raise RuntimeError("Poly Haven API did not expose a GLTF/GLB package within the import size limit.")

    # Prefer a 2K texture package, then 1K, and finally the smallest GLTF package.
    candidates.sort(key=lambda item: (
        0 if "2k" in str(item["path"]) else 1 if "1k" in str(item["path"]) else 2,
        int(item["size"]),
    ))
    selected = candidates[0]
    payload = request_bytes(str(selected["url"]))
    expected_md5 = selected.get("md5")
    if expected_md5 and hashlib.md5(payload).hexdigest().lower() != str(expected_md5).lower():
        raise RuntimeError("Poly Haven download MD5 did not match the API manifest.")

    staging = output_dir / ".polyhaven-staging"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)
    suffix = PurePosixPath(urlparse(str(selected["url"])).path).suffix.lower()
    source_file = staging / f"source{suffix or '.bin'}"
    source_file.write_bytes(payload)

    if suffix == ".zip":
        extracted = staging / "extracted"
        extracted.mkdir()
        safe_extract(source_file, extracted)
        model_files = list(extracted.rglob("*.glb")) + list(extracted.rglob("*.gltf"))
        if not model_files:
            raise RuntimeError("The Poly Haven GLTF archive contains no .gltf or .glb scene.")
        # Prefer a self-contained binary model when the archive provides one.
        model_files.sort(key=lambda item: (item.suffix != ".glb", len(item.parts), str(item)))
        selected_model = model_files[0]
        if selected_model.suffix == ".glb":
            destination = output_dir / "modular_urban_apartments_facade.glb"
            shutil.copy2(selected_model, destination)
        else:
            # Preserve the complete archive tree: Poly Haven's glTF references
            # texture files in sibling subdirectories, not just beside the scene.
            destination_root = output_dir / "source"
            if destination_root.exists():
                shutil.rmtree(destination_root)
            shutil.copytree(extracted, destination_root)
            relative_model = selected_model.relative_to(extracted)
            destination = destination_root / relative_model
            renamed_scene = destination.with_name("source.gltf")
            if destination != renamed_scene:
                shutil.copy2(destination, renamed_scene)
                destination.unlink()
            destination = renamed_scene
    elif suffix == ".glb":
        destination = output_dir / "modular_urban_apartments_facade.glb"
        destination.write_bytes(payload)
    elif suffix == ".gltf":
        destination_root = output_dir / "source"
        destination_root.mkdir(exist_ok=True)
        destination = destination_root / "source.gltf"
        destination.write_bytes(payload)
    else:
        raise RuntimeError(f"Unsupported Poly Haven download format: {suffix}")

    if destination.suffix == ".gltf":
        resolve_gltf_dependencies(destination, metadata)

    (output_dir / "polyhaven-source.json").write_text(json.dumps({
        "asset_id": ASSET_ID,
        "asset_name": "Modular Urban Apartments Facade",
        "author": "James Ray Cock",
        "source": "https://polyhaven.com/a/modular_urban_apartments_facade",
        "license": "CC0 1.0",
        "api_download_url": selected["url"],
        "api_package_size": selected["size"],
        "source_md5": expected_md5,
        "imported_scene": str(destination.relative_to(output_dir)),
        "runtime_network_dependency": False,
    }, indent=2) + "\n", encoding="utf-8")
    shutil.rmtree(staging, ignore_errors=True)
    print(f"Downloaded and verified Poly Haven source package: {destination}")
    print("Next step: convert source.gltf to the runtime GLB when the source package is glTF.")


if __name__ == "__main__":
    main()
