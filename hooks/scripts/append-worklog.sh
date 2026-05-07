#!/usr/bin/env bash
# Hook: append-worklog.sh
# Trigger: PostToolUse (Write|Edit|Bash)
# Purpose: Append one row to worklog.md for every file write or bash command.

# ── Resolve workspace root ────────────────────────────────────────────────────
if [[ -n "$CLAUDE_PROJECT_DIR" && -d "$CLAUDE_PROJECT_DIR" ]]; then
    workspace="$CLAUDE_PROJECT_DIR"
    dot_claude_dir="$workspace/.claude"
else
    hooks_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    plugin_root="$(dirname "$hooks_dir")"
    plugins_dir="$(dirname "$plugin_root")"
    dot_claude_dir="$(dirname "$plugins_dir")"
    workspace="$(dirname "$dot_claude_dir")"
fi

settings_file="$dot_claude_dir/wilma.local.md"
if [[ ! -f "$settings_file" ]]; then
    echo "wilma: not configured. Run /wilma-setup in Claude Code to get started." >&2
    exit 1
fi

worklog_rel_path="wilma/worklog.md"

settings_content="$(cat "$settings_file")"

# workspace_root in config always wins — set by /wilma-setup at project scope.
r="$(echo "$settings_content" | grep -m1 '^workspace_root:' | sed "s/^workspace_root:[[:space:]]*[\"']\?\([^\"']*\)[\"']\?[[:space:]]*/\1/")"
if [[ -n "$r" && -d "$r" ]]; then
    workspace="$r"
    dot_claude_dir="$workspace/.claude"
fi

wl="$(echo "$settings_content" | grep -m1 '^worklog_path:' | sed "s/^worklog_path:[[:space:]]*[\"']\?\([^\"']*\)[\"']\?[[:space:]]*/\1/")"
if [[ -n "$wl" ]]; then
    worklog_rel_path="$wl"
fi

# Parse worklog_tracked_fields from wilma.local.md (inline array: ["a","b"])
tracked_fields=()
raw_fields="$(echo "$settings_content" | grep -m1 '^worklog_tracked_fields:' | sed 's/^worklog_tracked_fields:[[:space:]]*//')"
if [[ -n "$raw_fields" ]]; then
    while IFS= read -r field; do
        tracked_fields+=("$field")
    done < <(echo "$raw_fields" | grep -oP '"[^"]*"' | tr -d '"')
fi

worklog_path="$workspace/$worklog_rel_path"

if [[ ! -f "$worklog_path" ]]; then
    echo "worklog.md not found at $worklog_path. Create it first." >&2
    exit 1
fi

# ── Parse stdin ───────────────────────────────────────────────────────────────
raw="$(cat)"
if [[ -z "${raw// /}" ]]; then exit 0; fi

tool_name="$(echo "$raw" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)"
file_path="$(echo "$raw" | python3 -c "import sys,json; d=json.load(sys.stdin); ti=d.get('tool_input',{}); print(ti.get('file_path',''))" 2>/dev/null)"
cmd="$(echo "$raw" | python3 -c "import sys,json; d=json.load(sys.stdin); ti=d.get('tool_input',{}); print(ti.get('command',''))" 2>/dev/null)"

action_type=""
description=""

case "$tool_name" in
    Write)
        action_type="write"
        description="Wrote $(basename "$file_path")"
        ;;
    Edit)
        action_type="edit"
        description="Edited $(basename "$file_path")"
        ;;
    Bash)
        if [[ "$cmd" == *"worklog.md"* ]]; then exit 0; fi
        short="${cmd:0:60}"
        [[ ${#cmd} -gt 60 ]] && short="${short}..."
        file_path="$short"
        action_type="bash"
        description="Bash: $short"
        ;;
    *) exit 0 ;;
esac

# Self-referential guard
if [[ "$file_path" == *"worklog.md"* ]]; then exit 0; fi

# ── Infer project folder ──────────────────────────────────────────────────────
project_folder="_root"
normalised="${file_path//\\//}"
if [[ "$normalised" =~ ^([^/]+)/[^/]+/ ]]; then
    project_folder="${BASH_REMATCH[1]}"
fi

# ── Extract tracked frontmatter fields from the written file ──────────────────
tracked_values=()
if [[ ${#tracked_fields[@]} -gt 0 && -n "$file_path" ]]; then
    abs_path="$workspace/$file_path"
    if [[ -f "$abs_path" ]]; then
        file_content="$(cat "$abs_path" 2>/dev/null)"
        frontmatter=""
        if [[ "$file_content" =~ ^---$'\n'(.*?)$'\n'--- ]]; then
            frontmatter="${BASH_REMATCH[1]}"
        fi
        for field in "${tracked_fields[@]}"; do
            val="$(echo "$frontmatter" | grep -m1 "^${field}:" | sed "s/^${field}:[[:space:]]*[\"']\?\([^\"']*\)[\"']\?[[:space:]]*/\1/" | tr '|' '-')"
            tracked_values+=("$val")
        done
    else
        for field in "${tracked_fields[@]}"; do
            tracked_values+=("")
        done
    fi
fi

# ── Build and append row ──────────────────────────────────────────────────────
date="$(date '+%Y-%m-%d')"
time="$(date '+%H:%M')"

safe_file="${file_path//|//}"
safe_desc="${description//|/-}"

extra_cols=""
if [[ ${#tracked_values[@]} -gt 0 ]]; then
    for v in "${tracked_values[@]}"; do
        extra_cols+=" $v |"
    done
    extra_cols=" $extra_cols"
fi

row="| $date | $time | $tool_name | $safe_file | $action_type | $project_folder | $safe_desc |${extra_cols}"

printf '%s\n' "$row" >> "$worklog_path"
echo "worklog: logged $tool_name on $safe_file"
exit 0
