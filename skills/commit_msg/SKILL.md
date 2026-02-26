---
description: Create git commit messages with user approval and no Claude attribution
---

# Commit Changes
You are tasked with creating git commit messages for the changes made during this session.

## Process:
1. **Think about what changed:**
   - Review the conversation history and understand what was accomplished
   - Run `git status` to see current changes
   - Run `git diff` to understand the modifications
   - Consider whether changes should be one commit or multiple logical commits
2. **Plan your commit(s):**
   - Identify which files belong together
   - Draft clear, descriptive commit messages
   - Use imperative mood in commit messages
   - Focus on why the changes were made, not just what
3. **Return the commit message(s) to the user:**
   - List the files that belong to each commit
   - Provide the commit message(s) you drafted
   - **Do NOT execute git commands** - the user will handle the commit themselves

## Important:
- **NEVER add co-author information or Claude attribution**
- Commits should be authored solely by the user
- Do not include any "Generated with Claude" messages
- Do not add "Co-Authored-By" lines
- Write commit messages as if the user wrote them
- **Conventional commit titles must be lowercase**: the first line (type and description) should always use lowercase letters (e.g., `feat: add new feature` not `feat: Add new feature`)
- Commit description should be in the past tense (e.g., `Introduced` instead of `Introduce`)

## Remember:
- You have the full context of what was done in this session
- Group related changes together
- Keep commits focused and atomic when possible
- The user trusts your judgment, they asked you to create a git commit message that reflects the changes made during this session
