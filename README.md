# wilma

Passive workspace maintenance for markdown workspaces. wilma keeps your file index and worklog current automatically via PostToolUse hooks, and provides on-demand governance review and reporting skills. Works with both local and global (marketplace) plugin installations.

---

## Features

| Feature | How it works |
| ------- | ------------ |
| **File index** | PostToolUse hooks keep `FILE-INDEX.md` current via incremental-append on every Write/Edit. A verify hook runs on Glob/Grep/Read to catch anything missed. |
| **Worklog capture** | PostToolUse hook auto-logs every Write, Edit, and Bash call to `worklog.md` with timestamp, tool, file, and project folder. |
| **Manual worklog** | `/worklog-add <description>` skill for entries not auto-captured (meetings, decisions, research). |
| **Activity report** | `/worklog-report` skill generates a weekly markdown summary with trends, top files, and improvement suggestions. |
| **Governance review** | `/weekly-review` skill scans workspace for orphaned, stale, and unclassified files; proposes backlog additions. |
| **Index rebuild** | `/wilma:rebuild-index` skill for full FILE-INDEX.md rebuilds from scratch, gated with a safety confirmation. |

---

## Installation

### 1. Install the plugin

**Local (project-level):** Copy the plugin to `.claude/plugins/wilma/` in your workspace root.

**Global (marketplace):** Install via the bonkers marketplace. Claude Code downloads the plugin to the user-level cache automatically.

### 2. Enable the plugin

Add the plugin to your `settings.json` (project-level at `.claude/settings.json`, or user-level at `C:\Users\{user}\.claude\settings.json`):

```json
{
  "enabledPlugins": {
    "wilma@bonkers": true
  }
}
```

When enabled, Claude Code automatically registers all hooks defined in `hooks/hooks.json` — **you do not need to add hook entries to settings.json manually**. Restart Claude Code after enabling for hooks to take effect.

---

## Configuration

### Workspace settings (optional)

Copy `wilma.local.md.template` to `.claude/wilma.local.md` to override defaults:

```yaml
---
workspace_root: ""
worklog_path: "workshop/worklog.md"
---
```

- `workspace_root`: Leave blank for auto-detection (recommended). Set explicitly only if the plugin is not installed at the standard path or if `$CLAUDE_PROJECT_DIR` is not being set by your environment.
- `worklog_path`: Path to worklog file, relative to workspace root.

### Filekeeper config override

To customise file index rules, create `.claude/plugins/simple-filekeeper/filekeeper-rules.json`. Plugin defaults are at `config/filekeeper-rules.default.json`.

### Weekly review config override

To customise governance scan rules, create `.claude/plugins/worklog/weekly-review-rules.json`. Plugin defaults are at `config/weekly-review-rules.default.json`.

Config fields (weekly review):

| Field | Purpose |
| ----- | ------- |
| `paths.*` | Workspace-relative paths for backlog, outcomes, work-registry, worklog, report output |
| `stale_rules.by_phase` | Stale thresholds per phase (days) |
| `scan_paths` | Directories to scan for governance review |
| `exclude_paths` | Directories excluded from scan |
| `new_file_window_days` | Days window for "new this week" classification |

---

## Skills Reference

| Skill | Slash command | What it does |
| ----- | ------------- | ------------ |
| `wilma-setup` | `/wilma-setup` | Interactive setup wizard. Asks all configuration questions, writes `.claude/wilma.local.md`, enables `wilma@bonkers` in `settings.json`, gitignores local config, optionally scaffolds governance config overrides, and creates missing workspace files. Re-entrant — safe to run any time to update settings. |
| `simple-filekeeper` | (internal) | Reference skill documenting how FILE-INDEX.md maintenance works, exemption rules, and the file lookup workflow. Used for troubleshooting the index. |
| `worklog-add` | `/worklog-add <description>` | Appends a manual entry to `worklog.md` with timestamp and project inference. Use for work not auto-captured by hooks (meetings, decisions, research). |
| `worklog-report` | `/worklog-report` | Reads `worklog.md` and generates a weekly activity report: activity by day/tool/project, top files touched, and 3–5 improvement suggestions. |
| `weekly-review` | `/weekly-review` | Scans workspace markdown files for orphaned (missing outcome linkage), stale (no updates past threshold), and unclassified (no frontmatter) files. Proposes backlog additions and outcome suggestions. |
| `rebuild-index` | `/wilma:rebuild-index` | Fully rebuilds `FILE-INDEX.md` from scratch by scanning all workspace files. Safety-gated: requires typing `CONFIRM` before proceeding. Destroys manually-written descriptions — only use when index is corrupt or after bulk reorganisation. |

---

## Hooks Reference

Hooks are registered automatically when the plugin is enabled. All hook commands use `$CLAUDE_PLUGIN_ROOT`, which the Claude Code harness substitutes at execution time.

**What `$CLAUDE_PLUGIN_ROOT` resolves to:**

- Local install: `{workspace}/.claude/plugins/wilma`
- Global/marketplace install: `C:\Users\{user}\.claude\plugins\cache\bonkers\wilma\{sha}`

You do not set this variable — the harness sets it automatically based on where the plugin is installed.

**Workspace root resolution:** Hook scripts use `$CLAUDE_PROJECT_DIR` (provided by the harness) as the primary workspace root source. This ensures worklog and file index are always written to the current project, not the plugin cache, regardless of whether the plugin is installed locally or globally. A `$PSScriptRoot` walk-up serves as fallback for environments where `$CLAUDE_PROJECT_DIR` is not set.

| Script | Fires when | What it does |
| ------ | ---------- | ------------ |
| `update-file-index.ps1` | PostToolUse: Write, Edit | Checks which files were written/edited and appends any not yet in `FILE-INDEX.md`. Incremental only — never rewrites existing entries or descriptions. |
| `verify-file-index.ps1` | PostToolUse: Glob, Grep, Read | Scans all workspace files against `FILE-INDEX.md`. If any are missing, delegates to `update-file-index.ps1` to patch them. Catches files added outside Claude sessions. |
| `append-worklog.ps1` | PostToolUse: Write, Edit, Bash | Appends one timestamped row to `worklog.md` for every file write, edit, or bash command. Self-referential guard prevents logging worklog.md writes themselves. |

---

## Path Resolution

Hook scripts resolve workspace root in priority order:

1. `$CLAUDE_PROJECT_DIR` — set by the Claude Code harness (works for local and global installs)
2. `$PSScriptRoot` walk-up — fallback for local installs (`{workspace}/.claude/plugins/wilma/hooks/scripts/` → 5 levels up)
3. `workspace_root` in `.claude/wilma.local.md` — manual override for non-standard layouts

`$CLAUDE_PLUGIN_ROOT` (used in `hooks/hooks.json` command strings) resolves to the plugin's installed directory, separate from the workspace root.

---

## Frontmatter Standard

`weekly-review` enforces the following frontmatter fields:

```yaml
---
title: ""
type: skill | agent | plugin | guide | template | prompt | research | design | draft
phase: discover | define | develop | deliver
version: "0.1.0"
author: ""
created: YYYY-MM-DD
updated: YYYY-MM-DD
project: ""
outcome: "O-XXX"
confluence_page: ""
---
```

Files missing frontmatter are **Unclassified**. Files with frontmatter but no valid `outcome` are **Orphaned**. Both surface in `/weekly-review`.
