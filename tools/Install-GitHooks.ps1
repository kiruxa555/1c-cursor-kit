#Requires -Version 5.1
<#
.SYNOPSIS
  Включает git hooks из .githooks (pre-commit → Test-PublishHygiene).

.EXAMPLE
  .\tools\Install-GitHooks.ps1
#>
[CmdletBinding()]
param(
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
$KitRoot = Split-Path -Parent $PSScriptRoot
Set-Location $KitRoot

if (-not (Test-Path (Join-Path $KitRoot '.git'))) {
    throw "Not a git repository: $KitRoot"
}

$hooksDir = Join-Path $KitRoot '.githooks'
if (-not (Test-Path $hooksDir)) {
    throw "Missing .githooks directory"
}

if ($Remove) {
    git config --unset core.hooksPath 2>$null
    Write-Host "core.hooksPath unset" -ForegroundColor Yellow
    return
}

git config core.hooksPath .githooks
Write-Host "Installed: git config core.hooksPath .githooks" -ForegroundColor Green
Write-Host "Pre-commit runs: tools\Test-PublishHygiene.ps1 -Scope Staged"
Write-Host "Manual:          .\tools\Test-PublishHygiene.ps1 -Scope Tree"
