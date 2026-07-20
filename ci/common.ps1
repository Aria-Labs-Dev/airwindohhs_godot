# Shared tool discovery for the CI scripts. Build agents (especially service
# accounts) often lack the interactive user's PATH, so every tool can also be
# located by search or pinned via an environment variable:
#   ANDROID_NDK_ROOT / ANDROID_NDK_HOME, NINJA_PATH, CMAKE_PATH, PYTHON_PATH.
# Dot-source this file; it defines functions only.

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

function Find-Cmake {
    param([string]$NinjaPath)
    $rejected = @()
    if ($env:CMAKE_PATH) {
        $explicit = $env:CMAKE_PATH.Trim().Trim('"')
        if (Test-Path $explicit -PathType Leaf) { return $explicit }
        $rejected += "CMAKE_PATH=$explicit is not a file"
    } else {
        $rejected += "CMAKE_PATH is not set in this process's environment"
    }
    $onPath = Get-Command cmake -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    $rejected += "cmake is not on PATH"
    # The Android SDK cmake package ships cmake.exe next to ninja.exe.
    if ($NinjaPath) {
        $bundled = Join-Path (Split-Path $NinjaPath -Parent) "cmake.exe"
        if (Test-Path $bundled -PathType Leaf) { return $bundled }
        $rejected += "no cmake.exe next to $NinjaPath"
    }
    $standalone = "C:\Program Files\CMake\bin\cmake.exe"
    if (Test-Path $standalone -PathType Leaf) { return $standalone }
    $rejected += "no $standalone"
    throw ("CMake not found. Install it or set CMAKE_PATH to a cmake.exe. " +
        "Checked:`n  " + ($rejected -join "`n  "))
}

function Assert-CmakeVersion {
    param([string]$Cmake, [version]$Minimum = "3.24")
    $version = [version](((& $Cmake --version) | Select-Object -First 1) `
        -replace '[^\d]*(\d+\.\d+\.\d+).*', '$1')
    if ($version -lt $Minimum) {
        throw "CMake $version at $Cmake is too old; this project requires >= $Minimum."
    }
    return $version
}

# ctest ships in the same bin directory as cmake.
function Find-Ctest {
    param([Parameter(Mandatory)][string]$Cmake)
    $ctest = Join-Path (Split-Path $Cmake -Parent) "ctest.exe"
    if (Test-Path $ctest -PathType Leaf) { return $ctest }
    throw "No ctest.exe next to $Cmake."
}

# Runs a candidate interpreter and returns the real executable path, or $null.
# Store/app-execution aliases are zero-byte shims, so candidates must be
# executed, not just stat'ed.
function Resolve-Python {
    param([string]$Candidate)
    try {
        $resolved = & $Candidate -c "import sys; print(sys.executable)" 2>$null
        if ($LASTEXITCODE -eq 0 -and $resolved) { return "$resolved".Trim() }
    } catch {}
    return $null
}

function Find-Python {
    $rejected = @()
    if ($env:PYTHON_PATH) {
        $explicit = $env:PYTHON_PATH.Trim().Trim('"')
        $resolved = Resolve-Python $explicit
        if ($resolved) { return $resolved }
        $rejected += "PYTHON_PATH=$explicit did not run"
    } else {
        $rejected += "PYTHON_PATH is not set in this process's environment"
    }
    foreach ($name in @("python", "py")) {
        $onPath = Get-Command $name -ErrorAction SilentlyContinue
        if ($onPath) {
            $resolved = Resolve-Python $onPath.Source
            if ($resolved) { return $resolved }
        }
        $rejected += "$name is not on PATH (or did not run)"
    }
    $userRoots = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { $_.FullName }
    $globs = @("$env:ProgramFiles\Python3*\python.exe") +
        ($userRoots | ForEach-Object { @(
            "$_\AppData\Local\Programs\Python\Python3*\python.exe",
            "$_\AppData\Local\Python\pythoncore-3*\python.exe") })
    foreach ($glob in $globs) {
        $found = Get-ChildItem $glob -ErrorAction SilentlyContinue |
            Sort-Object FullName | Select-Object -Last 1
        if ($found) {
            $resolved = Resolve-Python $found.FullName
            if ($resolved) { return $resolved }
        }
    }
    $rejected += "no runnable python.exe under $env:ProgramFiles or C:\Users\*\AppData\Local"
    throw ("Python not found. Install Python 3.9+ or set PYTHON_PATH to a " +
        "python.exe. Checked:`n  " + ($rejected -join "`n  "))
}
