from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[1]
PACKAGER = ROOT / "ci/package_addon.py"
ARCHIVE_ROOT = "addons/airwindohhs_godot/bin"


class PackageAddonTests(unittest.TestCase):
    def _run_packager(
        self, bin_dir: Path, output: Path, platforms: str
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(PACKAGER),
                "--bin-dir",
                str(bin_dir),
                "--output",
                str(output),
                "--platforms",
                platforms,
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    @staticmethod
    def _create_xcframework(bin_dir: Path, name: str) -> None:
        framework = bin_dir / name
        library_dir = framework / "ios-arm64"
        library_dir.mkdir(parents=True)
        (framework / "Info.plist").write_text("plist")
        (library_dir / f"{name.removesuffix('.xcframework')}.a").write_bytes(b"archive")

    def test_packages_ios_xcframeworks_and_dependencies(self) -> None:
        names = [
            f"lib{library}.ios.{target}.xcframework"
            for library in ("airwindohhs_godot", "godot-cpp")
            for target in ("template_debug", "template_release")
        ]
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            bin_dir = temp / "bin"
            output = temp / "dist/addon.zip"
            for name in names:
                self._create_xcframework(bin_dir, name)

            result = self._run_packager(bin_dir, output, "ios")

            self.assertEqual(0, result.returncode, result.stderr)
            with zipfile.ZipFile(output) as archive:
                archived = set(archive.namelist())
            for name in names:
                self.assertIn(f"{ARCHIVE_ROOT}/{name}/Info.plist", archived)
                self.assertTrue(
                    any(
                        path.startswith(f"{ARCHIVE_ROOT}/{name}/ios-arm64/")
                        for path in archived
                    )
                )

    def test_missing_ios_dependency_fails_packaging(self) -> None:
        missing = "libgodot-cpp.ios.template_release.xcframework"
        names = [
            "libairwindohhs_godot.ios.template_debug.xcframework",
            "libairwindohhs_godot.ios.template_release.xcframework",
            "libgodot-cpp.ios.template_debug.xcframework",
        ]
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            bin_dir = temp / "bin"
            output = temp / "dist/addon.zip"
            for name in names:
                self._create_xcframework(bin_dir, name)

            result = self._run_packager(bin_dir, output, "ios")

            self.assertNotEqual(0, result.returncode)
            self.assertIn(missing, result.stderr)

    def test_packages_existing_file_based_platform_artifacts(self) -> None:
        names = [
            "libairwindohhs_godot.macos.template_debug.dylib",
            "libairwindohhs_godot.macos.template_release.dylib",
            "airwindohhs_godot.windows.template_debug.dll",
            "airwindohhs_godot.windows.template_release.dll",
            "libairwindohhs_godot.linux.template_debug.so",
            "libairwindohhs_godot.linux.template_release.so",
            "libairwindohhs_godot.android.template_debug.arm64.so",
            "libairwindohhs_godot.android.template_release.arm64.so",
            "libairwindohhs_godot.android.template_debug.x86_64.so",
            "libairwindohhs_godot.android.template_release.x86_64.so",
        ]
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            bin_dir = temp / "bin"
            bin_dir.mkdir()
            output = temp / "dist/addon.zip"
            for name in names:
                (bin_dir / name).write_bytes(b"library")

            result = self._run_packager(bin_dir, output, "macos,windows,android")

            self.assertEqual(0, result.returncode, result.stderr)
            with zipfile.ZipFile(output) as archive:
                archived = set(archive.namelist())
            for name in names:
                self.assertIn(f"{ARCHIVE_ROOT}/{name}", archived)


if __name__ == "__main__":
    unittest.main()
