#!/usr/bin/env bash
# Pre-MR playbook review hook for Claude Code.
#
# Intercepts `glab mr create` and allows it only when the session transcript
# proves that the review_playbook skill ran for this exact HEAD: every changed
# file named in the prompt of a playbook-reviewer agent started after HEAD was
# committed, and every such reviewer reported "No violations found.".
# Verification lives in mr_review_verify.py; the hook keeps no state file.
# Passes through silently if the repo has no playbook.
#
# This is the only playbook gate. Commits are deliberately not gated: one
# review of the whole branch at MR time costs far less than one per commit.

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
# `|| true`: under pipefail an absent flag makes grep exit 1, which would kill
# the hook, and a hook that errors does not block, so the gate never fired.
SRC_BRANCH=$(echo "$COMMAND" | grep -oE -- '--source-branch[= ]+[^ ]+' | head -1 | sed -E 's/--source-branch[= ]+//' || true)
TGT_BRANCH=$(echo "$COMMAND" | grep -oE -- '--target-branch[= ]+[^ ]+' | head -1 | sed -E 's/--target-branch[= ]+//' || true)
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

# Discover every playbook directory at or below the git root: the repo root
# plus any packages/*/playbook (monorepo layout, e.g. web-app). A changed file
# is reviewed against the NEAREST playbook above it in the tree.
declare -a PLAYBOOK_DIRS=()
[[ -d "$GIT_ROOT/playbook" ]] && PLAYBOOK_DIRS+=("$GIT_ROOT/playbook")
for pb in "$GIT_ROOT"/packages/*/playbook; do
    [[ -d "$pb" ]] && PLAYBOOK_DIRS+=("$pb")
done

# No playbook anywhere: nothing to enforce, allow the MR
if [[ ${#PLAYBOOK_DIRS[@]} -eq 0 ]]; then
    exit 0
fi

# nearest_playbook <repo-relative-path> → absolute playbook dir governing it,
# or empty. The governing playbook is the one whose parent directory is the
# deepest ancestor of the file. The root playbook (if present) governs every
# file not claimed by a deeper package playbook.
nearest_playbook() {
    local rel="$1" best="" best_depth=-1
    local pb parent depth
    for pb in "${PLAYBOOK_DIRS[@]}"; do
        parent="${pb%/playbook}"        # absolute dir the playbook governs
        parent="${parent#"$GIT_ROOT"}"  # make repo-relative
        parent="${parent#/}"            # strip leading slash → "" at root
        if [[ -z "$parent" ]]; then
            depth=0                     # root playbook governs everything
        elif [[ "$rel" == "$parent/"* ]]; then
            depth=$(( $(grep -o "/" <<<"$parent" | wc -l) + 1 ))
        else
            continue
        fi
        if (( depth > best_depth )); then
            best_depth=$depth
            best="$pb"
        fi
    done
    printf '%s' "$best"
}

deny() {
    jq -n --arg reason "$1" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason,
            additionalContext: $reason
        }
    }'
    exit 0
}

# Diff against the remote-tracking ref of the MR target (--target-branch, else
# dev, else main). A local branch is only a fallback: a stale local dev makes
# the diff include files from other MRs merged since, and every one of them
# costs a reviewer agent.
BASE=""
for candidate in ${TGT_BRANCH:+"origin/$TGT_BRANCH" "$TGT_BRANCH"} origin/dev dev origin/main main; do
    if (cd "$GIT_ROOT" && git rev-parse --verify --quiet "$candidate" >/dev/null 2>&1); then
        BASE="$candidate"
        break
    fi
done
[[ -z "$BASE" ]] && deny "Playbook review cannot be verified: no base ref found (tried origin/dev, dev, origin/main, main). Pass --target-branch with a branch that exists locally or on origin."

# Deleted files have nothing left to review.
if ! CHANGED_FILES=$(cd "$GIT_ROOT" && git -c core.quotepath=off diff "$BASE"...HEAD --name-only --diff-filter=d 2>&1); then
    deny "Playbook review cannot be verified: git diff $BASE...HEAD failed: $CHANGED_FILES"
fi
HEAD_SHA=$(cd "$GIT_ROOT" && git rev-parse HEAD)
HEAD_TIME=$(cd "$GIT_ROOT" && git log -1 --format=%ct HEAD)

# Only files governed by some playbook need a review; the rest are not covered
# by any rule. A changed file is reviewed against its NEAREST playbook.
GOVERNED=""
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    [[ -n "$(nearest_playbook "$f")" ]] && GOVERNED+="$f"$'\n'
done <<< "$CHANGED_FILES"

# No changed file is governed by any playbook: nothing to review, allow the MR.
[[ -z "$GOVERNED" ]] && exit 0

TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""')
[[ -z "$TRANSCRIPT" ]] && deny "Playbook review cannot be verified: the hook input carries no transcript_path. Never allowed by default."

VERIFIER="$(dirname "${BASH_SOURCE[0]}")/mr_review_verify.py"
if VERDICT=$(printf '%s' "$GOVERNED" | python3 "$VERIFIER" \
        --transcript "$TRANSCRIPT" --repo "$GIT_ROOT" --head "$HEAD_SHA" --head-time "$HEAD_TIME" 2>&1); then
    exit 0
fi
deny "${VERDICT:-Playbook review could not be verified (verifier produced no output).}"
