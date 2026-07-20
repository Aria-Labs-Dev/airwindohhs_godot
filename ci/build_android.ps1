# Cross-compiles the Android debug + release libraries for each requested ABI.
# Requirements on the agent: Android NDK, CMake >= 3.24, Ninja, Python 3.9+,
# git. All tools are auto-discovered (see ci/common.ps1); pin them with
# ANDROID_NDK_ROOT, NINJA_PATH, CMAKE_PATH, or PYTHON_PATH if needed. The
# Android SDK's optional cmake package satisfies both the Ninja and CMake
# requirements.
param(
    [string]$SourceDir = (Split-Path $PSScriptRoot -Parent),
    [string[]]$Abis = @("arm64-v8a", "x86_64"),
    [string]$AndroidPlatform = "android-21"
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$ndk = Find-Ndk
$ninja = Find-Ninja -NdkRoot $ndk
$cmake = Find-Cmake -NinjaPath $ninja
$cmakeVersion = Assert-CmakeVersion $cmake
$python = Find-Python
Write-Host "Using NDK: $ndk"
Write-Host "Using Ninja: $ninja"
Write-Host "Using CMake: $cmake ($cmakeVersion)"
Write-Host "Using Python: $python"

foreach ($abi in $Abis) {
    foreach ($config in @("Debug", "Release")) {
        $buildDir = Join-Path $SourceDir "build-android-$abi-$($config.ToLower())"
        & $cmake -S $SourceDir -B $buildDir -G Ninja `
            "-DCMAKE_TOOLCHAIN_FILE=$ndk\build\cmake\android.toolchain.cmake" `
            "-DCMAKE_MAKE_PROGRAM=$ninja" `
            "-DANDROID_ABI=$abi" `
            "-DANDROID_PLATFORM=$AndroidPlatform" `
            "-DCMAKE_BUILD_TYPE=$config" `
            "-DPython3_EXECUTABLE=$python" `
            "-DAIRWINDOHHS_GODOT_BUILD_TESTS=OFF"
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $cmake --build $buildDir --parallel --target airwindohhs_godot
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
}
