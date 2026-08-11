#Requires -Version 5.1
<#
.SYNOPSIS
  Очищает rules/ и skills/ в kit перед повторной синхронизацией.

.DESCRIPTION
  Удаляет содержимое категорий rules/skills, но сохраняет:
  - skillKitOwned из manifest (например 1c-bsl-review)
  - локальные rules kit (1c-security-checklist, knowledge-feedback-loop)

.EXAMPLE
  .\tools\Clean-Kit.ps1
  .\tools\Clean-Kit.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'
$KitRoot = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $KitRoot 'manifest.yaml'

$kitOwnedSkills = @('1c-bsl-review')
if (Test-Path $ManifestPath) {
    $manifestText = Get-Content $ManifestPath -Raw -Encoding UTF8
    if ($manifestText -match '(?ms)^skillKitOwned\s*:\s*\r?\n((?:  - [^\r\n]+\r?\n)+)') {
        $kitOwnedSkills = [regex]::Matches($Matches[1], '- (.+)') | ForEach-Object { $_.Groups[1].Value.Trim() }
    }
}

$kitOwnedRules = @(
    '1c-security-checklist.mdc',
    'knowledge-feedback-loop.mdc',
    'metadata-xml-workarounds.mdc',
    'git-publish-hygiene.mdc',
    'change-impact-analysis.mdc'
)

# --- rules: очистить файлы внутри категорий, сохранить kit-owned ---
$rulesRoot = Join-Path $KitRoot 'rules'
if (Test-Path $rulesRoot) {
    Get-ChildItem -Path $rulesRoot -Directory -Force | ForEach-Object {
        $catDir = $_
        Get-ChildItem -Path $catDir.FullName -Force | ForEach-Object {
            if ($kitOwnedRules -contains $_.Name) {
                Write-Host "  keep kit-owned rule: $($catDir.Name)/$($_.Name)" -ForegroundColor DarkGray
                return
            }
            if ($PSCmdlet.ShouldProcess($_.FullName, 'Remove')) {
                Remove-Item -Recurse -Force $_.FullName
            }
        }
    }
}

# --- skills: очистить skill-папки в категориях, сохранить kit-owned ---
$skillCats = @(
    (Join-Path $KitRoot 'skills\platform'),
    (Join-Path $KitRoot 'skills\domain'),
    (Join-Path $KitRoot 'skills\workflow'),
    (Join-Path $KitRoot 'skills\optional')
)

foreach ($path in $skillCats) {
    if (-not (Test-Path $path)) { continue }
    Get-ChildItem -Path $path -Force | ForEach-Object {
        if ($_.PSIsContainer -and ($kitOwnedSkills -contains $_.Name)) {
            Write-Host "  keep kit-owned skill: $($_.Name)" -ForegroundColor DarkGray
            return
        }
        if ($PSCmdlet.ShouldProcess($_.FullName, 'Remove')) {
            Remove-Item -Recurse -Force $_.FullName
        }
    }
}

Write-Host 'Kit content cleaned (kit-owned preserved). Run tools\Sync-Upstream.ps1 next.' -ForegroundColor Green
