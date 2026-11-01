#!/usr/bin/env python3
"""Enrich Yaba OSM building ways from the cloud-native OpenBuildingMap Parquet tile."""
from __future__ import annotations
import argparse
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = ROOT / "assets/data/yaba_osm.json"
LAT, LON, ZOOM = 6.51147, 3.37000, 6
PARQUET_URL = "https://data.source.coop/tge-labs/openbuildingmap/building.{quadkey}.parquet"

def quadkey_for(lat: float, lon: float, zoom: int = ZOOM) -> str:
    n = 1 << zoom
    x = int((lon + 180.0) / 360.0 * n)
    y = int((1.0 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2.0 * n)
    digits = []
    for level in range(zoom, 0, -1):
        mask = 1 << (level - 1)
        digits.append(str((1 if x & mask else 0) + (2 if y & mask else 0)))
    return "".join(digits)

def parse_height_taxonomy(value: str | None) -> tuple[float | None, str | None, float | None]:
    """Return (metres, taxonomy key, approximate storeys); prefer HHT over story counts."""
    if not value:
        return None, None, None
    parts = [part.strip() for part in value.split("+")]
    for part in parts:
        match = re.fullmatch(r"HHT:(\d+(?:\.\d+)?)", part, re.I)
        if match and 2.0 <= float(match.group(1)) <= 100.0:
            return float(match.group(1)), "HHT", None
    for key in ("H", "HAPP", "HBET"):
        for part in parts:
            match = re.fullmatch(rf"{key}:(\d+(?:\.\d+)?)(?:\s*[-–]\s*(\d+(?:\.\d+)?))?", part, re.I)
            if match:
                stories = (float(match.group(1)) + float(match.group(2) or match.group(1))) / 2.0
                if 1.0 <= stories <= 40.0:
                    return stories * 3.1, key, stories
    return None, None, None

def records_from_rows(rows: list[tuple], osm_ids: list[int]) -> dict[int, tuple[str | None, str | None]]:
    wanted = set(osm_ids)
    records: dict[int, tuple[str | None, str | None]] = {}
    for row_id, height, occupancy, source in rows:
        if str(source).upper() != "OSM":
            continue
        try:
            osm_id = int(row_id)
        except (TypeError, ValueError):
            continue
        if osm_id not in wanted:
            continue
        records[osm_id] = (
            str(height) if height not in (None, "") else None,
            str(occupancy) if occupancy not in (None, "") else None,
        )
    return records

def query_openbuildingmap(url: str, bounds: dict[str, float], osm_ids: list[int]) -> dict[int, tuple[str | None, str | None]]:
    try:
        import duckdb
    except ImportError as exc:
        raise RuntimeError("Install the pinned DuckDB dependency before OpenBuildingMap enrichment") from exc
    connection = duckdb.connect(database=":memory:")
    try:
        connection.execute("INSTALL httpfs")
        connection.execute("LOAD httpfs")
        # Source Cooperative exposes public range-readable Parquet. DuckDB reads
        # only the required columns and spatially matching row groups over HTTPS.
        query = """
            SELECT id, height, occupancy, source
            FROM read_parquet(?)
            WHERE source = 'OSM'
              AND bbox.xmin <= ? AND bbox.xmax >= ?
              AND bbox.ymin <= ? AND bbox.ymax >= ?
        """
        rows = connection.execute(query, [
            url,
            float(bounds["east"]), float(bounds["west"]),
            float(bounds["north"]), float(bounds["south"]),
        ]).fetchall()
        return records_from_rows(rows, osm_ids)
    finally:
        connection.close()

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
        "source": "OpenBuildingMap",
        "version": "2025-002",
        "quadkey": quadkey,
        "license": "ODbL-1.0",
        "source_url": "https://doi.org/10.5880/GFZ.LKUT.2025.002",
        "parquet_url": PARQUET_URL.format(quadkey=quadkey),
        "join": "OSM way ID; source='OSM' only; spatial bbox prefilter",
        "counts": counts,
    }
    return counts

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    args = parser.parse_args()
    data = json.loads(args.input.read_text(encoding="utf-8"))
    osm_ids = sorted({int(item["id"]) for item in data.get("buildings", []) if str(item.get("id", "")).isdigit()})
    if not osm_ids:
        raise RuntimeError("No numeric OSM building IDs found")
    quadkey = quadkey_for(LAT, LON)
    url = PARQUET_URL.format(quadkey=quadkey)
    records = query_openbuildingmap(url, data["bounds"], osm_ids)
    if not records:
        raise RuntimeError(f"No OSM building IDs matched OpenBuildingMap Parquet tile {quadkey}")
    counts = enrich(data, records, quadkey)
    temporary = args.input.with_suffix(args.input.suffix + ".tmp")
    temporary.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    temporary.replace(args.input)
    print(f"OpenBuildingMap {quadkey}: {counts}")
    print(f"Source: {url} | Licence: ODbL-1.0")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
