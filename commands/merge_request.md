---
description: Create GitLab merge request with comprehensive description from feature branch
model: opus
---

# Create Merge Request

Analyze the feature branch and create a comprehensive GitLab MR with a detailed description.

## Process

### Step 0: Detect Promotion vs Feature MR

**Promotion merges** are: `dev → staging`, `dev → main`, `staging → main`.
**Feature MRs** are: any feature branch → `dev`.

Parse the arguments to determine source and target branch. If the user says something like "workers from dev to staging" or "merge dev to staging", that is a **promotion**.

**PROMOTIONS MUST NEVER USE SQUASH** — squash merges on long-lived branches permanently diverge history. Promotions bypass GitLab MR entirely and use a direct `git merge --no-ff --no-squash -X theirs` + push. See **Step 1B**.

If this is a feature MR, continue to **Step 1A**.

---

### Step 1A: Feature Branch MR

1. Verify you're on a feature branch: `git branch --show-current`
   - If on `main`, `dev`, `staging`, or `production`: stop and inform the user
2. Default target branch is `dev` — ask user if different target needed
3. Check for existing MR: `glab mr view 2>/dev/null`
   - If MR exists: ask if user wants to update description or cancel

### Step 1B: Promotion Merge (dev→staging, staging→main, dev→main)

**⚠️ SAFETY: For promotions, ONLY use the commands in this section (Step 1B). Do NOT use Step 5 commands — those include `--remove-source-branch` which would DELETE dev or staging.**

**Create a GitLab MR and merge it once the pipeline passes. Never squash. Never remove source branch.**

Promotions use MRs for two reasons: pipeline sanity check and GitLab history.

```bash
# Determine repo path, source and target from arguments
# e.g. "workers from dev to staging" → cd workers/, source=dev, target=staging

cd [repo-path]

# Make sure source branch is up to date locally
git fetch origin [source]

# CRITICAL: Promotions must NEVER use --remove-source-branch (would delete dev/staging!)
# CRITICAL: Promotions must NEVER use --squash (diverges long-lived branch history!)
glab mr create \
  --source-branch [source] \
  --target-branch [target] \
  --title "chore([repo]): promote [source] → [target]" \
  --description "Promotion merge. No squash. No remove source branch." \
  --no-editor

# After MR is created, immediately disable remove-source-branch (GitLab may default it on)
glab mr update [MR_NUMBER] --remove-source-branch=false

# Enable auto-merge once pipeline passes (no squash)
glab mr merge [MR_NUMBER] --auto-merge --no-squash
```

After creating the MR:
- Report the MR URL
- Confirm auto-merge is set (will merge automatically when pipeline passes)
- Remind user: **do NOT manually squash** when merging — `dev` and `staging` are permanent long-lived branches and squashing permanently diverges history

**DO NOT** use `--remove-source-branch` — `dev` and `staging` are permanent branches.

---

### Step 2: Comprehensive Change Analysis

### Step 3: Gather Documentation Context

1. Check for `ai-memories/tech/platform/[feature-name]/` and read any of:
   - `plan/implementation-plan.md`
   - `research/codebase-analysis.md`
   - `implement/implementation-log.md`
   - `validate/validation-report.md`

2. Search Notion for related task by feature name. If found, extract: Task URL, description, components, type, estimated effort.

### Step 4: Generate MR Description

````markdown
## Summary

[2-3 sentence overview of what this MR accomplishes and why]

## Changes

### Backend
- [Change with file references]

### Frontend
- [Change description]

### Workers
- [Change description]

### Data-Cluster
- [Change description]

### Infrastructure (K8s/Helm)
- [Change description]

### Data-Pipelines
- [Change description]

## Implementation Details

[Key technical decisions, patterns used, architectural considerations]

### Database Changes
- [ ] Migrations included: `[migration file names or "None"]`
- [ ] Migrations tested (up and down): `[yes/no/n/a]`

### API Changes
- [ ] New endpoints: `[list or "None"]`
- [ ] Modified endpoints: `[list or "None"]`
- [ ] Breaking changes: `[list or "None"]`
- [ ] Tuyau types regenerated (if backend): `[yes/no/n/a]`

### Configuration Changes
- [ ] Environment variables added/changed: `[list or "None"]`
- [ ] Secrets updated: `[list or "None"]`
- [ ] Helm values modified: `[list or "None"]`

## Testing

- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed
- [ ] All tests passing locally

## Validation Checklist

- [ ] Linting passes
- [ ] Type checking passes
- [ ] Tests pass
- [ ] Builds successfully
- [ ] Documentation updated (CLAUDE.md if architecture changed)

## Deployment Notes

[Special steps, migration procedures, or "Standard deployment - no special steps required"]

## Security Considerations

[Security implications or "No security impact"]

## Performance Impact

[Performance considerations or "No significant performance impact"]

## Related Links

- **Notion Task**: [URL or "Not tracked"]
- **Documentation**: `ai-memories/tech/platform/[feature-name]/` [or "None"]

---

**Commits**: [N commits]

<details>
<summary>Commit History</summary>

```
[git log dev..HEAD output]
```

</details>
````

### Step 4B: Version Bump (MANDATORY — CI will fail without it)

**Every MR into `dev` requires a version bump in the changed repository. This is enforced by CI.**

#### 4B.1 — Find and read VERSIONING.md

For each repo affected by the diff, look for a `VERSIONING.md` at its root:

```bash
# Detect affected repos from diff
git diff dev...HEAD --name-status | awk '{print $2}' | cut -d/ -f1 | sort -u
```

For each detected repo root, check: `cat <repo>/VERSIONING.md`

**If VERSIONING.md exists:** read it carefully — it lists every file that must be updated for a version bump in that repo (code version, Helm chart, values files in other repos, cross-repo files). Follow it exactly.

**If VERSIONING.md does NOT exist:** spawn a sub-agent with the following instruction:

> "Write a VERSIONING.md file for the `<repo>` repository in the DataStreaming monorepo. Research:
> 1. The code version file (pyproject.toml or package.json)
> 2. Any Helm Chart.yaml files in this repo or referencing this repo (appVersion, version fields)
> 3. Any values.yaml / values-dev.yaml files that pin the image tag for this service (in this repo, k8s-charts, or data-cluster-helm)
> 4. Any cross-repo files that must be updated when the version changes
> Document the image tag suffix convention (X.Y.Z-dev for dev, X.Y.Z-rc for staging, X.Y.Z for prod).
> Write the file to `<repo>/VERSIONING.md` following the same structure as existing VERSIONING.md files in sibling repos."

After the agent writes it, read it and proceed.

#### 4B.2 — Execute the version bump

Following the VERSIONING.md for each affected repo:

1. **Bump the code version:**
   - Python: `cd <repo> && uv run cz bump --increment PATCH` (`cz bump` auto-commits — do not make a separate commit)
   - Node: `cd <repo>/packages/<pkg> && npm version patch` (creates a commit)
   - If `cz bump` fails, manually edit the version field and commit: `chore(<repo>): bump version to X.Y.Z`

2. **Update the Helm chart** (if listed in VERSIONING.md):
   - Edit `Chart.yaml`: set both `appVersion: "X.Y.Z"` and `version: X.Y.Z` to match the new code version (no suffix)

3. **Update own Helm chart values** (if listed in VERSIONING.md):
   - Own chart `values.yaml`: set `image.tag` to `X.Y.Z-dev`

4. **Verify all changes:** grep each file to confirm the new version appears correctly

5. **Stage and commit** all Helm/values changes that were not auto-committed by `cz bump`:
   `chore(<repo>): update helm chart and values to X.Y.Z`

**If changes span multiple repos:** bump each affected repo following its own VERSIONING.md.

---

### Step 5: Create Merge Request

```bash
# Push branch
git push -u origin HEAD

# Write description to temp file
# (write generated description to /tmp/mr_description.md)

# Create MR
glab mr create \
  --title "<type>(<scope>): <title>" \
  --description "$(cat /tmp/mr_description.md)" \
  --target-branch dev \
  --assignee @me \
  --remove-source-branch
```

### Step 6: Update Notion Task

Ask user if they want the Notion task updated with the MR URL. If yes:
- Search for task by feature name
- Add MR URL as comment
- Update status to 👀 In Review

## Conventional Commit Prefixes

`feat` / `fix` / `refactor` / `perf` / `docs` / `chore` / `test`

**Components**: `backend` · `frontend` · `workers` · `data-cluster` · `data-pipelines` · `k8s-charts` · `operator` · `helm` · `platform`

## Error Handling

- **Not on feature branch**: Stop, inform user
- **No commits vs dev**: "No commits found. Make commits first using `/commit`."
- **Existing MR**: Ask to update description or cancel
- **Push fails**: Show error, check `glab auth status` and `git remote -v`
- **glab not installed**: Direct user to install glab CLI
- **glab mr create fails**: Show error, suggest manual MR via GitLab UI
