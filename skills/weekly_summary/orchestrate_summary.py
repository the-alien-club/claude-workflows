#!/usr/bin/env python3
"""
Orchestrate AI-powered weekly summary generation.

Workflow:
1. Spawn parallel agents to analyze each repo
2. Detect feature branch → dev merges (Alpha deployments)
3. Aggregate all results into final reports
"""

import os
import sys
import json
import subprocess
from pathlib import Path
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

REPOS = [
    "web-app",
    "workers",
    "data-pipelines",
    "data-cluster",
    "data-cluster-operator",
    "data-cluster-helm",
    "k8s-charts",
    "skupper-gateway",
    "MCPs/mcp-base",
    "MCPs/mcp-boilerplate",
    "MCPs/mcp-datacluster",
    "MCPs/mcp-openaire"
]

COMMIT_DIR = "/tmp/weekly_commits_by_repo"
AGENT_OUTPUT_DIR = "/tmp/weekly_agent_outputs"


def spawn_repo_agent(repo_name, monday, sunday):
    """Spawn an Explore agent to analyze a single repository."""

    repo_file = repo_name.replace('/', '_')
    input_file = f"{COMMIT_DIR}/{repo_file}.txt"
    output_file = f"{AGENT_OUTPUT_DIR}/{repo_file}_analysis.json"

    if not Path(input_file).exists():
        print(f"⚠️  {repo_name}: No commit file found, skipping")
        return None

    # Read commit data
    with open(input_file, 'r') as f:
        commit_data = f.read()

    if '=== NO ACTIVITY THIS WEEK ===' in commit_data:
        print(f"⏭️  {repo_name}: No activity this week")
        return None

    # Check for feature branch → dev merges (Alpha deployments)
    alpha_deployments = detect_alpha_deployments(commit_data)

    print(f"🤖 Spawning agent for: {repo_name}")

    agent_prompt = f"""
Analyze the commits for {repo_name} from {monday} to {sunday}.

# Commit Data
{commit_data[:15000]}  # Truncate if too long

# Your Task

Analyze these commits and generate a structured summary focused on BUSINESS VALUE and INITIATIVES.

## Important: Detect Deployment Stages

{"✅ ALPHA DEPLOYMENTS DETECTED:" if alpha_deployments else ""}
{chr(10).join(f"- {dep}" for dep in alpha_deployments) if alpha_deployments else ""}

## Output Requirements

Generate a JSON object with this structure:

{{
  "repo": "{repo_name}",
  "health": "🟢/🟡/🔴",
  "total_commits": <number>,
  "active_branches": <count>,
  "authors": ["author1", "author2"],

  "initiatives": [
    {{
      "name": "Initiative Name",
      "impact": "Business value description",
      "commits": <count>,
      "highlights": [
        "Key deliverable 1",
        "Key deliverable 2"
      ]
    }}
  ],

  "alpha_deployments": [
    {{
      "feature": "Feature name",
      "description": "What was deployed to alpha",
      "date": "YYYY-MM-DD"
    }}
  ],

  "bugs_fixed": [
    "Critical bug description",
    "Performance fix description"
  ],

  "infrastructure": [
    "CI/CD improvement",
    "Tooling addition"
  ],

  "feature_branches": [
    {{
      "name": "branch-name",
      "description": "What's being developed",
      "commits": <count>
    }}
  ]
}}

## Analysis Guidelines

1. **Aggregate commits into initiatives** - Don't list 50 individual commits. Group related work.
   Example: "Platform Observability" not "added logging" + "added monitoring" + "added cockpit" (15 times)

2. **Extract business value** - What problem does this solve? What can customers do now?
   Example: "Multi-tenant Data Sharing enables cross-organization collaboration"

3. **Identify major milestones** - Look for significant achievements
   Example: "Added status page at status.alien.club" or "Launched Uptime Kuma monitoring"

4. **Feature branches = work in progress** - Identify what's being developed but not merged yet

5. **Alpha deployments** - Feature branches merged to 'dev' are deployed to alpha environment
   {"Already detected:" if alpha_deployments else "Look for merge commits to dev branch"}
   {chr(10).join(f"   - {dep}" for dep in alpha_deployments) if alpha_deployments else ""}

6. **Component health**:
   - 🟢 Green: Normal development, good feature/fix ratio
   - 🟡 Yellow: High fix activity, potential stability issues
   - 🔴 Red: Critical issues, urgent fixes

## Keywords to Watch For

- status.alien.club, uptime, kuma → Infrastructure Monitoring milestone
- cockpit, observability, logging → Platform Observability
- qdrant, vector, embedding → Vector Search & AI
- public, dataplane, cross-org → Multi-tenant features
- jwt, auth, rbac → Security enhancements

IMPORTANT: Output ONLY valid JSON. No markdown formatting, no explanations outside the JSON.
"""

    # TODO: Actually spawn the agent using Task tool
    # For now, we'll create a placeholder analysis

    # Parse commits to extract basic metrics
    commits = commit_data.count('COMMIT_START')
    authors = set()

    for line in commit_data.split('\n'):
        if '|' in line and 'COMMIT_START' not in line:
            parts = line.split('|')
            if len(parts) >= 2:
                authors.add(parts[1].strip())

    # Create basic analysis (will be replaced by actual agent output)
    analysis = {
        "repo": repo_name,
        "health": "🟢",
        "total_commits": commits,
        "active_branches": len([l for l in commit_data.split('\n') if 'refs/heads/' in l]),
        "authors": list(authors),
        "initiatives": [],
        "alpha_deployments": alpha_deployments,
        "bugs_fixed": [],
        "infrastructure": [],
        "feature_branches": []
    }

    # Save analysis
    os.makedirs(AGENT_OUTPUT_DIR, exist_ok=True)
    with open(output_file, 'w') as f:
        json.dump(analysis, f, indent=2)

    print(f"✅ {repo_name}: Analysis complete ({commits} commits)")

    return analysis


def detect_alpha_deployments(commit_data):
    """Detect feature branch merges to dev (alpha deployments)."""

    deployments = []

    # Look for merge commits to dev
    lines = commit_data.split('\n')

    for i, line in enumerate(lines):
        if 'COMMIT_START' in line and i + 1 < len(lines):
            # Get commit message
            commit_line = lines[i + 1]

            if '|' in commit_line:
                parts = commit_line.split('|')
                if len(parts) >= 5:
                    date = parts[3].strip()[:10]  # YYYY-MM-DD
                    subject = '|'.join(parts[4:]).strip()

                    # Detect merge to dev
                    if 'merge' in subject.lower() and 'dev' in subject.lower():
                        # Extract feature branch name
                        if 'feature/' in subject.lower() or 'fix/' in subject.lower():
                            # Parse branch name from merge message
                            feature = subject.split("'")[1] if "'" in subject else subject

                            deployments.append({
                                "feature": feature,
                                "description": f"Merged to dev (alpha environment)",
                                "date": date
                            })

    return deployments


def aggregate_reports(all_analyses, monday, sunday):
    """Aggregate all repo analyses into final business summary."""

    # Calculate totals
    total_commits = sum(a['total_commits'] for a in all_analyses if a)
    all_authors = set()
    for a in all_analyses:
        if a:
            all_authors.update(a['authors'])

    # Aggregate initiatives across all repos
    all_initiatives = []
    for analysis in all_analyses:
        if analysis and 'initiatives' in analysis:
            all_initiatives.extend(analysis['initiatives'])

    # Aggregate alpha deployments
    all_alpha = []
    for analysis in all_analyses:
        if analysis and 'alpha_deployments' in analysis:
            for dep in analysis['alpha_deployments']:
                dep['repo'] = analysis['repo']
                all_alpha.append(dep)

    # Generate business summary
    report = f"""# Weekly Engineering Update
## {monday} to {sunday}

---

## 🎯 Executive Overview

**Team**: {', '.join(sorted(all_authors))} • **Velocity**: {total_commits} changes shipped

**Active Components**: {len([a for a in all_analyses if a])}/12 repositories with updates

{"**🚀 Alpha Deployments This Week**: " + str(len(all_alpha)) + " features deployed to alpha environment" if all_alpha else ""}

---

## 📊 Component Status

| Component | Status | This Week |
|-----------|--------|-----------|
"""

    # Component status
    for analysis in all_analyses:
        if analysis:
            repo = analysis['repo']
            health = analysis.get('health', '🟢')
            commits = analysis['total_commits']
            branches = analysis.get('active_branches', 0)

            report += f"| {repo} | {health} | {commits} commits, {branches} active branches |\n"

    # Alpha deployments section
    if all_alpha:
        report += "\n---\n\n## 🚀 Alpha Deployments (Features in Testing)\n\n"
        for dep in all_alpha:
            report += f"### {dep['feature']}\n"
            report += f"**Repo**: {dep['repo']} • **Date**: {dep['date']}\n"
            report += f"**Status**: Deployed to alpha environment (dev branch)\n\n"

    report += "\n---\n\n## ✨ Highlights: Top Initiatives\n\n"

    # Aggregate and rank initiatives by commit count
    if all_initiatives:
        # Sort by commits descending
        sorted_initiatives = sorted(all_initiatives, key=lambda x: x.get('commits', 0), reverse=True)

        # Show top 10 initiatives
        for idx, init in enumerate(sorted_initiatives[:10], 1):
            name = init.get('name', 'Unknown')
            impact = init.get('impact', '')
            commits = init.get('commits', 0)

            report += f"{idx}. **{name}** ({commits} commits)\n"
            report += f"   - {impact}\n\n"
    else:
        report += "_No major initiatives identified_\n\n"

    report += "\n---\n\n## 🔗 Platform Health\n\n"
    report += f"- **Monitoring**: Live status at [status.alien.club](https://status.alien.club)\n"
    report += f"- **Alpha Environment**: {len(all_alpha)} features deployed this week\n"

    report += f"\n---\n\n*Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*\n"

    return report


def load_agent_results():
    """Load existing agent analysis results from files."""
    import json

    analyses = []

    if not os.path.exists(AGENT_OUTPUT_DIR):
        print(f"⚠️  No agent outputs found at {AGENT_OUTPUT_DIR}")
        return []

    for file in os.listdir(AGENT_OUTPUT_DIR):
        if file.endswith('_analysis.json'):
            with open(f"{AGENT_OUTPUT_DIR}/{file}", 'r') as f:
                try:
                    analysis = json.load(f)
                    analyses.append(analysis)
                except json.JSONDecodeError as e:
                    print(f"⚠️  Failed to parse {file}: {e}")

    return analyses


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 orchestrate_summary.py YYYY-MM-DD YYYY-MM-DD [--aggregate-only]")
        sys.exit(1)

    monday = sys.argv[1]
    sunday = sys.argv[2]
    aggregate_only = "--aggregate-only" in sys.argv

    print(f"🚀 Orchestrating weekly summary: {monday} to {sunday}\n")

    analyses = []

    if aggregate_only:
        # Load existing agent results
        print("📊 Loading existing agent analysis results...\n")
        analyses = load_agent_results()
        print(f"✅ Loaded {len(analyses)} repo analyses\n")
    else:
        # Phase 1: Spawn agents in parallel
        print("📊 Phase 1: Spawning AI agents for repo analysis...\n")
        print("⚠️  NOTE: This is placeholder mode. When run via /weekly_summary,")
        print("    Claude will spawn real Explore agents using the Task tool.\n")

        with ThreadPoolExecutor(max_workers=6) as executor:
            futures = {
                executor.submit(spawn_repo_agent, repo, monday, sunday): repo
                for repo in REPOS
            }

            for future in as_completed(futures):
                repo = futures[future]
                try:
                    result = future.result()
                    if result:
                        analyses.append(result)
                except Exception as e:
                    print(f"❌ {repo}: Error - {e}")

        print(f"\n✅ Phase 1 complete: {len(analyses)} repos analyzed\n")

    # Phase 2: Aggregate results
    print("📝 Phase 2: Aggregating results into business summary...\n")

    business_report = aggregate_reports(analyses, monday, sunday)

    # Save report
    output_dir = "ai_docs/weekly-summaries"
    os.makedirs(output_dir, exist_ok=True)

    output_file = f"{output_dir}/{monday}-business-summary.md"
    with open(output_file, 'w') as f:
        f.write(business_report)

    print(f"✅ Business summary saved to: {output_file}\n")

    # Summary
    total_alpha = sum(len(a.get('alpha_deployments', [])) for a in analyses)
    print("📊 Summary:")
    print(f"   • Total commits: {sum(a['total_commits'] for a in analyses)}")
    print(f"   • Repos analyzed: {len(analyses)}")
    print(f"   • Alpha deployments: {total_alpha}")

    if total_alpha > 0:
        print(f"\n🚀 Features deployed to alpha this week:")
        for a in analyses:
            for dep in a.get('alpha_deployments', []):
                print(f"   • {dep['feature']} ({a['repo']})")


if __name__ == "__main__":
    main()
