---
description: Review recently changed frontend files against the frontend STYLE.md and report (or fix) violations.
---

# Frontend Style Review
You are tasked with auditing frontend code against the project's official style guide located at
`packages/frontend/STYLE.md`. Read that file first and keep it as your authoritative reference
throughout this task.

**IMPORTANT**: Use the Git history (last 20 commits) to identify which frontend files were recently
modified. Only review those files — do not scan the entire codebase.

Limit your scope to files inside `packages/frontend/`.

## What to check
Go through each recently changed `.tsx` and `.ts` file and verify the rules below.
For each violation, report the **file path**, **line number**, and a **short description** of what
is wrong and what it should be instead.

### 1. Component file rules
- Each `.tsx` file must export **exactly one** `export default` component.
- Helper functions, display mappings, and lookup tables must live in `lib/utils/` or `config/` —
  **never** defined inline inside a component file.
- Sub-components must have their **own file** inside a folder alongside `index.tsx` — they must not
  be defined inside the parent component's file.
- Props type must be defined **before** the component function.
- Props must always be **destructured** in the function signature.
- Event handler names must be prefixed with `handle` (e.g. `handleClick`, `handleSubmit`).
- Boolean prop names must be prefixed with `is`, `has`, or `should`.
- Callback prop names must be prefixed with `on`.

### 2. Naming conventions
- Component names must reflect their full folder path in PascalCase (e.g.
  `components/sheets/clusters/entries/details/fileRow.tsx` → `SheetsClustersEntryDetailsFileRow`).
  Exception: `components/ui/` components use plain names (e.g. `Button`, `Badge`).
- Form components: `Form` + Entity + Action (e.g. `FormOrganizationCreate`).
- Dialog components: Action + Entity + `Dialog` (e.g. `CreateFlowDialog`).
- Card components: Entity + `Card` (e.g. `FlowCard`).
- Complex components (more than one file): must use a folder with `index.tsx` as the main component.
- Simple components: single file with kebab-case filename and PascalCase export.

### 3. Query functions (`queries/` directory)
- Must be async functions named with: verb + entity + optional `ById`/`BySlug`/`ByEntityId`.
- Must be documented with a JSDoc comment covering purpose, params, and return value.
- Must wrap the Tuyau call in `try-catch`.
- Must log errors with `console.warn` and a descriptive message.
- Must return `null` on error (not `undefined`).
- Must call `.unwrap()` on Tuyau responses.
- Must check `response.success` before returning data.

### 4. TanStack Query hooks (`hooks/api/` directory)
- Hook files must start with `"use client"`.
- Each hook must have a JSDoc comment.
- Query hooks must use the `enabled` option to guard against missing auth/org dependencies.
- Query keys must use array format: `["entity"]`, `["entity", id]`, etc.
- Must spread `...queryConfig` for consistent defaults.
- Mutation hooks must invalidate related queries in `onSuccess`.

### 5. `"use client"` directive
- Only add `"use client"` when the component needs interactivity, hooks, or browser APIs.
- Server Components must have **no** `"use client"` directive.

## Output format
Group findings by file. For each file list the violations as a numbered list. If a file has no
violations, skip it. At the end, give a short summary of how many files were checked and how many
had violations.

Example:

```
packages/frontend/components/dialogs/flows/create/index.tsx
  1. Line 12: Inline helper function `formatLabel` defined inside component file — move to `lib/utils/`.
  2. Line 34: Sub-component `FlowStepPanel` defined inside this file — extract to a separate file in this folder.

packages/frontend/hooks/api/useFlows.tsx
  1. Line 1: Missing "use client" directive at the top of the hook file.

---
Checked 8 files — 2 had violations.
```

## Optional: fix mode
If the user's message contains the word **fix** (e.g. `/review_frontend_style fix`), apply the
fixes directly instead of just reporting them. For each fix:
- Move inline helpers/sub-components to the correct location.
- Add missing directives or JSDoc comments.
- Rename exports that don't match the naming convention.

Confirm each fix with a one-line summary after applying it.
