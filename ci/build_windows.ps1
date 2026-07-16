# Builds the Windows x86_64 debug + release libraries and runs the test suite.
# Requirements on the agent: Visual Studio 2022 (C++ workload), CMake >= 3.24,
# Python 3.9+, git. Optionally set GODOT_EXECUTABLE to a Godot 4.6+ console
# binary to include the headless smoke test.
param(
    [string]$SourceDir = (Split-Path $PSScriptRoot -Parent),
    [string]$BuildDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "build-windows"),
    [string]$GodotExecutable = $env:GODOT_EXECUTABLE
)
$ErrorActionPreference = "Stop"

$configureArgs = @(
    "-S", $SourceDir,
    "-B", $BuildDir,
    "-G", "Visual Studio 17 2022",
    "-A", "x64"
)
if ($GodotExecutable) {
    $configureArgs += "-DAIRWINDOHHS_GODOT_GODOT_EXECUTABLE=$($GodotExecutable -replace '\\', '/')"
}

cmake @configureArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

foreach ($config in @("Debug", "Release")) {
    cmake --build $BuildDir --config $config --parallel
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

ctest --test-dir $BuildDir -C Debug --output-on-failure
exit $LASTEXITCODE
