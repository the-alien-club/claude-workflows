---
description: Create merge requests from dev to staging across all repositories
model: opus
---

# Batch Merge Requests: Dev → Staging

You are tasked with creating merge requests from `dev` to `staging` branch across all repositories in the DataStreaming monorepo by spawning parallel agents for each repository.

## Initial Response

When this command is invoked, respond with:
```
I'll help you create merge requests from dev to staging across all repositories. Let me analyze which repositories have changes and spawn agents to handle each one.
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
8. **MCPs/** - MCP servers for AI assistant tools
9. **skupper-gateway/** - Skupper networking gateway

**Note**: Each repository is a subdirectory in the monorepo, not a separate git repository. They share the same git history.

### Step 2: Check Repository Status

For each repository, check:

1. **Does the repository have both dev and staging branches?**
   ```bash
   git show-ref --verify --quiet refs/heads/dev && \
   git show-ref --verify --quiet refs/heads/staging
   ```
   - If both exist: Continue
   - If missing: Skip this repository (inform user)

2. **Are there commits in dev not in staging?**
   ```bash
   git log staging..dev --oneline -- [repository-path]/
   ```
   - If commits exist: Repository needs MR
   - If no commits: Skip (already synced)

3. **Identify repositories needing MRs**:
   - Create a summary list showing which repos have changes
   - Show commit count per repository
   - Display to user before proceeding

### Step 3: Confirm with User

Present findings to user:
```
Found the following repositories with changes from dev to staging:

1. web-app/ - 12 commits
2. workers/ - 5 commits
3. k8s-charts/ - 8 commits
4. data-cluster/ - 3 commits

Repositories already synced (no changes):
- data-pipelines/
- data-cluster-operator/
- data-cluster-helm/
- MCPs/
- skupper-gateway/

Would you like me to create merge requests for the 4 repositories with changes? (yes/no)
```

If user says no, stop. If yes, proceed to Step 4.

### Step 4: Create Feature Branches for Each Repository

For each repository needing an MR, create a feature branch:

```bash
# For each repo, create a branch from dev
git checkout dev
git pull origin dev
git checkout -b release/[repo-name]-staging-sync-[date]

# Example branches:
# release/web-app-staging-sync-2026-02-13
# release/workers-staging-sync-2026-02-13
```

**Branch naming convention**:
- Prefix: `release/`
- Format: `release/[repo-name]-staging-sync-[YYYY-MM-DD]`
- Examples:
  - `release/web-app-staging-sync-2026-02-13`
  - `release/workers-staging-sync-2026-02-13`
  - `release/k8s-charts-staging-sync-2026-02-13`

### Step 5: Spawn Parallel Agents for MR Creation

**CRITICAL**: Use the Task tool to spawn multiple agents in parallel. Create ONE task per repository.

For each repository needing an MR, spawn an agent with this prompt template:

```
Create a merge request from dev to staging for the [REPO_NAME] repository.

Repository: [REPO_PATH]
Source Branch: dev
Target Branch: staging
Feature Branch: release/[repo-name]-staging-sync-[date]

Instructions:
1. You are currently on feature branch: release/[repo-name]-staging-sync-[date]
2. Analyze commits from staging to dev for this repository only:
   - git log staging..dev --oneline -- [repo-path]/
   - git diff staging...dev --stat -- [repo-path]/
   - git diff staging...dev -- [repo-path]/

3. Generate MR description following this template:

## Summary
Sync [REPO_NAME] changes from dev to staging for release deployment.

## Changes
[Analyze commits and categorize changes for this repository]

## Commits in this Release
[List all commits from staging..dev for this repository]

## Deployment Notes
- Target Environment: Staging
- Source Branch: dev
- Repository: [REPO_NAME]
- Deployment Strategy: [Standard/Requires manual steps/etc]

## Testing Checklist
- [ ] All tests passing in dev
- [ ] No breaking changes for staging
- [ ] Database migrations reviewed (if any)
- [ ] Configuration changes documented (if any)

## Related Links
- Repository CLAUDE.md: [link to repo's CLAUDE.md]
- CI/CD Docs: [CLAUDE_CICD.md](../CLAUDE_CICD.md)

4. Create the MR:
   ```bash
   glab mr create \
     --title "release([repo-name]): sync dev to staging [date]" \
     --description "$(cat /tmp/mr_description_[repo-name].md)" \
     --source-branch release/[repo-name]-staging-sync-[date] \
     --target-branch staging \
     --assignee @me \
     --label "release,staging-deployment,[repo-name]" \
     --web
   ```

5. Return the MR URL and status.

DO NOT create commits. This is a branch merge, not new code.
```

**Example agent spawning** (in a single message with multiple Task calls):

```
Task 1: web-app MR creation
Task 2: workers MR creation
Task 3: k8s-charts MR creation
Task 4: data-cluster MR creation
```

### Step 6: Wait for All Agents to Complete

**IMPORTANT**: Wait for ALL spawned agents to complete before proceeding.

Collect results from each agent:
- MR URL
- MR number
- Success/failure status
- Any errors encountered

### Step 7: Generate Summary Report

Create a comprehensive summary:

```markdown
## Batch MR Creation Summary: Dev → Staging

**Date**: [Current date]
**Total Repositories Processed**: [N]
**Successful MRs**: [N]
**Failed MRs**: [N]
**Already Synced**: [N]

### ✅ Successfully Created MRs

1. **web-app**
   - MR URL: [URL]
   - MR #: !123
   - Commits: 12
   - Status: ✅ Created

2. **workers**
   - MR URL: [URL]
   - MR #: !124
   - Commits: 5
   - Status: ✅ Created

### ❌ Failed MRs

[List any failures with error messages]

### ℹ️ Already Synced (No Changes)

- data-pipelines/
- data-cluster-operator/
- MCPs/

### Next Steps

1. Review each MR for correctness
2. Run staging deployment tests
3. Approve and merge MRs
4. Monitor staging environment after deployment
5. Create follow-up MRs from staging to production when ready

### Quick Links

[List all MR URLs]
```

### Step 8: Offer Notion Integration

Ask user:
```
Would you like me to:
1. Create a Notion task to track this staging release?
2. Update any existing release tasks with MR URLs?
3. No Notion updates needed

(Reply with 1, 2, or 3)
```

If user chooses 1:
- Create a new task in Notion Features & Tasks database
- Title: "Staging Release: Dev → Staging Sync [Date]"
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
3. **No New Commits**: This is a branch merge, not new code changes
4. **Branch Naming**: Use consistent `release/[repo]-staging-sync-[date]` format
5. **Error Handling**: If an agent fails, continue with others and report failures in summary
6. **User Confirmation**: Always confirm before creating multiple MRs
7. **Staging Target**: All MRs target `staging` branch, not `dev`
8. **Repository Paths**: Filter git log and diff by repository path to isolate changes

## Error Handling

### No Changes Found
```
No repositories have changes from dev to staging. All repositories are already synced.

Would you like me to check again or verify branch status?
```

### Git Branch Issues
```
Error: [Repository] is missing dev or staging branch.

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

Assistant: Creating feature branches and spawning parallel agents for MR creation...

[Spawns 3 Task agents in parallel - one for each repository]

[After all agents complete]

## Batch MR Creation Summary: Dev → Staging

**Date**: 2026-02-13
**Total Repositories Processed**: 9
**Successful MRs**: 3
**Failed MRs**: 0
**Already Synced**: 6

### ✅ Successfully Created MRs

1. **web-app**
   - MR URL: https://gitlab.com/alias3/datastreaming/-/merge_requests/245
   - MR #: \!245
   - Commits: 12
   - Status: ✅ Created

2. **workers**
   - MR URL: https://gitlab.com/alias3/datastreaming/-/merge_requests/246
   - MR #: \!246
   - Commits: 5
   - Status: ✅ Created

3. **k8s-charts**
   - MR URL: https://gitlab.com/alias3/datastreaming/-/merge_requests/247
   - MR #: \!247
   - Commits: 8
   - Status: ✅ Created

### ℹ️ Already Synced (No Changes)

- data-pipelines/
- data-cluster/
- data-cluster-operator/
- data-cluster-helm/
- MCPs/
- skupper-gateway/

### Next Steps

1. Review each MR for correctness
2. Run staging deployment tests
3. Approve and merge MRs
4. Monitor staging environment after deployment

### Quick Links

- web-app MR: https://gitlab.com/alias3/datastreaming/-/merge_requests/245
- workers MR: https://gitlab.com/alias3/datastreaming/-/merge_requests/246
- k8s-charts MR: https://gitlab.com/alias3/datastreaming/-/merge_requests/247

Would you like me to:
1. Create a Notion task to track this staging release?
2. Update any existing release tasks with MR URLs?
3. No Notion updates needed

(Reply with 1, 2, or 3)
```

## Quality Checklist

Before completing, verify:
- [ ] All repositories checked for dev→staging differences
- [ ] User confirmed before creating MRs
- [ ] Parallel agents spawned in single message
- [ ] Feature branches created with consistent naming
- [ ] All MR descriptions follow template
- [ ] Summary report generated with all results
- [ ] User offered Notion integration option
- [ ] Quick links provided for all created MRs

## Related Commands

- `/merge_request` - Create single MR from current feature branch
- `/ci_describe_pr` - Generate PR description for single repository
- `/commit` - Create conventional commits before creating MRs

---

**Note**: This command is designed for promoting tested code from dev to staging as part of the release process. For individual feature development, use `/merge_request` instead.
