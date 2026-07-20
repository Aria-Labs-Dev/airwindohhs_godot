# Locates Python (see ci/common.ps1) and forwards all arguments to
# ci/package_addon.py. Lets the packaging step run on agents where python is
# not on the service's PATH.
param(
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$python = Find-Python
Write-Host "Using Python: $python"
& $python (Join-Path $PSScriptRoot "package_addon.py") @Arguments
exit $LASTEXITCODE
