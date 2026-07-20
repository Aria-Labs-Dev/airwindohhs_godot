# Shared tool discovery for the macOS/iOS CI scripts. Agent daemons often run
# with a minimal PATH that misses Homebrew, so cmake is located by search too.
# Pin it explicitly with CMAKE_PATH if needed.
# Source this file; it defines functions only.

find_cmake() {
    if [[ -n "${CMAKE_PATH:-}" ]]; then
        if [[ -x "$CMAKE_PATH" ]]; then
            echo "$CMAKE_PATH"
            return 0
        fi
        echo "CMAKE_PATH=$CMAKE_PATH is not executable" >&2
        return 1
    fi
    local candidate
    for candidate in \
        "$(command -v cmake || true)" \
        /opt/homebrew/bin/cmake \
        /usr/local/bin/cmake \
        "/Applications/CMake.app/Contents/bin/cmake"; do
        if [[ -n "$candidate" && -x "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    echo "CMake not found. Install it (brew install cmake) or set CMAKE_PATH." >&2
    return 1
}

# ctest ships in the same bin directory as cmake.
find_ctest() {
    local cmake_path="$1"
    local ctest_path
    ctest_path="$(dirname "$cmake_path")/ctest"
    if [[ -x "$ctest_path" ]]; then
        echo "$ctest_path"
        return 0
    fi
    echo "No ctest next to $cmake_path." >&2
    return 1
}
