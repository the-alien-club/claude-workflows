#!/usr/bin/env bash
# Red/green tests for hooks/mr-review.sh.
#
#   hooks/tests/test_mr_review.sh                 # test the hook next to this dir
#   HOOK=/path/to/old/mr-review.sh hooks/tests/test_mr_review.sh
#
# Fixtures (a git repo with a playbook/ and session transcripts) are built under
# WORK, default /scratch/claude/DataStreaming/itg-contradictions/hook-tests.
# Every case runs the hook TWICE: a retry must not change the verdict, which is
# exactly what the old 180 s marker version got wrong.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${HOOK:-$HERE/../mr-review.sh}"
WORK="${WORK:-/scratch/claude/DataStreaming/itg-contradictions/hook-tests}/run-$$"
MK="$HERE/make_transcript.py"
T0="2026-11-04T10:00:00Z"        # HEAD commit time
BEFORE="2026-11-04T09:55:00.000Z"
AFTER="2026-11-04T10:05:00.000Z"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

PASS=0; FAIL=0

git_in() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}"; }

make_repo() {  # $1 dir, $2 with-playbook(1/0)
    git init -q -b main "$1"
    [[ "$2" == 1 ]] && { mkdir "$1/playbook"; echo "# no bare except" > "$1/playbook/rule.md"; }
    echo base > "$1/a.py"; git_in "$1" add -A; git_in "$1" commit -qm base
    git_in "$1" checkout -qb feature
    echo one >> "$1/a.py"; echo two > "$1/b.py"; git_in "$1" add -A
    GIT_COMMITTER_DATE="$T0" git_in "$1" commit -qm "feat: change"
}

REPO="$WORK/repo"; make_repo "$REPO" 1
BARE="$WORK/noplaybook"; make_repo "$BARE" 0

hook_in() {  # $1 cwd, $2 transcript path, $3 command
    jq -n --arg cwd "$1" --arg t "$2" --arg c "$3" \
        '{cwd:$cwd, transcript_path:$t, tool_input:{command:$c}}'
}

verdict() { grep -q '"permissionDecision": "deny"' <<<"$1" && echo DENY || echo ALLOW; }

# run_case NAME EXPECT(DENY|ALLOW) MUST_CONTAIN CWD TRANSCRIPT COMMAND
run_case() {
    local name="$1" expect="$2" needle="$3" cwd="$4" tr="$5" cmd="$6" out1 out2 v1 v2 ok=1
    out1=$(hook_in "$cwd" "$tr" "$cmd" | "$HOOK" 2>&1); v1=$(verdict "$out1")
    out2=$(hook_in "$cwd" "$tr" "$cmd" | "$HOOK" 2>&1); v2=$(verdict "$out2")   # the retry
    [[ "$v1" == "$expect" && "$v2" == "$expect" ]] || ok=0
    [[ -z "$needle" || "$expect" == ALLOW ]] || { grep -qF -- "$needle" <<<"$out2" || ok=0; }
    if (( ok )); then PASS=$((PASS+1)); echo "ok   $name (first=$v1 retry=$v2)"
    else FAIL=$((FAIL+1)); echo "FAIL $name: want $expect containing '${needle}', got first=$v1 retry=$v2"; fi
}

tr_make() { echo "$2" | python3 "$MK" "$WORK/$1.jsonl"; echo "$WORK/$1.jsonl"; }
MR="glab mr create --title t"
rev() { # files at result [subagent]
    jq -nc --argjson f "$1" --arg at "$2" --arg r "$3" --arg s "${4:-playbook-reviewer}" \
        '{files:$f, at:$at, result:$r, subagent:$s}'
}
spec() { local IFS=,; echo "[$*]"; }

# Fixture transcripts
T_NONE=$(tr_make none '[]')
T_CLEAN=$(tr_make clean "$(spec "$(rev '["a.py"]' $AFTER clean)" "$(rev '["b.py"]' $AFTER clean)")")
T_CLEAN_SYNC=$(tr_make cleansync "$(spec "$(rev '["a.py"]' $AFTER sync-clean)" "$(rev '["b.py"]' $AFTER sync-clean)")")
T_NS=$(tr_make namespaced "$(spec "$(rev '["a.py"]' $AFTER clean alien-intelligence-workflows:playbook-reviewer)" "$(rev '["b.py"]' $AFTER clean alien-intelligence-workflows:playbook-reviewer)")")
T_MISSING=$(tr_make missing "$(spec "$(rev '["a.py"]' $AFTER clean)")")
T_VIOL=$(tr_make viol "$(spec "$(rev '["a.py"]' $AFTER clean)" "$(rev '["b.py"]' $AFTER violations)")")
T_VIOL_SYNC=$(tr_make violsync "$(spec "$(rev '["a.py"]' $AFTER sync-clean)" "$(rev '["b.py"]' $AFTER sync-violations)")")
T_LEGACY=$(tr_make legacy "$(spec "$(rev '["a.py"]' $AFTER legacy-clean)" "$(rev '["b.py"]' $AFTER legacy-clean)")")
T_LEGACY_V=$(tr_make legacyv "$(spec "$(rev '["a.py"]' $AFTER legacy-clean)" "$(rev '["b.py"]' $AFTER legacy-violations)")")
T_STALE=$(tr_make stale "$(spec "$(rev '["a.py"]' $BEFORE clean)" "$(rev '["b.py"]' $BEFORE clean)")")
T_PENDING=$(tr_make pending "$(spec "$(rev '["a.py"]' $AFTER clean)" "$(rev '["b.py"]' $AFTER pending)")")
T_PARALLEL=$(tr_make parallel "$(spec "$(rev '["a.py"]' $AFTER clean)" "$(rev '["b.py"]' $AFTER clean)" "$(rev '["a.py"]' $AFTER violations)")")
printf 'this is not json\n' > "$WORK/garbage.jsonl"

run_case "no reviewer -> deny"                      DENY "a.py"      "$REPO" "$T_NONE"        "$MR"
run_case "clean reviewers cover all files -> allow" ALLOW ""         "$REPO" "$T_CLEAN"       "$MR"
run_case "foreground (sync) clean reviewers -> allow" ALLOW ""       "$REPO" "$T_CLEAN_SYNC"  "$MR"
run_case "plugin-namespaced subagent_type -> allow" ALLOW ""         "$REPO" "$T_NS"          "$MR"
run_case "older harness (<result> in notification) clean -> allow" ALLOW "" "$REPO" "$T_LEGACY" "$MR"
run_case "older harness violations -> deny"          DENY "reported violations" "$REPO" "$T_LEGACY_V" "$MR"
run_case "cd <dir> && glab mr create -> allow"      ALLOW ""         "$WORK" "$T_CLEAN"       "cd $REPO && $MR"
run_case "one file uncovered -> deny, names it"     DENY "b.py"      "$REPO" "$T_MISSING"     "$MR"
run_case "reviewer reports violations -> deny"      DENY "reported violations" "$REPO" "$T_VIOL" "$MR"
run_case "sync reviewer violations -> deny"         DENY "reported violations" "$REPO" "$T_VIOL_SYNC" "$MR"
run_case "commit after a clean review -> deny"      DENY "a.py"      "$REPO" "$T_STALE"       "$MR"
run_case "review with no result yet -> deny"        DENY "no result yet" "$REPO" "$T_PENDING" "$MR"
run_case "parallel: one of two covering a.py violates -> deny" DENY "reported violations" "$REPO" "$T_PARALLEL" "$MR"
run_case "unreadable transcript -> deny"            DENY "cannot read" "$REPO" "$WORK/nope.jsonl" "$MR"
run_case "unparseable transcript -> deny"           DENY "could not be verified" "$REPO" "$WORK/garbage.jsonl" "$MR"
run_case "no transcript_path -> deny"               DENY "transcript_path" "$REPO" "" "$MR"
run_case "command without glab mr create -> pass"   ALLOW ""         "$REPO" "$T_NONE"        "git status"
run_case "repo without playbook/ -> pass"           ALLOW ""         "$BARE" "$T_NONE"        "$MR"

# A commit made after the clean review must invalidate it, even on a later retry.
echo three >> "$REPO/a.py"; git_in "$REPO" commit -qam "fix: later"
run_case "new commit after clean review -> deny"    DENY "a.py"      "$REPO" "$T_CLEAN"       "$MR"
# The marker file must be gone entirely.
if grep -qE 'claude-mr-reviewed|/tmp|md5sum' "$HERE/../mr-review.sh" "$HERE/../mr_review_verify.py"; then
    FAIL=$((FAIL+1)); echo "FAIL hook still references /tmp or a marker"; else PASS=$((PASS+1)); echo "ok   no marker / no /tmp in hook"; fi

echo; echo "passed=$PASS failed=$FAIL"
(( FAIL == 0 ))
