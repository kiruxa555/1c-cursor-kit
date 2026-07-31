#Requires -Version 5.1
<#
.SYNOPSIS
  Очищает rules/ и skills/ в kit перед повторной синхронизацией.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

$KitRoot = Split-Path -Parent $PSScriptRoot
$targets = @(
    (Join-Path $KitRoot 'rules'),
    (Join-Path $KitRoot 'skills\platform'),
    (Join-Path $KitRoot 'skills\domain'),
    (Join-Path $KitRoot 'skills\workflow'),
    (Join-Path $KitRoot 'skills\optional')
)

foreach ($path in $targets) {
    if (-not (Test-Path $path)) { continue }
    Get-ChildItem -Path $path -Force | ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.FullName, 'Remove')) {
            Remove-Item -Recurse -Force $_.FullName
        }
    }
}

Write-Host 'Kit content cleaned. Run tools\Sync-Upstream.ps1 next.' -ForegroundColor Green
