---
name: "simple-filekeeper"
description: "This skill should be used when asked about FILE-INDEX.md, how the file index works, why a file is or isn't in the index, file index maintenance, missing index entries, how to rebuild the index, or when troubleshooting the file index. Also loaded when asked to look up a file in the workspace."
version: "1.1.0"
---

# Simple Filekeeper

Maintains the file index automatically via PostToolUse hooks. Incremental-append only — never rebuilds unless explicitly triggered by the rebuild-index skill.

## How It Works

Two PostToolUse hooks keep the index current:

| Hook script | Triggers on | Action |
| ----------- | ----------- | ------ |
| `update-file-index.ps1` | Write, Edit | Appends any new files not yet in the index |
| `verify-file-index.ps1` | Glob, Grep, Read | Scans for files on disk absent from index; calls update if any found |

Manual full rebuild available via the `rebuild-index` skill. Never runs automatically — it destroys manual descriptions.

## Configuration

All config is read from `.claude/wilma.local.md` (YAML frontmatter). If the file or a field is absent, built-in defaults apply.

| Field | Default | Purpose |
| ----- | ------- | ------- |
| `index_path` | `wilma/file-index.md` | Relative path to the index file |
| `exclude_paths` | `[".claude/", ".git/", "wilma/"]` | Paths excluded from indexing — matched as prefix against each file's relative path. Use trailing `/` to exclude a directory and all its contents. |
| `index_exempt_files` | `[]` | Files never added to index |
| `index_behavior_mode` | `incremental` | Update mode — `incremental` = append-only, never rewrites |
| `index_missing_action` | `warn_and_exit` | Behaviour when index file is missing at hook time |

## Exemption Rules

Files excluded from the index when **any** of the following match:

1. Relative path starts with any entry in `exclude_paths`
2. Filename matches any entry in `index_exempt_files`

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

1. Check the file index first
2. If not found → Glob search for filename pattern
3. If Glob finds matches → show user results, ask for confirmation
4. User confirms → add entry to file index for future queries
5. If still not found → check `resources/` for manually downloaded files

## Missing Entries

If a file is missing from the index:

- Normal cause: file was added outside of a Claude session (manually, bulk copy, git pull)
- Fix: the next Glob/Grep/Read hook run will detect and patch it automatically
- Immediate fix: ask Claude to search for the file — this triggers verify-file-index

To rebuild from scratch (destroys manual descriptions): use the `rebuild-index` skill.

## Workspace Settings

All settings are stored in `.claude/wilma.local.md`. Run `/wilma-setup` to configure or update them.
