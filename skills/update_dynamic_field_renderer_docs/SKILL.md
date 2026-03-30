---
description: "Review the dynamic field renderer documentation suite (docs/dynamic-field-renderer/) against recent git history and update any stale content, applying the project's Markdown formatting rules inline while editing."
---

# Dynamic Field Renderer Docs Update
You are tasked with reviewing the dynamic field renderer documentation suite and bringing it in sync with the current codebase. Apply the project's Markdown formatting rules **inline while you edit** each file — do not invoke `/format_md` at the end. Read the formatting rules below and treat them as hard constraints on every write you make.

ARGUMENTS: an optional free-text note about what changed (used to narrow the git diff review). If no argument is given, inspect recent commits automatically.

## Step 1: Identify what changed
Run `git log --oneline -20` to see recent commits. To find all commits that ever touched the dynamic field renderer, run:
```
git log --oneline --all -- "packages/frontend/components/ui/dynamic-field-renderer" "packages/frontend/config/dynamicFieldRenderer.ts"
```
For each commit that post-dates the last docs update, run `git show <hash> --stat` then `git show <hash>` (or `git diff <hash>^ <hash> -- <path>` for large commits) to read the actual diff.

Focus on changes that affect:
- Leaf renderer components (string, number, boolean, enum, expression, json, default)
- The dispatch layer (`FieldRendererInput` / `field/input.tsx`)
- Field-level wrapper and Controller logic (`FieldRenderer` / `field/index.tsx`)
- `FieldRendererContent` (`field/content.tsx`) — type resolution, null/value fallback logic
- Control components (`field/controls/`) — expression trigger, use-as-input, additional-property controls
- `FieldInputWithControls` (`field-input-with-controls.tsx`)
- `EmptyPropertySet` (`empty-property-set.tsx`)
- `DynamicFieldRenderer` entry point (`index.tsx`)
- Config (`config/dynamicFieldRenderer.ts`)
- Shared types: `RendererField`, `FieldRenderState`, `InputNodeIntegration`, `DynamicFieldCallbacks`, `NodeDataParam`
- Archived renderers moved to or from `archives/`

## Step 2: Find the last docs update date
Run `git log --oneline -- "docs/dynamic-field-renderer/"` to see the most recent commit that touched the docs. Only commits **after** that date need to be reviewed for documentation drift.

## Step 3: Read the documentation files
Read all three files in `docs/dynamic-field-renderer/`:
- `README.md`
- `CONTROLS.md`
- `RENDERERS.md`

## Step 4: Cross-reference and plan edits
For each documented item that was touched by a post-docs commit, note:
- What the doc currently says
- What the code now says
- The minimal edit needed to make the doc accurate

Common drift patterns in this codebase:
- Renderer scope changes (e.g. a new type added to a `case` block)
- New props added to a type definition
- Behaviour changes in `onChange` / value resolution logic
- New renderer options (e.g. new Select items in additional-property controls)
- Components moved to or from `archives/`
- New control components added to `FieldRendererContent`

## Step 5: Apply edits
Edit each file that needs updating. For every edit you make, simultaneously enforce all formatting rules listed in the **Formatting Rules** section below. You do not need to reformat content you did not change, but any line you touch must comply.

## Step 6: Verify
Re-read each file you edited and confirm:
- No stale type names, function names, renderer scopes, or prop signatures remain
- Every table you wrote or modified has aligned columns
- No blank line appears between a heading and the first body line
- No blank line appears between prose ending in `:` and its table

---

## Formatting Rules
Apply these rules to every line you write or modify. They match the project's established documentation style exactly.

### 1. Title and Metadata Block
The `#` title is always on line 1. Bold key-value metadata pairs follow **immediately on the next line**, with no blank line between the title and the metadata block. Each pair is on its own line, not in a list.

**Correct:**
```md
# Dynamic Field Renderer
**Location**: `packages/frontend/components/ui/dynamic-field-renderer/`
**Purpose**: Renders a complete form from a `JSONSchema7` schema.
```

**Incorrect (blank line between title and body):**
```md
# Dynamic Field Renderer

**Location**: `packages/frontend/components/ui/dynamic-field-renderer/`
```

### 2. Section Headings (`##`, `###`)
Description text starts **immediately on the next line** after any `##` or `###` heading. No blank line between the heading and the first line of body text.

**Correct:**
```md
## Dispatch: FieldRendererInput
`FieldRendererInput` sits between `FieldRendererContent` and the leaf renderers...
```

**Incorrect:**
```md
## Dispatch: FieldRendererInput

`FieldRendererInput` sits between...
```

### 3. Numbered Item Sections (`####`)
Used for named items in an ordered list (components, controls, renderers, etc.).

Format:
1. `#### N. \`ComponentName\`` heading (backtick-wrap the name)
2. `- **File**: \`path/to/file.tsx\`` immediately on the next line, no blank line
3. `- **Scope**: short description`
4. Blank line
5. Description prose

**Correct:**
```md
#### 1. `FieldRendererString`
- **File**: `renderers/string.tsx`
- **Scope**: `type === "string"`

Renders a standard `Input`.
```

**Incorrect (blank line before bullets, or missing blank line before prose):**
```md
#### 1. `FieldRendererString`

- **File**: `renderers/string.tsx`
- **Scope**: `type === "string"`
Renders a standard `Input`.
```

### 4. Tables: Colon Connection
When prose introduces a table, the last sentence of the prose **ends with a colon** and the table starts **on the very next line**, with no blank line in between.

**Correct:**
```md
`DynamicFieldRenderer` accepts:
| Prop      | Type           | Required | Description |
|-----------|----------------|----------|-------------|
| `control` | `Control<any>` | Yes      | ...         |
```

**Incorrect (blank line between intro and table):**
```md
`DynamicFieldRenderer` accepts:

| Prop      | Type           |
```

### 5. Table Column Alignment
Every column must be padded with spaces so that the `|` pipe characters align vertically across all rows, including the header and the separator row. Count the longest cell in each column and pad all other cells to that width with trailing spaces.

The separator row uses `-` characters to match the column width exactly. No spaces between pipes and dashes: `|---|` not `| --- |`.

### 6. Summary / Consumption Tables (No Leading Pipe)
Section-ending summary tables can use a header-row style without leading `|` on data rows. The separator still uses `|` to divide columns. Align with spaces.

This style is only used for terminal summary sections. All other tables use the standard `| col | col |` syntax.

### 7. Separators: Prohibited Patterns
Never use the following as visual separators:
- `---` horizontal rules: remove them entirely
- ` - ` (space-dash-space) as an inline separator: use a comma or colon instead
- ` — ` (em dash with spaces) as an inline separator: use a comma or colon instead

### 8. Code Blocks
Always include a language tag. Use `ts` for TypeScript, `tsx` for JSX/TSX, `md` for Markdown examples, `json` for JSON.

### 9. Inline Code
Wrap with backticks:
- File paths: `renderers/number.tsx`
- Variable / function / type names: `FieldRenderState`, `onChange`
- Specific string values: `"number"`, `"integer"`
- npm package names: `react-hook-form`

Do **not** wrap plain English words or prose in backticks.

### 10. Bold Text
Use `**bold**` for:
- Key terms being defined for the first time
- Metadata labels (`**File**`, `**Scope**`, `**Location**`)
- Numbered list lead-ins

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

### 13. What NOT to Change
- Do not rewrite, summarize, or extend the content.
- Do not change heading levels unless they are clearly wrong.
- Do not alter code block contents.
- Do not rename identifiers, file paths, or component names.
- Do not add or remove sections.
