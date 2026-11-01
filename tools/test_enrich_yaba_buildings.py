import sqlite3
import sys
import tempfile
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


    def test_lookup_joins_only_osm_source_rows(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            gpkg = Path(temp_dir) / "test.gpkg"
            db = sqlite3.connect(gpkg)
            db.execute("CREATE TABLE building (id INTEGER, height TEXT, occupancy TEXT, source_id INTEGER)")
            db.executemany("INSERT INTO building VALUES (?, ?, ?, ?)", [
                (123, "H:3", "RES2", 0),
                (124, "H:4", "COM1", 1),
            ])
            db.commit()
            db.close()
            records = enrichment.lookup(gpkg, [123, 124])
            self.assertEqual(records, {123: ("H:3", "RES2")})

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
