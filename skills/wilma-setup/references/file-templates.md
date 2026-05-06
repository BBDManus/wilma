# File Templates

Template content for each workspace file the wilma-setup wizard can create.
Replace `{TODAY}` with current date in `YYYY-MM-DD` format before writing.
Do not include the outer markdown fences when writing file content — they are display-only here.

---

## worklog.md

```text
| Date | Time | Tool | File/Command | Action | Project | Description |
| ---- | ---- | ---- | ------------ | ------ | ------- | ----------- |
```

---

## file-index.md

```text
# File Index

> Auto-maintained by wilma. Updated on every Write/Edit.
> When looking for a file: check this index first.

## Index
```

---

## backlog.md

```text
---
title: "Backlog"
type: guide
phase: discover
version: "0.1.0"
author: ""
created: {TODAY}
updated: {TODAY}
project: ""
outcome: ""
confluence_page: ""
---

# Backlog

## Active

## Orphaned & Stale Work
```

---

## outcomes.md

```text
---
title: "Outcomes"
type: guide
phase: define
version: "0.1.0"
author: ""
created: {TODAY}
updated: {TODAY}
project: ""
outcome: ""
confluence_page: ""
---

# Outcomes

## Outcomes Register

| ID | Title | Phase | Status |
| -- | ----- | ----- | ------ |
```

---

## work-registry.md

```text
---
title: "Work Registry"
type: guide
phase: define
version: "0.1.0"
author: ""
created: {TODAY}
updated: {TODAY}
project: ""
outcome: ""
confluence_page: ""
---

# Work Registry

## Registry

## Orphaned Pool

| File | Last Updated | Notes |
| ---- | ------------ | ----- |
```

---

## filekeeper-rules.json (inlined default)

Use when writing `.claude/plugins/simple-filekeeper/filekeeper-rules.json`.
Replace `{INDEX_PATH}` with the user's configured `index_path` value.

```json
{
  "skill": "simple-filekeeper",
  "version": "1.0.0",
  "index_path": "{INDEX_PATH}",
  "hooks": {
    "update_trigger": ["Write", "Edit"],
    "verify_trigger": ["Glob", "Grep", "Read"]
  },
  "exclude_dirs": [
    ".claude",
    ".git",
    "wilma"
  ],
  "exclude_paths": [],
  "index_exempt_files": [],
  "sections": {
    "auto_create": true,
    "group_by": "top_level_folder"
  },
  "behavior": {
    "mode": "incremental",
    "never_rebuild_automatically": true,
    "missing_index_action": "warn_and_exit"
  }
}
```

---

## weekly-review-rules.json (inlined default)

Use when writing `.claude/plugins/worklog/weekly-review-rules.json`.
Replace path placeholders with user's configured values.

```json
{
  "skill": "weekly-review",
  "version": "1.0.0",
  "paths": {
    "backlog": "{BACKLOG_PATH}",
    "outcomes": "{OUTCOMES_PATH}",
    "work_registry": "{WORK_REGISTRY_PATH}",
    "worklog": "{WORKLOG_PATH}",
    "report_output": "{REPORT_OUTPUT_DIR}"
  },
  "stale_rules": {
    "default_days": 14,
    "by_phase": {
      "discover": 30,
      "define": 21,
      "develop": 14,
      "deliver": 7
    }
  },
  "scan_paths": [
    "wilma/"
  ],
  "exclude_paths": [
    "wilma/worklog.md",
    "wilma/file-index.md",
    "wilma/reports"
  ],
  "orphan_pool_header": "## Orphaned Pool",
  "required_frontmatter_fields": [
    "title",
    "type",
    "phase",
    "version",
    "author",
    "created",
    "updated",
    "project",
    "outcome"
  ],
  "new_file_window_days": 7
}
```
