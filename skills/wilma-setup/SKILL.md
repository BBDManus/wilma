---
name: "wilma-setup"
description: "This skill should be used when the user invokes /wilma-setup, says 'set up wilma', 'configure wilma', 'initialize wilma', 'update wilma settings', 'change worklog path', 'wilma not configured', or wants to run or re-run the wilma setup wizard. Also trigger when the user wants to change any wilma setting or path (e.g. 'change my worklog path', 'update the file index path', 'point wilma at a different folder', 'reconfigure wilma', 'wilma settings', 'change wilma config', 'update wilma paths')."
allowed-tools: ["Read", "Write", "Bash", "Glob"]
version: "1.2.0"
---

# Wilma Setup

Interactive guided setup wizard for the wilma plugin. Asks all required configuration questions, writes config files, enables the plugin in settings.json, gitignores the local config, and creates any missing workspace files. Re-entrant — safe to run any time to update a single setting or reconfigure fully.

---

## Overview

Run four phases in order. Do not write any files before Phase 4.

1. **Phase 1** — Load existing config, ask core questions (paths + scope + depth)
2. **Phase 2** — Ask governance paths, behaviour settings, and frontmatter/worklog config (full depth only)
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
- `exclude_dirs`
- `exclude_paths`
- `index_exempt_files`
- `index_behavior_mode`
- `index_missing_action`
- `stale_days`
- `scan_paths`
- `weekly_review_exclude_paths`
- `new_file_window_days`
- `orphan_pool_header`
- `frontmatter_fields`
- `frontmatter_template_path`
- `worklog_tracked_fields`

If the file does not exist, use these defaults:

| Field | Default |
| ----- | ------- |
| `worklog_path` | `wilma/worklog.md` |
| `index_path` | `wilma/file-index.md` |
| `backlog_path` | `wilma/backlog.md` |
| `outcomes_path` | `wilma/outcomes.md` |
| `work_registry_path` | `wilma/work-registry.md` |
| `report_output_dir` | `wilma/reports` |
| `exclude_dirs` | `[".claude", ".git", "wilma"]` |
| `exclude_paths` | `[]` |
| `index_exempt_files` | `[]` |
| `index_behavior_mode` | `incremental` |
| `index_missing_action` | `warn_and_exit` |
| `stale_days` | `14` |
| `scan_paths` | `["wilma/"]` |
| `weekly_review_exclude_paths` | `["wilma/worklog.md", "wilma/file-index.md", "wilma/reports"]` |
| `new_file_window_days` | `7` |
| `orphan_pool_header` | `## Orphaned Pool` |
| `frontmatter_fields` | `[]` |
| `frontmatter_template_path` | `""` |
| `worklog_tracked_fields` | `[]` |

### Step 2: Ask core questions

Use AskUserQuestion with these four questions. Show current/default value in brackets in each question text:

- Q1: "Worklog file path? (current: `{worklog_path}`)"
  - Options: current value | `wilma/worklog.md` | Other
- Q2: "File index path? (current: `{index_path}`)"
  - Options: current value | `wilma/file-index.md` | Other
- Q3: "Enable wilma for this project only, or globally for all projects?"
  - Options: Project only (`.claude/settings.json`) | Global (`~/.claude/settings.json`)
- Q4: "Setup depth?"
  - Options: Minimal — write wilma.local.md + settings.json only | Full — also scaffold governance files and configure behaviour settings

Store answers:
- `worklog_path` — Q1 answer; if blank keep current/default
- `index_path` — Q2 answer; if blank keep current/default
- `settings_scope` — `project` or `global`
- `config_depth` — `minimal` or `full`

Strip any leading `./` from path values before storing.

---

## Phase 2 — Governance Paths + Behaviour + Frontmatter Settings (full depth only)

**Skip this phase if `config_depth == minimal`.** Set all governance, behaviour, and frontmatter fields to their defaults silently.

**If `config_depth == full`**, ask in three batches:

### Batch A — Governance paths (show current/default in brackets):

- Q1: "Backlog file path? (current: `{backlog_path}`)"
- Q2: "Outcomes file path? (current: `{outcomes_path}`)"
- Q3: "Work registry file path? (current: `{work_registry_path}`)"
- Q4: "Report output directory? (current: `{report_output_dir}`)"

### Batch B — Behaviour settings:

- Q1: "Directories to exclude from file index? Comma-separated. (current: `{exclude_dirs}`)"
  - Options: current value | `.claude, .git, wilma` | Other
- Q2: "Paths to scan during weekly review? Comma-separated. (current: `{scan_paths}`)"
  - Options: current value | `wilma/` | Other
- Q3: "Days before a file is considered stale in weekly review? (current: `{stale_days}`)"
  - Options: current value | `14` | Other
- Q4: "Days window for 'new file' detection in weekly review? (current: `{new_file_window_days}`)"
  - Options: current value | `7` | Other

### Batch C — Frontmatter and worklog field config:

Ask Q1 first; the answer determines whether to ask Q2.

- Q1: "How should weekly-review determine if a file's frontmatter is complete?"
  - Options:
    - `None — just check that a frontmatter block exists` — no field list configured; files with any frontmatter block pass, files with no block are unclassified
    - `Specify fields — I'll type the required field names` — ask Q2 (inline list)
    - `Use a template file — point to a .md file in my workspace` — ask Q2 (file path)

- Q2 (if "Specify fields"):
  - "Which frontmatter fields are required? Comma-separated. (current: `{frontmatter_fields}`)"
  - Store as `frontmatter_fields` array; set `frontmatter_template_path` = `""`

- Q2 (if "Use a template file"):
  - "Path to a .md file whose frontmatter keys define the required field set? (current: `{frontmatter_template_path}`)"
  - Store as `frontmatter_template_path`; set `frontmatter_fields` = `[]`
  - Validate: attempt to Read the file. If not found, warn and keep the previous value (or blank if first setup).

- Q3: "Which frontmatter fields should the worklog capture per file write? Comma-separated. Leave blank to capture none. (current: `{worklog_tracked_fields}`)"
  - Options: current value | blank (none) | Other
  - Store as `worklog_tracked_fields` array

**Dependency note:** If `worklog_tracked_fields` is non-empty, the worklog header row must include those fields as extra columns. This is handled in Phase 4.3 when creating `worklog.md`.

Blank answer = keep current/default value. Strip leading `./` from all path values.

For comma-separated array inputs, split on `,`, trim whitespace from each element, store as array.

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
workspace_root: ""
worklog_path: "{worklog_path}"
index_path: "{index_path}"
backlog_path: "{backlog_path}"
outcomes_path: "{outcomes_path}"
work_registry_path: "{work_registry_path}"
report_output_dir: "{report_output_dir}"
exclude_dirs: {exclude_dirs_as_json_array}
exclude_paths: {exclude_paths_as_json_array}
index_exempt_files: {index_exempt_files_as_json_array}
index_behavior_mode: "{index_behavior_mode}"
index_missing_action: "{index_missing_action}"
stale_days: {stale_days}
scan_paths: {scan_paths_as_json_array}
weekly_review_exclude_paths: {weekly_review_exclude_paths_as_json_array}
new_file_window_days: {new_file_window_days}
orphan_pool_header: "{orphan_pool_header}"
frontmatter_fields: {frontmatter_fields_as_json_array}
frontmatter_template_path: "{frontmatter_template_path}"
worklog_tracked_fields: {worklog_tracked_fields_as_json_array}
---

# wilma local settings

Per-project configuration for the wilma plugin. This file is gitignored — do not commit it.
Edit values here or re-run /wilma-setup to update settings.
```

Write arrays as inline JSON arrays, e.g. `[".claude", ".git", "wilma"]`. Always write all fields even if minimal depth — all defaults are stored for future use.

### 4.2 Write `settings.json` (enabledPlugins)

Determine target path:
- Project scope: `.claude/settings.json`
- Global scope: resolve home dir via `Bash("echo $env:USERPROFILE")` on Windows or `Bash("echo $HOME")` on Unix. Target: `{home}/.claude/settings.json`

Read existing file if present. If absent, treat existing content as `{}`.

Parse the JSON. Add or update: `enabledPlugins["wilma@bonkers"] = true`. Preserve ALL other keys exactly.

**Guard:** If `"wilma@bonkers": true` already exists, skip this write and note "already enabled — no change".

**Guard:** If existing file content is not valid JSON, do NOT overwrite. Report: "Could not parse settings.json at `{path}`. Check for JSON syntax errors and re-run setup." Then continue with remaining steps.

Write the merged JSON back.

### 4.3 Create approved workspace files

For each path in `files_to_create`:

1. Run `mkdir -p "$(dirname "{path}")"` via Bash to create parent directory.
2. Read the appropriate template section from `$CLAUDE_PLUGIN_ROOT/skills/wilma-setup/references/file-templates.md`.
3. Replace `{TODAY}` with current date in `YYYY-MM-DD` format.
4. **Special case — `worklog.md`**: Build the header row dynamically. Base columns are always: `Date | Time | Tool | File/Command | Action | Project | Description`. If `worklog_tracked_fields` is non-empty, append one column per field in order. Write this dynamic header instead of the static template header.
5. Write the file.

For `report_output_dir` type (directory): run `mkdir -p "{report_output_dir}"` only — no file to write.

Skip any file that already exists at write time (race condition guard).

### 4.4 Update `.gitignore`

Read existing `.gitignore` at workspace root (treat as empty string if missing).

Check if `.claude/wilma.local.md` already appears as a line. If not, append it.

Write `.gitignore` back (or create it if it didn't exist).

### 4.5 Summary report

Print a summary:

```
## Wilma Setup Complete

Config files written:
- .claude/wilma.local.md
- {settings_path} (enabledPlugins updated / already enabled)

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

- Phase 1 loads all existing values from `.claude/wilma.local.md` and shows them as current defaults
- User changes only the fields they want (blank = keep current)
- Phase 3 only asks about files that are still missing
- Phase 4.1 rewrites `.claude/wilma.local.md` with the full merged set of values
- Phase 4.2 skips settings.json if `wilma@bonkers` already enabled
- Phase 4.4 skips .gitignore entry if already present
- Summary clearly notes what changed vs what was skipped

---

## Edge Cases

- Blank answer to path question: keep the current/default value
- Path with leading `./`: strip before storing
- Comma-separated array input: split on `,`, trim each element
- `frontmatter_template_path` file not found: warn user, keep previous value, continue
- settings.json with invalid JSON: skip that write, report error, continue
- `wilma@bonkers` already in settings.json: skip, note in summary
- File already exists at write time: skip, note in summary
- Global scope on Windows: use `$env:USERPROFILE` in Bash to resolve home directory
- `worklog.md` already exists when `worklog_tracked_fields` changes: warn user that the existing header does not match the new field config — they should update it manually or delete the file and re-run setup
