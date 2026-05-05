---
name: "Worklog Add"
description: "This skill should be used when the user invokes /worklog-add, says 'log this to worklog', 'add worklog entry', 'log my work', 'record this task', or asks to manually add something to the work log."
argument-hint: "<description of work done>"
allowed-tools: ["Bash", "Read"]
version: "1.0.0"
---

# Worklog Add

Manually append a work entry to the workspace worklog.

## Steps

1. Extract description from everything after `/worklog-add` (or from the user's phrasing if invoked conversationally).
2. Determine the worklog path:
   - Read `.claude/wilma.local.md` if it exists — use `worklog_path` field if present
   - Default: `workshop/worklog.md`
3. Infer `project` by checking if the description mentions a known workshop project folder name (e.g. `fxbanking`, `_scratch`). Default to `_root` if none found.
4. Get current timestamp: date = `yyyy-MM-dd`, time = `HH:mm`.
5. Build the row:

   ```
   | {date} | {time} | Manual | - | manual | {project} | {description} |
   ```

6. Append the row using Bash `Add-Content` — not Write/Edit, to avoid triggering the file-index hook on worklog.md.
7. Confirm to user with a one-line preview of what was logged.

## Notes

- `Tool` column is always `Manual` — distinguishes from auto-captured hook entries.
- `Action` column is always `manual`.
- `File/Command` column is always `-` (no associated file for manual entries).
- Use Bash to append (`Add-Content -Path {path} -Value {row} -Encoding UTF8`).

## Worklog Table Format

```markdown
| Date | Time | Tool | File/Command | Action | Project | Description |
| ---- | ---- | ---- | ------------ | ------ | ------- | ----------- |
| 2026-04-22 | 09:15 | Manual | - | manual | fxbanking | Reviewed FX rate calculation logic |
```
