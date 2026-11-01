"""Offline tests for the Yaba OpenStreetMap normalization pipeline."""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fetch_yaba_osm as osm


class YabaOsmImportTests(unittest.TestCase):
    def test_origin_projects_to_zero(self):
        self.assertEqual(osm.local_coordinates(osm.CENTER_LAT, osm.CENTER_LON), [0.0, 0.0])

    def test_longitude_projects_east_and_latitude_projects_north(self):
        east = osm.local_coordinates(osm.CENTER_LAT, osm.CENTER_LON + 0.001)
        north = osm.local_coordinates(osm.CENTER_LAT + 0.001, osm.CENTER_LON)
        self.assertGreater(east[0], 0.0)
        self.assertLess(north[1], 0.0)

    def test_explicit_road_width_is_preferred(self):
        self.assertEqual(osm.road_width({"highway": "residential", "width": "8 m"}), (8.0, "osm:width"))

    def test_lane_count_has_documented_fallback(self):
        self.assertEqual(osm.road_width({"highway": "residential", "lanes": "2"}), (7.4, "estimated:lanes"))

    def test_highway_class_has_documented_fallback(self):
        self.assertEqual(osm.road_width({"highway": "residential"}), (6.0, "estimated:highway-default"))

    def test_building_height_prefers_explicit_height_then_levels(self):
        self.assertEqual(osm.building_height({"height": "12 ft"}), (3.66, "osm:height"))
        self.assertEqual(osm.building_height({"building:levels": "3"}), (9.3, "estimated:building-levels"))

    def test_normalize_preserves_roads_buildings_and_barriers(self):
        payload = {
            "elements": [
                {
                    "type": "way",
                    "id": 100,
                    "tags": {"highway": "residential", "name": "Hughes Avenue", "lanes": "2"},
                    "geometry": [
                        {"lat": 6.51147, "lon": 3.37000},
                        {"lat": 6.51147, "lon": 3.37100},
                    ],
                },
                {
                    "type": "way",
                    "id": 200,
                    "tags": {"building": "residential", "building:levels": "2"},
                    "geometry": [
                        {"lat": 6.51100, "lon": 3.36900},
                        {"lat": 6.51100, "lon": 3.36910},
                        {"lat": 6.51110, "lon": 3.36910},
                        {"lat": 6.51110, "lon": 3.36900},
                        {"lat": 6.51100, "lon": 3.36900},
                    ],
                },
                {
                    "type": "way",
                    "id": 300,
                    "tags": {"barrier": "fence"},
                    "geometry": [
                        {"lat": 6.51100, "lon": 3.36800},
                        {"lat": 6.51110, "lon": 3.36800},
                    ],
                },
            ]
        }
        result = osm.normalize(payload)
        self.assertEqual(result["counts"], {"roads": 1, "buildings": 1, "barriers": 1})
        self.assertEqual(result["roads"][0]["name"], "Hughes Avenue")
        self.assertEqual(result["buildings"][0]["height_m"], 6.2)
        self.assertEqual(result["barriers"][0]["barrier"], "fence")
        self.assertEqual(result["license"], "ODbL-1.0")

    def test_normalize_rejects_incomplete_extract(self):
        with self.assertRaises(RuntimeError):
            osm.normalize({"elements": []})


if __name__ == "__main__":
    unittest.main()
