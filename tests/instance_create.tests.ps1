$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$cliRoot = Split-Path -Parent $PSScriptRoot
$commandScript = Join-Path $cliRoot "instance_create.ps1"
$instanceRoot = Split-Path -Parent $cliRoot
$temporaryRoot = Join-Path $instanceRoot "_tmp"

if (-not (Test-Path -LiteralPath $temporaryRoot -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $temporaryRoot)
}

$instanceName = "zemi-cli-instance-create-" + [guid]::NewGuid().ToString("N")
$testRoot = Join-Path $temporaryRoot $instanceName

try {
    & $commandScript `
        -InstanceName $instanceName `
        -TargetPath $testRoot `
        -Yes

    $workspacePath = Join-Path $testRoot ($instanceName + ".code-workspace")
    if (-not (Test-Path -LiteralPath $workspacePath -PathType Leaf)) {
        throw "Instance creation did not create its empty VS Code workspace."
    }

    $workspace = Get-Content -LiteralPath $workspacePath -Raw -Encoding UTF8 |
        ConvertFrom-Json
    if ($workspace -isnot [PSCustomObject]) {
        throw "The Instance workspace does not contain a JSON object."
    }
    if ($workspace.folders -isnot [array] -or $workspace.folders.Count -ne 0) {
        throw "The new Instance workspace folders property is not an empty array."
    }
    if ($workspace.settings -isnot [PSCustomObject] -or
        @($workspace.settings.PSObject.Properties).Count -ne 0) {
        throw "The new Instance workspace settings property is not an empty object."
    }

    Write-Host "[OK] instance create tests passed." -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
