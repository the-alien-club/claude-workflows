---
name: merge_request
description: Create GitLab merge request with comprehensive description from feature branch
disable-model-invocation: true
---

# Create Merge Request
You are tasked with creating a comprehensive GitLab merge request (MR) by analyzing all changes in the feature branch, reviewing commit history, and generating a detailed MR description that follows repository conventions.

## Initial Response
When this command is invoked, respond with:
```text
I'll help you create a merge request. Let me analyze your feature branch and generate a comprehensive MR description.
```

Then proceed immediately to analysis.

## Process Steps
### Step 0: Detect Promotion vs Feature MR
**Promotion merges** are: `dev → staging`, `dev → main`, `staging → main`.
**Feature MRs** are: any feature branch → `dev`.

Parse the arguments to determine source and target branch. If the user says something like "workers from dev to staging" or "merge dev to staging", that is a **promotion**.

**PROMOTIONS MUST NEVER USE SQUASH** — squash merges on long-lived branches permanently diverge history. Promotions bypass GitLab MR entirely and use a direct `git merge --no-ff --no-squash -X theirs` + push. See **Step 1B**.

If this is a feature MR, continue to **Step 1A**.

### Step 1A: Feature Branch MR
1. **Verify you're on a feature branch**:
   ```bash
   git branch --show-current
   ```
   - If on `main`, `dev`, `staging`, or `production`: Stop and inform user they should be on a feature branch
   - Extract feature name from branch (e.g., `feature/add-mtls` → `add-mtls`)

2. **Identify target branch**:
   - Default target: `dev`
   - For hotfixes: may target `main` or `staging`
   - Ask user if target should be something other than `dev`

3. **Check for existing MR**:
   ```bash
   glab mr view --json url,title,state 2>/dev/null
   ```
   - If MR exists: Ask if user wants to update description
   - If no MR: Proceed with creation

### Step 1B: Promotion Merge (dev→staging, staging→main, dev→main)
**Create a GitLab MR and merge it once the pipeline passes. Never squash. Never remove source branch.**

Promotions use MRs for two reasons: pipeline sanity check and GitLab history.

```bash
# Determine repo path, source and target from arguments
# e.g. "workers from dev to staging" → cd workers/, source=dev, target=staging

cd [repo-path]

# Make sure source branch is up to date locally
git fetch origin [source]

# Create the promotion MR (no squash, no remove-source-branch)
glab mr create \
  --source-branch [source] \
  --target-branch [target] \
  --title "chore([repo]): promote [source] → [target]" \
  --description "Promotion merge. No squash." \
  --no-editor

# Enable auto-merge once pipeline passes (no squash)
glab mr merge --auto-merge --no-squash
```

After creating the MR:
- Report the MR URL
- Confirm auto-merge is set (will merge automatically when pipeline passes)
- Remind user: **do NOT manually squash** when merging — `dev` and `staging` are permanent long-lived branches and squashing permanently diverges history

**DO NOT** use `--remove-source-branch` — `dev` and `staging` are permanent branches.

### Step 2: Comprehensive Change Analysis
1. **Get all commits in feature branch**:
   ```bash
   git log dev..HEAD --oneline --no-decorate
   ```
   - Show user the commit list
   - Count total commits
   - Extract commit messages for context

2. **Analyze complete diff statistics**:
   ```bash
   git diff dev...HEAD --stat
   git diff dev...HEAD --name-status
   ```
   - Identify all modified files
   - Count additions/deletions per file
   - Categorize changes by repository/package (backend, frontend, workers, etc.)

3. **Review detailed changes**:
   ```bash
   git diff dev...HEAD
   ```
   - Understand the nature of changes
   - Identify key modifications
   - Note breaking changes or migrations
   - Look for database migration files
   - Check for API endpoint additions/modifications

### Step 3: Gather Documentation Context
1. **Search for related ai_docs**:
   - Look for `ai_docs/[feature-name]/` directory
   - Read if exists:
     - `plan/implementation-plan.md`
     - `research/codebase-analysis.md`
     - `implement/implementation-log.md`
     - `validate/validation-report.md`

2. **Search Notion for related task**:
   - Use mcp__notion__notion-search to find task by feature name
   - If found, fetch full task details with mcp__notion__notion-fetch
   - Extract: Task URL, description, components, type, estimated effort

3. **Check for Knowledge Base articles**:
   - Search Notion KB for any new patterns documented during implementation
   - Link if architectural changes were made

### Step 4: Generate MR Description
Use this template structure:

````markdown
## Summary

[2-3 sentence overview of what this MR accomplishes and why]

## Changes

### Backend
- [Change description with file references]
- [Another change]

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

- [ ] Linting passes (`make lint`, `yarn lint`, or `ruff check`)
- [ ] Type checking passes (`tsc --noEmit` or `mypy`)
- [ ] Tests pass (`make test`, `yarn test`, or `pytest`)
- [ ] Builds successfully
- [ ] Documentation updated (CLAUDE.md if architecture changed)

## Deployment Notes

[Any special deployment considerations, migration steps, rollback procedures, or "Standard deployment - no special steps required"]

## Security Considerations

[Any security implications or "No security impact"]

## Performance Impact

[Any performance considerations or "No significant performance impact"]

## Related Links

- **Notion Task**: [Task URL or "Not tracked in Notion"]
- **Documentation**: `ai_docs/[feature-name]/` [or "No ai_docs for this change"]
- **Knowledge Base**: [KB article URL if applicable or "None"]

---

**Commits in this MR**: [N commits]

<details>
<summary>Commit History</summary>

```
[Full commit list with messages from git log dev..HEAD]
```

</details>
````

### Step 4B: Versioning: check the repository's mode first

**Repositories with a `release-units.yaml` at their root use post-merge versioning (SDS-1058). In those, NEVER bump a
version.** The release bot bumps after the merge, from the commit messages. Most repositories are migrated; check
each repository the diff touches:

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

### Step 5: Create Merge Request
1. **Ensure branch is pushed**:
   ```bash
   git push -u origin HEAD
   ```
   - If push fails, show error and stop
   - If push succeeds, continue

2. **Write MR description to temp file**:
   ```bash
   MR_TMP=$(mktemp 2>/dev/null || echo "./mr_description_tmp.md")
   ```
   - Write generated description to `$MR_TMP`
   - This allows glab to read it properly and works on both Unix and Windows (Git Bash)

3. **Create MR using glab**:
   ```bash
   glab mr create \
     --title "<type>(<scope>): <title>" \
     --description "$(cat "$MR_TMP")" \
     --target-branch dev \
     --assignee @me \
     --remove-source-branch \
     --web
   rm -f "$MR_TMP"
   ```
   - `--title`: Use conventional commit format
   - `--description`: From generated template
   - `--target-branch`: Default to dev (or user-specified)
   - `--assignee @me`: Auto-assign to creator
   - `--remove-source-branch`: Auto-delete after merge
   - `--web`: Open in browser after creation

4. **Capture MR URL**:
   - Parse glab output for MR URL
   - Extract MR number

5. **Display success message**:
   ```text
   Merge Request created successfully!

   **MR URL**: [URL]
   **MR Number**: ![N]
   **Target Branch**: dev
   **Source Branch**: [feature-branch-name]

   Next steps:
   1. Update Notion task with MR URL
   2. Request review from team members
   3. Address any review comments
   4. After approval: Merge to dev
   5. After merge: Update Notion task to Done
   ```

### Step 6: Update Notion Task
1. **Prompt user for Notion update**:
   ```text
   Would you like me to update the Notion task with this MR URL? (yes/no)
   ```

2. **If yes, update Notion task**:
   - Use mcp__notion__notion-search to find task by feature name (if not already found)
   - Use mcp__notion__notion-update-page to:
     - Add MR URL to task content or create comment
     - Update status to 👀 In Review
     - Add comment: "MR created: [URL]"

## Conventional Commit Prefixes for MR Title
Match the MR title to the primary change type:
- `feat(component):`: New features
- `fix(component):`: Bug fixes
- `refactor(component):`: Code refactoring
- `perf(component):`: Performance improvements
- `docs(component):`: Documentation updates
- `chore(component):`: Maintenance tasks
- `test(component):`: Test additions/updates

**Component examples**:
- `backend`: AdonisJS backend
- `frontend`: Next.js frontend
- `workers`: Python workers
- `data-cluster`: FastAPI data API
- `data-pipelines`: Argo Workflows
- `k8s-charts`: Platform infrastructure
- `operator`: Data cluster operator
- `helm`: Helm charts

**Multi-component changes**: Use the primary component or `platform` for cross-cutting changes.

## Important Notes
1. **Always review changes before creating MR**: don't blindly generate descriptions
2. **Include migration notes** if database changes exist
3. **Flag breaking changes** prominently in description
4. **Link all relevant documentation** (Notion + ai_docs/)
5. **Use TodoWrite** to track MR creation steps
6. **Verify MR created successfully** before updating Notion
7. **Read ai_docs/ files** if they exist - they contain critical context

## Error Handling
- **No commits in branch**:
  ```text
  Your feature branch has no commits compared to dev. Please make commits first using the `/commit` command.
  ```
- **Already has MR**:
  ```text
  This branch already has an MR: [URL]

  Would you like me to:
  1. Update the existing MR description
  2. Create a new MR anyway (will fail)
  3. Cancel
  ```
- **glab not installed**:
  ```text
  The glab CLI is not installed. Please install it first:

  # macOS
  brew install glab

  # Linux
  Download from: https://gitlab.com/gitlab-org/cli/-/releases
  ```
- **Push fails (authentication)**:
  ```text
  Failed to push branch. Please check:
  1. GitLab authentication: `glab auth status`
  2. Remote permissions: `git remote -v`
  3. Branch protection rules
  ```
- **glab mr create fails**:
  - Show the error from glab
  - Suggest manual MR creation via GitLab UI
  - Provide URL: `https://gitlab.com/[project]/merge_requests/new?merge_request[source_branch]=[branch]`

## MR Description Quality Guidelines
**Good MR Description**:
- Clear summary of what changed and why
- Organized by component (backend/frontend/workers/etc)
- Specific file references for major changes
- Complete checklist (all items checked or marked n/a)
- Links to documentation and Notion tasks
- Deployment notes if needed

**Bad MR Description**:
- Vague summary like "Fixed bugs"
- No organization or structure
- Missing checklist items
- No links to context
- Unclear what needs to be deployed

Your MR description should enable a reviewer to understand the changes without reading all the code.
