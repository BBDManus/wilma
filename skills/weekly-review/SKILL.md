---
name: "weekly-review"
description: "This skill should be used when the user invokes /weekly-review, asks for 'weekly review', 'workspace review', 'governance review', 'what's orphaned', 'stale work', 'unclassified files', 'show orphaned files', or wants a health check of the workspace."
allowed-tools: ["Read", "Bash", "Write"]
version: "1.1.0"
---

# Weekly Review

Weekly workspace governance review. Surfaces orphaned, stale, and unclassified work. Links outcomes to files. Proposes backlog additions. Run once per week at end of week.

## Setup

Read `.claude/wilma.local.md` and extract these fields from the YAML frontmatter. If the file or a field is absent, use the built-in default shown:

| Field | Default |
| ----- | ------- |
| `backlog_path` | `wilma/backlog.md` |
| `outcomes_path` | `wilma/outcomes.md` |
| `work_registry_path` | `wilma/work-registry.md` |
| `worklog_path` | `wilma/worklog.md` |
| `report_output_dir` | `wilma/reports` |
| `stale_days` | `14` |
| `scan_paths` | `["wilma/"]` |
| `weekly_review_exclude_paths` | `["wilma/worklog.md", "wilma/file-index.md", "wilma/reports"]` |
| `new_file_window_days` | `7` |
| `orphan_pool_header` | `## Orphaned Pool` |
| `outcome_field` | `outcome` |
| `frontmatter_fields` | `[]` |
| `frontmatter_template_path` | `""` |

### Resolving required frontmatter fields

After loading config, determine the active required field set:

1. If `frontmatter_template_path` is non-empty: Read that file, parse its frontmatter block, collect the key names as `required_fields`. If the file cannot be read, fall back to step 2.
2. Else if `frontmatter_fields` is non-empty: use those field names as `required_fields`.
3. Else: `required_fields` = `[]` (no field-level checking — only presence of any frontmatter block matters).

Outcome linkage: if `outcome_field` is non-empty (default: `outcome`), weekly-review checks that every scanned file has that field set to a value present in `outcomes.md`. If `outcome_field` is blank, orphan detection and hollow-outcome checks are skipped entirely.

## Scan Phase

For every `.md` file under each path in `scan_paths`, excluding `weekly_review_exclude_paths`:

1. Read file frontmatter (YAML block between `---` delimiters at top of file).
2. Record all frontmatter key/value pairs present.
3. Compute `days_since_updated` = today minus `updated` date (use `created` if `updated` absent; skip stale check if neither present).
4. Determine if stale: `days_since_updated` > `stale_days`.
5. Classify the file (see Classification below).

Also read `outcomes.md` — collect all outcome IDs. Any outcome ID with zero files pointing to it = **hollow outcome**.

**Governance file exemptions**: Do not report on `outcomes.md`, `work-registry.md`, or `backlog.md` as unclassified or orphaned.

## Classification

Assign exactly one class per file. Use first matching rule top-to-bottom:

| Class | Detection rule |
| ----- | -------------- |
| **Unclassified** | No frontmatter block present |
| **Incomplete** | Frontmatter present; one or more `required_fields` are missing or empty (only applies when `required_fields` is non-empty) |
| **Orphaned** | Frontmatter present and complete (or no `required_fields`); `{outcome_field}` value missing/empty/not found in `outcomes.md` (only applies when `outcome_field` is non-empty) |
| **Stale** | Frontmatter present; `days_since_updated` > `stale_days` |
| **New** | `created` date within last `new_file_window_days` days |
| **Progressed** | `updated` date within last `new_file_window_days` days |
| **Healthy** | Frontmatter present; not stale; not new this week; passes all configured checks |

A file can carry multiple labels — e.g. **New** + **Incomplete**, or **Stale** + **Orphaned**.

## Report Sections

Generate report under heading `## Weekly Review — YYYY-MM-DD`.

### 1. Summary

One-line counts table:

| Class | Count |
| ----- | ----- |
| Progressed this week | N |
| New this week | N |
| Orphaned | N |
| Incomplete | N |
| Stale | N |
| Unclassified | N |
| Hollow outcomes | N |

### 2. Wins — Progressed This Week

List files updated this week with valid outcome linkage. Group by outcome ID.
Format: `- [filename](path) — O-XXX`

### 3. New Files This Week

List files created within `new_file_window_days`. Flag if missing frontmatter or `outcome`.
Format: `- [filename](path) — ⚠ missing: field1, field2` or `✓ complete`

### 4. Orphaned Files

Files with frontmatter but no valid `outcome` linkage. For each, propose a matching outcome from `outcomes.md` based on file path + title.

```
- [filename](path)
  Last updated: YYYY-MM-DD
  Suggested outcome: O-002 — Prompt library for analyst use cases
  Action: add `{outcome_field}: "O-002"` to frontmatter
```

### 5. Unclassified Files

Files with no frontmatter at all. For each, generate a full frontmatter block suggestion based on file path, folder position, and content inference.

### 6. Stale Files

Files with valid outcome but no progression past `stale_days` threshold. Group by outcome. Show days overdue.

```
- [filename](path)
  Outcome: O-001 | Last updated: YYYY-MM-DD (N days ago, threshold: {stale_days}d)
  Action: add a backlog task to resume or mark as complete
```

### 7. Hollow Outcomes

Outcomes in `outcomes.md` with no files pointing to them via the `{outcome_field}` frontmatter field.

### 8. Proposed Backlog Additions

Consolidate all items from sections 4–7 that require a backlog task. Present as a numbered list ready to paste into `backlog.md`.

Ask user: "Add these to backlog.md? Reply with numbers to include (e.g. '1,3,4') or 'all' or 'none'."

### 9. Orphaned Pool Updates

List files from section 4 that have no suggested outcome match (genuinely unknown).

Ask user: "Add these to Orphaned Pool in work-registry.md? Reply yes/no per file."

## Post-Report Actions

After user responds to sections 8 and 9:

1. **Backlog additions**: Append approved items to `backlog.md` under `## Orphaned & Stale Work` section (create section if absent). Use Bash append — not Write/Edit — to avoid triggering file rewrite.
2. **Orphaned Pool**: Append approved rows to the `{orphan_pool_header}` table in `work-registry.md`.
3. **Save report**: Offer to save full report to `{report_output_dir}/weekly-review-YYYY-MM-DD.md`.

## Notes

- Do not auto-modify frontmatter in scanned files — only suggest; user applies manually.
- Cross-reference `worklog.md` for files that appear orphaned but had heavy recent activity — note this in the orphan entry as context.
- Stale detection applies to all scanned files with frontmatter. There is no folder restriction — any file not updated within `stale_days` is considered stale.
