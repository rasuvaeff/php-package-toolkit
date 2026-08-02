#!/bin/bash
set -uo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

if [ "$tool_name" != "Bash" ]; then
    exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

# Heredoc bodies (commit messages, PR descriptions, etc.) are data, not shell
# code — scanning them for danger patterns produces false positives (e.g. a
# commit message that mentions "rm -rf" as prose). Blank them out before
# pattern-matching.
scan_command=$(awk '
    in_heredoc {
        if ($0 == delim) { in_heredoc = 0 }
        next
    }
    match($0, /<<-?[[:space:]]*["'"'"']?[A-Za-z_][A-Za-z0-9_]*["'"'"']?/) {
        tmp = substr($0, RSTART, RLENGTH)
        gsub(/<<-?[[:space:]]*["'"'"']?/, "", tmp)
        gsub(/["'"'"']$/, "", tmp)
        delim = tmp
        in_heredoc = 1
        print $0
        next
    }
    { print }
' <<< "$command")

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

# rm -rf on a root-ish target
if echo "$scan_command" | grep -qE '\brm\s+(-[a-zA-Z]*[rf][a-zA-Z]*[rf]?[a-zA-Z]*|--recursive.*--force|--force.*--recursive)\b' \
    && echo "$scan_command" | grep -qE '(^|[[:space:]])(/|/\*|~|~/|\$HOME|\$\{HOME\})([[:space:]]|$)'; then
    deny 'Blocked by .claude/hooks/bash-guard.sh: rm -rf on a root-ish path (/, ~, $HOME). If this is genuinely intended, ask the user to run it manually with "!".'
fi

# git push --force
if echo "$scan_command" | grep -qE '\bgit[[:space:]]+push\b' \
    && echo "$scan_command" | grep -qE '(--force\b|--force-with-lease\b|[[:space:]]-f\b)'; then

    after_push=$(echo "$scan_command" | sed -E 's/^.*\bgit[[:space:]]+push\b//')
    positional=()
    for tok in $after_push; do
        case "$tok" in
            -*) ;;
            *) positional+=("$tok") ;;
        esac
    done

    target_branch=""
    if [ "${#positional[@]}" -ge 2 ]; then
        refspec="${positional[1]}"
        target_branch="${refspec##*:}"
    fi

    if [ -n "$target_branch" ]; then
        if [ "$target_branch" = "main" ] || [ "$target_branch" = "master" ]; then
            deny "Blocked by .claude/hooks/bash-guard.sh: force-push to $target_branch. AGENTS.md/system rules forbid force-pushing main/master. Ask the user to run it manually with \"!\" if truly intended."
        fi
    elif [ -n "$cwd" ]; then
        current=$(git -C "$cwd" symbolic-ref --short -q HEAD 2>/dev/null || true)
        if [ "$current" = "main" ] || [ "$current" = "master" ]; then
            deny "Blocked by .claude/hooks/bash-guard.sh: force-push with no explicit branch while on $current. AGENTS.md/system rules forbid force-pushing main/master. Ask the user to run it manually with \"!\" if truly intended."
        fi
    fi
fi

# git reset --hard
if echo "$scan_command" | grep -qE '\bgit[[:space:]]+reset\b' && echo "$scan_command" | grep -qE '\-\-hard\b'; then
    deny 'Blocked by .claude/hooks/bash-guard.sh: git reset --hard discards uncommitted work irreversibly. Ask the user to run it manually with "!" if truly intended.'
fi

# git tag -d (re-tag policy: AGENTS.md forbids deleting/recreating a tag once pushed).
# -d/--delete must appear in the SAME command segment as `git tag` (not across ;/&/|),
# otherwise e.g. `gh pr merge --delete-branch && git tag -a ...` false-positives.
if echo "$scan_command" | grep -qE '\bgit[[:space:]]+tag[[:space:]]+([^;&|]*[[:space:]])?-(d|-delete)\b'; then
    deny 'Blocked by .claude/hooks/bash-guard.sh: git tag -d. AGENTS.md forbids re-tagging after a tag is pushed (Packagist blocks re-tagged versions permanently). Verify the tag was never pushed, then ask the user to run this manually with "!".'
fi

exit 0
