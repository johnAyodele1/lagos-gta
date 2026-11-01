import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import enrich_yaba_buildings as enrichment


class OpenBuildingMapEnrichmentTests(unittest.TestCase):
    def test_yaba_center_resolves_to_expected_zoom_six_tile(self):
        self.assertEqual(enrichment.quadkey_for(6.51147, 3.37000, 6), "122220")

    def test_exact_height_in_metres_takes_precedence(self):
        self.assertEqual(enrichment.parse_height_taxonomy("H:2+HHT:8.4"), (8.4, "HHT", None))

    def test_exact_story_count_is_converted_to_metres(self):
        self.assertEqual(enrichment.parse_height_taxonomy("H:3"), (9.3, "H", 3.0))

    def test_approximate_story_range_uses_midpoint(self):
        self.assertEqual(enrichment.parse_height_taxonomy("HBET:2-4"), (9.3, "HBET", 3.0))

    def test_unknown_or_invalid_height_is_not_guessed(self):
        self.assertEqual(enrichment.parse_height_taxonomy("UNK"), (None, None, None))
        self.assertEqual(enrichment.parse_height_taxonomy("H:0"), (None, None, None))

    def test_parquet_rows_match_only_requested_osm_source_ids(self):
        rows = [
            (123, "H:3", "RES2", "OSM"),
            (124, "H:4", "COM1", "Google"),
            (999, "H:2", "RES1", "OSM"),
        ]
        self.assertEqual(
            enrichment.records_from_rows(rows, [123, 124]),
            {123: ("H:3", "RES2")},
        )

    def test_explicit_osm_height_is_not_overwritten(self):
        data = {"buildings": [{
            "id": "123", "height_m": 12.0, "height_source": "osm:height", "levels": 4
        }]}
        counts = enrichment.enrich(data, {123: ("H:2", "RES2")}, "122220")
        self.assertEqual(data["buildings"][0]["height_m"], 12.0)
        self.assertEqual(data["buildings"][0]["height_source"], "osm:height")
        self.assertEqual(data["buildings"][0]["occupancy"], "RES2")
        self.assertEqual(counts["height_enriched"], 0)
        self.assertEqual(counts["occupancy_enriched"], 1)


if __name__ == "__main__":
    unittest.main()
