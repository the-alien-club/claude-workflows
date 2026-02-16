#!/usr/bin/env python3
"""Generate business-focused weekly summary with aggregated initiatives."""

import re
from collections import defaultdict
from datetime import datetime

def parse_commits(input_file):
    """Parse commits and aggregate into initiatives."""
    with open(input_file, 'r') as f:
        content = f.read()

    commits_by_repo = defaultdict(list)
    commits_by_author = defaultdict(list)
    commit_types = defaultdict(int)
    merge_requests = []
    total_commits = 0

    repo_sections = re.split(r'=== REPO: (.+?) ===', content)

    for i in range(1, len(repo_sections), 2):
        repo_name = repo_sections[i].strip()
        repo_content = repo_sections[i + 1]

        if '(NOT FOUND)' in repo_name:
            continue

        commits = re.split(r'COMMIT_START', repo_content)

        for commit_text in commits[1:]:
            if 'COMMIT_END' not in commit_text:
                continue

            commit_text = commit_text.split('COMMIT_END')[0].strip()
            lines = commit_text.split('\n')

            if not lines:
                continue

            header = lines[0]
            if '|' not in header:
                continue

            parts = header.split('|')
            if len(parts) < 5:
                continue

            author_name = parts[1].strip()
            date = parts[3].strip()
            subject = '|'.join(parts[4:]).strip()
            body = '\n'.join(lines[1:]).strip() if len(lines) > 1 else ""

            # Track merge requests
            if subject.lower().startswith('merge'):
                merge_requests.append({
                    'subject': subject,
                    'body': body,
                    'repo': repo_name,
                    'author': author_name,
                    'date': date
                })

            match = re.match(r'^(feat|fix|refactor|chore|docs|test|ci|perf|revert|wip|Merge)', subject, re.IGNORECASE)
            commit_type = match.group(1).lower() if match else 'other'

            commit_data = {
                'author': author_name,
                'date': date,
                'subject': subject,
                'body': body,
                'type': commit_type,
                'repo': repo_name
            }

            commits_by_repo[repo_name].append(commit_data)
            commits_by_author[author_name].append(commit_data)
            commit_types[commit_type] += 1
            total_commits += 1

    return {
        'commits_by_repo': dict(commits_by_repo),
        'commits_by_author': dict(commits_by_author),
        'commit_types': dict(commit_types),
        'merge_requests': merge_requests,
        'total_commits': total_commits
    }


def aggregate_into_initiatives(data):
    """Aggregate commits into business initiatives."""

    initiatives = defaultdict(lambda: {'commits': 0, 'repos': set(), 'highlights': []})
    component_health = defaultdict(lambda: {'features': 0, 'fixes': 0, 'issues': []})

    # Keywords that map to initiatives
    initiative_keywords = {
        'observability': ('Platform Observability', 'cockpit', 'logging', 'monitoring', 'observability', 'loki'),
        'status_page': ('Infrastructure Monitoring', 'uptime', 'kuma', 'status'),
        'vector_search': ('Vector Search & AI', 'qdrant', 'vector', 'embedding', 'mistral', 'google'),
        'authentication': ('Security & Authentication', 'auth', 'jwt', 'token', 'rbac', 'security'),
        'data_pipelines': ('Data Processing', 'pipeline', 'workflow', 'argo', 'processor', 'ti_xml'),
        'public_data': ('Multi-tenant Data Sharing', 'public', 'dataplane', 'cross-org'),
        'database': ('Database Infrastructure', 'postgres', 'pgbouncer', 'pool', 'database'),
        'networking': ('Network Infrastructure', 'istio', 'envoy', 'skupper', 'service mesh'),
        'api_improvements': ('API & Developer Experience', 'openapi', 'client', 'api'),
        'ui_features': ('Platform UI Enhancements', 'frontend', 'ui', 'dialog', 'toggle', 'interface'),
        'webhooks': ('Event Processing', 'webhook', 'event'),
        'performance': ('Performance Optimization', 'performance', 'memory', 'cpu', 'optimize', 'hpa')
    }

    # Map components to repos
    component_map = {
        'Backend API': ['web-app'],
        'Frontend': ['web-app'],
        'Data Processing': ['data-pipelines', 'data-cluster'],
        'Infrastructure': ['k8s-charts', 'data-cluster-helm', 'data-cluster-operator'],
        'Workers': ['workers'],
        'Networking': ['skupper-gateway'],
        'MCP Services': ['MCPs/mcp-base', 'MCPs/mcp-openaire', 'MCPs/mcp-datacluster']
    }

    for repo, commits in data['commits_by_repo'].items():
        # Determine component
        component = 'Infrastructure'  # default
        for comp, repos in component_map.items():
            if any(r in repo for r in repos):
                component = comp
                break

        for commit in commits:
            subject = commit['subject'].lower()

            # Track component health
            if commit['type'] == 'feat':
                component_health[component]['features'] += 1
            elif commit['type'] == 'fix':
                component_health[component]['fixes'] += 1
                # Critical issues
                if any(word in subject for word in ['critical', 'crash', '502', '504', 'timeout', 'memory leak']):
                    component_health[component]['issues'].append(commit['subject'])

            # Aggregate into initiatives
            for init_key, (init_name, *keywords) in initiative_keywords.items():
                if any(kw in subject for kw in keywords):
                    initiatives[init_name]['commits'] += 1
                    initiatives[init_name]['repos'].add(repo)

                    # Capture significant highlights
                    if commit['type'] == 'feat' and len(initiatives[init_name]['highlights']) < 3:
                        # Clean up subject
                        highlight = re.sub(r'^feat\([\w-]+\):\s*', '', commit['subject'])
                        highlight = re.sub(r'^feat:\s*', '', highlight)
                        initiatives[init_name]['highlights'].append(highlight)

    return dict(initiatives), dict(component_health)


def generate_business_summary(data, monday, sunday):
    """Generate business-focused summary."""

    total_features = data['commit_types'].get('feat', 0)
    total_fixes = data['commit_types'].get('fix', 0)
    active_repos = len([r for r, commits in data['commits_by_repo'].items() if commits])

    # Aggregate into initiatives
    initiatives, component_health = aggregate_into_initiatives(data)

    # Determine overall health
    total_issues = sum(len(c['issues']) for c in component_health.values())
    health_emoji = "🟢"
    health_desc = "Strong"
    if total_fixes > total_features * 1.5:
        health_emoji = "🟡"
        health_desc = "Moderate"
    if total_issues >= 3:
        health_emoji = "🔴"
        health_desc = "Needs Attention"

    # Find top initiative
    top_initiative = max(initiatives.items(), key=lambda x: x[1]['commits']) if initiatives else ("General improvements", {'commits': 0})

    report = f"""# Weekly Engineering Update
## {monday} to {sunday}

---

## 🎯 Executive Overview

**This week's focus**: {top_initiative[0]} ({top_initiative[1]['commits']} changes across {len(top_initiative[1]['repos'])} components)

**Team**: {', '.join(data['commits_by_author'].keys())} • **Velocity**: {data['total_commits']} changes shipped • **Health**: {health_emoji} {health_desc}

**Key Metric**: Shipped {total_features} new capabilities and resolved {total_fixes} issues across {active_repos} platform components

---

## 📊 Component Status

| Component | Status | This Week |
|-----------|--------|-----------|
"""

    # Component status table
    for component in sorted(component_health.keys()):
        health = component_health[component]

        # Determine status
        if health['issues']:
            status = "🔴"
            summary = f"{health['features']} features, {health['fixes']} fixes, {len(health['issues'])} critical issues"
        elif health['fixes'] > health['features'] * 2:
            status = "🟡"
            summary = f"{health['features']} features, {health['fixes']} fixes (high fix activity)"
        else:
            status = "🟢"
            summary = f"{health['features']} features, {health['fixes']} fixes"

        report += f"| {component} | {status} | {summary} |\n"

    report += "\n---\n\n## ✨ Highlights: Top Wins\n\n"

    # Top 3 initiatives with most impact
    sorted_initiatives = sorted(initiatives.items(), key=lambda x: x[1]['commits'], reverse=True)[:3]

    for i, (name, details) in enumerate(sorted_initiatives, 1):
        report += f"### {i}. {name}\n\n"
        report += f"**Impact**: {details['commits']} changes across {len(details['repos'])} components\n\n"

        if details['highlights']:
            report += "**Key deliverables**:\n"
            for highlight in details['highlights'][:3]:
                report += f"- {highlight}\n"
        report += "\n"

    report += "---\n\n## 🚧 Lowlights: Issues & Challenges\n\n"

    # Gather critical issues
    critical_issues = []
    for component, health in component_health.items():
        for issue in health['issues']:
            critical_issues.append((component, issue))

    if critical_issues:
        for component, issue in critical_issues[:3]:
            clean_issue = re.sub(r'^fix\([\w-]+\):\s*', '', issue)
            clean_issue = re.sub(r'^fix:\s*', '', clean_issue)
            report += f"- **{component}**: {clean_issue}\n"
    else:
        report += "_No critical issues this week_\n"

    # High fix-to-feature ratio areas
    high_fix_areas = [(c, h) for c, h in component_health.items()
                      if h['fixes'] > h['features'] * 2 and not h['issues']]

    if high_fix_areas:
        report += f"\n**Stability focus areas**:\n"
        for component, health in high_fix_areas[:2]:
            report += f"- **{component}**: High bug fix activity ({health['fixes']} fixes vs {health['features']} features)\n"

    report += "\n---\n\n## 🎯 Progress: Major Features Shipped\n\n"

    # Extract major features by initiative
    for name, details in sorted_initiatives:
        if details['highlights']:
            report += f"### {name}\n\n"
            for highlight in details['highlights']:
                report += f"✅ {highlight}\n"
            report += "\n"

    report += "---\n\n## 📈 Development Metrics\n\n"

    report += f"""### Velocity & Quality
- **Features Shipped**: {total_features} new capabilities
- **Issues Resolved**: {total_fixes} bugs fixed
- **Code Quality**: {data['commit_types'].get('test', 0)} test suites added, {data['commit_types'].get('refactor', 0)} refactorings
- **Active Components**: {active_repos}/12 repositories with updates
- **Merge Requests**: {len(data['merge_requests'])} major features merged

### Team Contribution
"""

    for author, commits in sorted(data['commits_by_author'].items(), key=lambda x: len(x[1]), reverse=True):
        author_features = sum(1 for c in commits if c['type'] == 'feat')
        author_fixes = sum(1 for c in commits if c['type'] == 'fix')
        report += f"- **{author}**: {author_features} features, {author_fixes} fixes\n"

    report += f"\n---\n\n## 🔗 Platform Health\n\n"
    report += f"- **Monitoring**: Live status at [status.alien.club](https://status.alien.club)\n"
    report += f"- **Observability**: Centralized logging and metrics via Scaleway Cockpit\n"
    report += f"- **Deployment Health**: {health_emoji} {health_desc}\n"

    report += "\n---\n\n## 📅 Next Week Priorities\n\n"
    report += "_To be determined based on current sprint goals and backlog prioritization_\n\n"
    report += "Suggested focus areas based on this week's momentum:\n"

    # Suggest next priorities based on unfinished initiatives
    incomplete_areas = [(name, details) for name, details in initiatives.items()
                        if details['commits'] >= 5 and details['commits'] < 15]

    for i, (name, details) in enumerate(incomplete_areas[:3], 1):
        report += f"{i}. Continue {name} work\n"

    if not incomplete_areas:
        report += "1. Address critical issues from this week\n"
        report += "2. Continue feature development momentum\n"
        report += "3. Focus on code quality and test coverage\n"

    report += f"\n---\n\n*Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} • [Technical Details](./weekly-summary.md)*\n"

    return report


if __name__ == "__main__":
    import sys
    import os

    if len(sys.argv) != 3:
        print("Usage: python3 generate_business_summary.py YYYY-MM-DD YYYY-MM-DD")
        sys.exit(1)

    monday = sys.argv[1]
    sunday = sys.argv[2]

    print("📖 Parsing commits and aggregating initiatives...")
    data = parse_commits('/tmp/weekly_commits_full.txt')

    print("📝 Generating business summary...")
    report = generate_business_summary(data, monday, sunday)

    output_file = f"ai_docs/weekly-summaries/{monday}-business-summary.md"
    os.makedirs("ai_docs/weekly-summaries", exist_ok=True)

    with open(output_file, 'w') as f:
        f.write(report)

    print(f"✅ Business summary saved to {output_file}")

    # Print summary of initiatives
    initiatives, _ = aggregate_into_initiatives(data)
    print(f"\n📊 Identified {len(initiatives)} major initiatives:")
    for name, details in sorted(initiatives.items(), key=lambda x: x[1]['commits'], reverse=True)[:5]:
        print(f"   • {name}: {details['commits']} commits")
