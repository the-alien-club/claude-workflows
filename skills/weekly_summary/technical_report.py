#!/usr/bin/env python3
import re
import json
from collections import defaultdict
from datetime import datetime

def parse_commits(input_file):
    """Parse commits from the collected file."""
    with open(input_file, 'r') as f:
        content = f.read()

    commits_by_repo = defaultdict(list)
    commits_by_author = defaultdict(list)
    commit_types = defaultdict(int)
    total_commits = 0

    # Split by repo sections
    repo_sections = re.split(r'=== REPO: (.+?) ===', content)

    for i in range(1, len(repo_sections), 2):
        repo_name = repo_sections[i].strip()
        repo_content = repo_sections[i + 1]

        if '(NOT FOUND)' in repo_name:
            continue

        # Split by commits
        commits = re.split(r'COMMIT_START', repo_content)

        for commit_text in commits[1:]:  # Skip first empty split
            if 'COMMIT_END' not in commit_text:
                continue

            commit_text = commit_text.split('COMMIT_END')[0].strip()
            lines = commit_text.split('\n')

            if not lines:
                continue

            # Parse header line
            header = lines[0]
            if '|' not in header:
                continue

            parts = header.split('|')
            if len(parts) < 5:
                continue

            commit_hash = parts[0].strip()
            author_name = parts[1].strip()
            author_email = parts[2].strip()
            date = parts[3].strip()
            subject = '|'.join(parts[4:]).strip()

            # Get body (everything after first line)
            body = '\n'.join(lines[1:]).strip() if len(lines) > 1 else ""

            # Extract commit type
            match = re.match(r'^(feat|fix|refactor|chore|docs|test|ci|perf|revert|wip|Merge)', subject, re.IGNORECASE)
            if match:
                commit_type = match.group(1).lower()
            else:
                commit_type = 'other'

            commit_data = {
                'hash': commit_hash[:7],
                'author': author_name,
                'email': author_email,
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
        'total_commits': total_commits
    }

def generate_markdown_report(data, monday, sunday):
    """Generate comprehensive markdown report."""

    report = f"""# Weekly Summary: {monday} to {sunday}

**Week**: {monday} (Monday) to {sunday} (Sunday)
**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

---

## 📊 Overview

- **Total Commits**: {data['total_commits']}
- **Active Repositories**: {len([r for r, commits in data['commits_by_repo'].items() if commits])}/{len(data['commits_by_repo'])}
- **Contributors**: {', '.join(data['commits_by_author'].keys())}
- **Most Active Repo**: {max(data['commits_by_repo'].items(), key=lambda x: len(x[1]))[0]} ({len(max(data['commits_by_repo'].items(), key=lambda x: len(x[1]))[1])} commits)

### Commits by Type

"""

    for ctype, count in sorted(data['commit_types'].items(), key=lambda x: x[1], reverse=True):
        report += f"- **{ctype}**: {count}\n"

    report += "\n---\n\n## 🎯 Key Achievements This Week\n\n"

    # Analyze major themes
    themes = defaultdict(list)
    for repo, commits in data['commits_by_repo'].items():
        for commit in commits:
            subject = commit['subject'].lower()
            if 'observability' in subject or 'cockpit' in subject or 'logging' in subject:
                themes['Observability & Logging'].append(f"{repo}: {commit['subject']}")
            elif 'qdrant' in subject or 'vector' in subject:
                themes['Vector Database (Qdrant)'].append(f"{repo}: {commit['subject']}")
            elif 'auth' in subject or 'jwt' in subject or 'token' in subject:
                themes['Authentication & Security'].append(f"{repo}: {commit['subject']}")
            elif 'webhook' in subject:
                themes['Webhook System'].append(f"{repo}: {commit['subject']}")
            elif 'pipeline' in subject or 'workflow' in subject or 'argo' in subject:
                themes['Data Pipelines'].append(f"{repo}: {commit['subject']}")
            elif 'istio' in subject or 'envoy' in subject:
                themes['Service Mesh & Networking'].append(f"{repo}: {commit['subject']}")
            elif 'postgres' in subject or 'pgbouncer' in subject or 'database' in subject:
                themes['Database Infrastructure'].append(f"{repo}: {commit['subject']}")

    for theme, items in sorted(themes.items(), key=lambda x: len(x[1]), reverse=True)[:5]:
        report += f"\n### {theme} ({len(items)} commits)\n\n"
        for item in items[:3]:  # Show top 3
            report += f"- {item}\n"
        if len(items) > 3:
            report += f"- _(and {len(items) - 3} more)_\n"

    report += "\n---\n\n## 👥 Contributions by Author\n\n"

    for author, commits in sorted(data['commits_by_author'].items(), key=lambda x: len(x[1]), reverse=True):
        report += f"\n### {author} ({len(commits)} commits)\n\n"

        # Group by repo
        author_by_repo = defaultdict(list)
        for commit in commits:
            author_by_repo[commit['repo']].append(commit)

        for repo, repo_commits in sorted(author_by_repo.items(), key=lambda x: len(x[1]), reverse=True):
            report += f"\n#### {repo} ({len(repo_commits)} commits)\n\n"

            # Group by type
            by_type = defaultdict(list)
            for commit in repo_commits:
                by_type[commit['type']].append(commit)

            for ctype in ['feat', 'fix', 'refactor', 'chore', 'test', 'docs', 'other']:
                if ctype not in by_type:
                    continue

                report += f"\n**{ctype.title()}**:\n"
                for commit in by_type[ctype][:5]:  # Show top 5 per type
                    report += f"- `{commit['hash']}` {commit['subject']}\n"
                    if commit['body']:
                        # Show first line of body
                        first_line = commit['body'].split('\n')[0].strip()
                        if first_line and len(first_line) > 0:
                            report += f"  > {first_line[:100]}{'...' if len(first_line) > 100 else ''}\n"

                if len(by_type[ctype]) > 5:
                    report += f"- _(and {len(by_type[ctype]) - 5} more)_\n"

    report += "\n---\n\n## 📁 Activity by Repository\n\n"

    for repo, commits in sorted(data['commits_by_repo'].items(), key=lambda x: len(x[1]), reverse=True):
        if not commits:
            continue

        report += f"\n### {repo} ({len(commits)} commits)\n\n"

        # Group by type
        by_type = defaultdict(list)
        for commit in commits:
            by_type[commit['type']].append(commit)

        for ctype in ['feat', 'fix', 'refactor', 'chore', 'test', 'docs', 'other']:
            if ctype not in by_type:
                continue

            report += f"\n#### {ctype.title()} ({len(by_type[ctype])})\n\n"
            for commit in by_type[ctype][:10]:  # Show top 10
                report += f"- `{commit['hash']}` {commit['subject']} - _{commit['author']}_ - {commit['date'][:10]}\n"
                if commit['body']:
                    body_lines = [line.strip() for line in commit['body'].split('\n') if line.strip()]
                    if body_lines:
                        report += f"  > {body_lines[0][:150]}{'...' if len(body_lines[0]) > 150 else ''}\n"

            if len(by_type[ctype]) > 10:
                report += f"- _(and {len(by_type[ctype]) - 10} more)_\n"

    # Repos with no activity
    inactive_repos = [repo for repo, commits in data['commits_by_repo'].items() if not commits]
    if inactive_repos:
        report += "\n---\n\n## 📌 Repositories With No Activity\n\n"
        for repo in inactive_repos:
            report += f"- {repo}\n"

    report += "\n---\n\n## 🔗 References\n\n"
    report += "- [GitLab](https://gitlab.com/alias3/datastreaming)\n"
    report += "- [Notion Knowledge Base](https://www.notion.so/2e9ee0eb364081dfa8e5faac9346edc5)\n"

    return report

if __name__ == "__main__":
    import sys
    import os

    if len(sys.argv) != 3:
        print("Usage: python3 generate_weekly_report.py YYYY-MM-DD YYYY-MM-DD")
        sys.exit(1)

    monday = sys.argv[1]
    sunday = sys.argv[2]

    # Parse commits
    print("📖 Parsing commits...")
    data = parse_commits('/tmp/weekly_commits_full.txt')

    # Generate report
    print("📝 Generating report...")
    report = generate_markdown_report(data, monday, sunday)

    # Save report
    output_file = f"ai_docs/weekly-summaries/{monday}-weekly-summary.md"
    os.makedirs("ai_docs/weekly-summaries", exist_ok=True)

    with open(output_file, 'w') as f:
        f.write(report)

    print(f"✅ Report saved to {output_file}")
    print(f"\n📊 Summary: {data['total_commits']} commits across {len([r for r, commits in data['commits_by_repo'].items() if commits])} repositories")
