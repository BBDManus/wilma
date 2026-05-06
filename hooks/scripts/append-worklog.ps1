# Hook: append-worklog.ps1
# Trigger: PostToolUse (Write|Edit|Bash)
# Purpose: Append one row to worklog.md for every file write or bash command.

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

$worklogRelPath = "wilma/worklog.md"

$settingsContent = Get-Content $settingsFile -Raw
if ($settingsContent -match '(?m)^workspace_root:\s*["'']?([^"''\r\n]+)["'']?\s*$') {
    $r = $Matches[1].Trim()
    if ($r -ne "" -and (Test-Path $r)) { $workspace = $r }
}
if ($settingsContent -match '(?m)^worklog_path:\s*["'']?([^"''\r\n]+)["'']?\s*$') {
    $worklogRelPath = $Matches[1].Trim()
}

$worklogPath = Join-Path $workspace ($worklogRelPath -replace '/', '\')

if (-not (Test-Path $worklogPath)) {
    Write-Warning "worklog.md not found at $worklogPath. Create it first."
    exit 1
}

# ── Parse stdin ───────────────────────────────────────────────────────────────
$raw = $input | Out-String
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

try {
    $data = $raw | ConvertFrom-Json
} catch {
    Write-Warning "append-worklog: failed to parse stdin JSON."
    exit 0
}

$toolName   = $data.tool_name
$toolInput  = $data.tool_input
$filePath   = ""
$actionType = ""
$description = ""

switch ($toolName) {
    "Write" {
        $filePath    = $toolInput.file_path
        $actionType  = "write"
        $description = "Wrote $($filePath | Split-Path -Leaf)"
    }
    "Edit" {
        $filePath    = $toolInput.file_path
        $actionType  = "edit"
        $description = "Edited $($filePath | Split-Path -Leaf)"
    }
    "Bash" {
        $cmd = $toolInput.command
        if ($cmd -like "*worklog.md*") { exit 0 }
        $short = if ($cmd.Length -gt 60) { $cmd.Substring(0, 60) + "..." } else { $cmd }
        $filePath    = $short
        $actionType  = "bash"
        $description = "Bash: $short"
    }
    default { exit 0 }
}

# Self-referential guard
if ($filePath -like "*worklog.md*") { exit 0 }

# ── Infer project folder ──────────────────────────────────────────────────────
$projectFolder = "_root"
$normalised = $filePath -replace '\\', '/'
if ($normalised -match '^workshop/([^/]+)/') {
    $projectFolder = $Matches[1]
}

# ── Build and append row ──────────────────────────────────────────────────────
$now  = Get-Date
$date = $now.ToString("yyyy-MM-dd")
$time = $now.ToString("HH:mm")

$safeFile = $filePath -replace '\|', '/'
$safeDesc = $description -replace '\|', '-'

$row = "| $date | $time | $toolName | $safeFile | $actionType | $projectFolder | $safeDesc |"

Add-Content -Path $worklogPath -Value $row -Encoding UTF8
Write-Host "worklog: logged $toolName on $safeFile"
exit 0
