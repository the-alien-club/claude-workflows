#!/usr/bin/env bash
# Claude Code hook (PreToolUse + PostToolUse on Bash) for repositories released by the vbump bot.
#
# The release bot derives every version bump from commit messages, and GitLab's push rule rejects a
# non-conforming message at `git push` with nothing but a raw regex. This hook tells the agent WHAT is
# wrong and HOW to fix it, at the earliest point:
#
#   PostToolUse, after `git commit` / `git merge` / `git revert`:  checks the commit just made.
#   PreToolUse,  before `git push`:  checks every commit about to be pushed and blocks the push.
#
# Only repositories with a release-units.yaml are policed, so the hook is inert until a repo migrates.
# The rules themselves live in vbump (`vbump check-message`), the same code that generates the push-rule
# regex and runs the MR commit-lint, so the three can never disagree.
#
# vbump comes from ci-scripts main via uvx (cached by uv), so no local ci-scripts checkout is needed. A bare
# `vbump` is never called: an unrelated tool of the same name exists in some Python environments.
#
# Env:
#   VBUMP_PROJECT  optional local vbump package directory (a ci-scripts checkout's vbump/), for developing vbump

set -euo pipefail

INPUT=$(cat)
EVENT=$(jq -r '.hook_event_name // ""' <<<"$INPUT")
COMMAND=$(jq -r '.tool_input.command // ""' <<<"$INPUT")
CWD=$(jq -r '.cwd // ""' <<<"$INPUT")
VBUMP_SOURCE="git+https://gitlab.com/alias3/datastreaming/ci-scripts.git@main#subdirectory=vbump"

case "$EVENT:$COMMAND" in
  PostToolUse:*"git "*commit*|PostToolUse:*"git "*merge*|PostToolUse:*"git "*revert*) MODE=commit ;;
  PreToolUse:*"git "*push*) MODE=push ;;
  *) exit 0 ;;
esac

# The repository the command acted on: an explicit `git -C <dir>` or a leading `cd <dir> &&`, else the cwd.
DIR=$(sed -nE 's/.*git -C ("([^"]+)"|([^ ]+)).*/\2\3/p' <<<"$COMMAND" | head -1)
[ -n "$DIR" ] || DIR=$(sed -nE 's/^cd ("([^"]+)"|([^ ;&]+)).*/\2\3/p' <<<"$COMMAND" | head -1)
case "$DIR" in
  "") DIR="$CWD" ;;
  /*) ;;
  *) DIR="$CWD/$DIR" ;;
esac
[ -d "$DIR" ] || exit 0
ROOT=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$ROOT/release-units.yaml" ] || exit 0

if ! command -v uv >/dev/null 2>&1; then
  echo "commit-msg-guard: uv is not installed — cannot check commit messages in $ROOT." >&2
  echo "Install uv (https://docs.astral.sh/uv/); GitLab's push rule will still reject bad messages." >&2
  exit 2
fi
if [ -n "${VBUMP_PROJECT:-}" ]; then
  VBUMP=(uv run --quiet --project "$VBUMP_PROJECT" vbump)
else
  VBUMP=(uvx --quiet --from "$VBUMP_SOURCE" vbump)
fi

if [ "$MODE" = commit ]; then
  REVISIONS=(-1 HEAD)
else
  # Everything not yet on a long-lived branch: exactly what the push and the MR commit-lint will judge.
  REVISIONS=(HEAD --not)
  for branch in dev staging main; do
    git -C "$ROOT" rev-parse -q --verify "origin/$branch" >/dev/null && REVISIONS+=("origin/$branch")
  done
fi

# `--`: the revisions contain `--not`, which must reach git, not vbump's option parser.
RC=0
OUT=$("${VBUMP[@]}" --root "$ROOT" check-message -- "${REVISIONS[@]}" 2>&1) || RC=$?
[ "$RC" -eq 0 ] && exit 0
if [ "$RC" -ne 1 ]; then
  # vbump exits 1 for a bad message. Anything else is this hook failing, and must not pose as a verdict.
  echo "commit-msg-guard: could not check commit messages in $ROOT (vbump exit $RC):" >&2
  echo "$OUT" >&2
  exit 2
fi

if [ "$MODE" = commit ]; then
  HEADLINE="⚠️ The commit you just made has a message this repository will reject."
else
  HEADLINE="🚫 BLOCKED: this push contains commit messages GitLab's push rule will reject."
fi
cat <<EOF >&2
$HEADLINE

Repository: $ROOT
$OUT

Why it matters: the release bot computes the version bump from these messages after merge
(feat → minor, fix/other → patch, '!' → major for the units named in the scope). Do NOT edit
version files by hand — fix the message instead.
EOF
exit 2
