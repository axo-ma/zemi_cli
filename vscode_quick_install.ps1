[CmdletBinding()]
param(
    [string]$InstallerPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-CodeCommand {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\bin\code.cmd"),
        (Join-Path $env:ProgramFiles "Microsoft VS Code\bin\code.cmd")
    )
    if (${env:ProgramFiles(x86)}) {
        $candidates += Join-Path ${env:ProgramFiles(x86)} "Microsoft VS Code\bin\code.cmd"
    }

    return $candidates |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1
}

function Install-VSCodeFromFile {
    param([Parameter(Mandatory)][string]$Path)

    $resolvedPath = (Resolve-Path -LiteralPath $Path).ProviderPath
    if ([IO.Path]::GetExtension($resolvedPath) -ine ".exe") {
        throw "The VS Code installer must be an .exe file: $resolvedPath"
    }

    $signature = Get-AuthenticodeSignature -LiteralPath $resolvedPath
    if ($signature.Status -ne "Valid" -or
        $signature.SignerCertificate.Subject -notmatch '(?i)\bMicrosoft Corporation\b') {
        throw "The installer does not have a valid Microsoft Corporation signature: $resolvedPath"
    }

    Write-Host "Installing VS Code from:" -ForegroundColor Cyan
    Write-Host "  $resolvedPath"
    $process = Start-Process `
        -FilePath $resolvedPath `
        -ArgumentList @(
            "/VERYSILENT",
            "/SUPPRESSMSGBOXES",
            "/NORESTART",
            "/MERGETASKS=!runcode,addcontextmenufiles,addcontextmenufolders,addtopath"
        ) `
        -Wait `
        -PassThru
    if ($process.ExitCode -ne 0) {
        throw "VS Code installer failed with exit code $($process.ExitCode)."
    }
}

function Install-VSCodeWithWinget {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "winget was not found. Download the VS Code User Installer and pass its path with -InstallerPath."
    }

    Write-Host "Installing VS Code Stable with winget..." -ForegroundColor Cyan
    & $winget.Source install `
        --id Microsoft.VisualStudioCode `
        --exact `
        --source winget `
        --scope user `
        --accept-package-agreements `
        --accept-source-agreements `
        --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        throw "winget failed to install VS Code (exit code $LASTEXITCODE)."
    }
}

$codeCommand = Resolve-CodeCommand
if (-not $codeCommand) {
    if ($InstallerPath) {
        Install-VSCodeFromFile -Path $InstallerPath
    }
    else {
        Install-VSCodeWithWinget
    }
    $codeCommand = Resolve-CodeCommand
}

if (-not $codeCommand) {
    throw "VS Code was installed, but bin\code.cmd was not found in a standard installation directory."
}

Write-Host ""
Write-Host "VS Code command:" -ForegroundColor Cyan
Write-Host "  $codeCommand"

$extensions = @(
    "ms-python.python",
    "ms-python.vscode-pylance",
    "ms-python.debugpy",
    "ms-python.vscode-python-envs",
    "ms-toolsai.jupyter"
)

foreach ($extension in $extensions) {
    Write-Host "Installing extension: $extension"
    & $codeCommand --install-extension $extension --force
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install VS Code extension: $extension"
    }
}

Write-Host ""
Write-Host "[OK] VS Code and the required Marketplace extensions are installed." -ForegroundColor Green
Write-Host "The script did not start or configure VS Code and did not change VS Code settings."
