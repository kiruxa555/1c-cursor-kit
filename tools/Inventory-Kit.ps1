#Requires -Version 5.1
<#
.SYNOPSIS
  Сравнивает установленный Cursor kit с manifest и содержимым репозитория.

.EXAMPLE
  .\tools\Inventory-Kit.ps1
  .\tools\Inventory-Kit.ps1 -CompareInstalled
#>
[CmdletBinding()]
param(
    [switch]$CompareInstalled
)

$ErrorActionPreference = 'Stop'
$KitRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ManifestPath = Join-Path $KitRoot 'manifest.yaml'
$GlobalRules = Join-Path $env:USERPROFILE '.cursor\rules'
$GlobalSkills = Join-Path $env:USERPROFILE '.cursor\skills'

function Get-YamlListUnderKey {
    param([string]$Text, [string]$ParentKey, [string]$ChildKey)
    $escapedParent = [regex]::Escape($ParentKey)
    $escapedChild = [regex]::Escape($ChildKey)
    if ($Text -notmatch "(?ms)^$escapedParent\s*:\s*\r?\n(.*?)(?=^[A-Za-z0-9_][^\r\n]*:\s*(?:\r?\n|\z)|\z)") {
        return @()
    }
    $parentBlock = $Matches[1]
    if ($parentBlock -notmatch "(?m)^  $escapedChild\s*:\s*\r?\n((?:    - [^\r\n]+\r?\n)+)") {
        return @()
    }
    return [regex]::Matches($Matches[1], '- (.+)') | ForEach-Object { $_.Groups[1].Value.Trim() }
}

$manifestText = Get-Content $ManifestPath -Raw -Encoding UTF8
$version = if ($manifestText -match 'version:\s*"?([^"\r\n]+)') { $Matches[1].Trim('"') } else { 'unknown' }

Write-Host "`n1c-cursor-kit v$version" -ForegroundColor Green
Write-Host "Kit root: $KitRoot`n"

# Rules in kit
$kitRules = Get-ChildItem -Path (Join-Path $KitRoot 'rules') -Recurse -Filter '*.mdc' -ErrorAction SilentlyContinue
Write-Host "Rules in kit: $($kitRules.Count)" -ForegroundColor Cyan
foreach ($r in ($kitRules | Sort-Object FullName)) {
    $rel = $r.FullName.Substring((Join-Path $KitRoot 'rules').Length + 1)
    Write-Host "  $rel"
}

# Skills in kit
$kitSkills = Get-ChildItem -Path (Join-Path $KitRoot 'skills') -Directory -Recurse -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') }
Write-Host "`nSkills in kit: $($kitSkills.Count)" -ForegroundColor Cyan
$byCat = $kitSkills | Group-Object { $_.Parent.Name }
foreach ($g in $byCat) {
    Write-Host "  [$($g.Name)]: $($g.Count)"
}

if (-not $CompareInstalled) {
    Write-Host "`nTip: run with -CompareInstalled to diff global Cursor install`n" -ForegroundColor DarkGray
    return
}

Write-Host "`n--- Global install comparison ---" -ForegroundColor Yellow

$expectedRules = @()
foreach ($cat in @('bsl', 'forms-xml', 'metadata', 'workflow', 'core')) {
    $expectedRules += Get-YamlListUnderKey $manifestText 'ruleCategories' $cat
}
$expectedRules = $expectedRules | Select-Object -Unique

$missingRules = @()
$extraGlobalRules = @()
foreach ($id in $expectedRules) {
    $global = Join-Path $GlobalRules "$id.mdc"
    $inKit = $kitRules | Where-Object { $_.BaseName -eq $id }
    if (-not (Test-Path $global)) { $missingRules += $id }
    elseif (-not $inKit) { Write-Host "  rule in global but not in kit: $id" -ForegroundColor DarkYellow }
}
if ($missingRules.Count) {
    Write-Host "`nMissing in $GlobalRules :" -ForegroundColor Red
    $missingRules | ForEach-Object { Write-Host "  - $_" }
} else {
    Write-Host "`nAll expected rules present in global install." -ForegroundColor Green
}

$expectedSkills = @()
foreach ($cat in @('platform', 'domain', 'workflow', 'optional')) {
    $expectedSkills += Get-YamlListUnderKey $manifestText 'skillCategories' $cat
}
$expectedSkills = $expectedSkills | Select-Object -Unique

$missingSkills = @()
foreach ($name in $expectedSkills) {
    $global = Join-Path $GlobalSkills $name
    if (-not (Test-Path $global)) { $missingSkills += $name }
}
if ($missingSkills.Count) {
    Write-Host "`nMissing skills in $GlobalSkills : $($missingSkills.Count)" -ForegroundColor Red
    $missingSkills | Select-Object -First 15 | ForEach-Object { Write-Host "  - $_" }
    if ($missingSkills.Count -gt 15) { Write-Host "  ... and $($missingSkills.Count - 15) more" }
} else {
    Write-Host "All expected skills present in global install." -ForegroundColor Green
}

# Project-level duplicates (optional: parent of kit, if it looks like a projects root)
$projectsRoot = Split-Path -Parent $KitRoot
$projectImported = Get-ChildItem -Path $projectsRoot -Recurse -Filter '*.mdc' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\\.cursor\\rules\\imported\\' }
if ($projectImported) {
    Write-Host "`nProject-level imported rules (candidates to remove):" -ForegroundColor Yellow
    $projectImported | ForEach-Object { Write-Host "  $($_.FullName)" }
}

Write-Host ""
