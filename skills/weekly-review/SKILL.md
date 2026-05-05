---
name: "weekly-review"
description: "This skill should be used when the user invokes /weekly-review, asks for 'weekly review', 'workspace review', 'governance review', 'what's orphaned', 'stale work', 'unclassified files', 'show orphaned files', or wants a health check of the workspace."
allowed-tools: ["Read", "Bash", "Write"]
version: "1.0.0"
---

# Weekly Review

Weekly workspace governance review. Surfaces orphaned, stale, and unclassified work. Links outcomes to files. Proposes backlog additions. Run once per week at end of week.

## Setup

Load rules from config with workspace-override fallback:

1. `.claude/plugins/worklog/weekly-review-rules.json` (workspace override — backward compatible)
2. `[plugin root]/config/weekly-review-rules.default.json` (plugin default)

Extract all configured paths (`backlog`, `outcomes`, `work_registry`, `worklog`, `report_output`), `stale_rules`, `scan_paths`, `exclude_paths`, `required_frontmatter_fields`, `new_file_window_days`.

## Scan Phase

For every `.md` file under each path in `scan_paths`, excluding `exclude_paths`:

1. Read file frontmatter (YAML block between `---` delimiters at top of file).
2. Record: `path`, `title`, `type`, `phase`, `version`, `author`, `created`, `updated`, `project`, `outcome`, `confluence_page`.
3. Note which required fields are missing.
4. Compute `days_since_updated` = today minus `updated` date (use `created` if `updated` absent).
5. Determine stale threshold: look up `phase` in `stale_rules.by_phase`; fallback to `stale_rules.default_days`.
6. Classify the file (see Classification below).

Also read `outcomes.md` — collect all outcome IDs. Any outcome ID with zero files pointing to it = **hollow outcome**.

**Governance file exemptions**: Do not report on `outcomes.md`, `work-registry.md`, or `backlog.md` as unclassified or orphaned.

## Classification

Assign exactly one class per file. Use first matching rule top-to-bottom:

| Class | Detection rule |
| ----- | -------------- |
| **Unclassified** | No frontmatter block present |
| **Orphaned** | Frontmatter present; `outcome` field missing, empty, or value not found in `outcomes.md` |
| **Stale** | Has valid `outcome`; `days_since_updated` > phase stale threshold; file still under `drafts/` or `planning/` |
| **New** | `created` date within last `new_file_window_days` days |
| **Progressed** | `updated` date within last `new_file_window_days` days; frontmatter complete |
| **Healthy** | Has valid `outcome`; not stale; not new this week |

A file can be both **New** and **Orphaned** — apply both labels.

## Report Sections

Generate report under heading `## Weekly Review — YYYY-MM-DD`.

### 1. Summary

One-line counts table:

| Class | Count |
| ----- | ----- |
| Progressed this week | N |
| New this week | N |
| Orphaned | N |
| Stale | N |
| Unclassified | N |
| Hollow outcomes | N |

### 2. Wins — Progressed This Week

List files updated this week with valid outcome linkage. Group by outcome ID.
Format: `- [filename](path) — O-XXX — phase`

### 3. New Files This Week

List files created within `new_file_window_days`. Flag if missing frontmatter or `outcome`.
Format: `- [filename](path) — ⚠ missing: field1, field2` or `✓ complete`

### 4. Orphaned Files

Files with frontmatter but no valid `outcome` linkage. For each, propose a matching outcome from `outcomes.md` based on file path + title.

```
- [filename](path)
  Phase: define | Last updated: YYYY-MM-DD
  Suggested outcome: O-002 — Prompt library for analyst use cases
  Action: add `outcome: "O-002"` to frontmatter
```

### 5. Unclassified Files

Files with no frontmatter at all. For each, generate a full frontmatter block suggestion based on file path, folder position, and content inference.

### 6. Stale Files

Files with valid outcome but no progression past stale threshold. Group by outcome. Show days overdue.

```
- [filename](path)
  Outcome: O-001 | Phase: develop | Last updated: YYYY-MM-DD (N days ago, threshold: 14d)
  Still in: drafts/ — consider moving to review/ or adding backlog task to resume
```

### 7. Hollow Outcomes

Outcomes in `outcomes.md` with no files pointing to them via `outcome:` frontmatter field.

### 8. Proposed Backlog Additions

Consolidate all items from sections 4–7 that require a backlog task. Present as a numbered list ready to paste into `backlog.md`.

Ask user: "Add these to backlog.md? Reply with numbers to include (e.g. '1,3,4') or 'all' or 'none'."

### 9. Orphaned Pool Updates

List files from section 4 that have no suggested outcome match (genuinely unknown).

Ask user: "Add these to Orphaned Pool in work-registry.md? Reply yes/no per file."

## Post-Report Actions

After user responds to sections 8 and 9:

1. **Backlog additions**: Append approved items to `backlog.md` under `## Orphaned & Stale Work` section (create section if absent). Use Bash append — not Write/Edit — to avoid triggering file rewrite.
2. **Orphaned Pool**: Append approved rows to `## Orphaned Pool` table in `work-registry.md`.
3. **Save report**: Offer to save full report to `{report_output}/weekly-review-YYYY-MM-DD.md`.

## Notes

- Do not auto-modify frontmatter in scanned files — only suggest; user applies manually.
- Do not scan `resources/` or `collaborative/` — read-only and external repos.
- Cross-reference `worklog.md` for files that appear orphaned but had heavy recent activity — note this in the orphan entry as context.
- Stale detection applies only to files under `drafts/` or `planning/` subfolders — files in `output/`, `review/`, or `publish/` are not stale by definition.
