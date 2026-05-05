# Script: rebuild-file-index.ps1
# Purpose: Full rebuild of FILE-INDEX.md from scratch.
# WARNING: Destroys all manually-written descriptions. Run only when needed.
# Normal operation uses update-file-index.ps1 (incremental-append).
# Invoked by the rebuild-index skill after user confirmation.

# ── Resolve workspace root from script location ───────────────────────────────
# Location: skills/rebuild-index/scripts/ (3 levels inside plugin root)
$rebuildIndexDir = Split-Path $PSScriptRoot -Parent     # rebuild-index/
$skillsDir       = Split-Path $rebuildIndexDir -Parent  # skills/
$pluginRoot      = Split-Path $skillsDir -Parent        # wilma/
$pluginsDir      = Split-Path $pluginRoot -Parent       # plugins/
$dotClaudeDir    = Split-Path $pluginsDir -Parent       # .claude/
$workspace       = Split-Path $dotClaudeDir -Parent     # workspace root

$settingsFile = Join-Path $dotClaudeDir "wilma.local.md"
if (Test-Path $settingsFile) {
    $content = Get-Content $settingsFile -Raw
    if ($content -match '(?m)^workspace_root:\s*["'']?([^"''\r\n]+)["'']?\s*$') {
        $r = $Matches[1].Trim()
        if (Test-Path $r) { $workspace = $r }
    }
}

# ── Load config ───────────────────────────────────────────────────────────────
$configOverride = Join-Path $dotClaudeDir "plugins\simple-filekeeper\filekeeper-rules.json"
$configDefault  = Join-Path $pluginRoot "config\filekeeper-rules.default.json"
$configPath     = if (Test-Path $configOverride) { $configOverride } else { $configDefault }

if (-not (Test-Path $configPath)) {
    Write-Warning "rebuild-file-index: config not found at $configPath"
    exit 1
}

$config       = Get-Content $configPath -Raw | ConvertFrom-Json
$indexPath    = Join-Path $workspace $config.index_path
$excludeDirs  = $config.exclude_dirs
$excludePaths = $config.exclude_paths
$exemptFiles  = $config.index_exempt_files

$today = Get-Date -Format "yyyy-MM-dd"

# ── Collect all files ─────────────────────────────────────────────────────────
$allFiles = Get-ChildItem -Path $workspace -Recurse -File | Where-Object {
    $rel = $_.FullName.Substring($workspace.Length + 1).Replace('\', '/')
    $top = $rel.Split('/')[0]

    if ($top -in $excludeDirs) { return $false }
    if ($_.Name -in $exemptFiles) { return $false }
    foreach ($ep in $excludePaths) {
        if ($rel.StartsWith($ep)) { return $false }
    }
    return $true
} | Sort-Object FullName

$groups = $allFiles | Group-Object {
    $rel   = $_.FullName.Substring($workspace.Length + 1).Replace('\', '/')
    $parts = $rel.Split('/')
    if ($parts.Count -gt 1) { $parts[0] } else { "root" }
}

# ── Build index content ───────────────────────────────────────────────────────
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# SIGAIFA File Index")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("> Auto-maintained. Updated by PostToolUse hook (incremental-append) on every Write/Edit.")
[void]$sb.AppendLine("> When looking for a file: check this index first. If not found, scan resources/ for new manual downloads.")
[void]$sb.AppendLine("> Last full rebuild: $today")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Index")

foreach ($group in ($groups | Sort-Object Name)) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("### $($group.Name)/")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Path | Description |")
    [void]$sb.AppendLine("| ---- | ----------- |")
    foreach ($file in ($group.Group | Sort-Object FullName)) {
        $rel = $file.FullName.Substring($workspace.Length + 1).Replace('\', '/')
        [void]$sb.AppendLine("| [$rel]($rel) | |")
    }
}

[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Missing from Index?")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("1. Run verify-file-index.ps1 (full scan + auto-append)")
[void]$sb.AppendLine("2. Or use the rebuild-index skill to full-rebuild from scratch")

$sb.ToString() | Set-Content -Path $indexPath -Encoding UTF8
Write-Host "FILE-INDEX.md rebuilt: $($allFiles.Count) files indexed."
