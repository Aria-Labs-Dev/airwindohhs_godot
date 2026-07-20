# Runs the test suite against a build directory produced by
# ci/build_windows.ps1. The smoke test only runs if GODOT_EXECUTABLE was set
# when that build was configured.
param(
    [string]$BuildDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "build-windows"),
    [string]$Config = "Debug"
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

if (-not (Test-Path "$BuildDir\CTestTestfile.cmake")) {
    throw "$BuildDir is not a configured build directory; run ci/build_windows.ps1 first."
}

$ctest = Find-Ctest -Cmake (Find-Cmake)
Write-Host "Using CTest: $ctest"

& $ctest --test-dir $BuildDir -C $Config --output-on-failure
exit $LASTEXITCODE
