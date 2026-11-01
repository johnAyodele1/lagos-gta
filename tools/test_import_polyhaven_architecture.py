import sys
import tempfile
import unittest
import zipfile
from unittest.mock import patch
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import import_polyhaven_architecture as importer


class PolyHavenImporterTests(unittest.TestCase):
    def test_collect_downloads_keeps_nested_gltf_metadata(self):
        payload = {
            "gltf": {
                "2k": {
                    "zip": {
                        "url": "https://example.invalid/model.zip",
                        "size": 1234,
                        "md5": "abc123",
                    }
                }
            }
        }
        result = importer.collect_downloads(payload)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["path"], "gltf/2k/zip")
        self.assertEqual(result[0]["size"], 1234)


    def test_external_gltf_texture_is_resolved_from_api_manifest(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            scene_path = Path(temp_dir) / "source.gltf"
            scene_path.write_text(
                '{"images":[{"uri":"textures/facade_diffuse.jpg"}],"buffers":[]}',
                encoding="utf-8",
            )
            manifest = {
                "textures": {
                    "2k": {
                        "diffuse": {
                            "url": "https://example.invalid/facade_diffuse.jpg",
                            "size": 7,
                        }
                    }
                }
            }
            with patch.object(importer, "request_bytes", return_value=b"texture"):
                importer.resolve_gltf_dependencies(scene_path, manifest)
            self.assertEqual((Path(temp_dir) / "textures/facade_diffuse.jpg").read_bytes(), b"texture")

    def test_safe_extract_rejects_path_traversal(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            archive = root / "unsafe.zip"
            with zipfile.ZipFile(archive, "w") as zipped:
                zipped.writestr("../../outside.txt", "not allowed")
            with self.assertRaises(RuntimeError):
                importer.safe_extract(archive, root / "out")

    def test_safe_extract_extracts_valid_files(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            archive = root / "safe.zip"
            with zipfile.ZipFile(archive, "w") as zipped:
                zipped.writestr("scene/model.gltf", "{}")
            destination = root / "out"
            destination.mkdir()
            importer.safe_extract(archive, destination)
            self.assertTrue((destination / "scene/model.gltf").is_file())


if __name__ == "__main__":
    unittest.main()
