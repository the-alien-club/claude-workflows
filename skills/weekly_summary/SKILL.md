---
name: weekly_summary
description: Generate comprehensive weekly engineering summary by analyzing ALL branches across all repositories using AI-powered per-repo analysis. Captures feature branch work, aggregates into business initiatives, detects alpha deployments, and creates executive-ready reports.
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash, Read, Write, Task
---

# Weekly Summary - AI-Powered Multi-Repo Analysis

Generate comprehensive weekly engineering summaries with:
- **All branch analysis** (including feature branches)
- **AI-powered summarization** per repository
- **Alpha deployment detection** (feature → dev merges)
- **Business-focused aggregation**

## Execution Flow

When `/weekly_summary` is invoked, follow these steps:

### Step 1: Calculate This Week's Date Range

```bash
python3 -c "
from datetime import datetime, timedelta
today = datetime.now()
monday = today - timedelta(days=today.weekday())
sunday = monday + timedelta(days=6)
print(f'{monday.strftime(\"%Y-%m-%d\")}|{sunday.strftime(\"%Y-%m-%d\")}')"
```

Store the output as `MONDAY` and `SUNDAY`.

### Step 2: Collect Commits from ALL Branches

```bash
bash .claude/skills/weekly_summary/collect_all_branches.sh "$MONDAY" "$SUNDAY"
```

This creates `/tmp/weekly_commits_by_repo/<repo>.txt` files with:
- All commits from all branches (not just main/dev)
- Active branch list
- Complete commit messages with bodies

### Step 3: Spawn AI Agents for Each Repository

For each repository with activity, spawn the **weekly-repo-analyzer** custom agent:

```
Task(
  subagent_type="weekly-repo-analyzer",
  model="haiku",
  description="Analyze {repo_name} weekly commits",
  prompt="Analyze the commits in /tmp/weekly_commits_by_repo/{repo_file}.txt for {repo_name} covering {MONDAY} to {SUNDAY}."
)
```

**Run all 12 agents in parallel** (use multiple Task tool calls in one response for speed).

The custom agent has built-in knowledge of:
- DataStreaming platform architecture
- Deployment stages (dev=alpha, staging, main=prod)
- Initiative keywords and business value extraction
- Component health assessment logic

#### Simple Agent Prompt

Since the `weekly-repo-analyzer` agent has all the context built-in, just tell it the file path:

```
Analyze the commits in /tmp/weekly_commits_by_repo/{repo_file}.txt for {repo_name}.

Week: {MONDAY} to {SUNDAY}

Output valid JSON with initiatives, deployments, bugs fixed, and feature branch activity.
```

The agent will automatically:
- Aggregate commits into business initiatives
- Detect alpha/staging/production deployments
- Extract business value and impact
- Assess component health
- Identify feature branch work in progress
- Output structured JSON

### Step 4: Aggregate All Agent Results

After all agents complete:

1. Read all agent JSON outputs from Task results
2. Save each to `/tmp/weekly_agent_outputs/{repo}_analysis.json` using Bash:

```bash
# Use cat with heredoc or echo to write JSON files
cat > /tmp/weekly_agent_outputs/web-app_analysis.json << 'EOF'
{JSON content from agent output}
EOF

# Or use echo with escaped quotes
echo '{JSON content}' > /tmp/weekly_agent_outputs/repo_analysis.json
```

**IMPORTANT**: Use Bash (cat/echo) instead of Write tool to avoid read-before-write requirements for new files.

3. Run aggregation:

```bash
python3 .claude/skills/weekly_summary/orchestrate_summary.py "$MONDAY" "$SUNDAY" --aggregate-only
```

This generates the final business summary with:
- Executive overview
- Component status table
- **🚀 Alpha Deployments section** (features in testing)
- Top initiatives (AI-aggregated)
- Platform health

### Step 5: Save Reports

```
ai_docs/weekly-summaries/
├── YYYY-MM-DD-business-summary.md  ← Executive report
└── YYYY-MM-DD-technical-summary.md ← Engineering details
```

## Example Agent Spawning

Spawn all 12 repo agents in parallel:

```
// In one response, call Task tool 12 times:

Task(subagent_type="Explore", description="Analyze web-app", prompt="...")
Task(subagent_type="Explore", description="Analyze workers", prompt="...")
Task(subagent_type="Explore", description="Analyze data-cluster", prompt="...")
// ... for all 12 repos
```

## Repositories to Analyze

- web-app (Backend + Frontend)
- workers (Job processing)
- data-pipelines (Argo workflows)
- data-cluster (FastAPI data API)
- data-cluster-operator (K8s operator)
- data-cluster-helm (Infrastructure Helm)
- k8s-charts (Platform deployment)
- skupper-gateway (Networking)
- MCPs/mcp-base
- MCPs/mcp-boilerplate
- MCPs/mcp-datacluster
- MCPs/mcp-openaire

## Key Innovations

✅ **Captures ALL branch activity** (not just merged)
✅ **AI understands context** (better than keyword matching)
✅ **Aggregates into initiatives** (not commit lists)
✅ **Detects alpha deployments** (feature → dev merges)
✅ **Parallel processing** (12 agents at once)
✅ **Business value focused** (not just technical changes)

## Expected Output

### Business Summary

```markdown
# Weekly Engineering Update
## 2026-02-02 to 2026-02-08

## 🎯 Executive Overview
**Focus**: Platform Observability (51 changes, 11 components)
**Health**: 🟢 Strong
**Shipped**: 90 features, 115 fixes

## 📊 Component Status
| Component | Status | Summary |
|---|---|---|
| Backend API | 🟢 | 20 features, 30 fixes |
| Infrastructure | 🟢 | 15 features, 12 fixes |

## 🚀 Alpha Deployments (Features in Testing)

### Uptime Kuma Status Page
**Repo**: k8s-charts • **Date**: 2026-02-04
**Status**: Deployed to alpha (dev branch)
**Impact**: Live status page at status.alien.club

### Public Dataplane Sharing
**Repo**: web-app • **Date**: 2026-02-03
**Status**: Deployed to alpha (dev branch)
**Impact**: Cross-organization data sharing capability

## ✨ Top Initiatives
1. Platform Observability (51 changes)
2. Vector Search & AI (26 changes)
3. Infrastructure Monitoring (12 changes) ← NEW!
```

## Troubleshooting

**If agents fail**: Check `/tmp/weekly_commits_by_repo/` for commit files
**If no alpha deployments detected**: Check for "Merge" commits to "dev" branch
**If analysis incomplete**: Ensure Task tool has access to file reads
