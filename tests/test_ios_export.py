from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


class IosExportTests(unittest.TestCase):
    def test_descriptor_retains_the_complete_platform_matrix(self) -> None:
        descriptor = (
            ROOT
            / "demo/addons/airwindohhs_godot/airwindohhs_godot.gdextension.in"
        ).read_text()
        library_block = descriptor.split("[libraries]", 1)[1].split(
            "[dependencies]", 1
        )[0]
        entries = re.findall(
            r'^([a-z0-9_.]+)\s*=\s*"([^"]+)"$', library_block, re.MULTILINE
        )
        keys = [key for key, _ in entries]

        self.assertEqual(
            len(keys), len(set(keys)), "descriptor library keys must be unique"
        )
        self.assertEqual(
            {
                "macos.debug",
                "macos.release",
                "ios.debug",
                "ios.release",
                "linux.debug.x86_64",
                "linux.release.x86_64",
                "windows.debug.x86_64",
                "windows.release.x86_64",
                "android.debug.arm64",
                "android.release.arm64",
                "android.debug.x86_64",
                "android.release.x86_64",
            },
            set(keys),
        )
        self.assertNotRegex(descriptor, r"airwindohhs_godot\.ios\..+\.dylib")
        self.assertNotIn("<<<<<<<", descriptor)
        self.assertNotIn(">>>>>>>", descriptor)

    def test_descriptor_packages_ios_xcframeworks(self) -> None:
        descriptor = (
            ROOT
            / "demo/addons/airwindohhs_godot/airwindohhs_godot.gdextension.in"
        ).read_text()

        for target in ("template_debug", "template_release"):
            self.assertIn(
                f'libairwindohhs_godot.ios.{target}.xcframework', descriptor
            )
            self.assertIn(f'libgodot-cpp.ios.{target}.xcframework', descriptor)
        self.assertIn("[dependencies]", descriptor)

    def test_ios_build_is_static_and_hides_peer_symbols(self) -> None:
        cmake = (ROOT / "CMakeLists.txt").read_text()

        self.assertIn('CMAKE_SYSTEM_NAME STREQUAL "iOS"', cmake)
        self.assertIn("add_library(airwindohhs_godot STATIC", cmake)
        self.assertIn("CXX_VISIBILITY_PRESET hidden", cmake)
        self.assertIn("VISIBILITY_INLINES_HIDDEN YES", cmake)
        self.assertIn("-create-xcframework", cmake)

    def test_cmake_combines_android_ios_and_desktop_output_rules(self) -> None:
        cmake = (ROOT / "CMakeLists.txt").read_text()

        self.assertIn("if(ANDROID)", cmake)
        self.assertIn('elseif(CMAKE_SYSTEM_NAME STREQUAL "iOS")', cmake)
        for abi, suffix in (
            ("arm64-v8a", ".arm64"),
            ("armeabi-v7a", ".arm32"),
            ("x86_64", ".x86_64"),
            ("x86", ".x86_32"),
        ):
            self.assertIn(f'_abi STREQUAL "{abi}"', cmake)
            self.assertIn(f'set(_arch_suffix "{suffix}")', cmake)
        self.assertIn('LIBRARY_OUTPUT_DIRECTORY "$<1:${_addon_bin}>"', cmake)
        self.assertIn('RUNTIME_OUTPUT_DIRECTORY "$<1:${_addon_bin}>"', cmake)
        self.assertIn("${_arch_suffix}", cmake)
        self.assertNotIn("<<<<<<<", cmake)
        self.assertNotIn(">>>>>>>", cmake)


if __name__ == "__main__":
    unittest.main()
