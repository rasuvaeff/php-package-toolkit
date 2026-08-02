#!/bin/bash
set -uo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

if [ "$tool_name" != "Bash" ]; then
    exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

echo "$command" | grep -qE '\bgit\b[^&|;]*\bcommit\b' || exit 0

repo_root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$repo_root" ]; then
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

strip_quotes() {
    local s="$1"
    s="${s#\"}"; s="${s%\"}"
    s="${s#\'}"; s="${s%\'}"
    printf '%s' "$s"
}

deny() {
    local reason="$1"
    jq -n --arg reason "$reason" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason
        }
    }'
    exit 0
}

# Walk the command as a sequence of &&/;/newline-separated segments, tracking
# the effective cwd across `cd` segments, so `cd pkg && ... && git commit`
# (single-line or multi-line) resolves to the right package directory.
current_dir="$cwd"
target_dir=""
unresolved=0

normalized="$(printf '%s' "$command" | tr '\n' ';' | sed -E 's/&&|;/\n/g')"
while IFS= read -r seg; do
    trimmed="$(echo "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [ -n "$trimmed" ] || continue

    if [[ "$trimmed" =~ ^cd[[:space:]]+(.+)$ ]]; then
        dir="$(strip_quotes "${BASH_REMATCH[1]}")"
        case "$dir" in
            *'$'*|*'`'*) unresolved=1 ;;
            /*) current_dir="$dir" ;;
            *) current_dir="$current_dir/$dir" ;;
        esac
        continue
    fi

    if echo "$trimmed" | grep -qE '\bgit\b[^&|;]*\bcommit\b'; then
        if [[ "$trimmed" =~ -C[[:space:]]+([^[:space:]]+) ]]; then
            dir="$(strip_quotes "${BASH_REMATCH[1]}")"
            case "$dir" in
                *'$'*|*'`'*) unresolved=1 ;;
                /*) target_dir="$dir" ;;
                *) target_dir="$current_dir/$dir" ;;
            esac
        else
            target_dir="$current_dir"
        fi
    fi
done <<< "$normalized"

if [ "$unresolved" -eq 1 ]; then
    deny 'Blocked by .claude/hooks/pre-commit-audit.sh: this commit'"'"'s target directory depends on a shell variable or command substitution in a preceding cd/-C, which the hook cannot statically resolve. Run bin/package-audit "<dir>" yourself before committing, or use a literal path in cd/-C.'
fi

[ -n "$target_dir" ] || exit 0

target_dir="$(cd "$target_dir" 2>/dev/null && pwd)"
[ -n "$target_dir" ] || exit 0
[ -f "$target_dir/composer.json" ] || exit 0

# Exempt the initial skeleton commit (create-php-package step 3: git init &&
# git add -A && git commit, before src/tests/README/etc. exist) — audit only
# once a package has at least one prior commit.
git -C "$target_dir" rev-parse --verify HEAD >/dev/null 2>&1 || exit 0

output="$(cd "$repo_root" && PKG_AUDIT_NO_EXAMPLES=1 ./bin/package-audit "$target_dir" 2>&1)"
rc=$?

if [ "$rc" -ne 0 ]; then
    deny "Blocked by .claude/hooks/pre-commit-audit.sh: bin/package-audit found ERRORs in $target_dir before commit.

$output

Fix the errors above, then retry the commit."
fi

exit 0
