[CmdletBinding()]
param(
    [string]$CodexCli,
    [string]$Manifest,
    [string]$Excel
)
$ErrorActionPreference = 'Stop'
try {
    $component = Get-Item -LiteralPath (Get-Location).Path
    while ($component -and -not (Test-Path -LiteralPath (Join-Path $component.FullName '.zemicomp'))) {
        $component = $component.Parent
    }
    if (-not $component) { throw 'Run this command inside a ZEMI Component.' }
    $settingsPath = Join-Path $component.FullName '.vscode\settings.json'
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    $python = $settings.'python.defaultInterpreterPath'
    if (-not $python) { throw 'python.defaultInterpreterPath is missing in project settings.' }
    $python = $python.Replace('${workspaceFolder}', $component.FullName)
    if (-not [IO.Path]::IsPathRooted($python)) { $python = Join-Path $component.FullName $python }
    if (-not (Test-Path -LiteralPath $python -PathType Leaf)) { throw "Python interpreter does not exist: $python" }
    if (-not $CodexCli) {
        $command = Get-Command codex -ErrorAction SilentlyContinue
        if ($command) { $CodexCli = $command.Source }
    }
    if (-not $CodexCli -or -not (Test-Path -LiteralPath $CodexCli -PathType Leaf)) {
        throw 'Codex CLI not found. Repeat: zemi codex install-zemi -CodexCli "full path to codex.exe"'
    }
    $setup = Join-Path $component.FullName 'zemi\coding_agents\codex\setup.py'
    if (-not (Test-Path -LiteralPath $setup)) { throw 'Update the component ZEMI library: coding_agents/codex/setup.py is missing.' }
    $setupArguments = @($setup, '--codex', $CodexCli, '--component', $component.FullName)
    if ($Manifest) { $setupArguments += @('--manifest', (Resolve-Path -LiteralPath $Manifest).Path) }
    if ($Excel) { $setupArguments += @('--excel', (Resolve-Path -LiteralPath $Excel).Path) }
    & $python @setupArguments
    if ($LASTEXITCODE -ne 0) { throw 'Integration registration failed.' }
    Write-Host 'ZEMI Codex integration installed and enabled.' -ForegroundColor Green
    Write-Host '1. Finish active work and fully close Codex.'
    Write-Host '2. Open Codex normally and start a chat.'
    Write-Host '3. Ask: call zemi_report_show with the path to your module HTML report.'
    Write-Host 'For diagnostics only: call zemi_probe_show.'
    Write-Host 'Backend, configuration and HTML changes are read on the next request. Reopen the interface after HTML changes.'
    Write-Host 'Changes to the transport or tool list may require another Codex restart.'
    Write-Host 'The existing plugins are left enabled.'
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
