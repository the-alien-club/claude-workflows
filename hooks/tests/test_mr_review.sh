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
[[ -n "${KEEP:-}" ]] || trap 'rm -rf "$WORK"' EXIT

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
# A reviewer of another repo's files (here c.py, not in this diff) that reported violations.
T_OTHER_REPO=$(tr_make otherrepo "$(spec "$(rev '["a.py"]' $AFTER clean)" "$(rev '["b.py"]' $AFTER clean)" "$(rev '["c.py"]' $AFTER violations)")")
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
run_case "violations on another repo's files only -> allow" ALLOW "" "$REPO" "$T_OTHER_REPO" "$MR"
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

# --- Rule scope: only files some rule's `## Scope` covers need a review ---------
# make_scope_repo DIR "<rule-file>=<body>" ... -- <changed files...>
# Rule bodies use \n for newlines. The base commit holds the playbook, the feature
# commit adds the changed files (playbook/ rule edits included).
make_scope_repo() {
    local dir="$1"; shift
    git init -q -b main "$dir"; mkdir "$dir/playbook"
    while [[ "$1" != "--" ]]; do
        printf '%b' "${1#*=}" > "$dir/playbook/${1%%=*}"; shift
    done; shift
    echo base > "$dir/base.txt"; git_in "$dir" add -A; git_in "$dir" commit -qm base
    git_in "$dir" checkout -qb feature
    local f; for f in "$@"; do mkdir -p "$dir/$(dirname "$f")"; echo x > "$dir/$f"; done
    git_in "$dir" add -A; GIT_COMMITTER_DATE="$T0" git_in "$dir" commit -qm "feat: change"
}
RUST_RULE='## Scope\n`**/*.rs`, `Cargo.toml`\n\n## Rule\nno unwrap\n'
TS_RULE='## Scope\n`frontend/**/*.ts` containing MCP tools (`#[tool(`)\n\n## Rule\nno any\n'
ITG_FILES=(src/x.rs playbook/README.md .gitlab-ci.yml)

ITG="$WORK/itg"
make_scope_repo "$ITG" "rust-a.md=$RUST_RULE" "ts-b.md=$TS_RULE" "README.md=# index\n" "_template.md=# t\n" -- "${ITG_FILES[@]}"
T_RS=$(tr_make rs "$(spec "$(rev '["src/x.rs"]' $AFTER clean)")")
T_ALLFILES=$(tr_make allfiles "$(spec "$(rev '["src/x.rs"]' $AFTER clean)" "$(rev '[".gitlab-ci.yml"]' $AFTER clean)" "$(rev '["playbook/README.md"]' $AFTER clean)")")
run_case "scope: no review -> deny, names the covered file"      DENY "src/x.rs" "$ITG" "$T_NONE" "$MR"
run_case "scope: deny says how many files were skipped"          DENY "2 changed file(s) skipped" "$ITG" "$T_NONE" "$MR"
run_case "scope: only covered file reviewed -> allow"            ALLOW "" "$ITG" "$T_RS" "$MR"
run_case "scope: reviewing everything -> allow"                  ALLOW "" "$ITG" "$T_ALLFILES" "$MR"

# Nothing changed is covered: no review needed at all.
SKIPONLY="$WORK/skiponly"
make_scope_repo "$SKIPONLY" "rust-a.md=$RUST_RULE" -- .gitlab-ci.yml docs/guide.md playbook/README.md
run_case "scope: only uncovered files changed -> allow, no reviewers" ALLOW "" "$SKIPONLY" "$T_NONE" "$MR"

# One rule without Scope covers every file (old playbooks behave as before).
NOSCOPE="$WORK/noscope"
make_scope_repo "$NOSCOPE" "rust-a.md=$RUST_RULE" "plain.md=# plain rule\nno bare except\n" -- "${ITG_FILES[@]}"
run_case "scope: a rule without Scope -> everything required"    DENY ".gitlab-ci.yml" "$NOSCOPE" "$T_NONE" "$MR"
run_case "scope: a rule without Scope -> nothing skipped"        DENY "0 changed file(s) skipped" "$NOSCOPE" "$T_NONE" "$MR"
# README.md and _-prefixed files are not rules: their lack of Scope must not widen it.
run_case "scope: README/_template without Scope are not rules"   ALLOW "" "$ITG" "$T_RS" "$MR"

# A Scope section with no parseable glob fails closed and warns.
EMPTYSCOPE="$WORK/emptyscope"
make_scope_repo "$EMPTYSCOPE" "rust-a.md=$RUST_RULE" "vague.md=## Scope\nall the Rust sources\n\n## Rule\nx\n" -- "${ITG_FILES[@]}"
run_case "scope: no parseable glob -> fail closed (all required)" DENY ".gitlab-ci.yml" "$EMPTYSCOPE" "$T_NONE" "$MR"
run_case "scope: no parseable glob -> warning in output"          DENY "WARNING: " "$EMPTYSCOPE" "$T_NONE" "$MR"
run_case "scope: warning names the rule file"                     DENY "vague.md" "$EMPTYSCOPE" "$T_NONE" "$MR"

# Glob semantics. `*` stays inside one segment; `**` spans segments (and may span none).
GLOBS="$WORK/globs"
make_scope_repo "$GLOBS" \
    "a.md=## Scope\n\`src/*.rs\`\n" \
    "b.md=## Scope\n\`lib/**/*.py\`, \`web/**\`, \`conf/\`, \`*.toml\`\n" \
    -- src/x.rs src/deep/y.rs lib/a.py lib/b/c/d.py libx/a.py lib/a.pyc web/p/q.txt web.txt conf/z.yml top.toml sub/top.toml
GLOB_OUT=$(hook_in "$GLOBS" "$T_NONE" "$MR" | "$HOOK" 2>&1)
glob_expect() {  # name required|skipped path
    local listed=0; grep -qF -- "- $3  (" <<<"$GLOB_OUT" && listed=1
    if [[ ( "$2" == required && $listed == 1 ) || ( "$2" == skipped && $listed == 0 ) ]]; then
        PASS=$((PASS+1)); echo "ok   glob: $3 is $2"
    else FAIL=$((FAIL+1)); echo "FAIL glob: $3 should be $2"; fi
}
glob_expect x required src/x.rs          # src/*.rs: one segment
glob_expect x skipped  src/deep/y.rs     # * does not cross /
glob_expect x required lib/a.py          # lib/**/*.py: zero segments in between
glob_expect x required lib/b/c/d.py      # ** spans several segments
glob_expect x skipped  libx/a.py         # ** must not match a sibling prefix
glob_expect x skipped  lib/a.pyc         # extension must match fully
glob_expect x required web/p/q.txt       # web/** : anything below web/
glob_expect x skipped  web.txt           # web/** needs the slash
glob_expect x required conf/z.yml        # trailing slash = everything below
glob_expect x required top.toml          # *.toml at the root
glob_expect x skipped  sub/top.toml      # root-relative: * does not reach into sub/

echo; echo "passed=$PASS failed=$FAIL"
(( FAIL == 0 ))
