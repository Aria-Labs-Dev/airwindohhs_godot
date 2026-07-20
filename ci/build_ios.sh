#!/usr/bin/env bash
# Cross-compiles the iOS (device, arm64) debug + release libraries.
# Requirements on the agent: Xcode with the iOS SDK, CMake >= 3.24,
# Python 3.9+, git.
# Produces device-only arm64 XCFrameworks for the extension and godot-cpp.
# Simulator support would require additional slices.
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SOURCE_DIR/ci/common.sh"
IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-12.0}"

CMAKE="$(find_cmake)"
echo "Using CMake: $CMAKE"

# Resolve the SDK to a real path; letting CMake pass the bare name 'iphoneos'
# fails when the active developer directory cannot supply the iOS SDK.
if [[ -z "${IOS_SDK:-}" ]]; then
    if ! IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)" || [[ ! -d "$IOS_SDK" ]]; then
        echo "Could not resolve the iphoneos SDK ($(xcode-select -p 2>/dev/null || echo 'no developer dir'))." >&2
        echo "Point xcode-select at a full Xcode: sudo xcode-select -s /Applications/Xcode.app" >&2
        echo "or set DEVELOPER_DIR / IOS_SDK explicitly." >&2
        exit 1
    fi
fi
echo "Using iOS SDK: $IOS_SDK"

for config in Debug Release; do
    build_dir="$SOURCE_DIR/build-ios-$(echo "$config" | tr '[:upper:]' '[:lower:]')"
    "$CMAKE" -S "$SOURCE_DIR" -B "$build_dir" \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_SYSROOT="$IOS_SDK" \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" \
        -DCMAKE_BUILD_TYPE="$config" \
        -DAIRWINDOHHS_GODOT_BUILD_TESTS=OFF
    "$CMAKE" --build "$build_dir" --parallel --target airwindohhs_godot
done
