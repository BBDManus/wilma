# Hook: verify-file-index.ps1
# Trigger: PostToolUse (Glob, Grep, Read)
# Purpose: Detect files on disk absent from FILE-INDEX.md and auto-patch missing entries.

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

$indexPath    = Join-Path $workspace $indexRelPath
$excludePaths = Read-YamlArray "exclude_paths"      $content
$exemptFiles  = Read-YamlArray "index_exempt_files" $content

if ($null -eq $excludePaths) {
    Write-Error "wilma: exclude_paths not found in wilma.local.md. Re-run /wilma-setup to repair config."
    exit 1
}
if ($null -eq $exemptFiles) { $exemptFiles = @() }

if (-not (Test-Path $indexPath)) {
    Write-Warning "File index not found at $indexPath. Run /wilma:rebuild-index first."
    exit 1
}

$indexContent = Get-Content $indexPath -Raw

# ── Find files on disk not in index ───────────────────────────────────────────
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

$missing = $diskFiles | Where-Object { $indexContent -notlike "*$_*" }

if ($missing.Count -eq 0) {
    Write-Host "File index verified: no missing entries."
    exit 0
}

Write-Warning "FILE-INDEX.md missing $($missing.Count) file(s). Triggering update..."
foreach ($m in $missing) {
    Write-Warning "  Missing: $m"
}

# ── Delegate to update-file-index.ps1 ─────────────────────────────────────────
$updateScript = Join-Path $PSScriptRoot "update-file-index.ps1"
& $updateScript
Write-Host "Index updated: missing entries appended."
