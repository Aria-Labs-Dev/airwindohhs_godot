import re
import unittest
from pathlib import Path


class DemoActivationTests(unittest.TestCase):
    def test_active_descriptor_never_points_at_a_missing_macos_library(self):
        root = Path(__file__).resolve().parents[1]
        addon = root / "demo" / "addons" / "airwindohhs_godot"
        template = addon / "airwindohhs_godot.gdextension.in"
        active = addon / "airwindohhs_godot.gdextension"

        self.assertTrue(template.exists(), "the build must retain a descriptor template")
        if not active.exists():
            return

        source = active.read_text(encoding="utf-8")
        match = re.search(r'macos\.debug\s*=\s*"res://addons/airwindohhs_godot/(.+)"', source)
        self.assertIsNotNone(match, "active descriptor has no macOS debug library")
        self.assertTrue(
            (addon / match.group(1)).exists(),
            "active descriptor points to a missing library; Godot 4.6.1 aborts in NSBundle",
        )


if __name__ == "__main__":
    unittest.main()
