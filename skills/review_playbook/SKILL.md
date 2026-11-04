---
name: review_playbook
description: "Review a commit or MR against the repo's playbook rules. Spawns one playbook-reviewer agent per changed file, in parallel, so no violation is missed to context saturation. Strict: every violation cited with file and line, pre-existing violations included. Its result is what the MR gate hook (mr-review.sh) verifies before glab mr create."
user-invocable: true
allowed-tools: Bash, Agent
---

# Review Against Playbook

This skill spawns one `playbook-reviewer` agent per changed file. Each agent reads the rules and its file's diff on its own. Your job is only to resolve the target, find the playbooks, and fan out.

The `mr-review.sh` hook gates `glab mr create` on this review. It reads the session transcript and allows the MR only if the conditions below hold, so follow them exactly.

## Gate contract

- **One reviewer per changed governed file.** A file is governed by the nearest `playbook/` above it. Deleted files are skipped.
- **Spawn them directly from the session that will run `glab mr create`**, with the Agent tool and `subagent_type: "playbook-reviewer"` (the plugin-prefixed name also counts). Reviewers spawned inside a subagent are not in this session's transcript and do not count.
- **Each prompt names its file path**, repo-relative or absolute. A reviewer whose prompt does not name a file covers nothing.
- **A clean result is exactly `No violations found.`** Any other output, including a summary, counts as violations.
- **Only reviews started after HEAD was committed count.** Any new commit, including a merge of `origin/dev`, needs a fresh review. Merge `origin/dev` first, then review, then open the MR. If violations are reported: fix, commit, and run this skill again on the new HEAD.
- A reviewer with no result yet does not count. Wait for all of them.

---

## Step 1: Resolve the Target

Argument forms:
- No argument: current branch vs the MR target (`origin/dev`, else `origin/main`; use `origin/<target>` when the MR targets another branch). Merge it into the branch first.
- `!1234` or `1234` (numeric): GitLab MR number
- 7-40 hex chars: commit SHA
- A branch name: that branch vs `origin/dev`

## Step 2: Find the Playbooks and the Files

```bash
find . -type d -name playbook | grep -v node_modules | grep -v .git
```

List the changed files, excluding deletions:

```bash
git diff origin/dev...HEAD --name-only --diff-filter=d   # commit: git show [sha] --name-only
```

Assign each file to the nearest playbook above it (the root `playbook/` governs everything not claimed by a deeper `packages/*/playbook`). Files with no playbook above them are skipped.

If no playbook is found, stop and report:
> No playbook found. Run `/add_playbook_rule` to create rules first.

## Step 3: Spawn One Reviewer per File

In a single message, call `Agent` once per governed file with `subagent_type: "playbook-reviewer"`. Each prompt contains only:
- the file path (repo-relative)
- the diff command for that file only
- the absolute path to its playbook directory
- the working directory

Example prompt:

```
Review a single file for playbook violations.

File under review: packages/backend/app/services/foo.ts

Diff command to get this file's changes:
  git diff origin/dev...HEAD -- packages/backend/app/services/foo.ts -U10

Playbook directory: /home/xqua/Documents/Work/Alien/DataStreaming/web-app/packages/backend/playbook
Working directory: /home/xqua/Documents/Work/Alien/DataStreaming/web-app
```

## Step 4: Relay Output

Print each agent's output verbatim, grouped by file. Do not editorialize, soften, or add context.

Append this footer:

```
---
Playbook : [path(s)]
Target   : [resolved target]
Reviewed : [n files, n reviewers, n clean]
```
