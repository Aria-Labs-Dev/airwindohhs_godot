import json
import tempfile
import unittest
from pathlib import Path

from tools.generate_catalog import generate_catalog, scan_catalog


class CatalogGeneratorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.airwindohhs = Path(__file__).resolve().parents[2] / "airwindohhs"

    def test_scans_the_complete_local_catalog(self):
        effects = scan_catalog(self.airwindohhs)
        self.assertEqual(495, len(effects))
        self.assertEqual(len(effects), len({effect.godot_class for effect in effects}))
        self.assertTrue(all(effect.parameter_count <= 16 for effect in effects))

    def test_generation_is_deterministic_and_complete(self):
        with tempfile.TemporaryDirectory() as first_dir, tempfile.TemporaryDirectory() as second_dir:
            first = Path(first_dir)
            second = Path(second_dir)
            generate_catalog(self.airwindohhs, first, shard_count=16)
            generate_catalog(self.airwindohhs, second, shard_count=16)
            first_files = sorted(path.relative_to(first) for path in first.rglob("*") if path.is_file())
            second_files = sorted(path.relative_to(second) for path in second.rglob("*") if path.is_file())
            self.assertEqual(first_files, second_files)
            for relative in first_files:
                self.assertEqual((first / relative).read_bytes(), (second / relative).read_bytes())

            manifest = json.loads((first / "catalog.json").read_text())
            self.assertEqual(495, manifest["compatible_effect_count"])
            self.assertEqual(0, manifest["excluded_effect_count"])
            self.assertEqual(16, len(manifest["shards"]))
            self.assertEqual(495, len(manifest["effects"]))


if __name__ == "__main__":
    unittest.main()
