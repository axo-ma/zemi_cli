[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [string]$ComponentName,

    [string]$InstancePath,
    [string]$RepositoryUrl,
    [switch]$NoRepository,
    [switch]$Yes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$templateUrl = "https://github.com/axo-ma/zemi_component_template.git"
$instanceMarkerNames = @(".zemiinst_dev", ".zemiinst_exp", ".zemiinst_prod")

function Test-ZemiComponentName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }

    if ($Name -in @(".", "..") -or [IO.Path]::IsPathRooted($Name)) {
        return $false
    }

    return $Name.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -lt 0
}

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

function Resolve-ZemiInstanceRoot {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "The ZEMI Instance path cannot be empty."
    }

    $expandedPath = [Environment]::ExpandEnvironmentVariables($Path.Trim().Trim('"'))
    if (-not (Test-Path -LiteralPath $expandedPath -PathType Container)) {
        throw "ZEMI Instance directory was not found: $expandedPath"
    }

    $resolvedPath = (Resolve-Path -LiteralPath $expandedPath).ProviderPath
    if (-not (Test-ZemiInstanceRoot -Path $resolvedPath)) {
        throw "Expected exactly one ZEMI Instance marker in: $resolvedPath"
    }

    return $resolvedPath
}

function Find-LatestDefaultPythonVenv {
    param([string]$InstanceRoot)

    $venvsRoot = Join-Path $InstanceRoot "_venvs"
    if (-not (Test-Path -LiteralPath $venvsRoot -PathType Container)) {
        return $null
    }

    $defaultVenvs = @(
        Get-ChildItem -LiteralPath $venvsRoot -Directory |
            ForEach-Object {
                if ($_.Name -match '^default-(WPy64-(\d+))$' -and
                    (Test-Path -LiteralPath (Join-Path $_.FullName "Scripts\python.exe") -PathType Leaf) -and
                    (Test-Path -LiteralPath (Join-Path $_.FullName "pyvenv.cfg") -PathType Leaf)) {
                    $numericVersion = 0L
                    if ([long]::TryParse($Matches[2], [ref]$numericVersion)) {
                        [pscustomobject]@{
                            Name = $_.Name
                            NumericVersion = $numericVersion
                            PythonPath = Join-Path $_.FullName "Scripts\python.exe"
                        }
                    }
                }
            }
    )

    return $defaultVenvs |
        Sort-Object -Property NumericVersion, Name -Descending |
        Select-Object -First 1
}

function Get-VSCodeDefaultInterpreterPath {
    param(
        [string]$ProjectRoot,
        [string]$PythonPath
    )

    $projectUri = New-Object Uri(
        ([IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar)
    )
    $pythonUri = New-Object Uri([IO.Path]::GetFullPath($PythonPath))
    $relativePath = [Uri]::UnescapeDataString($projectUri.MakeRelativeUri($pythonUri).ToString())
    return '${workspaceFolder}/' + $relativePath
}

function Invoke-Git {
    param(
        [string[]]$Arguments,
        [string]$FailureMessage
    )

    & $script:gitExecutable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw $FailureMessage
    }
}

function Assert-EmptyGitRepository {
    param([string]$Url)

    $output = @(& $script:gitExecutable ls-remote $Url 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $details = ($output | Out-String).Trim()
        throw "The Git repository is not accessible: $Url`n$details"
    }

    $refs = @($output | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($refs.Count -gt 0) {
        throw "The target Git repository is not empty: $Url"
    }
}

if ($RepositoryUrl -and $NoRepository) {
    throw "Use either -RepositoryUrl or -NoRepository, not both."
}

$gitCommand = Get-Command "git.exe" -ErrorAction SilentlyContinue
if (-not $gitCommand) {
    $gitCommand = Get-Command "git" -ErrorAction SilentlyContinue
}
if (-not $gitCommand) {
    throw "Git was not found. Install Git or add it to PATH, then run the command again."
}
$script:gitExecutable = $gitCommand.Source

if ($InstancePath) {
    $instanceRoot = Resolve-ZemiInstanceRoot -Path $InstancePath
}
else {
    $instanceRoot = Find-ZemiInstanceRoot -StartPath (Get-Location).ProviderPath
    while (-not $instanceRoot) {
        $enteredPath = (Read-Host "Full path to the ZEMI Instance").Trim()
        try {
            $instanceRoot = Resolve-ZemiInstanceRoot -Path $enteredPath
        }
        catch {
            Write-Warning $_.Exception.Message
        }
    }
}

$defaultVenv = Find-LatestDefaultPythonVenv -InstanceRoot $instanceRoot
if (-not $defaultVenv) {
    throw @"
No default Python venv was found in this ZEMI Instance.
Create one, then run component create again:
  zemi instance set-default-python-venv -InstancePath "$instanceRoot"
The component was not created.
"@
}

while (-not (Test-ZemiComponentName -Name $ComponentName)) {
    if (-not [string]::IsNullOrWhiteSpace($ComponentName)) {
        Write-Warning "Use a single valid folder name without path separators."
    }
    $ComponentName = (Read-Host "ZEMI Component folder name").Trim()
}

$componentRoot = Join-Path $instanceRoot $ComponentName
if (Test-Path -LiteralPath $componentRoot) {
    throw "The target already exists; refusing to modify it: $componentRoot"
}

Write-Host ""
Write-Host "ZEMI Component will be cloned from:"
Write-Host "  $templateUrl" -ForegroundColor Cyan
Write-Host "Target:"
Write-Host "  $componentRoot" -ForegroundColor Cyan
Write-Host "Default Python venv:"
Write-Host "  $($defaultVenv.PythonPath)" -ForegroundColor Cyan
Write-Host ""

if (-not $Yes) {
    $answer = (Read-Host "Clone the template and create this component? [Y/n]").Trim()
    if ($answer -and $answer -notin @("y", "yes")) {
        Write-Host "Cancelled."
        return
    }
}

if (-not $PSCmdlet.ShouldProcess($componentRoot, "Clone the ZEMI Component template")) {
    return
}

Invoke-Git `
    -Arguments @("clone", "--recurse-submodules", $templateUrl, $componentRoot) `
    -FailureMessage "Could not clone the ZEMI Component template into: $componentRoot"

Invoke-Git `
    -Arguments @("-C", $componentRoot, "remote", "remove", "origin") `
    -FailureMessage "The template was cloned, but its origin remote could not be removed: $componentRoot"

$componentMarkerPath = Join-Path $componentRoot ".zemicomp"
if (-not (Test-Path -LiteralPath $componentMarkerPath -PathType Leaf)) {
    [void](New-Item -ItemType File -Path $componentMarkerPath)
}

$vscodeRoot = Join-Path $componentRoot ".vscode"
[void](New-Item -ItemType Directory -Path $vscodeRoot -Force)
$vscodeSettingsPath = Join-Path $vscodeRoot "settings.json"
if (Test-Path -LiteralPath $vscodeSettingsPath -PathType Leaf) {
    try {
        $vscodeSettings = Get-Content -LiteralPath $vscodeSettingsPath -Raw -Encoding UTF8 |
            ConvertFrom-Json
    }
    catch {
        throw "The component VS Code settings file is not valid JSON: $vscodeSettingsPath"
    }

    if ($vscodeSettings -isnot [PSCustomObject]) {
        throw "The component VS Code settings file must contain a JSON object: $vscodeSettingsPath"
    }
}
else {
    $vscodeSettings = [PSCustomObject]@{}
}

$vscodeSettings |
    Add-Member `
        -MemberType NoteProperty `
        -Name "python.defaultInterpreterPath" `
        -Value (Get-VSCodeDefaultInterpreterPath -ProjectRoot $componentRoot -PythonPath $defaultVenv.PythonPath) `
        -Force
$vscodeSettingsJson = $vscodeSettings | ConvertTo-Json -Depth 20
[IO.File]::WriteAllText(
    $vscodeSettingsPath,
    $vscodeSettingsJson + [Environment]::NewLine,
    (New-Object Text.UTF8Encoding($false))
)

if (-not $RepositoryUrl -and -not $NoRepository -and -not $Yes) {
    Write-Host ""
    Write-Host "Optionally connect an empty Git repository."
    Write-Host "Leave the URL empty to keep the component local without a remote."

    while ($true) {
        $enteredUrl = (Read-Host "Empty Git repository URL").Trim()
        if (-not $enteredUrl) {
            $NoRepository = $true
            break
        }

        try {
            Assert-EmptyGitRepository -Url $enteredUrl
            $RepositoryUrl = $enteredUrl
            break
        }
        catch {
            Write-Warning $_.Exception.Message
        }
    }
}
elseif ($RepositoryUrl) {
    Assert-EmptyGitRepository -Url $RepositoryUrl
}
else {
    $NoRepository = $true
}

if ($RepositoryUrl) {
    Invoke-Git `
        -Arguments @("-C", $componentRoot, "remote", "add", "origin", $RepositoryUrl) `
        -FailureMessage "The component was created, but its origin remote could not be added: $RepositoryUrl"
}

$componentMarkers = @(
    Get-ChildItem -LiteralPath $componentRoot -Force -File |
        Where-Object { $_.Name -eq ".zemicomp" }
)
if ($componentMarkers.Count -ne 1) {
    throw "ZEMI Component marker verification failed: $componentRoot"
}

Write-Host ""
Write-Host "[OK] ZEMI Component created." -ForegroundColor Green
Write-Host "Root:   $componentRoot"
Write-Host "Marker: .zemicomp"
Write-Host "VS Code: .vscode/settings.json"
Write-Host "Python: $($defaultVenv.PythonPath)"
if ($RepositoryUrl) {
    Write-Host "Origin: $RepositoryUrl"
}
else {
    Write-Host "Origin: not configured"
}
Write-Host ""
Write-Host "Review and customize the component, then create its first component-specific commit."
if ($RepositoryUrl) {
    Write-Host "After committing, publish it with: git push -u origin main"
}
