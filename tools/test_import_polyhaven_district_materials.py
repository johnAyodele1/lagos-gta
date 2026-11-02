import unittest
from tools.import_polyhaven_district_materials import choose, flatten

class PolyHavenDistrictMaterialTests(unittest.TestCase):
    def test_prefers_1k_map(self):
        rows = [
            {"url": "https://cdn.example/road_2k.jpg", "size": 500, "path": "diffuse/2k/jpg"},
            {"url": "https://cdn.example/road_1k.jpg", "size": 200, "path": "diffuse/1k/jpg"},
        ]
        self.assertEqual(choose(rows, ("diffuse",))["size"], 200)

    def test_ignores_blend_package(self):
        rows = [{"url": "https://cdn.example/road.blend", "size": 10, "path": "diffuse/1k/blend"}]
        self.assertIsNone(choose(rows, ("diffuse",)))

    def test_flattens_nested_api_response(self):
        rows = flatten({"Diffuse": {"1k": {"jpg": {"url": "https://cdn.example/a.jpg", "size": 20}}}})
        self.assertEqual(rows[0]["path"], "diffuse/1k/jpg")

if __name__ == "__main__":
    unittest.main()
