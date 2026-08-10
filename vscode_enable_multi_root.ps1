[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$instanceMarkerNames = @(".zemiinst_dev", ".zemiinst_exp", ".zemiinst_prod")
$componentMarkerName = ".zemicomp"
$workspaceRootMarkerName = ".zemiworkroot"
$workspaceFileName = "ZEMI.code-workspace"

function Test-ZemiInstanceRoot {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $false
    }

    $markers = @(
        Get-ChildItem -LiteralPath $Path -Force -File |
            Where-Object { $_.Name -in $instanceMarkerNames }
    )

    return $markers.Count -eq 1
}

function Find-ZemiInstanceRoot {
    param([string]$StartPath)

    $currentPath = (Resolve-Path -LiteralPath $StartPath).ProviderPath
    while ($currentPath) {
        if (Test-ZemiInstanceRoot -Path $currentPath) {
            return $currentPath
        }

        $parentPath = Split-Path -Parent $currentPath
        if (-not $parentPath -or $parentPath -eq $currentPath) {
            break
        }
        $currentPath = $parentPath
    }

    return $null
}

$instanceRoot = Find-ZemiInstanceRoot -StartPath (Get-Location).ProviderPath
if (-not $instanceRoot) {
    throw "Run this command from inside a ZEMI Instance containing exactly one .zemiinst_* marker."
}

$workspaceRoots = @(
    Get-ChildItem -LiteralPath $instanceRoot -Force -Directory |
        Where-Object {
            (Test-Path -LiteralPath (Join-Path $_.FullName $componentMarkerName) -PathType Leaf) -or
            (Test-Path -LiteralPath (Join-Path $_.FullName $workspaceRootMarkerName) -PathType Leaf)
        } |
        Sort-Object -Property Name
)

if ($workspaceRoots.Count -eq 0) {
    throw "No workspace roots were found. Add .zemicomp or .zemiworkroot to an immediate child directory of the ZEMI Instance."
}

$folders = @(
    $workspaceRoots | ForEach-Object {
        [PSCustomObject][ordered]@{ path = $_.Name }
    }
)

$workspacePath = Join-Path $instanceRoot $workspaceFileName
if (Test-Path -LiteralPath $workspacePath -PathType Leaf) {
    try {
        $workspace = Get-Content -LiteralPath $workspacePath -Raw -Encoding UTF8 |
            ConvertFrom-Json
    }
    catch {
        throw "The existing workspace file is not valid JSON: $workspacePath"
    }

    if ($workspace -isnot [PSCustomObject]) {
        throw "The existing workspace file must contain a JSON object: $workspacePath"
    }

    $workspace |
        Add-Member -MemberType NoteProperty -Name "folders" -Value $folders -Force
    if (-not $workspace.PSObject.Properties["settings"]) {
        $workspace |
            Add-Member -MemberType NoteProperty -Name "settings" -Value ([PSCustomObject]@{})
    }
}
else {
    $workspace = [PSCustomObject][ordered]@{
        folders = $folders
        settings = [PSCustomObject]@{}
    }
}

$json = $workspace | ConvertTo-Json -Depth 20
$content = $json + [Environment]::NewLine
$currentContent = if (Test-Path -LiteralPath $workspacePath -PathType Leaf) {
    Get-Content -LiteralPath $workspacePath -Raw -Encoding UTF8
}
else {
    $null
}

if ($currentContent -cne $content) {
    [IO.File]::WriteAllText(
        $workspacePath,
        $content,
        (New-Object Text.UTF8Encoding($false))
    )
}

Write-Host "[OK] ZEMI multi-root workspace is ready." -ForegroundColor Green
Write-Host "Workspace: $workspacePath"
Write-Host "Roots:     $($workspaceRoots.Count)"
foreach ($root in $workspaceRoots) {
    Write-Host "  $($root.Name)"
}
Write-Host "Open the workspace file in VS Code. Use 'Open in Integrated Terminal' on an Explorer folder to start a terminal in that context."
