# Cross-compiles the Android debug + release libraries for each requested ABI.
# Requirements on the agent: Android NDK (ANDROID_NDK_ROOT or ANDROID_NDK_HOME,
# or an SDK at ANDROID_HOME / %LOCALAPPDATA%\Android\Sdk with an ndk\ dir),
# CMake >= 3.24, Ninja (on PATH or bundled with the SDK's cmake package),
# Python 3.9+, git.
param(
    [string]$SourceDir = (Split-Path $PSScriptRoot -Parent),
    [string[]]$Abis = @("arm64-v8a", "x86_64"),
    [string]$AndroidPlatform = "android-21"
)
$ErrorActionPreference = "Stop"

function Find-Ndk {
    foreach ($candidate in @($env:ANDROID_NDK_ROOT, $env:ANDROID_NDK_HOME)) {
        if ($candidate -and (Test-Path "$candidate\build\cmake\android.toolchain.cmake")) {
            return $candidate
        }
    }
    foreach ($sdk in @($env:ANDROID_HOME, "$env:LOCALAPPDATA\Android\Sdk")) {
        if (-not $sdk) { continue }
        $newest = Get-ChildItem "$sdk\ndk" -Directory -ErrorAction SilentlyContinue |
            Sort-Object { [version]($_.Name -replace '[^\d.].*$', '') } |
            Select-Object -Last 1
        if ($newest -and (Test-Path "$($newest.FullName)\build\cmake\android.toolchain.cmake")) {
            return $newest.FullName
        }
    }
    throw "Android NDK not found. Set ANDROID_NDK_ROOT."
}

function Find-Ninja {
    $onPath = Get-Command ninja -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    foreach ($sdk in @($env:ANDROID_HOME, "$env:LOCALAPPDATA\Android\Sdk")) {
        if (-not $sdk) { continue }
        $bundled = Get-ChildItem "$sdk\cmake\*\bin\ninja.exe" -ErrorAction SilentlyContinue |
            Select-Object -Last 1
        if ($bundled) { return $bundled.FullName }
    }
    throw "Ninja not found. Install it or add the Android SDK cmake package."
}

$ndk = Find-Ndk
$ninja = Find-Ninja
Write-Host "Using NDK: $ndk"
Write-Host "Using Ninja: $ninja"

foreach ($abi in $Abis) {
    foreach ($config in @("Debug", "Release")) {
        $buildDir = Join-Path $SourceDir "build-android-$abi-$($config.ToLower())"
        cmake -S $SourceDir -B $buildDir -G Ninja `
            "-DCMAKE_TOOLCHAIN_FILE=$ndk\build\cmake\android.toolchain.cmake" `
            "-DCMAKE_MAKE_PROGRAM=$ninja" `
            "-DANDROID_ABI=$abi" `
            "-DANDROID_PLATFORM=$AndroidPlatform" `
            "-DCMAKE_BUILD_TYPE=$config" `
            "-DAIRWINDOHHS_GODOT_BUILD_TESTS=OFF"
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        cmake --build $buildDir --parallel --target airwindohhs_godot
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
}
