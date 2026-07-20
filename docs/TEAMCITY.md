# TeamCity release pipeline

Per-platform build configurations feed a final packaging configuration that
produces a single addon zip containing binaries for Windows, macOS, iOS, and
Android. All build logic lives in [`ci/`](../ci);
TeamCity steps are one-line script invocations so the pipeline is testable
locally and changes are code-reviewed.

## 1. `Build Windows + Android` (Windows agent)

Agent requirements: Visual Studio 2022 (C++ workload), CMake >= 3.24,
Python 3.9+, git, Android NDK, Ninja (standalone or the Android SDK `cmake`
package). Optional: `GODOT_EXECUTABLE` env pointing at a Godot console binary
to run the headless smoke test.

CMake, Python, Ninja, and the NDK are auto-discovered even when the agent
service's PATH lacks them (see `ci/common.ps1`); pin any of them with the
`env.CMAKE_PATH`, `env.PYTHON_PATH`, `env.NINJA_PATH`, or
`env.ANDROID_NDK_ROOT` TeamCity parameters.

Steps (PowerShell):

```
powershell -File ci/build_windows.ps1   # compile: windows libs + test executables
powershell -File ci/test_windows.ps1    # run the test suite (separate step)
powershell -File ci/build_android.ps1   # cross-compile android libs
```

Artifact paths:

```
demo/addons/airwindohhs_godot/bin/*.dll => bin
demo/addons/airwindohhs_godot/bin/*.so => bin
```

## 2. `Build macOS + iOS` (Mac agent)

Agent requirements: Xcode with the iOS SDK, CMake >= 3.24, Python 3.9+, git.
Optional: `GODOT_EXECUTABLE` for the smoke test.

CMake is auto-discovered even when the agent daemon's PATH misses Homebrew
(`/opt/homebrew/bin`, `/usr/local/bin`, and `CMake.app` are searched — see
`ci/common.sh`); pin it with an `env.CMAKE_PATH` TeamCity parameter if needed.

Steps (bash):

```
bash ci/build_macos.sh   # compile: macos libs + test executables
bash ci/test_macos.sh    # run the test suite (separate step)
bash ci/build_ios.sh     # cross-compile ios libs
```

Artifact paths:

```
demo/addons/airwindohhs_godot/bin/** => bin
```

## 3. `Package Addon` (any agent with Python 3.9+)

Depends on every platform build configuration, twice over:

- A **snapshot dependency** on each, so one packaging run corresponds to one
  VCS revision built consistently across all platforms.
- An **artifact dependency** on each, set to **"Build from the same chain"**
  (not "Last successful build" — that can mix revisions), with the rule:

```
bin/** => staging/bin
```

All platform libraries have distinct names, so they merge safely into one
`staging/bin` directory.

Step — on a Windows agent (auto-discovers Python via `ci/common.ps1`):

```
powershell -File ci/package_addon.ps1 --bin-dir staging/bin --output dist/airwindohhs_godot_addon.zip
```

or on a Mac agent:

```
python3 ci/package_addon.py --bin-dir staging/bin --output dist/airwindohhs_godot_addon.zip
```

Artifact path: `dist/airwindohhs_godot_addon.zip`.

Put the VCS trigger on this configuration; the snapshot dependencies pull the
four platform builds into the chain automatically. To stamp releases, add
`%build.number%` to the `--output` filename.

The packager copies the `.gdextension` descriptor, `generated/catalog.json`,
LICENSE, and THIRD_PARTY.md next to the binaries and XCFramework directories.
It fails the build if any library or dependency entry for a shipping platform
(`--platforms`, default windows,macos,ios,android) has no artifact. The zip
extracts as `addons/airwindohhs_godot/` directly into a Godot project root.

## Notes

- Debug and release template libraries are both built for every platform:
  editors and debug exports load `template_debug`, release exports load
  `template_release`.
- Android ships arm64 for devices plus x86_64 for emulator testing. Add ABIs
  by passing `-Abis` to `ci/build_android.ps1` — the descriptor and
  `CMakeLists.txt` arch map already cover arm32/x86_32 naming.
- iOS builds device-only arm64 XCFrameworks for the extension and `godot-cpp`,
  targeting iOS 12.0 by default. Set `IOS_DEPLOYMENT_TARGET` to override the
  minimum version. Simulator slices are not currently built.
- Each build directory fetches pinned `godot-cpp` and latest `airwindohhs`
  via FetchContent. To avoid re-cloning on every build, pre-clone on the agent
  and pass `-DAIRWINDOHHS_GODOT_GODOT_CPP_PATH=...` /
  `-DAIRWINDOHHS_GODOT_AIRWINDOHHS_PATH=...`, or keep build directories
  between runs (they are incremental).
- macOS dylibs are unsigned; for distribution outside the team, add
  codesigning/notarization to `ci/build_macos.sh`.
