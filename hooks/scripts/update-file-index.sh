#!/usr/bin/env bash
# Hook: update-file-index.sh
# Trigger: PostToolUse (Write, Edit)
# Purpose: Incremental-append only — adds new files to FILE-INDEX.md, never rebuilds.
# Full rebuild: use the rebuild-index skill or run rebuild-file-index.sh manually.

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
# Usage: read_yaml_array "field_name" "$content"  → prints one entry per line
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
    echo "File index missing at $index_path. Run /wilma:rebuild-index first." >&2
    exit 1
fi

index_content="$(cat "$index_path")"

# ── Collect files on disk, applying exemption rules ───────────────────────────
new_files=()
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
        new_files+=("$rel")
    fi
done < <(find "$workspace" -type f -print0 | sort -z)

if [[ ${#new_files[@]} -eq 0 ]]; then exit 0; fi

# ── Group by top-level folder and append ──────────────────────────────────────
# Build associative array: folder -> list of files
declare -A groups
for f in "${new_files[@]}"; do
    folder="${f%%/*}"
    groups["$folder"]+="$f"$'\n'
done

tmp="$(mktemp)"
cp "$index_path" "$tmp"

for folder in $(echo "${!groups[@]}" | tr ' ' '\n' | sort); do
    section="### ${folder}/"
    if ! grep -qF "$section" "$tmp"; then
        # Find insertion point: before last "---" or at end
        sep_line="$(grep -n '^---$' "$tmp" | tail -1 | cut -d: -f1)"
        if [[ -n "$sep_line" ]]; then
            insert_at="$sep_line"
        else
            insert_at="$(wc -l < "$tmp")"
            ((insert_at++))
        fi
        # Insert section header before separator
        sed -i "${insert_at}i\\
\\
${section}\\
\\
| Path | Description |\\
| ---- | ----------- |" "$tmp"
    fi

    # Find end of this section's table and insert rows
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        section_line="$(grep -n "^${section}$" "$tmp" | head -1 | cut -d: -f1)"
        [[ -z "$section_line" ]] && continue
        # Find where next section or separator starts
        table_end="$(awk -v start="$((section_line+1))" 'NR>start && /^###|^---/{print NR; exit}' "$tmp")"
        if [[ -z "$table_end" ]]; then
            table_end="$(wc -l < "$tmp")"
            ((table_end++))
        fi
        # Back up past trailing blank lines
        insert_row="$table_end"
        while [[ $insert_row -gt $section_line ]]; do
            prev=$((insert_row - 1))
            line_content="$(sed -n "${prev}p" "$tmp")"
            [[ -z "${line_content// /}" ]] && ((insert_row--)) || break
        done
        sed -i "${insert_row}i| [$f]($f) | |" "$tmp"
    done <<< "${groups[$folder]}"
done

cp "$tmp" "$index_path"
rm -f "$tmp"
echo "FILE-INDEX.md: appended ${#new_files[@]} new file(s)."
