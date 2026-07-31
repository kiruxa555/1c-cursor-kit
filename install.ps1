#Requires -Version 5.1
<#
.SYNOPSIS
  Устанавливает 1c-cursor-kit в глобальный Cursor (~/.cursor).

.PARAMETER Profile
  Minimal | Standard | Full

.PARAMETER WhatIf
  Показать, что будет скопировано, без изменений.

.EXAMPLE
  .\install.ps1 -Profile Standard
  .\install.ps1 -Profile Full -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Minimal', 'Standard', 'Full')]
    [string]$Profile = 'Standard'
)

$ErrorActionPreference = 'Stop'
$KitRoot = $PSScriptRoot
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

function Install-Rule {
    param([string]$SourceFile, [string]$RuleId)
    $dest = Join-Path $GlobalRules "$RuleId.mdc"
    if ($PSCmdlet.ShouldProcess($dest, 'Copy rule')) {
        Copy-Item -Force $SourceFile $dest
        Write-Host "  rule: $RuleId"
    }
}

function Install-Skill {
    param([string]$SourceDir, [string]$SkillName)
    $dest = Join-Path $GlobalSkills $SkillName
    if ($PSCmdlet.ShouldProcess($dest, 'Copy skill')) {
        if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
        Copy-Item -Recurse -Force $SourceDir $dest
        Write-Host "  skill: $SkillName"
    }
}

if (-not (Test-Path $ManifestPath)) { throw "Run from kit root. manifest.yaml not found." }
$manifestText = Get-Content $ManifestPath -Raw -Encoding UTF8

# Resolve profile
$ruleIds = @()
$skillCats = @()

switch ($Profile) {
    'Minimal' {
        $ruleIds = Get-YamlListUnderKey $manifestText 'profiles' 'Minimal'
        # parse rules list from Minimal profile manually
        if ($manifestText -match '(?ms)Minimal:.*?rules:\s*\[(.*?)\]') {
            $ruleIds = $Matches[1] -split ',' | ForEach-Object { $_.Trim() }
        }
        $skillCats = @()  # explicit skills below
        $explicitSkills = @('1c-config-router', '1c-bsl-review')
    }
    'Standard' {
        foreach ($cat in @('bsl', 'forms-xml', 'metadata', 'workflow', 'core')) {
            $ruleIds += Get-YamlListUnderKey $manifestText 'ruleCategories' $cat
        }
        $skillCats = @('platform', 'domain')
        $explicitSkills = @()
    }
    'Full' {
        foreach ($cat in @('bsl', 'forms-xml', 'metadata', 'workflow', 'core')) {
            $ruleIds += Get-YamlListUnderKey $manifestText 'ruleCategories' $cat
        }
        $skillCats = @('platform', 'domain', 'workflow', 'optional')
        $explicitSkills = @()
    }
}

$ruleIds = $ruleIds | Select-Object -Unique

Write-Host "1c-cursor-kit install - Profile: $Profile" -ForegroundColor Cyan
Write-Host "Target rules:  $GlobalRules"
Write-Host "Target skills: $GlobalSkills`n"

New-Item -ItemType Directory -Force -Path $GlobalRules, $GlobalSkills | Out-Null

# Rules
Write-Host "Rules ($($ruleIds.Count)):" -ForegroundColor Yellow
$kitRulesRoot = Join-Path $KitRoot 'rules'
foreach ($id in $ruleIds) {
    $found = Get-ChildItem -Path $kitRulesRoot -Recurse -Filter "$id.mdc" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $found) {
        Write-Warning "Rule not in kit (run Sync-Upstream.ps1): $id"
        continue
    }
    Install-Rule -SourceFile $found.FullName -RuleId $id
}

# Skills
$skillsToInstall = @()
if ($skillCats.Count) {
    foreach ($cat in $skillCats) {
        $skillsToInstall += Get-YamlListUnderKey $manifestText 'skillCategories' $cat
    }
}
if ($explicitSkills) { $skillsToInstall += $explicitSkills }
$skillsToInstall = $skillsToInstall | Select-Object -Unique

Write-Host "`nSkills ($($skillsToInstall.Count)):" -ForegroundColor Yellow
$kitSkillsRoot = Join-Path $KitRoot 'skills'
foreach ($name in $skillsToInstall) {
    $found = Get-ChildItem -Path $kitSkillsRoot -Recurse -Directory -Filter $name -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } |
        Select-Object -First 1
    if (-not $found) {
        Write-Warning "Skill not in kit (run Sync-Upstream.ps1): $name"
        continue
    }
    Install-Skill -SourceDir $found.FullName -SkillName $name
}

# Agents/commands (Full only)
if ($Profile -eq 'Full') {
    Write-Host ''
    Write-Host 'Agents/commands: see agents/ and commands/ folders in kit' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host 'Done. Add project rule from templates/project-rule.mdc.template' -ForegroundColor Green
