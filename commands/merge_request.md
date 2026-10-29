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

### Step 4B: Versioning: check the repository's mode first

**Repositories with a `release-units.yaml` at their root use post-merge versioning (SDS-1058). In those, NEVER bump a
version.** The release bot bumps after the merge, from the commit messages. Every application repository is migrated
(2026-10-29); the exceptions are k8s-charts (versions set by gitops jobs, by design) and the main-only tooling repos
claude-sre and lds-langfuse-sync. Check each repository the diff touches:

```bash
for repo in $(git diff dev...HEAD --name-only | cut -d/ -f1 | sort -u); do
  [ -f "$repo/release-units.yaml" ] && echo "$repo: post-merge (no bump)" || echo "$repo: manual bump"
done
```

#### 4B.1: Post-merge repositories (`release-units.yaml` present)

1. **Do not touch any version location** (`pyproject.toml` / `package.json` version, `__version__`, `uv.lock`
   self-entry, `Chart.yaml` `version`/`appVersion`, literal image tags in `values.yaml`). The MR `commit-lint` job
   rejects a hand edit. If you merged `dev` in and a version file conflicts, take `dev`'s side.
2. **Commit messages are the release input:** `<type>(<scope>): <summary>`, type one of
   `build chore ci docs feat fix perf refactor revert style test`. `feat` → minor, anything else → patch.
3. **Breaking change** (`!` or a `BREAKING CHANGE:` footer) → **major**. Majors are rare (Leo): only for a big
   change. Otherwise reword the commit without the `!`.
   - In a repository with several units (data-cluster-helm), name the units it breaks: `feat(operators)!: …`.
   - A real major needs the MR label `release::major`, then a **new** pipeline. Retrying the failed job does not
     pick up the label.
4. **Check before pushing**, with the same rules CI runs:
   ```bash
   uvx --from "git+https://gitlab.com/alias3/datastreaming/ci-scripts.git@main#subdirectory=vbump" \
     vbump --root <repo> lint --target <dev|main>
   ```
   Never call a bare `vbump`: an unrelated tool with that name exists in some Python environments. The
   `commit-msg-guard` hook from this plugin runs the same check after `git commit` and before `git push`.

#### 4B.2: Repositories not migrated yet (no `release-units.yaml`)

Follow that repository's `VERSIONING.md`. Bump the version once, on the consolidated branch, above `dev` and above
every open MR. Use `chore(<repo>): bump version to X.Y.Z`. Do not use `cz bump`: its configured message carries a
CI-skip token.

Full guide: ci-scripts `docs/VERSIONING.md`.

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
