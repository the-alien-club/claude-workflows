---
name: add_playbook_rule
description: "Interactively add a new architectural rule to a repo's playbook directory. Guides the user through defining the rule, forbidden patterns, and examples, then writes a properly-formatted .md file into the playbook."
user-invocable: true
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# Add Playbook Rule

A playbook is a directory of `.md` files, one per architectural rule. This skill guides the user through authoring a new rule and writes it to the correct playbook directory.

---

## Step 1 — Find the Target Playbook

```bash
find . -type d -name playbook | grep -v node_modules | grep -v .git
```

If multiple, ask the user which one. If none, ask for the path.

---

## Step 2 — Check for Duplicates

Read all existing `.md` files (first 20 lines each) to understand current coverage. If the user's rule is already covered, name the file and ask whether they want to extend it or add a distinct complementary rule.

---

## Step 3 — Elicit the Rule

Use `AskUserQuestion` to collect:

1. **Rule name** — slug, kebab-case, used as filename (e.g. `error-handling`, `service-boundaries`)
2. **The rule in one sentence** — what must always be true?
3. **The motivation** — what breaks when it is violated? Name the failure mode.
4. **A correct example** — code showing the rule followed
5. **A forbidden example** — code showing the violation, with the specific problem annotated

If the user gives a vague rule, ask for a concrete forbidden pattern first — that surfaces the real constraint.

---

## Step 4 — Draft the Rule File

Structure:

```markdown
# [Title] Rule

## Rule

[One-paragraph statement. Direct, no hedging. State what is forbidden.
Name the consequence — not a style issue, a correctness/security/maintainability issue.]

---

## Why

[2–4 sentences: what breaks when this rule is violated. Be specific — name the failure mode.]

---

## Correct Pattern

```[lang]
// ✅ [Short description]
[code example]
```

---

## Forbidden Patterns

```[lang]
// ❌ [Violation description] — [specific harm]
[code example]
```

---

## Rules Summary

- [Bullet: precise, imperative]
- [...]

---

## Relation to Other Rules

[Optional cross-references to other playbook files.]
```

**Quality checks before writing:**
- No weasel words ("try to", "prefer", "consider")
- Every forbidden pattern has a named harm — not "messy" or "unclear"
- The rule is falsifiable — a reviewer can determine pass/fail without judgment calls
- Correct pattern is valid syntax
- File is between 40 and 200 lines

If any check fails, iterate with the user.

---

## Step 5 — Confirm and Write

Show the full draft. Once approved, write to `[playbook-path]/[rule-name].md`.

Confirm with the exact path written, then:

> Rule added. Run `/review_playbook` on any commit or MR to enforce it.