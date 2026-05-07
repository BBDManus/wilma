---
name: "worklog-add"
description: "This skill should be used when the user invokes /worklog-add, says 'log this to worklog', 'add worklog entry', 'log my work', 'record this task', or asks to manually add something to the work log."
argument-hint: "<description of work done>"
allowed-tools: ["Bash", "Read"]
version: "1.0.0"
---

# Worklog Add

Manually append a work entry to the workspace worklog.

## Steps

1. Extract description from everything after `/worklog-add` (or from the user's phrasing if invoked conversationally).
2. Read `.claude/wilma.local.md` if it exists. Extract:
   - `worklog_path` — default: `wilma/worklog.md`
   - `worklog_tracked_fields` — default: `[]`
3. Infer `project` by checking the first path segment of any file mentioned in the description. Default to `_root` if none found.
4. Get current timestamp: date = `yyyy-MM-dd`, time = `HH:mm`.
5. Build the row. Base columns are always:
   ```
   | {date} | {time} | Manual | - | manual | {project} | {description} |
   ```
   If `worklog_tracked_fields` is non-empty, append one empty cell per tracked field to keep the table aligned with auto-captured rows:
   ```
   | {date} | {time} | Manual | - | manual | {project} | {description} |  |  |
   ```
6. Append the row using Bash `printf` — not Write/Edit, to avoid triggering the file-index hook on worklog.md.
7. Confirm to user with a one-line preview of what was logged.

## Notes

- `Tool` column is always `Manual` — distinguishes from auto-captured hook entries.
- `Action` column is always `manual`.
- `File/Command` column is always `-` (no associated file for manual entries).
- Empty cells for tracked fields are intentional — no file context to extract values from.
- Use Bash to append: `printf '%s\n' "{row}" >> "{path}"`

## Worklog Table Format

```markdown
| Date | Time | Tool | File/Command | Action | Project | Description |
| ---- | ---- | ---- | ------------ | ------ | ------- | ----------- |
| 2026-04-22 | 09:15 | Manual | - | manual | myproject | Reviewed rate calculation logic |
```
