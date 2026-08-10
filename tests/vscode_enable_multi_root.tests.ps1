[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-Equal {
    param(
        $Actual,
        $Expected,
        [string]$Message
    )

    if ($Actual -is [string] -and $Expected -is [string]) {
        if ($Actual -cne $Expected) {
            throw "$Message`nExpected: $Expected`nActual:   $Actual"
        }
        return
    }

    if (($Actual | ConvertTo-Json -Compress) -cne ($Expected | ConvertTo-Json -Compress)) {
        throw "$Message`nExpected: $($Expected | ConvertTo-Json -Compress)`nActual:   $($Actual | ConvertTo-Json -Compress)"
    }
}

function Assert-ThrowsLike {
    param(
        [scriptblock]$Action,
        [string]$Pattern,
        [string]$Message
    )

    try {
        & $Action
    }
    catch {
        if ($_.Exception.Message -like $Pattern) {
            return
        }
        throw "$Message`nUnexpected error: $($_.Exception.Message)"
    }

    throw "$Message`nThe command did not fail."
}

$cliRoot = Split-Path -Parent $PSScriptRoot
$commandPath = Join-Path $cliRoot "zemi_cli.ps1"
$commandArguments = @("vscode", "enable-multi-root")

$instanceRoot = (Resolve-Path -LiteralPath $cliRoot).ProviderPath
while ($instanceRoot) {
    $instanceMarkers = @(
        Get-ChildItem -LiteralPath $instanceRoot -Force -File |
            Where-Object { $_.Name -in @(".zemiinst_dev", ".zemiinst_exp", ".zemiinst_prod") }
    )
    if ($instanceMarkers.Count -eq 1) {
        break
    }

    $parentPath = Split-Path -Parent $instanceRoot
    if (-not $parentPath -or $parentPath -eq $instanceRoot) {
        $instanceRoot = $null
        break
    }
    $instanceRoot = $parentPath
}
if (-not $instanceRoot) {
    throw "Run this test from a zemi_cli checkout inside a ZEMI Instance."
}

$temporaryRoot = Join-Path $instanceRoot "_tmp"
[void](New-Item -ItemType Directory -Path $temporaryRoot -Force)

$testRoot = Join-Path $temporaryRoot ("zemi-vscode-test-" + [Guid]::NewGuid().ToString("N"))
[void](New-Item -ItemType Directory -Path $testRoot)

try {
    [void](New-Item -ItemType File -Path (Join-Path $testRoot ".zemiinst_exp"))

    foreach ($directory in @("component_b", "component_a", "zemi", "ignored")) {
        [void](New-Item -ItemType Directory -Path (Join-Path $testRoot $directory))
    }
    [void](New-Item -ItemType File -Path (Join-Path $testRoot "component_a\.zemicomp"))
    [void](New-Item -ItemType File -Path (Join-Path $testRoot "component_b\.zemicomp"))
    [void](New-Item -ItemType File -Path (Join-Path $testRoot "zemi\.zemiworkroot"))

    Push-Location $testRoot
    try {
        & $commandPath @commandArguments | Out-Null
    }
    finally {
        Pop-Location
    }

    $workspacePath = Join-Path $testRoot "ZEMI.code-workspace"
    $workspace = Get-Content -LiteralPath $workspacePath -Raw -Encoding UTF8 |
        ConvertFrom-Json
    Assert-Equal `
        -Actual @($workspace.folders.path) `
        -Expected @("component_a", "component_b", "zemi") `
        -Message "The generated workspace root list is incorrect."

    $workspace |
        Add-Member -MemberType NoteProperty -Name "custom" -Value "preserved" -Force
    $json = $workspace | ConvertTo-Json -Depth 20
    [IO.File]::WriteAllText(
        $workspacePath,
        $json + [Environment]::NewLine,
        (New-Object Text.UTF8Encoding($false))
    )

    Push-Location (Join-Path $testRoot "component_a")
    try {
        & $commandPath @commandArguments | Out-Null
        $firstContent = [IO.File]::ReadAllText($workspacePath)
        & $commandPath @commandArguments | Out-Null
        $secondContent = [IO.File]::ReadAllText($workspacePath)
    }
    finally {
        Pop-Location
    }

    $workspace = $secondContent | ConvertFrom-Json
    Assert-Equal -Actual $workspace.custom -Expected "preserved" -Message "Custom workspace data was not preserved."
    Assert-Equal -Actual $secondContent -Expected $firstContent -Message "Repeated execution changed the workspace file."

    $emptyInstanceRoot = Join-Path $testRoot "empty_instance"
    [void](New-Item -ItemType Directory -Path $emptyInstanceRoot)
    [void](New-Item -ItemType File -Path (Join-Path $emptyInstanceRoot ".zemiinst_dev"))
    Assert-ThrowsLike `
        -Action {
            Push-Location $emptyInstanceRoot
            try {
                & $commandPath @commandArguments
            }
            finally {
                Pop-Location
            }
        } `
        -Pattern "No workspace roots were found.*" `
        -Message "An Instance without workspace roots must be rejected."

    [IO.File]::WriteAllText(
        $workspacePath,
        "{ invalid JSON",
        (New-Object Text.UTF8Encoding($false))
    )
    Assert-ThrowsLike `
        -Action {
            Push-Location $testRoot
            try {
                & $commandPath @commandArguments
            }
            finally {
                Pop-Location
            }
        } `
        -Pattern "The existing workspace file is not valid JSON:*" `
        -Message "An invalid existing workspace file must not be overwritten."

    Write-Host "[OK] vscode enable-multi-root tests passed." -ForegroundColor Green
}
finally {
    $resolvedTemporaryRoot = (Resolve-Path -LiteralPath $temporaryRoot).ProviderPath.TrimEnd('\')
    $resolvedTestRoot = (Resolve-Path -LiteralPath $testRoot).ProviderPath
    if (-not $resolvedTestRoot.StartsWith($resolvedTemporaryRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove a test directory outside @inst/_tmp: $resolvedTestRoot"
    }
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
}
