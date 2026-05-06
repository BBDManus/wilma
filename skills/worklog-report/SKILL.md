---
name: "worklog-report"
description: "This skill should be used when the user invokes /worklog-report, asks for 'worklog summary', 'weekly report', 'what did I work on', 'show my activity', 'activity report', or wants a summary of recent work."
allowed-tools: ["Read", "Write"]
version: "1.0.0"
---

# Worklog Report

Generate a weekly activity report from the workspace worklog.

## Setup

1. Determine the worklog path:
   - Read `.claude/wilma.local.md` if it exists — use `worklog_path` field if present
   - Default: `wilma/worklog.md`
2. Read the worklog file in full.
3. Parse all table rows (skip header rows starting with `| Date` or `| ---`).
4. Filter to current week (Monday–today) unless user specifies a different date range.

## Report Sections

Generate a markdown report under the heading `## Worklog Report — Week of YYYY-MM-DD`.

### Activity by Day

Table showing row count per day of week. Highlight the most active day.

### Activity by Tool

Breakdown of Write, Edit, Bash, and Manual call counts. Ratio of edits to writes signals rework rate.

### Top Files Touched

Rank files by occurrence count. Flag files touched 5+ times — may need a review checkpoint.

### Project Folder Breakdown

Group by `project` column. Show which projects had activity this week.

### File Type Breakdown

Group by file extension (`.md`, `.ps1`, `.txt`, `.docx`, etc.).

### Trends and Patterns

Surface the following patterns:

- Files with many edits but path still in `drafts/` — suggest moving to `review/`
- Bash-heavy sessions with no file writes — may indicate exploratory work without artefacts
- New files created but never edited — possibly abandoned drafts
- High activity early in week dropping off — check if work is getting stuck

### Improvement Suggestions

Provide 3–5 concrete, actionable suggestions based on observed patterns. Examples:

- "You created N draft files this week but moved 0 to output/ — consider scheduling a review pass."
- "Most Bash commands ran on [day] — your exploration sessions cluster. Consider a dedicated scratch note."
- "File X was edited N times — it may be scope-creeping. Consider splitting or freezing a version."

## Output

Output the full report as a markdown document under the `## Worklog Report — Week of YYYY-MM-DD` heading.

Offer to save the report to `{report_output_dir}/worklog-report-YYYY-MM-DD.md` (read `report_output_dir` from `.claude/wilma.local.md`; default: `wilma/reports`) if the user wants a persistent copy.
