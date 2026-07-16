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
    $rejected = @()
    foreach ($pair in @(
            @("ANDROID_NDK_ROOT", $env:ANDROID_NDK_ROOT),
            @("ANDROID_NDK_HOME", $env:ANDROID_NDK_HOME))) {
        $name, $candidate = $pair
        if (-not $candidate) {
            $rejected += "$name is not set in this process's environment"
            continue
        }
        $candidate = $candidate.Trim().Trim('"').TrimEnd('\', '/')
        if (Test-Path "$candidate\build\cmake\android.toolchain.cmake") {
            return $candidate
        }
        $rejected += "$name=$candidate has no build\cmake\android.toolchain.cmake"
    }
    foreach ($sdk in @($env:ANDROID_HOME, "$env:LOCALAPPDATA\Android\Sdk")) {
        if (-not $sdk) { continue }
        $newest = Get-ChildItem "$sdk\ndk" -Directory -ErrorAction SilentlyContinue |
            Sort-Object { [version]($_.Name -replace '[^\d.].*$', '') } |
            Select-Object -Last 1
        if (-not $newest) {
            $rejected += "no NDK directories under $sdk\ndk"
        } elseif (Test-Path "$($newest.FullName)\build\cmake\android.toolchain.cmake") {
            return $newest.FullName
        } else {
            $rejected += "$($newest.FullName) has no build\cmake\android.toolchain.cmake"
        }
    }
    throw ("Android NDK not found. Set ANDROID_NDK_ROOT. Checked:`n  " +
        ($rejected -join "`n  "))
}

function Find-Ninja {
    param([string]$NdkRoot)
    $rejected = @()
    if ($env:NINJA_PATH) {
        $explicit = $env:NINJA_PATH.Trim().Trim('"')
        if (Test-Path $explicit -PathType Leaf) { return $explicit }
        $rejected += "NINJA_PATH=$explicit is not a file"
    } else {
        $rejected += "NINJA_PATH is not set in this process's environment"
    }
    $onPath = Get-Command ninja -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    $rejected += "ninja is not on PATH"
    $sdkRoots = @($env:ANDROID_HOME, "$env:LOCALAPPDATA\Android\Sdk")
    if ($NdkRoot) {
        # NDKs installed through the SDK manager live at <sdk>\ndk\<version>,
        # and the SDK's optional cmake package bundles ninja.exe.
        $sdkRoots += Split-Path (Split-Path $NdkRoot -Parent) -Parent
    }
    foreach ($sdk in $sdkRoots) {
        if (-not $sdk) { continue }
        $bundled = Get-ChildItem "$sdk\cmake\*\bin\ninja.exe" -ErrorAction SilentlyContinue |
            Select-Object -Last 1
        if ($bundled) { return $bundled.FullName }
        $rejected += "no cmake\*\bin\ninja.exe under $sdk"
    }
    throw ("Ninja not found. Install it, add the Android SDK cmake package, " +
        "or set NINJA_PATH to a ninja.exe. Checked:`n  " + ($rejected -join "`n  "))
}

$ndk = Find-Ndk
$ninja = Find-Ninja -NdkRoot $ndk
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
