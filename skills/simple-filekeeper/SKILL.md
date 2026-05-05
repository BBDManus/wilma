---
name: "Simple Filekeeper"
description: "This skill should be used when asked about FILE-INDEX.md, how the file index works, why a file is or isn't in the index, file index maintenance, missing index entries, how to rebuild the index, or when troubleshooting the file index. Also loaded when asked to look up a file in the workspace."
version: "1.0.0"
---

# Simple Filekeeper

Maintains `FILE-INDEX.md` automatically via PostToolUse hooks. Incremental-append only — never rebuilds unless explicitly triggered by the rebuild-index skill.

## How It Works

Two PostToolUse hooks keep the index current:

| Hook script | Triggers on | Action |
| ----------- | ----------- | ------ |
| `update-file-index.ps1` | Write, Edit | Appends any new files not yet in the index |
| `verify-file-index.ps1` | Glob, Grep, Read | Scans for files on disk absent from index; calls update if any found |

Manual full rebuild available via the `rebuild-index` skill. Never runs automatically — it destroys manual descriptions.

## Configuration

Config loads with workspace-override fallback:

1. `.claude/plugins/simple-filekeeper/filekeeper-rules.json` (workspace override — backward compatible)
2. `[plugin root]/config/filekeeper-rules.default.json` (plugin default)

Key config fields:

| Field | Purpose |
| ----- | ------- |
| `index_path` | Relative path to the index file (default: `FILE-INDEX.md`) |
| `exclude_dirs` | Top-level dirs never indexed (`.claude`, `.git`) |
| `exclude_paths` | Sub-paths exempt from indexing (`resources/tools`, `resources/scripts`) |
| `index_exempt_files` | Files never added to index (`FILE-INDEX.md` itself) |
| `behavior.mode` | `incremental` — only appends, never rewrites |

## Exemption Rules

Files excluded from the index when **any** of the following match:

1. Top-level folder is in `exclude_dirs`
2. Path starts with any entry in `exclude_paths`
3. Filename matches any entry in `index_exempt_files`

## Index Format

```markdown
### {folder}/

| Path | Description |
| ---- | ----------- |
| [relative/path/to/file.md](relative/path/to/file.md) | optional description |
```

Descriptions populated manually or by Claude when context is available. Hooks never overwrite existing descriptions.

## File Lookup Workflow

When looking for any file:

1. Check `FILE-INDEX.md` first
2. If not found → Glob search for filename pattern
3. If Glob finds matches → show user results, ask for confirmation
4. User confirms → add entry to FILE-INDEX for future queries
5. If still not found → check `resources/` for manually downloaded files

## Missing Entries

If a file is missing from the index:

- Normal cause: file was added outside of a Claude session (manually, bulk copy, git pull)
- Fix: the next Glob/Grep/Read hook run will detect and patch it automatically
- Immediate fix: ask Claude to search for the file — this triggers verify-file-index

To rebuild from scratch (destroys manual descriptions): use the `rebuild-index` skill.

## Workspace Settings

To override workspace root or worklog path, create `.claude/wilma.local.md` from the template at `[plugin root]/wilma.local.md.template`.
