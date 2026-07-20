#!/usr/bin/env bash
# Runs the test suite against the debug build directory produced by
# ci/build_macos.sh. The smoke test only runs if GODOT_EXECUTABLE was set when
# that build was configured.
# Usage: test_macos.sh [build-dir]
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SOURCE_DIR/ci/common.sh"

BUILD_DIR="${1:-$SOURCE_DIR/build-macos-debug}"

if [[ ! -f "$BUILD_DIR/CTestTestfile.cmake" ]]; then
    echo "$BUILD_DIR is not a configured build directory; run ci/build_macos.sh first." >&2
    exit 1
fi

CTEST="$(find_ctest "$(find_cmake)")"
echo "Using CTest: $CTEST"

"$CTEST" --test-dir "$BUILD_DIR" --output-on-failure
