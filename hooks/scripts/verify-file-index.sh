#!/usr/bin/env bash
# Hook: verify-file-index.sh
# Trigger: PostToolUse (Glob, Grep, Read)
# Purpose: Detect files on disk absent from FILE-INDEX.md and auto-patch missing entries.

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

content="$(cat "$settings_file")"

# workspace_root in config always wins — set by /wilma-setup at project scope.
r="$(echo "$content" | grep -m1 '^workspace_root:' | sed "s/^workspace_root:[[:space:]]*[\"']\?\([^\"']*\)[\"']\?[[:space:]]*/\1/")"
if [[ -n "$r" && -d "$r" ]]; then
    workspace="$r"
    dot_claude_dir="$workspace/.claude"
fi

index_rel_path="wilma/file-index.md"
ip="$(echo "$content" | grep -m1 '^index_path:' | sed "s/^index_path:[[:space:]]*[\"']\?\([^\"']*\)[\"']\?[[:space:]]*/\1/")"
if [[ -n "$ip" ]]; then
    index_rel_path="$ip"
fi

# ── Parse YAML inline arrays from wilma.local.md ─────────────────────────────
read_yaml_array() {
    local field="$1" fc="$2"
    local line
    line="$(echo "$fc" | grep -m1 "^${field}:")"
    [[ -z "$line" ]] && { echo "__absent__"; return; }
    echo "$line" | grep -oP '"[^"]*"' | tr -d '"'
}

index_path="$workspace/$index_rel_path"

mapfile -t exclude_paths < <(read_yaml_array "exclude_paths" "$content")
mapfile -t exempt_files  < <(read_yaml_array "index_exempt_files" "$content")

if [[ "${exclude_paths[0]}" == "__absent__" ]]; then
    echo "wilma: exclude_paths not found in wilma.local.md. Re-run /wilma-setup to repair config." >&2
    exit 1
fi
[[ "${exempt_files[0]}" == "__absent__" ]] && exempt_files=()

if [[ ! -f "$index_path" ]]; then
    echo "File index not found at $index_path. Run /wilma:rebuild-index first." >&2
    exit 1
fi

# ── Find files on disk not in index ───────────────────────────────────────────
missing=()
while IFS= read -r -d '' abs; do
    rel="${abs#$workspace/}"
    basename_file="$(basename "$rel")"

    skip=false
    for ef in "${exempt_files[@]}"; do
        [[ "$basename_file" == "$ef" ]] && { skip=true; break; }
    done
    $skip && continue

    for ep in "${exclude_paths[@]}"; do
        [[ "$rel" == "$ep"* ]] && { skip=true; break; }
    done
    $skip && continue

    if ! grep -qF "$rel" "$index_path"; then
        missing+=("$rel")
    fi
done < <(find "$workspace" -type f -print0 | sort -z)

if [[ ${#missing[@]} -eq 0 ]]; then
    echo "File index verified: no missing entries."
    exit 0
fi

echo "FILE-INDEX.md missing ${#missing[@]} file(s). Triggering update..." >&2
for m in "${missing[@]}"; do
    echo "  Missing: $m" >&2
done

# ── Delegate to update-file-index.sh ─────────────────────────────────────────
update_script="$(dirname "${BASH_SOURCE[0]}")/update-file-index.sh"
bash "$update_script"
echo "Index updated: missing entries appended."
