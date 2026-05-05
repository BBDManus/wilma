---
title: "wilma plugin"
type: plugin
phase: deliver
version: "1.0.0"
author: "manus@bbd.co.za"
created: 2026-05-05
updated: 2026-05-05
project: "workspace-tooling"
outcome: "O-003"
confluence_page: ""
---

# wilma

Passive workspace maintenance plugin for markdown workspaces. Keeps file index and worklog current automatically, and provides governance review on demand.

**Completely decoupled from workspace-workflow (Plugin B).** No phase-gate or Double Diamond dependencies.

---

## Features

| Feature | How it works |
| ------- | ------------ |
| **File index** | PostToolUse hooks keep `FILE-INDEX.md` current via incremental-append on every Write/Edit. Verify hook runs on Glob/Grep/Read to catch anything missed. |
| **Worklog capture** | PostToolUse hook auto-logs every Write, Edit, and Bash call to `worklog.md`. |
| **Manual worklog** | `/worklog-add <description>` skill for entries not auto-captured. |
| **Activity report** | `/worklog-report` skill generates a weekly markdown summary with trends and suggestions. |
| **Governance review** | `/weekly-review` skill scans workspace for orphaned, stale, and unclassified files. |
| **Index rebuild** | `/wilma:rebuild-index` skill for full rebuilds, gated with a safety confirmation. |

---

## Installation

This plugin is installed locally in the workspace at `.claude/plugins/wilma/`.

Enable it in Claude Code settings to activate hooks and skills. After enabling, **restart Claude Code** for hooks to take effect.

### Migrate from standalone hooks

If the workspace previously used standalone hooks in `.claude/settings.json`, remove those entries after enabling this plugin to avoid double-firing:

```json
// Remove these three entries from settings.json hooks.PostToolUse:
// - update-file-index.ps1
// - verify-file-index.ps1
// - append-worklog.ps1
```

---

## Configuration

### Workspace settings (optional)

Copy `wilma.local.md.template` to `.claude/wilma.local.md`:

```yaml
---
workspace_root: ""
worklog_path: "workshop/worklog.md"
---
```

- `workspace_root`: Leave blank for auto-detection (recommended). Set explicitly only if plugin is not installed at the standard `{workspace}/.claude/plugins/wilma/` path.
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

| Skill | Trigger | Purpose |
| ----- | ------- | ------- |
| `simple-filekeeper` | Internal reference | Documents how FILE-INDEX.md maintenance works |
| `worklog-add` | `/worklog-add <description>` | Manually append worklog entry |
| `worklog-report` | `/worklog-report` | Generate weekly activity report |
| `weekly-review` | `/weekly-review` | Workspace governance scan |
| `rebuild-index` | `/wilma:rebuild-index` | Full FILE-INDEX.md rebuild (safety-gated) |

---

## Hooks Reference

| Script | Trigger | Action |
| ------ | ------- | ------ |
| `update-file-index.ps1` | PostToolUse: Write, Edit | Incremental-append new files to FILE-INDEX.md |
| `verify-file-index.ps1` | PostToolUse: Glob, Grep, Read | Detect missing index entries; calls update |
| `append-worklog.ps1` | PostToolUse: Write, Edit, Bash | Append one row to worklog.md |
| `rebuild-file-index.ps1` | Manual only (via rebuild-index skill) | Full rebuild of FILE-INDEX.md from scratch |

---

## Path Resolution

Hook scripts derive workspace root automatically by walking up from `$PSScriptRoot`:

```
{workspace}/.claude/plugins/wilma/hooks/scripts/
     ^─────────────────────────────────────────────────────────── 5 levels up
```

An explicit override can be set in `.claude/wilma.local.md`.

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
