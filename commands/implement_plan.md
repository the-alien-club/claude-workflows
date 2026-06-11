---
description: Implement technical plans from ai-memories/tech/ plans with verification
---

# Implement Plan

You are tasked with implementing an approved technical plan from `ai-memories/tech/`. These plans contain phases with specific changes and success criteria.

## Getting Started

### Step 0: Read the guidelines

If there is a style.md file read it, and if there is a playbook read it before writing any code. This will avoid long and painful loop at the end when commiting and the code review comes back negative.

### Step 1: Branch Setup

Before touching any code, verify and set up the feature branch:

```bash
git branch --show-current
```

**If the current branch is a feature branch** (i.e. starts with `feature/`, `fix/`, or `refactor/`):
- **STOP immediately**
- Inform the user:
  ```
  ⚠️ Already on feature branch: [branch-name]

  This branch may have active work from a previous session or another contributor.
  I will not proceed automatically to avoid overwriting in-progress work.

  Please confirm:
  1. This is the correct branch for this plan and I should continue here
  2. I should create a new branch instead (provide the name)
  ```
- Wait for explicit user confirmation before continuing.

**If the current branch is `dev`, `main`, or `master`**:
```bash
git checkout dev   # or main if dev doesn't exist
git pull
git checkout -b feature/[feature-name-derived-from-plan]
```

Use the plan's ai-memories/tech/ folder name or the feature name from the plan title to derive the branch name (kebab-case, 2-4 words, e.g. `feature/add-mtls-auth`).

Confirm the branch was created, then proceed.

### Step 2: Load the Plan

When given a plan path:
- Read the plan completely and check for any existing checkmarks (- [x])
- Read the original ticket and all files mentioned in the plan
- **Read files fully** - never use limit/offset parameters, you need complete context
- Think deeply about how the pieces fit together
- Create a todo list to track your progress
- Start implementing if you understand what needs to be done

If no plan path provided, ask for one.

## Implementation Philosophy

Plans are carefully designed, but reality can be messy. Your job is to:
- Follow the plan's intent while adapting to what you find
- Implement each phase fully before moving to the next
- Verify your work makes sense in the broader codebase context
- Update checkboxes in the plan as you complete sections

When things don't match the plan exactly, think about why and communicate clearly. The plan is your guide, but your judgment matters too.

If you encounter a mismatch:
- STOP and think deeply about why the plan can't be followed
- Present the issue clearly:
  ```
  Issue in Phase [N]:
  Expected: [what the plan says]
  Found: [actual situation]
  Why this matters: [explanation]

  How should I proceed?
  ```

## Committing Changes

**Use the `/commit` slash command for all commits during implementation:**

```bash
/commit
```

**When to commit:**
- After completing each logical unit of work
- After each phase completes successfully
- After fixing tests or linting issues
- Before moving to the next phase
- Regularly to avoid losing work

**The `/commit` command will**:
- Review all staged and unstaged changes
- Generate conventional commit message scoped by component
- Follow the format: `feat(backend): add feature` or `fix(workers): resolve issue`
- Create atomic commits with clear descriptions

**Do NOT**:
- ❌ Create commits manually with `git commit -m`
- ❌ Use generic messages like "wip" or "fix"
- ❌ Commit large batches of unrelated changes
- ✅ Use `/commit` for all commits during implementation

## Verification Approach

After implementing a phase:
- Run the success criteria checks (usually `make check test` covers everything)
- Fix any issues before proceeding
- **Commit your changes** using `/commit`
- Update your progress in both the plan and your todos
- Check off completed items in the plan file itself using Edit
- **Pause for human verification**: After completing all automated verification for a phase, pause and inform the human that the phase is ready for manual testing. Use this format:
  ```
  Phase [N] Complete - Ready for Manual Verification

  Automated verification passed:
  - [List automated checks that passed]

  Please perform the manual verification steps listed in the plan:
  - [List manual verification items from the plan]

  Let me know when manual testing is complete so I can proceed to Phase [N+1].
  ```

If instructed to execute multiple phases consecutively, skip the pause until the last phase. Otherwise, assume you are just doing one phase.

do not check off items in the manual testing steps until confirmed by the user.


## If You Get Stuck

When something isn't working as expected:
- First, make sure you've read and understood all the relevant code
- Consider if the codebase has evolved since the plan was written
- Present the mismatch clearly and ask for guidance

Use sub-tasks sparingly - mainly for targeted debugging or exploring unfamiliar territory.

## Resuming Work

If the plan has existing checkmarks:
- Trust that completed work is done
- Pick up from the first unchecked item
- Verify previous work only if something seems off

Remember: You're implementing a solution, not just checking boxes. Keep the end goal in mind and maintain forward momentum.
