#!/usr/bin/env bash
# Script: rebuild-file-index.sh
# Purpose: Full rebuild of FILE-INDEX.md from scratch.
# WARNING: Destroys all manually-written descriptions. Run only when needed.
# Normal operation uses update-file-index.sh (incremental-append).
# Invoked by the rebuild-index skill after user confirmation.

# ── Resolve workspace root ────────────────────────────────────────────────────
# Walk-up from script location is NOT used: wilma is globally installed, so
# __file__ points to the user-level .claude folder, not the project workspace.
if [[ -z "$CLAUDE_PROJECT_DIR" || ! -d "$CLAUDE_PROJECT_DIR" ]]; then
    echo "wilma: CLAUDE_PROJECT_DIR not set or does not exist. Ensure you are running inside a Claude Code session." >&2
    exit 1
fi
workspace="$CLAUDE_PROJECT_DIR"
dot_claude_dir="$workspace/.claude"

# ── Load config from wilma.local.md ──────────────────────────────────────────
settings_file="$dot_claude_dir/wilma.local.md"
if [[ ! -f "$settings_file" ]]; then
    echo "wilma: not configured. Run /wilma-setup in Claude Code to get started." >&2
    exit 1
fi

content="$(cat "$settings_file")"

# workspace_root in config overrides CLAUDE_PROJECT_DIR — set by /wilma-setup at project scope.
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

# ── Parse YAML inline arrays ──────────────────────────────────────────────────
read_yaml_array() {
    local field="$1" fc="$2"
    local line
    line="$(echo "$fc" | grep -m1 "^${field}:")"
    [[ -z "$line" ]] && { echo "__absent__"; return; }
    echo "$line" | grep -oP '"[^"]*"' | tr -d '"'
}

mapfile -t exclude_paths < <(read_yaml_array "exclude_paths" "$content")
mapfile -t exempt_files  < <(read_yaml_array "index_exempt_files" "$content")

if [[ "${exclude_paths[0]}" == "__absent__" ]]; then
    echo "wilma: exclude_paths not found in wilma.local.md. Re-run /wilma-setup to repair config." >&2
    exit 1
fi
[[ "${exempt_files[0]}" == "__absent__" ]] && exempt_files=()

# ── Collect all files ─────────────────────────────────────────────────────────
index_path="$workspace/$index_rel_path"
today="$(date '+%Y-%m-%d')"

all_files=()
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

    all_files+=("$rel")
done < <(find "$workspace" -type f -print0 | sort -z)

# ── Group by top-level folder ─────────────────────────────────────────────────
declare -A groups
for f in "${all_files[@]}"; do
    parts=(${f//\// })
    if [[ ${#parts[@]} -gt 1 ]]; then
        folder="${parts[0]}"
    else
        folder="root"
    fi
    groups["$folder"]+="$f"$'\n'
done

# ── Write index ───────────────────────────────────────────────────────────────
{
    echo "# File Index"
    echo ""
    echo "> Auto-maintained by wilma. Updated on every Write/Edit."
    echo "> When looking for a file: check this index first."
    echo "> Last full rebuild: $today"
    echo ""
    echo "## Index"

    for folder in $(echo "${!groups[@]}" | tr ' ' '\n' | sort); do
        echo ""
        echo "### ${folder}/"
        echo ""
        echo "| Path | Description |"
        echo "| ---- | ----------- |"
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            echo "| [$f]($f) | |"
        done <<< "${groups[$folder]}"
    done

    echo ""
    echo "---"
    echo ""
    echo "## Missing from Index?"
    echo ""
    echo "1. Run verify-file-index.sh (full scan + auto-append)"
    echo "2. Or use the rebuild-index skill to full-rebuild from scratch"
} > "$index_path"

echo "File index rebuilt: ${#all_files[@]} files indexed."
