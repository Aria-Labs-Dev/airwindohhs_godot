#!/usr/bin/env bash
# Cross-compiles the iOS (device, arm64) debug + release libraries.
# Requirements on the agent: Xcode with the iOS SDK, CMake >= 3.24,
# Python 3.9+, git.
# Godot 4.2+ wraps the produced dylibs into frameworks at export time; add an
# xcframework step here if simulator slices are ever needed.
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-12.0}"

for config in Debug Release; do
    build_dir="$SOURCE_DIR/build-ios-$(echo "$config" | tr '[:upper:]' '[:lower:]')"
    cmake -S "$SOURCE_DIR" -B "$build_dir" \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" \
        -DCMAKE_BUILD_TYPE="$config" \
        -DAIRWINDOHHS_GODOT_BUILD_TESTS=OFF
    cmake --build "$build_dir" --parallel --target airwindohhs_godot
done
