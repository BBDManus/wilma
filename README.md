# wilma

Passive workspace maintenance for Claude Code. wilma keeps a file index and worklog current automatically, and provides on-demand governance review and activity reporting — all from a single config file.

## What it does

| Feature | Description |
| ------- | ----------- |
| **File index** | Automatically tracks every file in your workspace. Updated on every write and edit, verified on every search. |
| **Worklog** | Logs every write, edit, and bash command with timestamp, file, and project. Runs silently in the background. |
| **Activity report** | `/worklog-report` — weekly summary with activity by day, tool, and project; top files touched; improvement suggestions. |
| **Governance review** | `/weekly-review` — scans for orphaned, stale, and unclassified files; proposes backlog additions. |
| **Manual log entry** | `/worklog-add <description>` — log meetings, decisions, or research not captured automatically. |
| **Index rebuild** | `/wilma:rebuild-index` — full rebuild from scratch when the index is corrupt or out of date. |

## Getting started

### 1. Enable the plugin

Add wilma to your `settings.json`:

```json
{
  "enabledPlugins": {
    "wilma@bonkers": true
  }
}
```

Use `.claude/settings.json` for a single project, or `~/.claude/settings.json` to enable globally. Restart Claude Code after enabling.

### 2. Run setup

```text
/wilma-setup
```

The setup wizard asks for your file paths and preferences, writes `.claude/wilma.local.md`, and creates any missing workspace files. Safe to re-run at any time to update settings.

## Configuration

All settings live in `.claude/wilma.local.md`. Run `/wilma-setup` to manage this file interactively, or copy `wilma.local.md.template` and edit manually.

Key settings:

| Field | Default | Purpose |
| ----- | ------- | ------- |
| `worklog_path` | `wilma/worklog.md` | Worklog file location |
| `index_path` | `wilma/file-index.md` | File index location |
| `scan_paths` | `["wilma/"]` | Directories scanned by weekly review |
| `stale_days` | `14` | Days without update before a file is flagged as stale |
| `outcome_field` | `outcome` | Frontmatter field used to link files to outcomes |
| `frontmatter_fields` | `[]` | Required frontmatter fields; files missing any are flagged as incomplete |
| `frontmatter_template_path` | `""` | Path to a `.md` file whose frontmatter keys define the required field set |
| `worklog_tracked_fields` | `[]` | Frontmatter fields extracted per file write and added as extra worklog columns |

## Frontmatter

wilma does not enforce a frontmatter schema. You define what fields matter for your workspace during `/wilma-setup`.

Set `outcome_field` to the field name your files use to link to an outcome or goal (default: `outcome`). Weekly review uses this field to detect orphaned files and hollow outcomes. Set it to blank to disable outcome linkage entirely.

Use `frontmatter_fields` or `frontmatter_template_path` to tell weekly review which fields are required. Files missing any required field are flagged as incomplete. Leave both blank to only check for the presence of a frontmatter block.

## Skills

| Command | What it does |
| ------- | ------------ |
| `/wilma-setup` | Interactive setup wizard — configure paths, frontmatter rules, and worklog tracking |
| `/worklog-add <description>` | Append a manual worklog entry |
| `/worklog-report` | Generate a weekly activity report |
| `/weekly-review` | Governance scan — orphaned, stale, and unclassified files |
| `/wilma:rebuild-index` | Full file index rebuild (destructive — requires confirmation) |
