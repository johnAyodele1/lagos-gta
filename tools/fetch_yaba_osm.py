#!/usr/bin/env python3
"""Fetch a small, reproducible Yaba road/building extract from OpenStreetMap.

The generated data is committed only to the active feature branch by CI.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
QUERY_PATH = ROOT / "data" / "osm" / "yaba.overpassql"
CENTER_LAT = 6.51147
CENTER_LON = 3.37000
BOUNDS = {"south": 6.505, "west": 3.360, "north": 6.520, "east": 3.382}
ENDPOINTS = (
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
)
USER_AGENT = "LagosGTA-OSMImporter/1.0 (https://github.com/johnAyodele1/lagos-gta)"
SELECTED_TAGS = (
    "name", "highway", "surface", "width", "lanes", "oneway",
    "building", "building:levels", "height", "roof:shape", "barrier", "fence_type",
    "shop", "amenity", "landuse", "addr:street", "addr:housenumber",
    "building:material", "building:colour", "roof:material", "roof:colour", "roof:levels",
    "building:min_level", "min_height",
)

ROAD_WIDTHS = {
    "primary": 14.0,
    "secondary": 10.0,
    "tertiary": 8.0,
    "unclassified": 7.0,
    "residential": 6.0,
    "living_street": 5.0,
    "service": 4.0,
    "pedestrian": 4.0,
    "footway": 2.0,
    "path": 2.0,
}


def local_coordinates(lat: float, lon: float) -> list[float]:
    """Project WGS84 into local metres; game X=east and Z=south."""
    metres_per_degree_lat = 110_574.0
    metres_per_degree_lon = 111_320.0 * math.cos(math.radians(CENTER_LAT))
    x = (lon - CENTER_LON) * metres_per_degree_lon
    z = -(lat - CENTER_LAT) * metres_per_degree_lat
    return [round(x, 2), round(z, 2)]


def parse_distance(value: str | None) -> float | None:
    if not value:
        return None
    match = re.search(r"([0-9]+(?:\.[0-9]+)?)\s*(m|meter|metre|ft|feet)?", value.lower())
    if not match:
        return None
    amount = float(match.group(1))
    unit = match.group(2)
    if unit in ("ft", "feet"):
        amount *= 0.3048
    return amount if 0.5 <= amount <= 100.0 else None


def road_width(tags: dict[str, str]) -> tuple[float, str]:
    explicit = parse_distance(tags.get("width"))
    if explicit is not None:
        return round(max(2.0, min(explicit, 30.0)), 2), "osm:width"
    try:
        lanes = float(tags.get("lanes", ""))
        if 1.0 <= lanes <= 8.0:
            return round(lanes * 3.2 + 1.0, 2), "estimated:lanes"
    except ValueError:
        pass
    highway = tags.get("highway", "residential")
    return ROAD_WIDTHS.get(highway, 6.0), "estimated:highway-default"


DEFAULT_BUILDING_HEIGHTS = {
    "house": 6.2,
    "detached": 6.2,
    "semidetached_house": 6.2,
    "residential": 7.2,
    "commercial": 7.2,
    "apartments": 10.0,
    "office": 9.3,
    "school": 7.2,
    "university": 10.0,
    "retail": 4.2,
    "industrial": 5.5,
    "warehouse": 5.5,
    "yes": 6.2,
}


def building_height(tags: dict[str, str]) -> tuple[float, str]:
    explicit = parse_distance(tags.get("height"))
    if explicit is not None:
        return round(max(2.8, min(explicit, 45.0)), 2), "osm:height"
    try:
        levels = float(tags.get("building:levels", ""))
        if 1.0 <= levels <= 15.0:
            return round(levels * 3.1, 2), "estimated:building-levels"
    except ValueError:
        pass
    building_type = tags.get("building", "")
    default_height = DEFAULT_BUILDING_HEIGHTS.get(building_type, 6.2)
    source = f"estimated:{building_type}-default" if building_type in DEFAULT_BUILDING_HEIGHTS else "estimated:building-type-default"
    return default_height, source


def compact_tags(raw: dict[str, str]) -> dict[str, str]:
    return {key: str(raw[key]) for key in SELECTED_TAGS if key in raw}


def fetch_overpass(query: str) -> dict:
    body = urlencode({"data": query}).encode("utf-8")
    failures: list[str] = []
    for endpoint in ENDPOINTS:
        for attempt in range(2):
            request = Request(
                endpoint,
                data=body,
                headers={
                    "User-Agent": USER_AGENT,
                    "Content-Type": "application/x-www-form-urlencoded; charset=utf-8",
                    "Accept": "application/json",
                },
                method="POST",
            )
            try:
                with urlopen(request, timeout=100) as response:
                    payload = json.loads(response.read().decode("utf-8"))
                if not isinstance(payload.get("elements"), list):
                    raise ValueError("Overpass response has no elements array")
                return payload
            except (HTTPError, URLError, TimeoutError, ValueError, json.JSONDecodeError) as exc:
                failures.append(f"{endpoint} attempt {attempt + 1}: {exc}")
                time.sleep(2 + attempt * 3)
    raise RuntimeError("All Overpass endpoints failed:\\n" + "\\n".join(failures))


def normalize(payload: dict) -> dict:
    roads: list[dict] = []
    buildings: list[dict] = []
    barriers: list[dict] = []
    for element in payload.get("elements", []):
        if element.get("type") != "way":
            continue
        raw_geometry = element.get("geometry") or []
        if len(raw_geometry) < 2:
            continue
        tags = element.get("tags") or {}
        geometry = [
            local_coordinates(float(point["lat"]), float(point["lon"]))
            for point in raw_geometry
            if "lat" in point and "lon" in point
        ]
        if len(geometry) < 2:
            continue
        way_id = str(element.get("id", ""))
        selected = compact_tags(tags)
        if "highway" in tags:
            width, width_source = road_width(tags)
            roads.append({
                "id": way_id,
                "name": tags.get("name", ""),
                "highway": tags["highway"],
                "surface": tags.get("surface", "unknown"),
                "width_m": width,
                "width_source": width_source,
                "oneway": tags.get("oneway", "no"),
                "tags": selected,
                "coordinates": geometry,
            })
        if "barrier" in tags:
            barriers.append({
                "id": way_id,
                "barrier": tags["barrier"],
                "name": tags.get("name", ""),
                "tags": selected,
                "coordinates": geometry,
            })
        if "building" in tags and len(geometry) >= 4 and geometry[0] == geometry[-1]:
            height, height_source = building_height(tags)
            try:
                levels = int(float(tags.get("building:levels", "0")))
            except ValueError:
                levels = 0
            buildings.append({
                "id": way_id,
                "building": tags.get("building", "yes"),
                "name": tags.get("name", ""),
                "shop": tags.get("shop", ""),
                "amenity": tags.get("amenity", ""),
                "levels": max(0, levels),
                "height_m": height,
                "height_source": height_source,
                "roof_shape": tags.get("roof:shape", "flat"),
                "tags": selected,
                "outline": geometry,
            })

    if not roads:
        raise RuntimeError("The OSM extract contains no road ways inside the configured Yaba bounds.")
    if not buildings:
        raise RuntimeError("The OSM extract contains no closed building footprints inside the configured Yaba bounds.")

    return {
        "schema_version": 1,
        "source": "OpenStreetMap",
        "attribution": "© OpenStreetMap contributors",
        "license": "ODbL-1.0",
        "source_url": "https://www.openstreetmap.org/",
        "extracted_at": datetime.now(timezone.utc).isoformat(),
        "center": {"latitude": CENTER_LAT, "longitude": CENTER_LON},
        "bounds": BOUNDS,
        "coordinate_system": "local metres; X east, Z south; origin at Yaba place node near Tejuosho Market",
        "counts": {"roads": len(roads), "buildings": len(buildings), "barriers": len(barriers)},
        "roads": roads,
        "buildings": buildings,
        "barriers": barriers,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "assets" / "data" / "yaba_osm.json")
    args = parser.parse_args()

    query = QUERY_PATH.read_text(encoding="utf-8")
    payload = fetch_overpass(query)
    normalized = normalize(payload)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix(args.output.suffix + ".tmp")
    temporary.write_text(json.dumps(normalized, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    temporary.replace(args.output)
    print(
        f"Imported {normalized['counts']['roads']} roads and "
        f"{normalized['counts']['buildings']} building footprints into {args.output}"
    )
    print(f"Imported {normalized['counts']['barriers']} mapped fence/wall ways.")
    print("Source: © OpenStreetMap contributors | License: ODbL-1.0")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # fail CI clearly; do not produce a partial map
        print(f"Yaba OSM import failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
