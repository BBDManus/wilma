# Script: rebuild-file-index.ps1
# Purpose: Full rebuild of FILE-INDEX.md from scratch.
# WARNING: Destroys all manually-written descriptions. Run only when needed.
# Normal operation uses update-file-index.ps1 (incremental-append).
# Invoked by the rebuild-index skill after user confirmation.

# ── Resolve workspace root ────────────────────────────────────────────────────
# Priority: workspace_root from config > $CLAUDE_PROJECT_DIR > walk-up fallback.
# workspace_root is written by /wilma-setup and is the authoritative source.
if ($env:CLAUDE_PROJECT_DIR -and (Test-Path $env:CLAUDE_PROJECT_DIR)) {
    $workspace    = $env:CLAUDE_PROJECT_DIR
    $dotClaudeDir = Join-Path $workspace ".claude"
} else {
    # Location: skills/rebuild-index/scripts/ (3 levels inside plugin root)
    $rebuildIndexDir = Split-Path $PSScriptRoot -Parent     # rebuild-index/
    $skillsDir       = Split-Path $rebuildIndexDir -Parent  # skills/
    $pluginRoot      = Split-Path $skillsDir -Parent        # wilma/
    $pluginsDir      = Split-Path $pluginRoot -Parent       # plugins/
    $dotClaudeDir    = Split-Path $pluginsDir -Parent       # .claude/
    $workspace       = Split-Path $dotClaudeDir -Parent     # workspace root
}

# ── Load config from wilma.local.md ──────────────────────────────────────────
$settingsFile = Join-Path $dotClaudeDir "wilma.local.md"
if (-not (Test-Path $settingsFile)) {
    Write-Error "wilma: not configured. Run /wilma-setup in Claude Code to get started."
    exit 1
}

$content = Get-Content $settingsFile -Raw

# workspace_root in config always wins — set by /wilma-setup at project scope.
if ($content -match '(?m)^workspace_root:\s*["'']?([^"''\r\n]+)["'']?\s*$') {
    $r = $Matches[1].Trim()
    if ($r -ne "" -and (Test-Path $r)) {
        $workspace    = $r
        $dotClaudeDir = Join-Path $workspace ".claude"
    }
}

# index_path
$indexRelPath = "wilma/file-index.md"
if ($content -match '(?m)^index_path:\s*["'']?([^"''\r\n]+)["'']?\s*$') {
    $indexRelPath = $Matches[1].Trim()
}

# Returns parsed array if field present (even if empty), $null if field absent.
function Read-YamlArray {
    param([string]$fieldName, [string]$fileContent)
    if ($fileContent -match "(?m)^${fieldName}:\s*(\[.*?\])\s*$") {
        $raw = $Matches[1]
        $m   = [regex]::Matches($raw, '"([^"]*)"')
        if ($m.Count -gt 0) { return @($m | ForEach-Object { $_.Groups[1].Value }) }
        return @()
    }
    return $null
}

$excludePaths = Read-YamlArray "exclude_paths"      $content
$exemptFiles  = Read-YamlArray "index_exempt_files" $content

if ($null -eq $excludePaths) {
    Write-Error "wilma: exclude_paths not found in wilma.local.md. Re-run /wilma-setup to repair config."
    exit 1
}
if ($null -eq $exemptFiles) { $exemptFiles = @() }

# ── Build index ───────────────────────────────────────────────────────────────
$indexPath = Join-Path $workspace $indexRelPath
$today     = Get-Date -Format "yyyy-MM-dd"

$allFiles = Get-ChildItem -Path $workspace -Recurse -File | Where-Object {
    $rel = $_.FullName.Substring($workspace.Length + 1).Replace('\', '/')

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

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# File Index")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("> Auto-maintained by wilma. Updated on every Write/Edit.")
[void]$sb.AppendLine("> When looking for a file: check this index first.")
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
Write-Host "File index rebuilt: $($allFiles.Count) files indexed."
