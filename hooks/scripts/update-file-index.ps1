# Hook: update-file-index.ps1
# Trigger: PostToolUse (Write, Edit)
# Purpose: Incremental-append only — adds new files to FILE-INDEX.md, never rebuilds.
# Full rebuild: use the rebuild-index skill or run rebuild-file-index.ps1 manually.

# ── Resolve workspace root ────────────────────────────────────────────────────
# $CLAUDE_PROJECT_DIR is provided by the harness and works for both local and
# global (marketplace cache) installs. Walk-up fallback for local installs only.
if ($env:CLAUDE_PROJECT_DIR -and (Test-Path $env:CLAUDE_PROJECT_DIR)) {
    $workspace    = $env:CLAUDE_PROJECT_DIR
    $dotClaudeDir = Join-Path $workspace ".claude"
} else {
    $hooksDir     = Split-Path $PSScriptRoot -Parent
    $pluginRoot   = Split-Path $hooksDir -Parent
    $pluginsDir   = Split-Path $pluginRoot -Parent
    $dotClaudeDir = Split-Path $pluginsDir -Parent
    $workspace    = Split-Path $dotClaudeDir -Parent
}

$settingsFile = Join-Path $dotClaudeDir "wilma.local.md"
if (-not (Test-Path $settingsFile)) {
    Write-Error "wilma: not configured. Run /wilma-setup in Claude Code to get started."
    exit 1
}

$content = Get-Content $settingsFile -Raw
if ($content -match '(?m)^workspace_root:\s*["'']?([^"''\r\n]+)["'']?\s*$') {
    $r = $Matches[1].Trim()
    if ($r -ne "" -and (Test-Path $r)) { $workspace = $r }
}

$indexRelPath = "wilma/file-index.md"
if ($content -match '(?m)^index_path:\s*["'']?([^"''\r\n]+)["'']?\s*$') {
    $indexRelPath = $Matches[1].Trim()
}

# ── Load filekeeper config from wilma.local.md ───────────────────────────────
function Read-YamlArray {
    param([string]$fieldName, [string]$fileContent, [string[]]$default)
    if ($fileContent -match "(?m)^${fieldName}:\s*(\[.*?\])\s*$") {
        $raw = $Matches[1]
        $m   = [regex]::Matches($raw, '"([^"]*)"')
        if ($m.Count -gt 0) { return $m | ForEach-Object { $_.Groups[1].Value } }
    }
    return $default
}

$indexPath    = Join-Path $workspace $indexRelPath
$excludePaths = Read-YamlArray "exclude_paths"      $content @(".claude/", ".git/", "wilma/")
$exemptFiles  = Read-YamlArray "index_exempt_files" $content @()

if (-not (Test-Path $indexPath)) {
    Write-Warning "File index missing at $indexPath. Run /wilma:rebuild-index first."
    exit 1
}

$indexContent = Get-Content $indexPath -Raw

# ── Collect files on disk, applying exemption rules ───────────────────────────
$diskFiles = Get-ChildItem -Path $workspace -Recurse -File | Where-Object {
    $rel = $_.FullName.Substring($workspace.Length + 1).Replace('\', '/')

    if ($_.Name -in $exemptFiles) { return $false }
    foreach ($ep in $excludePaths) {
        if ($rel.StartsWith($ep)) { return $false }
    }
    return $true
} | ForEach-Object {
    $_.FullName.Substring($workspace.Length + 1).Replace('\', '/')
}

$newFiles = $diskFiles | Where-Object { $indexContent -notlike "*$_*" }

if ($newFiles.Count -eq 0) { exit 0 }

# ── Group by top-level folder and append ──────────────────────────────────────
$grouped = $newFiles | Group-Object { ($_ -split '/')[0] }
$lines   = Get-Content $indexPath
$result  = [System.Collections.Generic.List[string]]$lines

foreach ($group in $grouped) {
    $section    = "### $($group.Name)/"
    $sectionIdx = -1
    for ($i = 0; $i -lt $result.Count; $i++) {
        if ($result[$i] -eq $section) { $sectionIdx = $i; break }
    }

    if ($sectionIdx -eq -1) {
        $separatorIdx = $result.LastIndexOf("---")
        $insertAt = if ($separatorIdx -ge 0) { $separatorIdx } else { $result.Count }
        $result.Insert($insertAt,     "")
        $result.Insert($insertAt + 1, $section)
        $result.Insert($insertAt + 2, "")
        $result.Insert($insertAt + 3, "| Path | Description |")
        $result.Insert($insertAt + 4, "| ---- | ----------- |")
        $sectionIdx = $insertAt + 1
    }

    $tableEnd = $sectionIdx + 1
    while ($tableEnd -lt $result.Count -and
           $result[$tableEnd] -notmatch '^###' -and
           $result[$tableEnd] -ne "---") {
        $tableEnd++
    }
    $insertRow = $tableEnd
    while ($insertRow -gt $sectionIdx -and [string]::IsNullOrWhiteSpace($result[$insertRow - 1])) {
        $insertRow--
    }

    foreach ($f in ($group.Group | Sort-Object)) {
        $result.Insert($insertRow, "| [$f]($f) | |")
        $insertRow++
    }
}

$result | Set-Content -Path $indexPath -Encoding UTF8
Write-Host "FILE-INDEX.md: appended $($newFiles.Count) new file(s)."
