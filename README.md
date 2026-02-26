# Alien Intelligence Workflows
**Production-ready development workflows for Claude Code**: Planning, research, implementation, commits, and merge requests for full-stack AI-powered development.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/the-alien-club/claude-workflows)

## What's Included
This plugin provides **21 slash commands** and **8 custom agents** to streamline your development workflow:

### Planning & Research
- `/create_plan`: Interactive implementation planning
- `/research_codebase`: Codebase analysis and exploration
- `/iterate_plan`: Iterate on existing implementation plans

### Implementation
- `/implement_plan`: Execute implementation plans with verification
- `/validate_plan`: Validate implementation against plan criteria
- `/debug`: Debug issues with comprehensive analysis

### Git Workflows
- `/commit`: Create conventional commits without Claude attribution
- `/commit_msg`: Create conventional commit messages based on the git diff
- `/merge_request`: Generate comprehensive GitLab MR descriptions
- `/describe_pr`: Create PR descriptions
- `/jira_mr`: Link a merged/open MR to a Jira SDS ticket, find or create the card and update it with MR info

### Specialized Workflows
- `/oneshot`: Research and plan in one command
- `/oneshot_plan`: Execute full feature workflow

### Documentation & Handoffs
- `/create_handoff`: Create handoff documents for session transfer
- `/resume_handoff`: Resume work from handoff documentation
- `/weekly_summary`: Generate weekly repository summaries
- `/adrien_weekly_wrap`: Generate Adrien's weekly C-level wrap-up report (technical + non-technical versions, in French)
- `/format_comments`: Format comments in the codebase to follow the natural prose style guide
- `/format_md`: Format Markdown documentation files, enforcing heading spacing, table alignment, separator rules (no em dashes, no inline dashes), and list style

### DevOps & Utilities
- `/local_review`: Set up branch review environment
- `/batch_mr_dev_to_staging`: Batch merge request creation

### Custom Agents
- **project-tracker**: Track project progress and next steps
- **codebase-locator**: Find relevant code quickly
- **codebase-analyzer**: Deep codebase analysis
- **codebase-pattern-finder**: Find implementation patterns
- **web-search-researcher**: Research with web search
- **weekly-repo-analyzer**: Generate weekly summaries
- **thoughts-locator** / **thoughts-analyzer**: Work with thoughts directory

## Installation
### Option 1: Install from GitHub (Recommended)
```bash
/plugin install https://github.com/the-alien-club/claude-workflows.git
```

### Option 2: Install from Zip
1. Download the latest release
2. Run:
   ```bash
   /plugin install /path/to/claude-workflows.zip
   ```

### Option 3: Local Development
```bash
claude --plugin-dir /path/to/claude-workflows
```

## Quick Start
After installation, all commands are available with the plugin namespace:

```bash
# Create a git commit
/alien-intelligence-workflows:commit

# Create an implementation plan
/alien-intelligence-workflows:create_plan

# Generate a merge request
/alien-intelligence-workflows:merge_request
```

Run `/help` to see all available commands.

## Command Details
### Planning Commands
#### `/create_plan`
Creates detailed implementation plans through interactive research.

**Features:**
- Spawns parallel research agents
- Interactive planning workflow
- Automated/manual success criteria separation
- Phase-based implementation structure

**Usage:**
```bash
/alien-intelligence-workflows:create_plan Add user authentication
```

#### `/implement_plan`
Executes approved implementation plans with continuous verification.

**Features:**
- Phase-by-phase execution
- Automated verification checkpoints
- Manual testing coordination
- Uses `/commit` for all commits
- Updates plan checkboxes automatically

**Usage:**
```bash
/alien-intelligence-workflows:implement_plan ai_docs/feature-name/plan/implementation-plan.md
```

### Git Commands
#### `/commit`
Creates conventional commits without Claude attribution.

**Features:**
- Reviews all changes (staged + unstaged)
- Generates semantic commit messages
- Component-scoped (backend, frontend, workers, etc.)
- Atomic commits with clear descriptions
- **Never adds Claude co-author attribution**

**Usage:**
```bash
/alien-intelligence-workflows:commit
```

#### `/merge_request`
Creates comprehensive GitLab merge requests by analyzing feature branches.

**Features:**
- Analyzes all commits and changes
- Generates structured MR description
- Includes deployment and security notes
- Creates MR via `glab` CLI

**Usage:**
```bash
/alien-intelligence-workflows:merge_request
```

## Workflow Patterns
### Feature Development Workflow
```bash
# 1. Research the codebase
/alien-intelligence-workflows:research_codebase_nt authentication

# 2. Create implementation plan
/alien-intelligence-workflows:create_plan_nt add user authentication

# 3. Implement the plan
/alien-intelligence-workflows:implement_plan ai_docs/add-auth/plan/implementation-plan.md

# 4. Commit changes
/alien-intelligence-workflows:commit

# 5. Create merge request
/alien-intelligence-workflows:merge_request
```

### Bug Fix Workflow
```bash
# 1. Debug the issue
/alien-intelligence-workflows:debug

# 2. Commit the fix
/alien-intelligence-workflows:commit

# 3. Create merge request
/alien-intelligence-workflows:merge_request
```

### Documentation Handoff
```bash
# At end of session
/alien-intelligence-workflows:create_handoff

# Start of next session
/alien-intelligence-workflows:resume_handoff ai_docs/handoffs/2025-02-16-auth-implementation.md
```

## Configuration
### Prerequisites
The following tools should be installed:
- `git`: Version control
- `glab`: GitLab CLI (for merge requests)
- Node.js / Python / Go (depending on your stack)

### Environment Variables
Commands respect standard environment variables:
- `EDITOR`: Default editor for interactive commands
- `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`: Git configuration

## Updating the Plugin
```bash
# Update to latest version
/plugin update alien-intelligence-workflows

# Or reinstall
/plugin uninstall alien-intelligence-workflows
/plugin install https://github.com/the-alien-club/claude-workflows.git
```

## Contributing
This plugin is maintained by Alien Intelligence for internal use. If you're part of the team:

1. Clone the repo
2. Make changes to skills or agents
3. Test locally with `claude --plugin-dir ./claude-workflows`
4. Create a merge request
5. After merge, team updates with `/plugin update`

## License
MIT License - See [LICENSE](LICENSE) for details.

## Links
- **GitHub**: https://github.com/the-alien-club/claude-workflows
- **Alien Intelligence**: https://alien.club
- **Claude Code Docs**: https://code.claude.com/docs

**Built with ❤️ by Alien Intelligence**

For support or questions, reach out to the engineering team.