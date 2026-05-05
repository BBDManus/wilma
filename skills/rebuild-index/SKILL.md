---
name: "rebuild-index"
description: "This skill should be used when the user invokes /wilma:rebuild-index, asks to 'rebuild file index', 'reset file index', 'regenerate FILE-INDEX', 'rebuild FILE-INDEX.md from scratch', or when the file index is corrupt or severely out of date."
allowed-tools: ["Bash", "Read"]
version: "1.0.0"
---

# Rebuild Index

Fully rebuilds `FILE-INDEX.md` from scratch by scanning all workspace files.

**Warning:** This destroys all manually-written descriptions in `FILE-INDEX.md`. Normal file index maintenance is incremental — only use this skill when the index is corrupt, severely out of date, or after a bulk file reorganisation.

## Safety Gate

Before running the rebuild, present this warning to the user and ask for explicit confirmation:

```
⚠ Full Rebuild Warning

This will overwrite FILE-INDEX.md completely, deleting all manually-written
file descriptions. The new index will have blank descriptions for all entries.

Normal use: incremental hooks keep the index current without losing descriptions.
Use this only if the index is corrupt or after a bulk file reorganisation.

Type CONFIRM to proceed, or anything else to cancel.
```

Only proceed if the user types exactly `CONFIRM` (case-insensitive). On any other response, cancel and inform the user that no changes were made.

## Steps

1. Present the safety gate. Wait for user response.
2. If confirmed: run the rebuild script via Bash:

   ```bash
   powershell -ExecutionPolicy Bypass -File ".claude/plugins/wilma/skills/rebuild-index/scripts/rebuild-file-index.ps1"
   ```

3. Report the result to the user:
   - On success: "FILE-INDEX.md rebuilt. N files indexed. All descriptions are blank — add them manually as needed."
   - On failure: show the error output and suggest checking whether `FILE-INDEX.md` exists and the workspace path is correct.

## Notes

- The rebuild script derives workspace root automatically from its own location (no hardcoded paths).
- Config is loaded from `.claude/plugins/simple-filekeeper/filekeeper-rules.json` if present, otherwise from the plugin default at `.claude/plugins/wilma/config/filekeeper-rules.default.json`.
- After rebuild, incremental hooks resume normal operation automatically.
- To add descriptions back to the index, edit `FILE-INDEX.md` directly — hooks will never overwrite existing descriptions.
