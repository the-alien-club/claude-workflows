---
name: review_playbook
description: "Review a commit or MR against the repo's playbook rules. Spawns a fresh playbook-reviewer agent that reads the rules and diff independently. Strict — every violation cited with file and line, pre-existing violations included."
user-invocable: true
allowed-tools: Bash, Agent
---

# Review Against Playbook

This skill spawns the `playbook-reviewer` agent with a target and a playbook path. The agent does all the reading — rules and diff — on its own. Your job here is only to resolve the target and locate the correct playbook.

---

## Step 1 — Resolve the Target

Argument forms:
- No argument → current branch vs `dev` (fall back to `main`)
- `!1234` or `1234` (numeric) → GitLab MR number
- 7–40 hex chars → commit SHA
- A branch name → that branch vs `dev`

---

## Step 2 — Find the Playbook

```bash
find . -type d -name playbook | grep -v node_modules | grep -v .git
```

If only one playbook exists, use it.

If multiple, determine which repo the target touches:
- Commit: `git show [sha] --name-only`
- Branch/MR: `git diff dev...[branch] --name-only`

Match changed paths to the correct repo subdirectory and pick its playbook.

If no playbook found: stop and report:
> No playbook found. Run `/add_playbook_rule` to create rules first.

---

## Step 3 — Spawn the Reviewer

Call `Agent` with `subagent_type: "playbook-reviewer"` and a prompt that contains only:
- The target identifier (commit SHA, branch range, or MR number)
- The absolute path to the playbook directory
- The working directory (so git commands resolve correctly)

Example prompt:

```
Review target: git diff dev...feature/my-branch
Playbook: /home/xqua/Documents/Work/Alien/DataStreaming/datastreaming-demos/lds-chatbot/playbook
Working directory: /home/xqua/Documents/Work/Alien/DataStreaming/datastreaming-demos/lds-chatbot
```

---

## Step 4 — Relay Output

Print the agent's output verbatim. Do not editorialize, soften, or add context.

Append this footer:

```
---
Playbook : [path]
Target   : [resolved target]
```