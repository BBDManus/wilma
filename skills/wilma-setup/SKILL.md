---
name: "wilma-setup"
description: "This skill should be used when the user invokes /wilma-setup, says 'set up wilma', 'configure wilma', 'initialize wilma', 'update wilma settings', 'change worklog path', 'wilma not configured', or wants to run or re-run the wilma setup wizard."
allowed-tools: ["Read", "Write", "Bash", "Glob"]
version: "1.0.0"
---

# Wilma Setup

Interactive guided setup wizard for the wilma plugin. Asks all required configuration questions, writes config files, enables the plugin in settings.json, gitignores the local config, and creates any missing workspace files. Re-entrant — safe to run any time to update a single setting or reconfigure fully.

---

## Overview

Run four phases in order. Do not write any files before Phase 4.

1. **Phase 1** — Load existing config, ask core questions (paths + scope + depth)
2. **Phase 2** — Ask governance file paths (full depth only)
3. **Phase 3** — Detect missing workspace files, ask per-file whether to create them
4. **Phase 4** — Write all config and workspace files, update settings.json, update .gitignore

---

## Phase 1 — Load Existing Config + Core Questions

### Step 1: Load existing config

Attempt to Read `.claude/wilma.local.md`. If it exists, parse the YAML frontmatter block (between the first pair of `---` delimiters) and extract these fields as current values:

- `worklog_path`
- `index_path`
- `backlog_path`
- `outcomes_path`
- `work_registry_path`
- `report_output_dir`

If the file does not exist, use these defaults:

| Field | Default |
| ----- | ------- |
| `worklog_path` | `wilma/worklog.md` |
| `index_path` | `wilma/file-index.md` |
| `backlog_path` | `wilma/backlog.md` |
| `outcomes_path` | `wilma/outcomes.md` |
| `work_registry_path` | `wilma/work-registry.md` |
| `report_output_dir` | `wilma/reports` |

### Step 2: Ask core questions

Use AskUserQuestion with these four questions. Show current/default value in brackets in each question text:

- Q1: "Worklog file path? (current: `{worklog_path}`)"
  - Options: current value | `wilma/worklog.md` | Other
- Q2: "File index path? (current: `{index_path}`)"
  - Options: current value | `wilma/file-index.md` | Other
- Q3: "Enable wilma for this project only, or globally for all projects?"
  - Options: Project only (`.claude/settings.json`) | Global (`~/.claude/settings.json`)
- Q4: "Setup depth?"
  - Options: Minimal — write wilma.local.md + settings.json only | Full — also scaffold governance config files

Store answers:
- `worklog_path` — Q1 answer; if blank keep current/default
- `index_path` — Q2 answer; if blank keep current/default
- `settings_scope` — `project` or `global`
- `config_depth` — `minimal` or `full`

Strip any leading `./` from path values before storing.

---

## Phase 2 — Governance Paths (full depth only)

**Skip this phase if `config_depth == minimal`.** Set all four governance fields to their defaults silently:
- `backlog_path` = `wilma/backlog.md`
- `outcomes_path` = `wilma/outcomes.md`
- `work_registry_path` = `wilma/work-registry.md`
- `report_output_dir` = `wilma/reports`

**If `config_depth == full`**, ask these four questions (show current/default in brackets):

- Q1: "Backlog file path? (current: `{backlog_path}`)"
- Q2: "Outcomes file path? (current: `{outcomes_path}`)"
- Q3: "Work registry file path? (current: `{work_registry_path}`)"
- Q4: "Report output directory? (current: `{report_output_dir}`)"

Blank answer = keep current/default value. Strip leading `./` from all paths.

---

## Phase 3 — Missing File Detection

Build a required files list based on `config_depth`:

- Always required: `{worklog_path}`, `{index_path}`
- Also required if full: `{backlog_path}`, `{outcomes_path}`, `{work_registry_path}`, `{report_output_dir}` (directory)

For each file path, use Bash to check existence:

```bash
if [ -e "{path}" ]; then echo "exists"; else echo "missing"; fi
```

Collect all missing paths into a list. If none are missing, skip to Phase 4.

For each missing path, ask the user whether to create it. Batch up to 4 questions per AskUserQuestion call (may require two calls if 6 files are missing):

- Question: "Create `{path}`? It does not exist yet."
- Options: Yes — create it | No — skip

Store approved paths as `files_to_create`.

---

## Phase 4 — Write Everything

Execute all writes in this order. Report each completed action.

### 4.1 Write `.claude/wilma.local.md`

Run `mkdir -p .claude` via Bash first.

Write `.claude/wilma.local.md` with this exact structure (substitute actual values):

```text
---
worklog_path: "{worklog_path}"
index_path: "{index_path}"
backlog_path: "{backlog_path}"
outcomes_path: "{outcomes_path}"
work_registry_path: "{work_registry_path}"
report_output_dir: "{report_output_dir}"
---

# wilma local settings

Per-project configuration for the wilma plugin. This file is gitignored — do not commit it.
Edit values here or re-run /wilma-setup to update settings.
```

Always write all six fields even if minimal depth — governance path defaults are stored for future use.

### 4.2 Write `settings.json` (enabledPlugins)

Determine target path:
- Project scope: `.claude/settings.json`
- Global scope: resolve home dir via `Bash("echo $env:USERPROFILE")` on Windows or `Bash("echo $HOME")` on Unix. Target: `{home}/.claude/settings.json`

Read existing file if present. If absent, treat existing content as `{}`.

Parse the JSON. Add or update: `enabledPlugins["wilma@bonkers"] = true`. Preserve ALL other keys exactly.

**Guard:** If `"wilma@bonkers": true` already exists, skip this write and note "already enabled — no change".

**Guard:** If existing file content is not valid JSON, do NOT overwrite. Report: "Could not parse settings.json at `{path}`. Check for JSON syntax errors and re-run setup." Then continue with remaining steps.

Write the merged JSON back.

### 4.3 Write filekeeper config (full depth only)

Only if `config_depth == full`.

Read template from `$CLAUDE_PLUGIN_ROOT/skills/wilma-setup/references/file-templates.md` — use the `filekeeper-rules.json` inlined default section. Replace `{INDEX_PATH}` with `{index_path}`.

Run `mkdir -p .claude/plugins/simple-filekeeper` via Bash.

Write to `.claude/plugins/simple-filekeeper/filekeeper-rules.json`.

Skip if file already exists and ask user: "Overwrite existing filekeeper-rules.json?" (yes / no).

### 4.4 Write weekly-review config (full depth only)

Only if `config_depth == full`.

Read template from `$CLAUDE_PLUGIN_ROOT/skills/wilma-setup/references/file-templates.md` — use the `weekly-review-rules.json` inlined default section. Replace all path placeholders with configured values.

Run `mkdir -p .claude/plugins/worklog` via Bash.

Write to `.claude/plugins/worklog/weekly-review-rules.json`.

Skip if file already exists and ask user: "Overwrite existing weekly-review-rules.json?" (yes / no).

### 4.5 Create approved workspace files

For each path in `files_to_create`:

1. Run `mkdir -p "$(dirname "{path}")"` via Bash to create parent directory.
2. Read the appropriate template section from `$CLAUDE_PLUGIN_ROOT/skills/wilma-setup/references/file-templates.md`.
3. Replace `{TODAY}` with current date in `YYYY-MM-DD` format.
4. Write the file.

For `report_output_dir` type (directory): run `mkdir -p "{report_output_dir}"` only — no file to write.

Skip any file that already exists at write time (race condition guard).

### 4.6 Update `.gitignore`

Read existing `.gitignore` at workspace root (treat as empty string if missing).

Check if `.claude/wilma.local.md` already appears as a line. If not, append it.

Write `.gitignore` back (or create it if it didn't exist).

### 4.7 Summary report

Print a summary:

```
## Wilma Setup Complete

Config files written:
- .claude/wilma.local.md
- {settings_path} (enabledPlugins updated / already enabled)
[if full] - .claude/plugins/simple-filekeeper/filekeeper-rules.json
[if full] - .claude/plugins/worklog/weekly-review-rules.json

Workspace files created:
[list each file, or "none — all files already existed"]

.gitignore updated: .claude/wilma.local.md added

Next steps:
1. Restart Claude Code for hooks to take effect.
2. Run /worklog-add test to verify worklog capture works.
3. Run /weekly-review to verify governance scan paths are correct.
```

---

## Re-run Behaviour

When `/wilma-setup` is run on an already-configured workspace:

- Phase 1 loads existing values from `.claude/wilma.local.md` and shows them as current defaults
- User changes only the fields they want (blank = keep current)
- Phase 3 only asks about files that are still missing
- Phase 4.1 rewrites `.claude/wilma.local.md` with the full merged set of values
- Phase 4.2 skips settings.json if `wilma@bonkers` already enabled
- Phase 4.6 skips .gitignore entry if already present
- Summary clearly notes what changed vs what was skipped

---

## Edge Cases

- Blank answer to path question: keep the current/default value
- Path with leading `./`: strip before storing
- settings.json with invalid JSON: skip that write, report error, continue
- `wilma@bonkers` already in settings.json: skip, note in summary
- File already exists at write time: skip, note in summary
- Global scope on Windows: use `$env:USERPROFILE` in Bash to resolve home directory
