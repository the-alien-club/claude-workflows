---
description: Create merge requests to promote branches across all repositories (dev→staging or staging→main)
model: opus
---

# Batch Promote: Branch Promotion

You are tasked with promoting code between long-lived branches across all repositories in the DataStreaming monorepo.

**Supported promotions:**
- `dev → staging` — promoting tested development code to staging environment
- `staging → main` — promoting validated staging code to production

## CRITICAL: NO SQUASH MERGES

**Promotions between long-lived branches (`dev → staging`, `staging → main`) MUST NEVER be squash-merged.**

Squash merges create a new commit SHA on the target branch that doesn't exist in the source branch history. This permanently diverges the branches — every future promotion shows false "X commits behind" counts and causes growing conflicts.

**Always use: glab cli to create a MR with a proper message as to what the promotion entails**

This command creates GitLab MRs for each repository with a comprehensive analysis of changes, then enables auto-merge so they merge automatically once CI pipelines pass.

## Step 0: Determine Promotion Direction

If the user specifies the promotion direction (e.g. "dev to staging", "staging to main", "to prod"), use that.

If not specified, **ask the user before proceeding**:

```
Which promotion would you like to run?

1. **dev → staging** — promote development code to staging
2. **staging → main** — promote staging code to production

(Reply with 1 or 2)
```

Once determined, set these variables for the rest of the process:
- **SOURCE_BRANCH**: `dev` or `staging`
- **TARGET_BRANCH**: `staging` or `main`

**Note on k8s-charts and data-cluster-helm**: These repositories only have `main` by design — they do NOT have `dev` or `staging` branches. Skip them entirely for `dev → staging` promotions. For `staging → main`, skip them as well (they are managed directly on `main`).

## Initial Response

When the promotion direction is determined, respond with:
```
I'll promote [SOURCE_BRANCH] to [TARGET_BRANCH] across all repositories using GitLab merge requests (no squash). Let me check which repositories have pending changes.
```

Then proceed immediately to repository discovery.

## Process Steps

### Step 1: Identify All Repositories

The DataStreaming monorepo contains these primary repositories:

1. **web-app/** - Frontend (Next.js) + Backend (AdonisJS) monorepo
2. **workers/** - Python async job processing
3. **data-pipelines/** - Argo Workflows with Hera SDK
4. **data-cluster/** - FastAPI client cluster data API
5. **data-cluster-operator/** - Kopf-based K8s operator
6. **data-cluster-helm/** - Multi-tenant Helm infrastructure
7. **k8s-charts/** - Platform ArgoCD GitOps deployment
8. **skupper-gateway/** - Skupper networking gateway
9. **MCPs/mcp-base/** - Core MCP framework
11. **MCPs/mcp-datacluster/** - Data exploration MCP tools
12. **MCPs/mcp-openaire/** - Research intelligence MCP tools
13. **MCPs/mcp-operator/** - Operator MCP tools
13. **MCPs/mcp-bnf/** - BNF MCP 

**Note**: Each repository is a subdirectory in the root folder, each are separate git repositories in gitlab. They share the same git history. MCPs sub-packages must be checked individually — `MCPs/` as a whole is not a single repository path but a folder.

### Step 2: Check Repository Status

For each repository, check:

1. **Does the repository have both SOURCE_BRANCH and TARGET_BRANCH?**
   ```bash
   git show-ref --verify --quiet refs/heads/[SOURCE_BRANCH] && \
   git show-ref --verify --quiet refs/heads/[TARGET_BRANCH]
   ```
   - If both exist: Continue
   - If missing: Skip this repository (inform user)
   - **k8s-charts/ and data-cluster-helm/**: Only have `main` — always skip for branch promotions

2. **Are there commits in SOURCE_BRANCH not in TARGET_BRANCH?**
   ```bash
   git log [TARGET_BRANCH]..[SOURCE_BRANCH] --oneline -- [repository-path]/
   ```
   - If commits exist: Repository needs MR
   - If no commits: Skip (already synced)

3. **Identify repositories needing MRs**:
   - Create a summary list showing which repos have changes
   - Show commit count per repository
   - Display to user before proceeding

### Step 3: Confirm with User

Present findings to user (example for dev → staging):
```
Found the following repositories with changes from dev to staging:

1. web-app/ - 12 commits
2. workers/ - 5 commits
3. data-cluster/ - 3 commits

Repositories already synced (no changes):
- data-pipelines/
- data-cluster-operator/
- MCPs/mcp-base/
- MCPs/mcp-boilerplate/
- MCPs/mcp-datacluster/
- MCPs/mcp-openaire/
- MCPs/mcp-operator/
- skupper-gateway/

Skipped (no dev/staging branches):
- k8s-charts/ (main only)
- data-cluster-helm/ (main only)

Would you like me to create merge requests for the 3 repositories with changes? (yes/no)
```

If user says no, stop. If yes, proceed to Step 4.

### Step 4: Spawn Parallel Agents for GitLab MR Creation

**CRITICAL**: Use the Task tool to spawn multiple agents in parallel. Create ONE task per repository.

For each repository needing promotion, spawn an agent with this prompt:

```
Promote [SOURCE_BRANCH] to [TARGET_BRANCH] for the [REPO_NAME] repository by creating a GitLab MR.

Repository path: [REPO_PATH] (run all git commands from this directory)
GitLab project path: [GITLAB_PROJECT_PATH] (e.g. alias3/datastreaming/web-app)

## ❌ ABSOLUTELY FORBIDDEN
- DO NOT squash commits (use --no-squash or merge strategy "merge")
- DO NOT enable "delete source branch" — [SOURCE_BRANCH] must NEVER be deleted
- DO NOT merge manually via git — use GitLab MR exclusively

## Instructions

### 1. Analyze changes between [SOURCE_BRANCH] and [TARGET_BRANCH]

Collect the full picture of what this promotion includes:

   git fetch origin [SOURCE_BRANCH] [TARGET_BRANCH]
   git log origin/[TARGET_BRANCH]..origin/[SOURCE_BRANCH] --oneline -- [REPO_PATH]/
   git diff origin/[TARGET_BRANCH]..origin/[SOURCE_BRANCH] --stat -- [REPO_PATH]/

For each commit, note:
- The conventional commit type (feat, fix, chore, refactor, etc.)
- Which component/area is affected
- Any breaking changes, migrations, or config changes

### 2. Create the MR with a comprehensive description

Use glab to create the MR:

   glab mr create \
     --source-branch [SOURCE_BRANCH] \
     --target-branch [TARGET_BRANCH] \
     --title "chore([repo-name]): promote [SOURCE_BRANCH] to [TARGET_BRANCH] — [DATE]" \
     --squash-before-merge=false \
     --remove-source-branch=false \
     --description "$(cat <<'EOF'
   ## [SOURCE_BRANCH] → [TARGET_BRANCH] Promotion: [REPO_NAME]

   **Date**: [DATE]
   **Commits**: [N] commits being promoted

   ### Changes Summary

   [Group commits by type and summarize:]

   **Features**
   - [list feat() commits with brief description]

   **Fixes**
   - [list fix() commits with brief description]

   **Infrastructure / Chore**
   - [list chore/refactor/ci commits with brief description]

   ### Files Changed
   [N] files changed, [+additions/-deletions]

   [Paste git diff --stat output]

   ### Notable Changes
   - [Flag any database migrations]
   - [Flag any API breaking changes]
   - [Flag any config/env changes]
   - [Flag any dependency updates]

   ### Deployment Notes
   - [Any special deployment considerations]
   - [Services that need restart]
   - [Environment variables to set]

   ---
   ⚠️ **CRITICAL**: Merge with NO SQUASH — full commit history must be preserved.
   ⚠️ **CRITICAL**: DO NOT delete source branch ([SOURCE_BRANCH]).
   EOF
   )"

### 3. Add reviewer (staging → main promotions only)

**If TARGET_BRANCH is `main`**, add user `leo` (GitLab user ID 15315) as a reviewer:

   glab api "projects/[ENCODED_PROJECT_PATH]/merge_requests/[MR_NUMBER]" \
     --method PUT \
     -F "reviewer_ids[]=15315"

This must be done BEFORE enabling auto-merge so the approval is recorded before the MR closes.

**If TARGET_BRANCH is `staging`**, skip this step.

### 4. Enable auto-merge (merge when pipeline succeeds)

**If TARGET_BRANCH is `staging`**: enable auto-merge immediately after MR creation:

   glab mr merge [MR_NUMBER] --auto --no-squash --no-delete

**If TARGET_BRANCH is `main`**: DO NOT enable auto-merge yet. Report the MR back and wait — auto-merge will be enabled by the orchestrator only after leo approves.

If auto-merge is not available (e.g. pipeline not running yet), note this in the report.

### 5. Report back with:
   - MR URL
   - MR number
   - Number of commits included
   - Files changed summary (+additions/-deletions)
   - Whether reviewer was added (staging→main only)
   - Whether auto-merge was enabled (staging promotions) or skipped pending approval (main promotions)
   - Any notable changes flagged (migrations, breaking changes, config)
```

**Example agent spawning** (in a single message with multiple Task calls):

```
Task 1: web-app promotion (GitLab MR)
Task 2: workers promotion (GitLab MR)
Task 3: k8s-charts promotion (GitLab MR)
Task 4: data-cluster promotion (GitLab MR)
```

### Step 6: Wait for All Agents to Complete

**IMPORTANT**: Wait for ALL spawned agents to complete before proceeding.

Collect results from each agent:
- MR URL and number
- Commits included count
- Files changed (+additions/-deletions)
- Whether reviewer was added (staging→main)
- Whether auto-merge was enabled or is pending approval
- Notable changes flagged (migrations, breaking changes, config)
- Success/failure status
- Any errors encountered

### Step 6b: Approval Gate (staging → main only)

**If TARGET_BRANCH is `main`**, after presenting the summary report, tell the user:

```
You have been added as reviewer on all [N] MRs. Please review and approve each one in GitLab — auto-merge will be enabled on each MR as you approve them, so they will merge automatically once CI passes.

Would you like me to enable auto-merge on all MRs now without waiting for your approval? (yes/no)
```

- If **yes**: enable auto-merge on all MRs immediately (`glab mr merge [N] --auto --no-squash --no-delete` for each).
- If **no**: spawn a background monitoring agent that polls each MR every 60 seconds. When it detects that leo has approved an MR (check `approved_by` in `glab mr view --output json`), immediately enable auto-merge on that MR. Report back when all MRs are approved and auto-merge enabled.

**If TARGET_BRANCH is `staging`**: skip this step (auto-merge was already enabled in Step 4).

### Step 7: Generate Summary Report

Use a **compact table format** for the summary. This is the required output style:

```markdown
## Batch Promotion Summary: [SOURCE_BRANCH] → [TARGET_BRANCH]

**Date**: [Current date]
**Total Repositories**: [N] checked
**MRs Created**: [N]
**Already Synced**: [N]
**Skipped (no branches)**: [N]

### Merge Requests Created

| Repository | MR | Commits | Files | Auto-Merge |
|---|---|---|---|---|
| **web-app** | [!52](MR_URL) | 12 | 47 (+1234/-567) | ✅ Enabled |
| **workers** | [!18](MR_URL) | 5 | 11 (+89/-23) | ✅ Enabled |

All MRs configured with **NO squash** and **NO delete source branch**. Auto-merge will trigger once CI pipelines pass.

### Key changes being promoted
- [Brief summary of notable changes across all repos]

### Next Steps (dev → staging)
1. MRs will auto-merge once CI pipelines pass
2. **Claude Security Review** runs automatically in the `security` stage — check inline findings on MR
3. Monitor pipeline status on each MR
4. Verify staging deployments pick up new images after merge
5. Promote staging → main when ready

### Next Steps (staging → main)
1. You have been added as reviewer on all MRs — please approve each one in GitLab
2. Auto-merge will be enabled per MR as you approve (or all at once if you choose to skip review)
3. MRs will merge automatically once approved + CI passes
4. Verify production deployments after merge
5. Monitor error rates and performance post-deploy
```

Use the appropriate "Next Steps" block based on the promotion direction.

If any promotions failed, add a **Failed** section with error details.

### Step 8: Offer Notion Integration

Ask user:
```
Would you like me to:
1. Create a Notion task to track this release promotion?
2. Update any existing release tasks with MR URLs?
3. No Notion updates needed

(Reply with 1, 2, or 3)
```

If user chooses 1:
- Create a new task in Notion Features & Tasks database
- Title (dev→staging): "Staging Release: Dev → Staging Sync [Date]"
- Title (staging→main): "Production Release: Staging → Main Sync [Date]"
- Type: 🚢 Deployment
- Status: 👀 In Review
- Components: All affected repositories
- Description: Link all MR URLs and summary

If user chooses 2:
- Search Notion for existing release task
- Update with MR URLs in comments

## Important Notes

1. **Parallel Execution**: Spawn all agents in a SINGLE message with multiple Task tool calls
2. **Repository Isolation**: Each agent works independently on its repository
3. **No New Commits**: This is a branch promotion, not new code changes
4. **NO Squash**: MRs must use merge commit strategy — never squash
5. **NO Delete Source Branch**: source branch (dev or staging) must NEVER be deleted
6. **Auto-Merge**: Enable auto-merge on all MRs so they merge once CI passes
7. **Error Handling**: If an agent fails, continue with others and report failures in summary
8. **User Confirmation**: Always confirm before creating multiple MRs
9. **Branch Direction**: MRs target `[TARGET_BRANCH]` from `[SOURCE_BRANCH]` — determined in Step 0
10. **Repository Paths**: Filter git log and diff by repository path to isolate changes
11. **Change Analysis**: Each MR description must include grouped commit summary, file stats, and flagged notable changes
12. **k8s-charts & data-cluster-helm**: These repos only have `main` — skip them for all promotions

## Error Handling

### No Changes Found
```
No repositories have changes from [SOURCE_BRANCH] to [TARGET_BRANCH]. All repositories are already synced.

Would you like me to check again or verify branch status?
```

### Git Branch Issues
```
Error: [Repository] is missing [SOURCE_BRANCH] or [TARGET_BRANCH] branch.

This repository may use a different branching strategy. Would you like to:
1. Skip this repository
2. Manually specify branches
3. Investigate branch structure
```

### Agent Failure
```
Warning: Failed to create MR for [repository]

Error: [error message from agent]

Would you like me to:
1. Retry this repository
2. Create MR manually with provided description
3. Skip and continue
```

### GitLab API Errors
```
Error: GitLab API rate limit exceeded or authentication failed.

Please check:
1. GitLab authentication: glab auth status
2. API rate limits: Check GitLab settings
3. Network connectivity

Would you like me to retry after you've resolved the issue?
```

## Repository-Specific Considerations

### web-app/
- Check for Tuyau type regeneration needs
- Verify database migrations are included
- Review backend and frontend changes separately in MR description

### workers/
- Check for worker configuration changes
- Review queue configuration updates
- Note any new job types

### k8s-charts/
- Review ArgoCD application changes
- Check Helm values modifications
- Note any sync wave changes
- Flag critical infrastructure changes

### data-cluster/
- Check for API endpoint changes
- Review database migrations (Alembic)
- Note configuration updates

### data-cluster-operator/
- Review CRD changes
- Check operator logic updates
- Note Kopf framework changes

## Example Interaction

```
User: /batch_mr_dev_to_staging

Assistant: I'll help you create merge requests from dev to staging across all repositories. Let me analyze which repositories have changes...

[Checking repositories]

Found the following repositories with changes from dev to staging:

1. web-app/ - 12 commits
2. workers/ - 5 commits  
3. k8s-charts/ - 8 commits

Repositories already synced (no changes):
- data-pipelines/
- data-cluster/
- data-cluster-operator/
- MCPs/

Would you like me to create merge requests for the 3 repositories with changes? (yes/no)

User: yes

Assistant: Analyzing changes and spawning parallel agents to create GitLab MRs...

[Spawns 3 Task agents in parallel - one for each repository]

[After all agents complete]

## Batch Promotion Summary: Dev → Staging

**Date**: 2026-02-13
**Total Repositories**: 9 checked
**MRs Created**: 3
**Already Synced**: 6

### Merge Requests Created

| Repository | MR | Commits | Files | Auto-Merge |
|---|---|---|---|---|
| **web-app** | [!52](MR_URL) | 12 | 47 (+1234/-567) | ✅ Enabled |
| **workers** | [!18](MR_URL) | 5 | 11 (+89/-23) | ✅ Enabled |
| **k8s-charts** | [!31](MR_URL) | 8 | 15 (+201/-45) | ✅ Enabled |

All MRs configured with **NO squash** and **NO delete source branch**. Auto-merge will trigger once CI pipelines pass.

### Key changes being promoted
- Secret delivery reconciliation
- Worker queue configuration updates
- ArgoCD sync wave adjustments

### Next Steps
1. MRs will auto-merge once CI pipelines pass
2. Monitor pipeline status on each MR
3. Verify staging deployments pick up new images after merge
4. Promote staging → main when ready
```

### Step 9: Monitor CI Pipeline & MR Merge Status

After all MRs are created with auto-merge enabled, spawn a **background monitoring agent** using the `/loop` pattern that checks MR status every 60 seconds.

**Launch the monitor:**

Use the Agent tool to spawn a background agent with this prompt:

```
You are monitoring CI pipeline status for a batch branch promotion.

MRs to monitor (replace with actual MR numbers and repos):
[List of repository name + MR number pairs from Step 4 results]

GitLab project paths:
[List of GitLab project paths]

Every 60 seconds, check the status of each MR using:

   glab mr view [MR_NUMBER] --repo [GITLAB_PROJECT_PATH] --output json

For each MR, extract:
- state (open, merged, closed)
- pipeline status (running, success, failed)
- auto-merge status

Then output a status table:

## CI Pipeline Status — [SOURCE_BRANCH] → [TARGET_BRANCH] Promotion

| Repository | MR | State | Auto-Merge | Action Needed |
|---|---|---|---|---|
| **workers** | !14 | ✅ Merged | — | None |
| **data-pipelines** | !9 | 🟡 Open | Waiting on pipeline | Monitor CI |
| **data-cluster** | !25 | ❌ Failed | Pipeline failed | Investigate |

[N]/[TOTAL] merged, [N] still waiting on CI pipelines ([list repos]).
These have auto-merge enabled and will merge automatically once pipelines pass.

State icons:
- ✅ Merged — MR has been merged
- 🟡 Open — MR is open, pipeline running or pending
- ❌ Failed — Pipeline failed, needs investigation
- 🔴 Closed — MR was closed without merging (something went wrong)

If a pipeline fails:
- Report the failed pipeline URL
- Suggest: "Pipeline failed for [repo]. Check CI logs: [pipeline URL]"

Stop monitoring when ALL MRs are either merged or failed (no more 🟡 Open).
When all are merged, output a final summary:

✅ All [N] MRs merged successfully. Promotion complete.

If any failed, output:

⚠️ [N]/[TOTAL] MRs merged. [N] failed and need manual attention: [list repos with pipeline URLs]
```

**Important**: This agent runs in the background. Continue to the next steps while it monitors. It will notify you when all MRs have resolved.

### Step 10: Update k8s-charts Version Files (User Confirmation Required)

**This step applies to specific repositories that publish versioned images.** Not all promoted repositories have entries in versions.yaml.

**Before proceeding, ask the user:**

```
All MRs are [merged / in progress]. Would you like me to update the k8s-charts version files to match the latest published versions?

This will:
- Read the latest published version tags from the merged MR branches
- Update the appropriate versions.yaml files in k8s-charts/
- Target environment based on promotion direction:
  - dev → staging: update staging/versions.yaml
  - staging → main: update prod/versions.yaml

Proceed? (yes/no)
```

If user says no, skip to Step 11.

**If yes, proceed with the version update:**

#### Version File Structure

The version files live at:
- `k8s-charts/environments/dev/platform/versions.yaml` — dev image tags (CI-managed, `-dev` suffix)
- `k8s-charts/environments/staging/platform/versions.yaml` — staging image tags (`-rc` suffix)
- `k8s-charts/environments/prod/platform/versions.yaml` — production image tags (no suffix)

#### Repository → versions.yaml Mapping

| Repository | versions.yaml Key | Tag Suffix (dev) | Tag Suffix (staging) | Tag Suffix (prod) |
|---|---|---|---|---|
| web-app (backend) | `backend.image.tag` | `-dev` | `-rc` | (none) |
| workers | `workers.image.tag` | `-dev` | `-rc` | (none) |
| skupper-gateway | `skupperGateway.image.tag` | `-dev` | `-rc` | (none) |
| MCPs/mcp-operator | `mcpOperator.image.tag` | (none) | (none) | (none) |
| MCPs/mcp-openaire | `mcpServices.mcps.openaire.imageTag` | `-dev` | `-rc` | (none) |
| MCPs/mcp-datacluster | `mcpServices.mcps.[name].imageTag` | `-dev` | `-rc` | (none) |

**Repositories NOT in versions.yaml** (skip these):
- data-pipelines (Argo WorkflowTemplates, not deployed as images)
- data-cluster (deployed via data-cluster-helm, not k8s-charts)
- data-cluster-operator (deployed via data-cluster-helm, not k8s-charts)
- MCPs/mcp-base (shared library, not deployed directly)
- MCPs/mcp-boilerplate (template, not deployed)

#### Process

1. **Determine the target versions.yaml file** based on promotion direction:
   - `dev → staging`: update `k8s-charts/environments/staging/platform/versions.yaml`
   - `staging → main`: update `k8s-charts/environments/prod/platform/versions.yaml`

2. **For each promoted repository that has a versions.yaml entry**, get the latest published version:
   - Check the CI pipeline of the merged MR for the published image tag
   - Or read the version from the source environment's versions.yaml (the one we're promoting FROM)
   - The version number stays the same, but the suffix changes:
     - `dev → staging`: `0.5.21-dev` becomes `0.5.21-rc`
     - `staging → main`: `0.5.21-rc` becomes `0.5.21`

3. **Cross-check with dev versions.yaml**:
   - Read `k8s-charts/environments/dev/platform/versions.yaml`
   - For each version being promoted to staging, verify the dev version matches or is ahead
   - **If dev version is BEHIND the staging version being set**, emit a warning:
     ```
     ⚠️ WARNING: [repo] dev version (0.5.19-dev) is behind the version being promoted
     to staging (0.5.21-rc). This version may not have been tested in dev.
     ```
   - For staging→main promotions, verify staging version matches what's being promoted to prod

4. **Update the target versions.yaml** with the new tags

5. **Present the changes for review**:

   ```
   ## k8s-charts Version Update — [TARGET_BRANCH]

   File: k8s-charts/environments/[TARGET_ENV]/platform/versions.yaml

   | Service | Previous | New | Source |
   |---|---|---|---|
   | backend | 0.6.37-rc | 0.6.40-rc | dev 0.6.40-dev |
   | workers | 0.5.20-rc | 0.5.21-rc | dev 0.5.21-dev |
   | skupperGateway | 0.1.2-rc | 0.1.2-rc | (unchanged) |

   ⚠️ Warnings:
   - [any dev-behind-staging warnings]

   Changes ready to commit. Shall I commit and push to k8s-charts main?
   ```

6. **Commit and push** (only after user confirms):
   - k8s-charts only has `main` branch
   - Commit message: `chore(versions): update [TARGET_ENV] versions — [SOURCE_BRANCH] → [TARGET_BRANCH] promotion [DATE]`
   - Push to `main`

### Step 11: Generate Non-Technical Changelog

After all MRs are created, generate a plain-language changelog suitable for non-technical stakeholders (CEO, product, clients). Use the MR descriptions as the source of truth — they already contain the grouped commit summaries, notable changes, and deployment notes.

**Process:**
1. Collect all MR descriptions from the agents' reports
2. Extract features, fixes, and notable changes from each
3. Rewrite in business language — no code references, no file paths, no technical jargon
4. Group by impact area (what the user/client sees), not by repository

**Output format:**

```markdown
## What's New in [Staging/Production] — [DATE]

### New Capabilities
- [Business-facing description of new features]
- Example: "Users can now export datasets in CSV format directly from the dashboard"

### Improvements
- [Business-facing description of enhancements and optimizations]
- Example: "Data processing pipelines are now 40% faster for large datasets"

### Fixes
- [Business-facing description of bug fixes]
- Example: "Fixed an issue where dataset uploads would occasionally time out for files over 500MB"

### Infrastructure & Reliability
- [High-level summary of infra/DevOps changes, framed as reliability or performance gains]
- Example: "Improved system resilience with better error recovery during cluster communication"
- Only include if meaningful to stakeholders — skip pure internal refactors

---
*Promoted from [SOURCE_BRANCH] to [TARGET_BRANCH] on [DATE]. Currently running validation pipelines.*
*(For dev→staging: "expected to reach production after staging validation")*
*(For staging→main: "now live in production")*
```

**Rules for writing the changelog:**
- NO repository names, file paths, function names, or commit hashes
- NO technical terms like "middleware", "migration", "helm", "ArgoCD", "mTLS" — translate them
- Write from the user's perspective: what changed FOR THEM, not what changed in the code
- If a change is purely internal with zero user-visible impact, omit it entirely
- Keep each bullet to one sentence
- If nothing user-facing changed in a category, omit that category

Present this changelog to the user after the technical summary report.

## Quality Checklist

Before completing, verify:
- [ ] Promotion direction confirmed (dev→staging or staging→main)
- [ ] All repositories checked for source→target differences
- [ ] User confirmed before creating MRs
- [ ] Parallel agents spawned in single message
- [ ] All MR descriptions include grouped commit analysis and notable changes
- [ ] Auto-merge enabled on all MRs
- [ ] Claude Security Review will run in `security` stage on each MR pipeline
- [ ] Summary report generated with all MR links
- [ ] User offered Notion integration option
- [ ] CI monitoring agent launched and tracking all MRs
- [ ] User asked before updating k8s-charts versions
- [ ] Version cross-check performed (dev version not behind promoted version)
- [ ] Non-technical changelog generated from MR descriptions
- [ ] Quick links provided for all created MRs

## Related Commands

- `/merge_request` - Create single MR from current feature branch
- `/ci_describe_pr` - Generate PR description for single repository
- `/commit` - Create conventional commits before creating MRs

---

**Note**: This command is designed for promoting code between long-lived branches (`dev → staging` or `staging → main`) as part of the release process. For individual feature development, use `/merge_request` instead.
