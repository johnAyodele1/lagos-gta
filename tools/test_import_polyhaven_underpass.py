import unittest
from tools.import_polyhaven_underpass import ASSETS,MAX,entries
class ImporterTests(unittest.TestCase):
 def test_curated_assets(self):
  self.assertEqual(len(ASSETS),4)
  self.assertIn("modular_factory_facade",ASSETS)
  self.assertIn("portable_generator",ASSETS)
 def test_recursive_manifest(self):
  got=entries({"gltf":{"1k":{"zip":{"url":"https://x/a.zip","size":5}}}})
  self.assertEqual(got[0]["path"],"gltf/1k/zip")
  self.assertEqual(got[0]["size"],5)
 def test_package_limit(self): self.assertEqual(MAX,90*1024*1024)
if __name__=="__main__": unittest.main()
