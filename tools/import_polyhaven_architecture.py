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
            source_root = selected_model.parent
            destination_root = output_dir / "source"
            if destination_root.exists():
                shutil.rmtree(destination_root)
            shutil.copytree(source_root, destination_root)
            destination = destination_root / "source.gltf"
            shutil.copy2(destination_root / selected_model.name, destination)
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
    print(f"Downloaded and verified Poly Haven source package: {destination}")
    print("Next step: convert source.gltf to the runtime GLB when the source package is glTF.")


if __name__ == "__main__":
    main()
