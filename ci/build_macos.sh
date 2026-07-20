#!/usr/bin/env bash
# Builds the macOS universal (arm64 + x86_64) debug + release libraries plus
# the debug test executables. Run ci/test_macos.sh afterwards to execute the
# test suite.
# Requirements on the agent: Xcode command line tools, CMake >= 3.24,
# Python 3.9+, git. CMake is auto-discovered (see ci/common.sh); pin it with
# CMAKE_PATH if needed. Optionally set GODOT_EXECUTABLE to a Godot 4.6+ binary
# to register the headless smoke test.
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SOURCE_DIR/ci/common.sh"

CMAKE="$(find_cmake)"
echo "Using CMake: $CMAKE"

# Debug builds everything so the test step has its executables; release only
# needs the shipping library.
for config in Debug Release; do
    build_dir="$SOURCE_DIR/build-macos-$(echo "$config" | tr '[:upper:]' '[:lower:]')"
    "$CMAKE" -S "$SOURCE_DIR" -B "$build_dir" \
        -DCMAKE_BUILD_TYPE="$config" \
        -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
        ${GODOT_EXECUTABLE:+-DAIRWINDOHHS_GODOT_GODOT_EXECUTABLE="$GODOT_EXECUTABLE"}
    if [[ "$config" == "Debug" ]]; then
        "$CMAKE" --build "$build_dir" --parallel
    else
        "$CMAKE" --build "$build_dir" --parallel --target airwindohhs_godot
    fi
done
