---
description: Generate the weekly C-level wrap-up for Adrien (to be handed to Leo), based on recent git commits and codebase context. Produces two versions of the four-column report: one technical for Leo, one non-technical for the CEO and non-tech stakeholders.
---

# Weekly Wrap-up Generator
You are tasked with generating Adrien's weekly contribution to Leo's C-level wrap-up report.
This report feeds directly into the Master Sheet used for investor and board-level steering.

## Context
- **Author**: Adrien (yoratoni), reports to Leo, who submits the combined wrap-up
- **Audience**: two distinct readers, Leo (technical, CTO level) and the CEO + non-tech stakeholders
- **Language**: French
- **Anti-pattern**: "J'ai travaillé sur X cette semaine" is explicitly called out as a failed
  report. The goal is risk/impact analysis, not a task log.

## Step 1: Gather data
Run the following in parallel:
1. `git log --author="yoratoni" --since="8 days ago" --oneline --all` to get the week's commits
2. `git show <sha> --stat` for the 3-5 most significant commits to understand scope and changed
   systems, not to count files
3. Read `ai_docs/workflow_editor/README.md` for the Known Gaps / TODOs table
4. Read any other `ai_docs/` files that are directly relevant to the commits found

Do not skip steps 3 and 4: the complexity and risk analysis must be grounded in actual
architectural constraints, not generic statements.

## Step 2: Synthesise
Before writing, answer these questions internally:
- What was the underlying engineering problem being solved this week (not the surface task)?
- What does it unblock for the product, and what does it still leave blocked?
- What concrete business or product risk exists if this work is delayed or incomplete?
- What is the developer experience or team velocity impact of this work?
- Is there a dependency on another team member or an external decision?
- Does this work affect what can be shown in a fundraising demo?

Never mention file counts, line counts, or any raw git statistics in the output. Scope is
communicated through the systems and layers affected, not through numbers.

## Step 3: Write the two versions
Output the report in two clearly separated blocks, each containing the same four columns.
Use `# Version Leo (technique)` and `# Version CEO (non-technique)` as top-level headings.

### Version Leo (technique)
Written for a technical reader. Uses engineering vocabulary freely. For each deliverable:
- Lead with the structural or architectural problem that was solved, not the implementation
- Explain WHY it matters: what it unblocks, what risk it removes, what it enables for the team
  (e.g., a documentation effort is not "we wrote docs" but "we eliminated a bus-factor risk,
  reduced onboarding time, and created a shared reference that cuts debugging cycles")
- Reference specific known gaps or TODOs when they are relevant to the risk assessment
- Be honest: if a feature is partially implemented, name the gap and its consequence

### Version CEO (non-technique)
Written for a non-technical reader. No code names, no architecture jargon. For each deliverable:
- Translate the engineering work into product capability or business outcome
  (e.g., "the workflow editor is now more reliable and easier to extend" rather than
  "we unified the node schema types")
- Business value must be explicit: time saved, risk reduced, demo capability improved,
  investor confidence increased, etc.
- Risks and blockers must be expressed in terms of product delivery or demo readiness,
  not technical debt
- Keep sentences short and direct

## The four columns (apply to both versions)
### Avancement & KPI
Describe what was achieved and why it matters. Group related commits into a single deliverable.
3-5 sentences per deliverable maximum.

### Alerte / Risque stratégique
The most important column. It must explain:
- WHY the current chantier is taking the time it takes (real constraints, not excuses)
- What specific gaps remain and what happens if they stay unresolved
- What could go wrong and under what condition it becomes a blocker
- In the CEO version, frame every risk in terms of product or fundraising impact

### Impact Levée de Fonds
Answer: does this work affect what can be demoed or what a technical investor will evaluate?
- If yes: explain how it improves or de-risks the demo or due diligence
- If no: explain why the work is still necessary (stability, velocity, onboarding)
- Keep it short: 2-4 sentences

### Focus Semaine Prochaine / Call for Help or Collaboration
- State the top 1-2 priorities for next week and what they unblock
- Call out any dependency on Leo, another team member, or an external decision explicitly
- If a demo date or external deadline is known, reference it

## Format rules
- Write in French throughout
- No `---` horizontal rules between sections
- Use `-` bullet lists, not `*` or `+`
- Bold only key terms or labels, not full sentences
- Do not add a preamble before the first version heading
- Do not add a closing remark or sign-off after the last section
- Each column heading is `## <column name>` with no blank line before the first line of content
