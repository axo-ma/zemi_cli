$ErrorActionPreference = "Stop"

$commandScript = Join-Path (Split-Path $PSScriptRoot -Parent) "instance_deploy_winpython.ps1"
$testRoot = Join-Path (Split-Path $PSScriptRoot -Parent) "_test_instance_deploy_winpython"

try {
    New-Item -ItemType Directory -Path (Join-Path $testRoot "nested\project") -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $testRoot ".zemiinst_exp") -Force | Out-Null

    Push-Location (Join-Path $testRoot "nested\project")
    try {
        $output = & $commandScript -Yes -WhatIf *>&1 | Out-String
    }
    finally {
        Pop-Location
    }

    $expectedArchive = Join-Path $testRoot "_tmp\Winpython64-3.12.10.1slim.7z"
    if ($output -notlike "*$expectedArchive*") {
        throw "The command did not discover the enclosing ZEMI Instance.`n$output"
    }
    if ($output -notlike '*Manual download command:*Invoke-WebRequest*') {
        throw "The command did not show a manual download command.`n$output"
    }
    Write-Host "[OK] instance deploy-winpython tests passed" -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
