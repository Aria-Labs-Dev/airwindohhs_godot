# Builds the Windows x86_64 debug + release libraries plus the debug test
# executables. Run ci/test_windows.ps1 afterwards to execute the test suite.
# Requirements on the agent: Visual Studio 2022 (C++ workload), CMake >= 3.24,
# Python 3.9+, git. CMake and Python are auto-discovered (see ci/common.ps1);
# pin them with CMAKE_PATH / PYTHON_PATH if needed. Optionally set
# GODOT_EXECUTABLE to a Godot 4.6+ console binary to register the headless
# smoke test.
param(
    [string]$SourceDir = (Split-Path $PSScriptRoot -Parent),
    [string]$BuildDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "build-windows"),
    [string]$GodotExecutable = $env:GODOT_EXECUTABLE
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$cmake = Find-Cmake
$cmakeVersion = Assert-CmakeVersion $cmake
$python = Find-Python
Write-Host "Using CMake: $cmake ($cmakeVersion)"
Write-Host "Using Python: $python"

$configureArgs = @(
    "-S", $SourceDir,
    "-B", $BuildDir,
    "-G", "Visual Studio 17 2022",
    "-A", "x64",
    "-DPython3_EXECUTABLE=$python"
)
if ($GodotExecutable) {
    $configureArgs += "-DAIRWINDOHHS_GODOT_GODOT_EXECUTABLE=$($GodotExecutable -replace '\\', '/')"
}

& $cmake @configureArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Debug builds everything so the test step has its executables; release only
# needs the shipping library.
& $cmake --build $BuildDir --config Debug --parallel
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $cmake --build $BuildDir --config Release --target airwindohhs_godot --parallel
exit $LASTEXITCODE
