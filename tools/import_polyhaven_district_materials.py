#!/usr/bin/env python3
"""Import bounded Poly Haven CC0 PBR maps for the Yaba district."""
import hashlib
import json
import urllib.request
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/materials/polyhaven"
API = "https://api.polyhaven.com"
UA = "LagosGTA-AssetImporter/1.0 (https://github.com/johnAyodele1/lagos-gta)"
MAX_BYTES = 18 * 1024 * 1024
ASSETS = {
    "asphalt_02": "https://polyhaven.com/a/asphalt_02",
    "concrete_floor": "https://polyhaven.com/a/concrete_floor",
    "corrugated_iron": "https://polyhaven.com/a/corrugated_iron",
}
CHANNELS = {
    "diff": ("diffuse", "albedo", "basecolor"),
    "nor_gl": ("nor_gl", "normal"),
    "rough": ("rough",),
}

def get(url, limit=MAX_BYTES):
    request = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(request, timeout=60) as response:
        size = response.headers.get("Content-Length")
        if size and int(size) > limit:
            raise ValueError("Download exceeds byte budget: " + url)
        data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError("Download exceeds byte budget: " + url)
    return data

def flatten(value, path=()):
    result = []
    if isinstance(value, dict):
        if isinstance(value.get("url"), str) and isinstance(value.get("size"), int):
            result.append({"url": value["url"], "size": value["size"], "md5": value.get("md5"), "path": "/".join(path).lower()})
        for key, child in value.items():
            result.extend(flatten(child, path + (str(key),)))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            result.extend(flatten(child, path + (str(index),)))
    return result

def choose(rows, aliases):
    matches = []
    for row in rows:
        path = row["path"]
        if not any(alias in path for alias in aliases):
            continue
        if not any(token in path for token in ("/1k/", "/2k/", "_1k.", "_2k.")):
            continue
        extension = Path(urlparse(row["url"]).path).suffix.lower()
        if extension not in (".jpg", ".jpeg", ".png", ".webp"):
            continue
        matches.append((0 if "1k" in path else 1, row["size"], row))
    return min(matches, key=lambda item: (item[0], item[1]))[2] if matches else None

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"schema_version": 1, "source": "Poly Haven", "license": "CC0 1.0", "runtime_network_dependency": False, "assets": {}}
    for asset_id, source in ASSETS.items():
        metadata = json.loads(get(f"{API}/files/{asset_id}", 8 * 1024 * 1024))
        rows = flatten(metadata)
        maps = {}
        for channel, aliases in CHANNELS.items():
            item = choose(rows, aliases)
            if item is None:
                raise RuntimeError(f"{asset_id} is missing required {channel} map")
            data = get(item["url"])
            if item["md5"] and hashlib.md5(data).hexdigest().lower() != str(item["md5"]).lower():
                raise RuntimeError(f"MD5 mismatch for {asset_id}/{channel}")
            extension = Path(urlparse(item["url"]).path).suffix.lower()
            filename = f"{asset_id}_{channel}{extension}"
            (OUT / filename).write_bytes(data)
            maps[channel] = {"file": filename, "bytes": len(data), "source_path": item["path"]}
            print(f"{filename}: {len(data):,} bytes")
        manifest["assets"][asset_id] = {"source": source, "license": "CC0 1.0", "maps": maps}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
