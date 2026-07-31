#Requires -Version 5.1
<#
.SYNOPSIS
  Синхронизирует rules и skills из upstream-репозиториев в локальный kit.

.DESCRIPTION
  1. Shallow-clone Desko77, comol, fairballer во vendor/_cache
  2. Копирует rules по категориям из manifest.yaml (canonical = Desko77)
  3. Копирует skills по категориям
  4. Merge extras из comol/fairballer; kit-owned skills не перезаписываются

.EXAMPLE
  .\tools\Sync-Upstream.ps1
  .\tools\Sync-Upstream.ps1 -RulesOnly
  .\tools\Sync-Upstream.ps1 -SkillsOnly
#>
[CmdletBinding()]
param(
    [switch]$RulesOnly,
    [switch]$SkillsOnly,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$KitRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$VendorCache = Join-Path $KitRoot 'vendor\_cache'
$ManifestPath = Join-Path $KitRoot 'manifest.yaml'

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

function Ensure-ShallowClone {
    param([string]$Name, [string]$Url, [string]$Branch)
    $dest = Join-Path $VendorCache $Name
    if ((Test-Path $dest) -and -not $Force) {
        Write-Step "Update $Name"
        Push-Location $dest
        git fetch --depth 1 origin $Branch 2>$null
        git checkout $Branch 2>$null
        git reset --hard "origin/$Branch" 2>$null
        Pop-Location
        return $dest
    }
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    Write-Step "Clone $Name ($Branch)"
    git clone --depth 1 --branch $Branch $Url $dest
    return $dest
}

function Copy-RuleFile {
    param(
        [string]$SourceFile,
        [string]$Category,
        [string]$FileName
    )
    if (-not (Test-Path $SourceFile)) {
        Write-Warning "Rule not found: $SourceFile"
        return
    }
    $destDir = Join-Path $KitRoot "rules\$Category"
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $destFile = Join-Path $destDir $FileName
    if ((Test-Path $destFile) -and -not $Force) {
        $srcLen = (Get-Item $SourceFile).Length
        $dstLen = (Get-Item $destFile).Length
        if ($dstLen -ge $srcLen) {
            Write-Host "  skip (local >= upstream): $FileName" -ForegroundColor DarkGray
            return
        }
    }
    Copy-Item -Force $SourceFile $destFile
    Write-Host "  rule: $Category/$FileName"
}

function Copy-SkillDir {
    param(
        [string]$SourceDir,
        [string]$Category,
        [string]$SkillName
    )
    if (-not (Test-Path $SourceDir)) {
        Write-Warning "Skill not found: $SourceDir"
        return
    }
    $destDir = Join-Path $KitRoot "skills\$Category\$SkillName"
    if (Test-Path $destDir) { Remove-Item -Recurse -Force $destDir }
    New-Item -ItemType Directory -Force -Path (Split-Path $destDir) | Out-Null
    Copy-Item -Recurse -Force $SourceDir $destDir
    Write-Host "  skill: $Category/$SkillName"
}

# --- Parse manifest (minimal YAML parsing for categories) ---
if (-not (Test-Path $ManifestPath)) { throw "manifest.yaml not found: $ManifestPath" }
$manifestText = Get-Content $ManifestPath -Raw -Encoding UTF8

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

# skillKitOwned is a top-level YAML list
if ($manifestText -match '(?ms)^skillKitOwned\s*:\s*\r?\n((?:  - [^\r\n]+\r?\n)+)') {
    $kitOwnedSkills = [regex]::Matches($Matches[1], '- (.+)') | ForEach-Object { $_.Groups[1].Value.Trim() }
} else {
    $kitOwnedSkills = @('1c-bsl-review')
}

New-Item -ItemType Directory -Force -Path $VendorCache | Out-Null

$desko = $null
$comol = $null
$fair = $null

if (-not $SkillsOnly) {
    Write-Step "Sync rules (canonical: Desko77)"
    $desko = Ensure-ShallowClone 'desko77' 'https://github.com/Desko77/cursor-1c-skills.git' 'master'
    $fair = Ensure-ShallowClone 'fairballer' 'https://github.com/fairballer-rgb/universal_1c_rules.git' 'master'

    $categories = @{
        bsl = Get-YamlListUnderKey $manifestText 'ruleCategories' 'bsl'
        'forms-xml' = Get-YamlListUnderKey $manifestText 'ruleCategories' 'forms-xml'
        metadata = Get-YamlListUnderKey $manifestText 'ruleCategories' 'metadata'
        workflow = Get-YamlListUnderKey $manifestText 'ruleCategories' 'workflow'
        core = Get-YamlListUnderKey $manifestText 'ruleCategories' 'core'
    }

    # Не тянем из Desko77: fairballer core + kit-owned rules
    $skipFromDesko = @(
        'agent_routing', 'bsp_libraries', 'platform-solutions',
        '1c-security-checklist', 'knowledge-feedback-loop', 'metadata-xml-workarounds',
        'git-publish-hygiene'
    )

    foreach ($cat in $categories.Keys) {
        foreach ($ruleId in $categories[$cat]) {
            if ($skipFromDesko -contains $ruleId) { continue }
            $src = Join-Path $desko "rules\$ruleId.mdc"
            Copy-RuleFile -SourceFile $src -Category $cat -FileName "$ruleId.mdc"
        }
    }

    # fairballer core rules
    $fairExtras = @(
        @{ file = 'agent_routing.mdc'; cat = 'core' },
        @{ file = 'bsp_libraries.mdc'; cat = 'core' },
        @{ file = 'platform-solutions.mdc'; cat = 'core' }
    )
    foreach ($e in $fairExtras) {
        $src = Join-Path $fair ".cursor\rules\$($e.file)"
        Copy-RuleFile -SourceFile $src -Category $e.cat -FileName $e.file
    }
}

if (-not $RulesOnly) {
    Write-Step "Sync skills (canonical: Desko77)"
    if (-not $desko) {
        $desko = Ensure-ShallowClone 'desko77' 'https://github.com/Desko77/cursor-1c-skills.git' 'master'
    }
    $comol = Ensure-ShallowClone 'comol' 'https://github.com/comol/ai_rules_1c.git' 'main'

    $skillCats = @{
        platform = Get-YamlListUnderKey $manifestText 'skillCategories' 'platform'
        domain = Get-YamlListUnderKey $manifestText 'skillCategories' 'domain'
        workflow = Get-YamlListUnderKey $manifestText 'skillCategories' 'workflow'
        optional = Get-YamlListUnderKey $manifestText 'skillCategories' 'optional'
    }

    foreach ($cat in $skillCats.Keys) {
        foreach ($skillName in $skillCats[$cat]) {
            if ($kitOwnedSkills -contains $skillName) {
                $localKit = Join-Path $KitRoot "skills\$cat\$skillName"
                if (Test-Path (Join-Path $localKit 'SKILL.md')) {
                    Write-Host "  skip kit-owned: $cat/$skillName" -ForegroundColor DarkGray
                } else {
                    Write-Warning "Kit-owned skill missing in repo: $cat/$skillName"
                }
                continue
            }
            if ($cat -eq 'workflow' -and $skillName -in @('caveman', 'handoff', '1c-metadata-manage')) {
                $src = Join-Path $comol "content\skills\$skillName"
            }
            else {
                $src = Join-Path $desko "skills\$skillName"
            }
            Copy-SkillDir -SourceDir $src -Category $cat -SkillName $skillName
        }
    }

    # comol agents/commands
    Write-Step "Sync agents and commands (comol)"
    $agentsSrc = Join-Path $comol 'content\agents'
    $commandsSrc = Join-Path $comol 'content\commands'
    $agentsDst = Join-Path $KitRoot 'agents'
    $commandsDst = Join-Path $KitRoot 'commands'
    if (Test-Path $agentsSrc) {
        if (Test-Path $agentsDst) { Remove-Item -Recurse -Force $agentsDst }
        Copy-Item -Recurse -Force $agentsSrc $agentsDst
        Write-Host "  agents: copied"
    }
    if (Test-Path $commandsSrc) {
        # Preserve kit-only commands (e.g. kit-feedback.md)
        $kitOnlyCommands = @('kit-feedback.md')
        $preserved = @{}
        foreach ($name in $kitOnlyCommands) {
            $p = Join-Path $commandsDst $name
            if (Test-Path $p) { $preserved[$name] = Get-Content $p -Raw -Encoding UTF8 }
        }
        if (Test-Path $commandsDst) { Remove-Item -Recurse -Force $commandsDst }
        Copy-Item -Recurse -Force $commandsSrc $commandsDst
        foreach ($name in $preserved.Keys) {
            Set-Content -Path (Join-Path $commandsDst $name) -Value $preserved[$name] -Encoding UTF8
        }
        Write-Host "  commands: copied"
    }
}

Write-Step 'Done. Run tools\Inventory-Kit.ps1 to verify.'
