# Hook: update-file-index.ps1
# Trigger: PostToolUse (Write, Edit)
# Purpose: Incremental-append only — adds new files to FILE-INDEX.md, never rebuilds.
# Full rebuild: use the rebuild-index skill or run rebuild-file-index.ps1 manually.

# ── Resolve workspace root from script location ───────────────────────────────
$hooksDir     = Split-Path $PSScriptRoot -Parent
$pluginRoot   = Split-Path $hooksDir -Parent
$pluginsDir   = Split-Path $pluginRoot -Parent
$dotClaudeDir = Split-Path $pluginsDir -Parent
$workspace    = Split-Path $dotClaudeDir -Parent

# Settings override: .claude/wilma.local.md
$settingsFile = Join-Path $dotClaudeDir "wilma.local.md"
if (Test-Path $settingsFile) {
    $content = Get-Content $settingsFile -Raw
    if ($content -match '(?m)^workspace_root:\s*["'']?([^"''\r\n]+)["'']?\s*$') {
        $r = $Matches[1].Trim()
        if (Test-Path $r) { $workspace = $r }
    }
}

# ── Load config with workspace-override fallback ──────────────────────────────
$configOverride = Join-Path $dotClaudeDir "plugins\simple-filekeeper\filekeeper-rules.json"
$configDefault  = Join-Path $pluginRoot "config\filekeeper-rules.default.json"
$configPath     = if (Test-Path $configOverride) { $configOverride } else { $configDefault }

if (-not (Test-Path $configPath)) {
    Write-Warning "update-file-index: config not found at $configPath"
    exit 1
}

$config       = Get-Content $configPath -Raw | ConvertFrom-Json
$indexPath    = Join-Path $workspace $config.index_path
$excludeDirs  = $config.exclude_dirs
$excludePaths = $config.exclude_paths
$exemptFiles  = $config.index_exempt_files

if (-not (Test-Path $indexPath)) {
    Write-Warning "FILE-INDEX.md missing at $indexPath. Run rebuild-index skill first."
    exit 1
}

$indexContent = Get-Content $indexPath -Raw

# ── Collect files on disk, applying exemption rules ───────────────────────────
$diskFiles = Get-ChildItem -Path $workspace -Recurse -File | Where-Object {
    $rel = $_.FullName.Substring($workspace.Length + 1).Replace('\', '/')
    $top = $rel.Split('/')[0]

    if ($top -in $excludeDirs) { return $false }
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
