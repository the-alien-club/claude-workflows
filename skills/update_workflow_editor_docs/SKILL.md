---
description: "Review the workflow editor documentation suite (docs/workflow-editor/) against recent git history and update any stale content, applying the project's Markdown formatting rules inline while editing."
---

# Workflow Editor Docs Update
You are tasked with reviewing the workflow editor documentation suite and bringing it in sync with the current codebase. Apply the project's Markdown formatting rules **inline while you edit** each file — do not invoke `/format_md` at the end. Read the formatting rules below and treat them as hard constraints on every write you make.

ARGUMENTS: an optional free-text note about what changed (used to narrow the git diff review). If no argument is given, inspect recent commits automatically.

## Step 1: Identify what changed
Run `git log --oneline -20` to see recent commits. For each commit that touches `packages/frontend/` or `packages/backend/shared/`, run `git show <hash> --stat` and then `git show <hash>` (or `git diff <hash>^ <hash> -- <path>` for large commits) to read the actual diff.

Focus on changes that affect:
- Node types, node components, or node data shapes
- Edge / handle types or handle enums
- Provider names, context values, or provider nesting
- Config objects (e.g. `WORKFLOWS_CONFIG`, `EDITOR_CONFIG`, `REACT_FLOW_CONFIG`)
- Utility / helper function signatures or names
- Hook names or return values
- New UI components added to the editor shell

## Step 2: Read the documentation files
Read all eight files in `docs/workflow-editor/`:
- `README.md`
- `01-provider-stack.md`
- `02-graph-model.md`
- `03-ui-components.md`
- `04-data-flow.md`
- `05-node-interactions.md`
- `06-expressions.md`
- `07-utilities.md`

## Step 3: Cross-reference and plan edits
For each documented item that was touched by a recent commit, note:
- What the doc currently says
- What the code now says
- The minimal edit needed to make the doc accurate

Also check the Known Gaps table in `README.md` — if a gap has been resolved in code, remove that row. If a new gap is introduced, add a row.

## Step 4: Apply edits
Edit each file that needs updating. For every edit you make, simultaneously enforce all formatting rules listed in the **Formatting Rules** section below. You do not need to reformat content you did not change, but any line you touch must comply.

After all content edits are complete, update the `**Last Updated**` date in `README.md` to today's date.

## Step 5: Verify
Re-read each file you edited and confirm:
- No stale identifiers, config names, function names, or type names remain
- Every table you wrote or modified has aligned columns
- No blank line appears between a heading and the first body line
- No blank line appears between prose ending in `:` and its table

## Formatting Rules
Apply these rules to every line you write or modify. They match the project's established documentation style exactly.

### 1. Title and Metadata Block
The `#` title is always on line 1. Bold key-value metadata pairs follow **immediately on the next line**, with no blank line between the title and the metadata block. Each pair is on its own line, not in a list.

**Correct:**
```md
# Workflow Editor - System Documentation
**Location**: `packages/frontend/`
**Route**: `/editor/workflows/[workflowId]`
**Last Updated**: 2026-03-30
```

**Incorrect (blank line between title and body):**
```md
# Workflow Editor - System Documentation

**Location**: `packages/frontend/`
```

### 2. Section Headings (`##`, `###`)
Description text starts **immediately on the next line** after any `##` or `###` heading. No blank line between the heading and the first line of body text.

**Correct:**
```md
## Purpose
This documentation traces the entire Workflow Editor system...
```

**Incorrect:**
```md
## Purpose

This documentation traces the entire Workflow Editor system...
```

### 3. Numbered Item Sections (`####`)
Used for named items in an ordered list (providers, components, utilities, etc.).

Format:
1. `#### N. \`ItemName\`` heading (backtick-wrap the name; add a qualifier in parentheses if needed)
2. `- **File**: \`path/to/file.tsx\`` immediately on the next line, no blank line
3. `- **Scope**: short description` or `- **Consumed by**: ComponentA, ComponentB`
4. Blank line
5. Description prose

**Correct:**
```md
#### 1. `ProviderBanners`
- **File**: `components/providers/banners.tsx`
- **Scope**: full editor shell

Manages dismissible banner notifications shown above the nav bar.
```

**Incorrect (blank line before bullets, or missing blank line before prose):**
```md
#### 1. `ProviderBanners`

- **File**: `components/providers/banners.tsx`
- **Scope**: full editor shell
Manages dismissible banner notifications...
```

Sub-sections within a `####` block use `#####`:
```md
##### `ResourceViewTarget`
```ts
type ResourceViewTarget = { ... }
```
```

### 4. Tables: Colon Connection
When prose introduces a table, the last sentence of the prose **ends with a colon** and the table starts **on the very next line**, with no blank line in between.

**Correct:**
```md
Manages the job (run) lifecycle for the current resource:
| Exposed value   | Description                       |
|-----------------|-----------------------------------|
| `jobs`          | All jobs for the current workflow |
```

**Incorrect (blank line between intro and table):**
```md
Manages the job (run) lifecycle for the current resource:

| Exposed value   | Description                       |
```

### 5. Table Column Alignment
Every column must be padded with spaces so that the `|` pipe characters align vertically across all rows, including the header and the separator row. Count the longest cell in each column and pad all other cells to that width with trailing spaces.

The separator row uses `-` characters to match the column width exactly. No spaces between pipes and dashes: `|---|` not `| --- |`.

**Correct:**
```md
| Exposed value           | Description                                     |
|-------------------------|-------------------------------------------------|
| `jobs`                  | All jobs for the current workflow               |
| `currentJobContextHash` | Hash used by `useNodeData` to detect re-renders |
```

**Incorrect (unaligned, spaced separator):**
```md
| Exposed value | Description |
| --- | --- |
| `jobs` | All jobs |
```

### 6. Summary / Consumption Tables (No Leading Pipe)
Section-ending summary tables can use a header-row style without leading `|` on data rows. The separator still uses `|` to divide the two columns. Align with spaces.

**Correct:**
```md
## Context consumption summary
Provider                                    | Primary consumers
--------------------------------------------|--------------------------------------------
ProviderBanners                             | LayoutEditorWorkflow (banner offset)
```

This style is only used for terminal summary sections. All other tables use the standard `| col | col |` syntax with leading and trailing pipes.

### 7. Separators: Prohibited Patterns
Never use the following as visual separators:
- `---` horizontal rules: remove them entirely
- ` - ` (space-dash-space) as an inline separator: use a comma or colon instead
- ` — ` (em dash with spaces) as an inline separator: use a comma or colon instead

**Incorrect:**
```md
## Section A
Content here.

---

## Section B
```

**Correct:**
```md
## Section A
Content here.

## Section B
```

### 8. Code Blocks
Always include a language tag. Use `ts` for TypeScript, `tsx` for JSX/TSX, `md` for Markdown examples, `json` for JSON. Indentation inside the block must match the source.

### 9. Inline Code
Wrap with backticks:
- File paths: `components/providers/banners.tsx`
- Variable / function / type names: `fullGraphNodes`, `useReactFlow()`
- Specific string values: `"none"`, `"workflow"`
- npm package names: `@xyflow/react`

Do **not** wrap plain English words or prose in backticks.

### 10. Bold Text
Use `**bold**` for:
- Key terms being defined for the first time
- Metadata labels (`**File**`, `**Scope**`, `**Location**`)
- Numbered list lead-ins (`1. **Provider cascade**: ...`)

Do not bold entire sentences or arbitrary emphasis.

### 11. Blank Lines: Full Rules Summary
| Situation                                            | Blank line? |
|------------------------------------------------------|-------------|
| Between `#` title and metadata / description         | No          |
| Between `##` / `###` heading and first body line     | No          |
| Between `####` heading and `- **File**:` bullet      | No          |
| Between `- **Scope**:` bullet and description prose  | Yes (one)   |
| Between prose ending with `:` and a table            | No          |
| Between two consecutive `####` sections              | Yes (one)   |
| Between `##` sections                                | Yes (one)   |
| Between list items (bullet or numbered)              | No          |
| At the end of the file                               | Yes         |

### 12. Lists
Use `-` for unordered lists (not `*` or `+`). Numbered lists use `1.`, `2.`, etc. Never add blank lines between list items, even when items contain sub-bullets.

**Incorrect:**
```md
1. First item
   - sub-bullet

2. Second item
```

**Correct:**
```md
1. First item
   - sub-bullet
2. Second item
```

### 13. What NOT to Change
- Do not rewrite, summarize, or extend the content.
- Do not change heading levels unless they are clearly wrong.
- Do not alter code block contents.
- Do not rename identifiers, file paths, or component names.
- Do not add or remove sections.
