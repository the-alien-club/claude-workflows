---
description: Link a merged/open MR to a Jira SDS ticket, finds or creates the card and updates it with MR info
model: opus
---

# Jira MR Linker
After a merge request is created, find the corresponding Jira SDS ticket and update it with the MR details. If no ticket exists, create one.

## Constants
- **Cloud ID**: `YOUR_CLOUD_ID`
- **Project Key**: `SDS`
- **My Account ID**: `YOUR_ACCOUNT_ID`

## Step 1: Gather Git & MR Context
```bash
git branch --show-current
git log dev..HEAD --oneline --no-decorate
git diff dev...HEAD --stat
glab mr view --json url,title,description,state 2>/dev/null
```

Extract and hold:
- **Branch name** (strip prefix: `feature/`, `fix/`, `refactor/`, `chore/`)
- **MR URL** and **MR title**
- **Commit list** (full one-line log)
- **Changed files summary** (stat output)
- **ai_docs context** if `ai_docs/[feature-name]/` exists, read `plan/implementation-plan.md` and `implement/implementation-log.md`
- **Version bump**: scan commits and `Chart.yaml` / `pyproject.toml` / `package.json` changes for version bumps, note old → new version if found

## Step 2: Fetch All Open SDS Issues
Load the Atlassian MCP tools and fetch all open issues in the SDS project:
```text
mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql
  cloudId: "YOUR_CLOUD_ID"
  jql: "project = SDS AND statusCategory != Done ORDER BY updated DESC"
  fields: ["summary", "description", "status", "issuetype", "assignee"]
  maxResults: 50
```

**Important**: The response is large and will be saved to a file. Extract the relevant fields with jq before reasoning:
```bash
jq '[.issues.nodes[] | {key: .key, summary: .fields.summary, status: .fields.status.name}]' /path/to/tool-results/file.txt
```

## Step 3: Match Issue via LLM Reasoning
Look at the full list of issues and reason over:
- Branch name (converted from kebab-case: words)
- MR title
- Commit messages
- Changed file paths and components

**Matching confidence levels:**
- **High confidence** (single clear match): Inform the user which issue matched and why (1 sentence), then proceed directly to Step 5.
- **Low confidence** (2–3 plausible candidates): Show a numbered list with title + key (e.g. `SDS-42 - Alpha to staging`) and ask the user to pick one or choose "None, create new".
- **No match found**: Ask the user: "I couldn't find a matching Jira ticket. Should I create a new one?"

Never guess silently, if unsure, always ask.

## Step 4: Create New Issue (if no match or user requests it)
```text
mcp__claude_ai_Atlassian__createJiraIssue
  cloudId: "YOUR_CLOUD_ID"
  projectKey: "SDS"
  summary: "[Derived from MR title or branch name, human readable]"
  issueType: "Story"
  description: [See template below]
  assignee: "ASSIGNEE_ACCOUNT_ID"
```

**New issue description template:**
```markdown
## What was done

[2-3 sentence summary of the change based on commits and changed files]

## Merge Request

[MR URL]

## Key Changes

[Bullet list of changed components and what changed, derived from git diff --stat]

## Commits

[Full commit list from git log]
```

## Step 5: Update Existing Issue
### 5a, Add a comment
```text
mcp__claude_ai_Atlassian__addCommentToJiraIssue
  cloudId: "YOUR_CLOUD_ID"
  issueKey: "[SDS-XX]"
  comment: [See template below]
```

**Comment template:**
```markdown
## MR Submitted

**MR**: [MR URL]
**Branch**: `[branch name]`

### What was done

[2-3 sentence summary of the changes, synthesized from commits and changed files, focused on what matters, not just what changed]

### Key Changes

[Bullet list grouped by component, derived from git diff --stat]

### Commits

[git log dev..HEAD --oneline output]

### Version Bump

[Only include this section if a version bump was detected]
`[component]`: `[old version]` → `[new version]`
```

### 5b, Transition status
```text
mcp__claude_ai_Atlassian__getTransitionsForJiraIssue
  cloudId: "YOUR_CLOUD_ID"
  issueKey: "[SDS-XX]"
```

**Known SDS transition IDs** (verify with getTransitions if unsure):
- `"11"` → To Do
- `"21"` → In Progress
- `"2"`  → VALIDATION
- `"31"` → Done

If MR(s) are merged: transition to **VALIDATION** (`"2"`), Done is set by the product team after manual review.
If MR is open/in review: transition to **In Progress** (`"21"`).
If the current status is already correct: skip this step.

## Step 6: Confirm
Show the user:
```text
Jira ticket [SDS-XX] updated
- Title: [issue summary]
- URL: https://YOUR_DOMAIN.atlassian.net/browse/SDS-XX
- Status transitioned to: [new status or "unchanged"]
```

## Error Handling
- **MCP tools not available**: Ask user to run `/mcp` to reconnect Atlassian
- **glab not available / no MR**: Ask user to provide the MR URL manually
- **Not on a feature branch**: Warn the user, this command is meant to run after an MR is created
- **No open issues in SDS**: Skip matching, go directly to create flow
- **Transition not found**: Skip the status update, note it in the confirmation
