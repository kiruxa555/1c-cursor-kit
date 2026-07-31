#Requires -Version 5.1
<#
.SYNOPSIS
  Publish hygiene scanner: secrets, personal paths, blocklist, LICENSE/NOTICE.

.PARAMETER Scope
  Staged - git index (pre-commit)
  Tree   - tracked working tree (CI / before push)
  Diff   - changed vs origin/main (fallback HEAD~1)

.PARAMETER FailOnWarning
  Exit 1 on Warning as well (strict public release).

.EXAMPLE
  .\tools\Test-PublishHygiene.ps1 -Scope Staged
  .\tools\Test-PublishHygiene.ps1 -Scope Tree -FailOnWarning
#>
[CmdletBinding()]
param(
    [ValidateSet('Staged', 'Tree', 'Diff')]
    [string]$Scope = 'Staged',
    [string]$BlocklistPath = '',
    [switch]$FailOnWarning,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$KitRoot = Split-Path -Parent $PSScriptRoot
Set-Location $KitRoot

function New-Finding {
    param(
        [ValidateSet('Critical', 'Warning')]
        [string]$Severity,
        [string]$File,
        [int]$Line = 0,
        [string]$Rule,
        [string]$Message
    )
    [pscustomobject]@{
        Severity = $Severity
        File     = $File
        Line     = $Line
        Rule     = $Rule
        Message  = $Message
    }
}

function Test-IsSkippedPath {
    param([string]$RelPath)
    $n = $RelPath.Replace('\', '/')
    if ($n -match '(^|/)\.git(/|$)') { return $true }
    if ($n -match '(^|/)vendor/_cache(/|$)') { return $true }
    if ($n -match '(^|/)vendor/_tmp(/|$)') { return $true }
    if ($n -match '(^|/)node_modules(/|$)') { return $true }
    if ($n -match '\.(png|jpg|jpeg|gif|webp|ico|pdf|zip|7z|rar|exe|dll|pdb|bin|1CD|cf|cfe|epf|erf)$') { return $true }
    return $false
}

function Get-TargetFiles {
    param([string]$ScopeName)
    $files = @()
    switch ($ScopeName) {
        'Staged' {
            $raw = git diff --cached --name-only -z 2>$null
            if ($LASTEXITCODE -ne 0) { throw 'git diff --cached failed' }
            if ($raw) { $files = @($raw -split "`0" | Where-Object { $_ }) }
        }
        'Tree' {
            $raw = git ls-files -z 2>$null
            if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed' }
            if ($raw) { $files = @($raw -split "`0" | Where-Object { $_ }) }
        }
        'Diff' {
            $base = 'origin/main'
            git rev-parse --verify $base 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { $base = 'HEAD~1' }
            $raw = git diff --name-only -z $base 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Warning 'Diff base unavailable; fallback to Tree'
                return (Get-TargetFiles -ScopeName 'Tree')
            }
            if ($raw) { $files = @($raw -split "`0" | Where-Object { $_ }) }
        }
    }
    return @($files | Where-Object { $_ -and -not (Test-IsSkippedPath $_) } | Select-Object -Unique)
}

function Get-BlocklistPatterns {
    param([string]$Path)
    if (-not $Path) {
        $Path = Join-Path $KitRoot 'publish-blocklist.txt'
    }
    if (-not (Test-Path $Path)) { return @() }
    return @(
        Get-Content $Path -Encoding UTF8 |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith('#') }
    )
}

function Test-IsAllowlistedLine {
    param([string]$Line)
    if ($Line -match '(?i)<user>|%USERPROFILE%|\$env:USERPROFILE|\{\{PROJECT_NAME\}\}|CHANGE_ME|your[_-]?token|example\.com') {
        return $true
    }
    # Placeholders like {IB_PASSWORD}, {API_KEY}
    if ($Line -match '\{[A-Za-z0-9_]+\}') { return $true }
    if ($Line -match '(?i)password\s*[:=]\s*[''"]?\*+[''"]?') { return $true }
    if ($Line -match '(?i)(?:C:|D:)\\Users\\<[^>\\]+>') { return $true }
    if ($Line -match '(?i)/Users/<[^>/]+>') { return $true }
    # Doc examples with ellipsis / empty placeholders
    if ($Line -match '(?i)Srvr\s*=.*Pwd\s*=\s*[:.…]') { return $true }
    if ($Line -match '(?i)Bearer\s+[…]') { return $true }
    # Code that parses KEY= from a line (not a hardcoded secret)
    if ($Line -match '(?i)len\(["''].*API[_-]?KEY=') { return $true }
    if ($Line -match '(?i)startswith\(["''].*API[_-]?KEY') { return $true }
    return $false
}

$criticalContent = @(
    @{ Rule = 'secret-assignment'; Pattern = '(?i)(password|passwd|pwd|secret|api[_-]?key|access[_-]?token|client[_-]?secret)\s*[:=]\s*[''"][^''"\s]{6,}[''"]' }
    @{ Rule = 'bearer-token'; Pattern = '(?i)\bBearer\s+[A-Za-z0-9\-._~+/]{20,}=*' }
    @{ Rule = 'aws-key'; Pattern = 'AKIA[0-9A-Z]{16}' }
    @{ Rule = 'private-key'; Pattern = '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----' }
    @{ Rule = '1c-conn-pwd'; Pattern = '(?i)(Srvr|Ref)\s*=.+;(Pwd|Password)\s*=\s*[^;\s]+' }
    @{ Rule = 'personal-win-path'; Pattern = '(?i)(?:C:|D:)\\Users\\(?!Public\\|All Users\\|<[^\>\\]+>)([^\\\s"'']+)\\' }
    @{ Rule = 'personal-unix-path'; Pattern = '(?i)(?<![\w.-])/(?:Users|home)/(?!Shared|tmp|<)([A-Za-z0-9._-]+)/' }
)

$criticalPathNames = @(
    @{ Rule = 'env-file'; Pattern = '(^|[\\/])\.env$|(^|[\\/])\.dev\.env$|(^|[\\/])\.env\.[^.]+$' }
    @{ Rule = 'pfx'; Pattern = '\.(pfx|p12)$' }
)

$findings = New-Object System.Collections.Generic.List[object]
$blocklist = Get-BlocklistPatterns -Path $BlocklistPath
$files = Get-TargetFiles -Scope $Scope

foreach ($rel in $files) {
    $full = Join-Path $KitRoot $rel
    if (-not (Test-Path -LiteralPath $full)) { continue }

    # Meta files describing patterns — skip content rules (path rules still apply)
    $skipContent = $rel -match '(?i)git-publish-hygiene|Test-PublishHygiene|publish-hygiene\.yml|publish-blocklist'

    foreach ($pn in $criticalPathNames) {
        if ($rel -match $pn.Pattern) {
            [void]$findings.Add((New-Finding -Severity Critical -File $rel -Rule $pn.Rule -Message 'Sensitive path name should not be committed'))
        }
    }

    if ($skipContent) { continue }

    $item = Get-Item -LiteralPath $full
    if ($item.Length -gt 2MB) { continue }

    $text = $null
    try {
        $bytes = [System.IO.File]::ReadAllBytes($full)
        $nuls = 0
        foreach ($b in $bytes) {
            if ($b -eq 0) {
                $nuls++
                if ($nuls -gt 8) { break }
            }
        }
        if ($nuls -gt 8) { continue }
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    } catch {
        continue
    }

    $lines = $text -split "`r?`n", -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if (Test-IsAllowlistedLine -Line $line) { continue }

        foreach ($c in $criticalContent) {
            if ($line -match $c.Pattern) {
                if ($c.Rule -eq 'personal-win-path' -and $line -match '(?i)\\Users\\<') { continue }
                $msg = $line.Trim()
                if ($msg.Length -gt 120) { $msg = $msg.Substring(0, 120) }
                [void]$findings.Add((New-Finding -Severity Critical -File $rel -Line ($i + 1) -Rule $c.Rule -Message $msg))
            }
        }

        foreach ($b in $blocklist) {
            if ($line.IndexOf($b, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                [void]$findings.Add((New-Finding -Severity Critical -File $rel -Line ($i + 1) -Rule 'blocklist' -Message ("Blocklist hit: " + $b)))
            }
        }
    }
}

$hasLicense = Test-Path (Join-Path $KitRoot 'LICENSE')
$hasNotice = Test-Path (Join-Path $KitRoot 'NOTICE')
if ($Scope -eq 'Tree' -or $Scope -eq 'Diff') {
    if (-not $hasLicense) {
        [void]$findings.Add((New-Finding -Severity Warning -File 'LICENSE' -Rule 'missing-license' -Message 'Public repos should include LICENSE'))
    }
    if (-not $hasNotice) {
        [void]$findings.Add((New-Finding -Severity Warning -File 'NOTICE' -Rule 'missing-notice' -Message 'Redistributing upstream? Prefer NOTICE with attribution'))
    }
}

if ($Scope -eq 'Tree') {
    foreach ($rel in $files) {
        if ($rel -notmatch '\.(md|mdc|ps1|py|js|yml|yaml|txt)$') { continue }
        $full = Join-Path $KitRoot $rel
        if (-not (Test-Path -LiteralPath $full)) { continue }
        try {
            $head = Get-Content -LiteralPath $full -TotalCount 40 -Encoding UTF8 -ErrorAction SilentlyContinue
            $blob = ($head -join "`n")
            if ($blob -match '(?i)SPDX-License-Identifier:\s*GPL|GNU GENERAL PUBLIC LICENSE') {
                $baseName = [IO.Path]::GetFileName($rel)
                if ($baseName -ne 'LICENSE' -and $baseName -ne 'NOTICE' -and $rel -notmatch 'LICENSE') {
                    [void]$findings.Add((New-Finding -Severity Warning -File $rel -Rule 'gpl-marker' -Message 'GPL marker in non-license file - check compatibility'))
                }
            }
        } catch {}
    }
}

$critical = @($findings | Where-Object { $_.Severity -eq 'Critical' })
$warnings = @($findings | Where-Object { $_.Severity -eq 'Warning' })

if ($Json) {
    $findings | ConvertTo-Json -Depth 4
} else {
    Write-Host ("Publish hygiene ({0}): {1} file(s) scanned" -f $Scope, $files.Count) -ForegroundColor Cyan
    if ($critical.Count -eq 0 -and $warnings.Count -eq 0) {
        Write-Host 'OK - no findings' -ForegroundColor Green
    } else {
        foreach ($f in ($findings | Sort-Object Severity, File, Line)) {
            $color = if ($f.Severity -eq 'Critical') { 'Red' } else { 'Yellow' }
            $loc = if ($f.Line -gt 0) { ':' + $f.Line } else { '' }
            Write-Host ('[{0}] {1}{2} ({3}) {4}' -f $f.Severity, $f.File, $loc, $f.Rule, $f.Message) -ForegroundColor $color
        }
        Write-Host ('Critical: {0}  Warning: {1}' -f $critical.Count, $warnings.Count) -ForegroundColor Cyan
    }
}

if ($critical.Count -gt 0) { exit 1 }
if ($FailOnWarning -and $warnings.Count -gt 0) { exit 1 }
exit 0
