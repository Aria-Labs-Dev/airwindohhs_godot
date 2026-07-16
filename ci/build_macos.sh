#!/usr/bin/env bash
# Builds the macOS universal (arm64 + x86_64) debug + release libraries and
# runs the test suite.
# Requirements on the agent: Xcode command line tools, CMake >= 3.24,
# Python 3.9+, git. Optionally set GODOT_EXECUTABLE to a Godot 4.6+ binary to
# include the headless smoke test.
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for config in Debug Release; do
    build_dir="$SOURCE_DIR/build-macos-$(echo "$config" | tr '[:upper:]' '[:lower:]')"
    cmake -S "$SOURCE_DIR" -B "$build_dir" \
        -DCMAKE_BUILD_TYPE="$config" \
        -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
        ${GODOT_EXECUTABLE:+-DAIRWINDOHHS_GODOT_GODOT_EXECUTABLE="$GODOT_EXECUTABLE"}
    cmake --build "$build_dir" --parallel
done

ctest --test-dir "$SOURCE_DIR/build-macos-debug" --output-on-failure
