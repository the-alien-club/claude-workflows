#!/usr/bin/env bash
# Pre-MR playbook review hook for Claude Code.
#
# Intercepts glab mr create commands and denies the first attempt, instructing
# Claude to run a playbook review on the branch before the MR is opened.
# Falls back silently if no playbook exists for the repo.
#
# A time-limited marker file prevents infinite deny loops: the second attempt
# within 3 minutes is allowed through.

set -euo pipefail

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only intercept glab mr create
if ! echo "$COMMAND" | grep -qE 'glab\s+mr\s+create\b'; then
    exit 0
fi

# Skip playbook review for branch-promotion MRs (dev→staging, staging→main).
# All content was already reviewed when it landed on the source branch via
# normal feature MRs. Re-reviewing on promotion surfaces pre-existing
# violations that are out of scope for the promotion. See feedback memory:
# feedback_no_playbook_on_promotion_mrs.md
SRC_BRANCH=$(echo "$COMMAND" | grep -oE -- '--source-branch[= ]+[^ ]+' | head -1 | sed -E 's/--source-branch[= ]+//')
TGT_BRANCH=$(echo "$COMMAND" | grep -oE -- '--target-branch[= ]+[^ ]+' | head -1 | sed -E 's/--target-branch[= ]+//')
if [[ "$SRC_BRANCH" == "dev" && "$TGT_BRANCH" == "staging" ]] \
   || [[ "$SRC_BRANCH" == "staging" && "$TGT_BRANCH" == "main" ]]; then
    exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
[[ -z "$CWD" ]] && exit 0

# Handle "cd <dir> && glab mr create ..." compound commands
if [[ "$COMMAND" =~ ^cd[[:space:]]+([^;&\|]+) ]]; then
    CD_TARGET=$(echo "${BASH_REMATCH[1]}" | xargs)
    if [[ "$CD_TARGET" = /* ]]; then
        CWD="$CD_TARGET"
    else
        CWD="$CWD/$CD_TARGET"
    fi
fi

GIT_ROOT=$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || exit 0
[[ -z "$GIT_ROOT" ]] && exit 0

# No playbook: nothing to enforce, allow the MR
if [[ ! -d "$GIT_ROOT/playbook" ]]; then
    exit 0
fi

PLAYBOOK_DIR="$GIT_ROOT/playbook"

# Marker prevents infinite deny loop
REPO_HASH=$(echo "$GIT_ROOT" | md5sum | cut -d' ' -f1)
MARKER="/tmp/.claude-mr-reviewed-${REPO_HASH}"

if [[ -f "$MARKER" ]]; then
    MARKER_AGE=$(( $(date +%s) - $(stat -c %Y "$MARKER" 2>/dev/null || echo 0) ))
    if [[ $MARKER_AGE -lt 180 ]]; then
        rm -f "$MARKER"
        exit 0
    fi
    rm -f "$MARKER"
fi

CURRENT_BRANCH=$(cd "$GIT_ROOT" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
DIFF_STAT=$(cd "$GIT_ROOT" && git diff dev...HEAD --stat 2>/dev/null || git diff main...HEAD --stat 2>/dev/null || echo "(could not compute diff stat)")

touch "$MARKER"

read -r -d '' CONTEXT <<CTXEOF || true
PLAYBOOK REVIEW REQUIRED BEFORE OPENING MR

This repo has a playbook. You MUST review the branch diff against it before
creating the merge request. Use the playbook-reviewer agent — do not review manually.

Steps:
1. Spawn the playbook-reviewer agent with:
   - Target: git diff dev...HEAD -U10 (run from $GIT_ROOT; fall back to main if dev doesn't exist)
   - Playbook: $PLAYBOOK_DIR
   - Working directory: $GIT_ROOT
2. If the agent reports violations, fix them, commit the fixes, then run glab mr create again.
3. If the agent reports "No violations found.", run glab mr create again immediately.

Current branch: $CURRENT_BRANCH
Diff stat:
${DIFF_STAT}
CTXEOF

jq -n \
    --arg reason "Playbook review required. Spawn the playbook-reviewer agent before opening the MR." \
    --arg context "$CONTEXT" \
    '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason,
            additionalContext: $context
        }
    }'
