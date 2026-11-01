#!/usr/bin/env python3
"""Join Yaba OSM building ways to OpenBuildingMap's ODbL height/occupancy tile."""
from __future__ import annotations
import argparse, bz2, json, math, re, shutil, sqlite3, tempfile
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = ROOT / "assets/data/yaba_osm.json"
LAT, LON, ZOOM = 6.51147, 3.37000, 6
URL = "https://datapub.gfz.de/download/10.5880.GFZ.LKUT.2025.002-Caweb/2025-002_Oostwegel-et-al_data/building.{quadkey}.gpkg.bz2"
UA = "LagosGTA-OpenBuildingMapImporter/1.0 (https://github.com/johnAyodele1/lagos-gta)"
MAX_COMPRESSED_BYTES = 1024 * 1024 * 1024

def quadkey_for(lat: float, lon: float, zoom: int = ZOOM) -> str:
    n = 1 << zoom
    x = int((lon + 180.0) / 360.0 * n)
    y = int((1.0 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2.0 * n)
    out = []
    for level in range(zoom, 0, -1):
        mask = 1 << (level - 1)
        out.append(str((1 if x & mask else 0) + (2 if y & mask else 0)))
    return "".join(out)

def parse_height_taxonomy(value: str | None) -> tuple[float | None, str | None, float | None]:
    if not value:
        return None, None, None
    parts = [p.strip() for p in value.split("+")]
    for part in parts:
        m = re.fullmatch(r"HHT:(\d+(?:\.\d+)?)", part, re.I)
        if m and 2 <= float(m.group(1)) <= 100:
            return float(m.group(1)), "HHT", None
    for key in ("H", "HAPP", "HBET"):
        for part in parts:
            m = re.fullmatch(rf"{key}:(\d+(?:\.\d+)?)(?:\s*[-–]\s*(\d+(?:\.\d+)?))?", part, re.I)
            if m:
                stories = (float(m.group(1)) + float(m.group(2) or m.group(1))) / 2
                if 1 <= stories <= 40:
                    return stories * 3.1, key, stories
    return None, None, None

def download_tile(url: str, destination: Path) -> None:
    req = Request(url, headers={"User-Agent": UA, "Accept": "application/octet-stream"})
    with urlopen(req, timeout=180) as response:
        declared = response.headers.get("Content-Length")
        if declared and int(declared) > MAX_COMPRESSED_BYTES:
            raise RuntimeError(f"OpenBuildingMap tile exceeds 1 GiB compressed limit: {declared} bytes")
        total = 0
        with bz2.BZ2File(response) as source, destination.open("wb") as target:
            while chunk := source.read(1024 * 1024):
                total += len(chunk)
                if total > 1024 * 1024 * 1024:
                    raise RuntimeError("OpenBuildingMap tile exceeds 1 GiB expanded limit")
                target.write(chunk)
    if not destination.is_file() or destination.stat().st_size == 0:
        raise RuntimeError("OpenBuildingMap download produced an empty GeoPackage")

def lookup(gpkg: Path, osm_ids: list[int]) -> dict[int, tuple[str | None, str | None]]:
    db = sqlite3.connect(f"file:{gpkg}?mode=ro", uri=True)
    try:
        tables = {r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        if "building" not in tables:
            raise RuntimeError("GeoPackage has no building table")
        columns = {r[1] for r in db.execute("PRAGMA table_info(building)")}
        required = {"id", "height", "occupancy", "source_id"}
        if not required.issubset(columns):
            raise RuntimeError(f"GeoPackage missing columns: {sorted(required - columns)}")
        db.execute("CREATE TEMP TABLE wanted_osm_ids (id INTEGER PRIMARY KEY)")
        db.executemany("INSERT OR IGNORE INTO wanted_osm_ids(id) VALUES (?)", ((item,) for item in osm_ids))
        query = (
            "SELECT b.id,b.height,b.occupancy FROM building AS b "
            "INNER JOIN wanted_osm_ids AS w ON w.id=b.id WHERE b.source_id=0"
        )
        found = {}
        for row_id, height, occupancy in db.execute(query):
            found[int(row_id)] = (str(height) if height else None, str(occupancy) if occupancy else None)
        return found
    finally:
        db.close()

def enrich(data: dict, records: dict[int, tuple[str | None, str | None]], quadkey: str) -> dict[str, int]:
    counts = {"matched_osm_buildings": 0, "height_enriched": 0, "occupancy_enriched": 0}
    for building in data.get("buildings", []):
        try:
            osm_id = int(building.get("id", ""))
        except (TypeError, ValueError):
            continue
        if osm_id not in records:
            continue
        counts["matched_osm_buildings"] += 1
        taxonomy, occupancy = records[osm_id]
        metres, kind, stories = parse_height_taxonomy(taxonomy)
        if metres is not None and str(building.get("height_source", "")).startswith("estimated:"):
            building["height_m"] = round(metres, 2)
            building["height_source"] = f"openbuildingmap:{kind}"
            if stories is not None and int(building.get("levels", 0)) <= 0:
                building["levels"] = round(stories)
            counts["height_enriched"] += 1
        if occupancy and occupancy.upper() != "UNK":
            building["occupancy"] = occupancy
            building["occupancy_source"] = "OpenBuildingMap-ODbL-1.0"
            counts["occupancy_enriched"] += 1
    data["building_enrichment"] = {
        "source": "OpenBuildingMap", "version": "2025-002", "quadkey": quadkey,
        "license": "ODbL-1.0", "source_url": "https://doi.org/10.5880/GFZ.LKUT.2025.002",
        "join": "OSM way ID; source_id=0 only", "counts": counts,
    }
    return counts

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    args = parser.parse_args()
    data = json.loads(args.input.read_text(encoding="utf-8"))
    ids = sorted({int(b["id"]) for b in data.get("buildings", []) if str(b.get("id", "")).isdigit()})
    if not ids:
        raise RuntimeError("No numeric OSM building IDs found")
    quadkey = quadkey_for(LAT, LON)
    with tempfile.TemporaryDirectory(prefix="lagos-obm-") as temp:
        gpkg = Path(temp) / f"building.{quadkey}.gpkg"
        download_tile(URL.format(quadkey=quadkey), gpkg)
        records = lookup(gpkg, ids)
    if not records:
        raise RuntimeError(f"No OSM IDs matched OpenBuildingMap tile {quadkey}")
    counts = enrich(data, records, quadkey)
    tmp = args.input.with_suffix(args.input.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    tmp.replace(args.input)
    print(f"OpenBuildingMap {quadkey}: {counts}")
    print("Source: GFZ OpenBuildingMap | Licence: ODbL-1.0")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
