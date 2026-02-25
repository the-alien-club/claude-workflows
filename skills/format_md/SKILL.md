---
description: Format any Markdown documentation file to match the project's established style — no blank line between headings and body, bullet points for File/Scope, colon-connected tables, aligned table columns.
---

# Markdown Formatting Guide
You are tasked with reformatting one or more Markdown documentation files to match the project's
established documentation style. Your goal is **not** to change the content — only the formatting.

Read the target file(s) first, then apply every rule below strictly.

## 1. Title and Metadata Block
The `#` title is always on line 1. Bold key-value metadata pairs follow **immediately on the next
line** — no blank line between the title and the metadata block. Each pair is on its own line,
not in a list.

**Correct:**
```md
# Provider Stack
Every context provider wrapping the Workflow Editor, in nesting order (outermost first).
File paths are relative to `packages/frontend/`.
```

```md
# Workflow Editor - System Documentation
**Location**: `packages/frontend/`
**Route**: `/editor/workflows/[workflowId]`
**Last Updated**: 2026-02-23
```

**Incorrect (blank line between title and body):**
```md
# Provider Stack

Every context provider wrapping the Workflow Editor...
```

## 2. Section Headings (`##`, `###`)
Description text starts **immediately on the next line** after any `##` or `###` heading.
No blank line between the heading and the first line of body text. This applies to every heading
level without exception.

**Correct:**
```md
## Purpose
This documentation traces the entire Workflow Editor system...

## Key Design Principles
1. **Provider cascade**: Each layer adds one responsibility...
```

**Incorrect:**
```md
## Purpose

This documentation traces the entire Workflow Editor system...
```

## 3. Numbered Item Sections (`####`)
Used for named items in an ordered list (providers, components, utilities, etc.).

Format:
1. `#### N. \`ItemName\`` heading (backtick-wrap the name; add a qualifier in parentheses if needed)
2. `- **File**: \`path/to/file.tsx\`` — immediately on the next line, no blank line
3. `- **Scope**: short description` or `- **Consumed by**: ComponentA, ComponentB`
4. Blank line
5. Description prose

**Correct:**
```md
#### 1. `ProviderBanners`
- **File**: `components/providers/banners.tsx`
- **Scope**: full editor shell

Manages dismissible banner notifications shown above the nav bar. Exposes
`visibleBanners` (count) so layout components can offset their `top` position.
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

## 4. Tables — Colon Connection
When prose introduces a table, the last sentence of the prose **ends with a colon** and the table
starts **on the very next line** — no blank line in between.

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

## 5. Table Column Alignment
Every column must be padded with spaces so that the `|` pipe characters align vertically across
all rows, including the header and the separator row. Use a monospace mental model: count the
longest cell in each column and pad all other cells to that width with trailing spaces.

The separator row uses `-` characters to match the column width exactly.

**Correct:**
```md
| Exposed value                 | Description                                                                                       |
|-------------------------------|---------------------------------------------------------------------------------------------------|
| `jobs`                        | All jobs for the current workflow                                                                 |
| `currentJob`                  | The selected job (defaults to latest)                                                             |
| `currentJobContext`           | Full execution context for the current job                                                        |
| `currentJobContextHash`       | Hash of `currentJobContext`, used by `useNodeData` to detect when to re-inject results into nodes |
```

**Incorrect (unaligned columns):**
```md
| Exposed value | Description |
|---|---|
| `jobs` | All jobs for the current workflow |
| `currentJobContextHash` | Hash of `currentJobContext`... |
```

For small reference tables (two or three short rows), alignment still applies but tighter widths
are acceptable as long as pipes are vertically aligned.

## 6. Summary / Consumption Tables (No Leading Pipe)
Section-ending summary tables can use a header-row style without leading `|` on data rows.
The separator still uses `|` to divide the two columns. Align with spaces.

**Correct:**
```md
## Context consumption summary
Provider                                    | Primary consumers
--------------------------------------------|--------------------------------------------
ProviderBanners                             | LayoutEditorWorkflow (banner offset)
SidebarProvider                             | EdgeInteractiveAddNode, ControlsEditorWorkflow
```

This style is only used for terminal summary sections. All other tables use the standard
`| col | col |` syntax with leading and trailing pipes.

## 7. Separators — Prohibited Patterns
Never use the following as visual separators between sections or items:
- `---` horizontal rules (thematic breaks) — remove them entirely; heading hierarchy provides structure
- ` - ` (space-dash-space) as an inline separator between two concepts — use a comma, a colon,
  or restructure the sentence instead

**Incorrect:**
```md
## Section A
Content here.

---

## Section B
Content here.
```

**Correct:**
```md
## Section A
Content here.

## Section B
Content here.
```

**Incorrect (inline dash separator):**
```md
Returns the node type - used for icon lookup.
```

**Correct:**
```md
Returns the node type, used for icon lookup.
```

## 8. Code Blocks
Always include a language tag. Use `ts` for TypeScript snippets, `tsx` for JSX/TSX, `md` for
Markdown examples, `json` for JSON. Indentation inside the block must match the source.

```md
```ts
type ResourceViewTarget = {
    type: string | "none"
    id: string | null
}
```
```

## 9. Inline Code
Wrap with backticks:
- File paths: `components/providers/banners.tsx`
- Variable / function / type names: `fullGraphNodes`, `useReactFlow()`
- Specific string values: `"none"`, `"workflow"`
- npm package names: `@xyflow/react`

Do **not** wrap plain English words or prose in backticks. Do not use quotes for code references.

## 10. Bold Text
Use `**bold**` for:
- Key terms being defined for the first time
- Metadata labels (`**File**`, `**Scope**`, `**Location**`)
- `**Correct:**` / `**Incorrect:**` example labels
- Numbered list lead-ins (`1. **Provider cascade**: ...`)

Do not bold entire sentences or arbitrary emphasis.

## 11. Blank Lines — Full Rules Summary
| Situation                                            | Blank line?                            |
|------------------------------------------------------|----------------------------------------|
| Between `#` title and metadata / description         | No                                     |
| Between `##` / `###` heading and first body line     | No                                     |
| Between `####` heading and `- **File**:` bullet      | No                                     |
| Between `- **Scope**:` bullet and description prose  | Yes (one)                              |
| Between prose ending with `:` and a table            | No                                     |
| Between two consecutive `####` sections              | Yes (one)                              |
| Between `##` sections                                | Yes (one)                              |
| Between list items (bullet or numbered)              | No                                     |
| At the end of the file                               | Single trailing newline, no blank line |

## 12. Lists
Use `-` for unordered lists (not `*` or `+`). Numbered lists use `1.`, `2.`, etc.
Do not mix ordered and unordered styles within the same list. Never add blank lines
between list items, even when items contain sub-bullets or multi-line content.

**Incorrect:**
```md
1. Review the changes made during the session
   - Run `git status` to see current changes
   - Run `git diff` to understand the modifications

2. Plan your commits
   - Identify which files belong together
   - Draft clear, descriptive commit messages
```

**Correct:**
```md
1. Review the changes made during the session
   - Run `git status` to see current changes
   - Run `git diff` to understand the modifications
2. Plan your commits
   - Identify which files belong together
   - Draft clear, descriptive commit messages
```

## 13. What NOT to Change
- Do not rewrite, summarize, or extend the content.
- Do not change heading levels (`##` to `###`, etc.) unless they are clearly wrong relative to
  nesting.
- Do not alter code block contents.
- Do not rename identifiers, file paths, or component names.
- Do not add or remove sections.

## 14. Not too much emojis
Use emojis sparingly and only when they add clear value or context. Avoid excessive or irrelevant
emoji use that may distract from the content.
