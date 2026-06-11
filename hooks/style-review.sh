#!/usr/bin/env bash
# Pre-commit review hook for Claude Code.
#
# Intercepts git commit commands and denies the first attempt to trigger a
# review. Two flows depending on what the repo has:
#
#   1. playbook/ directory exists → instruct Claude to spawn the
#      playbook-reviewer agent against the staged diff (new flow).
#   2. STYLE.md exists, no playbook → instruct Claude to read STYLE.md and
#      review staged changes manually (legacy flow, kept during migration).
#
# A time-limited marker file prevents infinite deny loops: the second commit
# attempt within 3 minutes is allowed through.
#
# Web-app special case (STYLE.md flow only): selects backend/STYLE.md,
# frontend/STYLE.md, or both based on which packages have staged files.

set -euo pipefail

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only intercept git commit commands
if ! echo "$COMMAND" | grep -qE 'git\s+(.*\s+)?commit\b'; then
    exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
[[ -z "$CWD" ]] && exit 0

# Handle "cd <dir> && git commit ..." compound commands
if [[ "$COMMAND" =~ ^cd[[:space:]]+([^;&\|]+) ]]; then
    CD_TARGET=$(echo "${BASH_REMATCH[1]}" | xargs)
    if [[ "$CD_TARGET" = /* ]]; then
        CWD="$CD_TARGET"
    else
        CWD="$CWD/$CD_TARGET"
    fi
fi

# Find the git repository root
GIT_ROOT=$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || exit 0
[[ -z "$GIT_ROOT" ]] && exit 0

# Marker file prevents infinite deny loop.
# First attempt: create marker + deny.  Second attempt within 180s: allow.
REPO_HASH=$(echo "$GIT_ROOT" | md5sum | cut -d' ' -f1)
MARKER="/tmp/.claude-style-reviewed-${REPO_HASH}"

if [[ -f "$MARKER" ]]; then
    MARKER_AGE=$(( $(date +%s) - $(stat -c %Y "$MARKER" 2>/dev/null || echo 0) ))
    if [[ $MARKER_AGE -lt 180 ]]; then
        rm -f "$MARKER"
        exit 0
    fi
    rm -f "$MARKER"
fi

# ── Flow selection ──────────────────────────────────────────────────────────
# Check for a playbook directory in the git root first. If found, use the
# playbook-reviewer agent flow. Otherwise fall back to STYLE.md.

PLAYBOOK_DIR=""
if [[ -d "$GIT_ROOT/playbook" ]]; then
    PLAYBOOK_DIR="$GIT_ROOT/playbook"
fi

REPO_NAME=$(basename "$GIT_ROOT")

if [[ -n "$PLAYBOOK_DIR" ]]; then
    # ── Playbook flow ────────────────────────────────────────────────────────
    STAGED_SUMMARY=$(cd "$GIT_ROOT" && git diff --cached --stat 2>/dev/null || echo "(no staged changes)")

    touch "$MARKER"

    read -r -d '' CONTEXT <<CTXEOF || true
PLAYBOOK REVIEW REQUIRED BEFORE COMMIT

This repo has a playbook. You MUST review the staged diff against it before
committing. Use the playbook-reviewer agent — do not review manually.

Steps:
1. Spawn the playbook-reviewer agent with:
   - Target: the staged diff (git diff --cached -U10 run from $GIT_ROOT)
   - Playbook: $PLAYBOOK_DIR
   - Working directory: $GIT_ROOT
2. If the agent reports violations, fix them, re-stage, and commit again.
3. If the agent reports "No violations found.", commit again immediately.

Staged files:
${STAGED_SUMMARY}
CTXEOF

    jq -n \
        --arg reason "Playbook review required. Spawn the playbook-reviewer agent before committing." \
        --arg context "$CONTEXT" \
        '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "deny",
                permissionDecisionReason: $reason,
                additionalContext: $context
            }
        }'

else
    # ── Legacy STYLE.md flow ─────────────────────────────────────────────────
    STYLE_PATHS=""

    if [[ "$REPO_NAME" == "web-app" ]]; then
        STAGED=$(cd "$GIT_ROOT" && git diff --cached --name-only 2>/dev/null || true)

        HAS_BACKEND=false
        HAS_FRONTEND=false

        if echo "$STAGED" | grep -q "^packages/backend/"; then
            HAS_BACKEND=true
        fi
        if echo "$STAGED" | grep -q "^packages/frontend/"; then
            HAS_FRONTEND=true
        fi

        # When staged files don't match either package, check both
        if ! $HAS_BACKEND && ! $HAS_FRONTEND; then
            HAS_BACKEND=true
            HAS_FRONTEND=true
        fi

        if $HAS_BACKEND && [[ -f "$GIT_ROOT/packages/backend/STYLE.md" ]]; then
            STYLE_PATHS="$GIT_ROOT/packages/backend/STYLE.md"
        fi
        if $HAS_FRONTEND && [[ -f "$GIT_ROOT/packages/frontend/STYLE.md" ]]; then
            [[ -n "$STYLE_PATHS" ]] && STYLE_PATHS="$STYLE_PATHS"$'\n'
            STYLE_PATHS="${STYLE_PATHS}$GIT_ROOT/packages/frontend/STYLE.md"
        fi
    else
        if [[ -f "$GIT_ROOT/STYLE.md" ]]; then
            STYLE_PATHS="$GIT_ROOT/STYLE.md"
        fi
    fi

    # No STYLE.md found: nothing to review, allow the commit
    if [[ -z "$STYLE_PATHS" ]]; then
        exit 0
    fi

    STAGED_SUMMARY=$(cd "$GIT_ROOT" && git diff --cached --stat 2>/dev/null || echo "(no staged changes)")

    touch "$MARKER"

    read -r -d '' CONTEXT <<CTXEOF || true
STYLE REVIEW REQUIRED BEFORE COMMIT

You MUST review all staged changes against the style guide before committing.

Steps:
1. Read the STYLE.md file(s) listed below
2. Run 'git diff --cached' in the repo ($GIT_ROOT) to see all staged changes
3. Compare every change against the style rules
4. Fix any violations and re-stage the fixes
5. Commit again once everything is compliant

STYLE.md file(s) to read:
${STYLE_PATHS}

Staged files:
${STAGED_SUMMARY}

If all changes already comply with the style guide, proceed to commit again immediately.
CTXEOF

    jq -n \
        --arg reason "Style review required. Read the repo STYLE.md and review staged changes before committing." \
        --arg context "$CONTEXT" \
        '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "deny",
                permissionDecisionReason: $reason,
                additionalContext: $context
            }
        }'
fi