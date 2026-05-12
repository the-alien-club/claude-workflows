---
description: Format JSDoc comments in backend controllers to match the established style in organization_users_controller.ts — route-first for public handlers, prose-only for private helpers and types.
---

# Backend Controller JSDoc Formatter
You are tasked with formatting JSDoc comments across all controllers in `packages/backend/app/controllers/` to match the established style defined in `organization_users_controller.ts`.

## Reference Style
Study `packages/backend/app/controllers/organization_users_controller.ts` carefully — it is the canonical example.

### Public route handler methods

The JSDoc must open with the HTTP verb and full route path on the **first line**, followed by a plain-prose description on the lines that follow:

```typescript
/**
 * POST /organizations/:organization_id/users
 * Create a user in the enterprise organization. Supports both "human" (managed user)
 * and "client_managed" (service account) types.
 */
async store(ctx: HttpContext) { ... }
```

```typescript
/**
 * DELETE /organizations/:organization_id/users/:user_id/tokens/:token_id
 * Revoke a specific API token for a `client_managed` user.
 */
async destroyToken(ctx: HttpContext) { ... }
```

### Private helper methods

No route line — description only:

```typescript
/**
 * Resolve and validate the :organization_id route param, returning the Organization or an error response.
 */
private async _resolveOrganization({ params }: HttpContext) { ... }
```

### Type definitions

No route line — description only:

```typescript
/**
 * Serialized form of an organization user returned by this controller.
 */
type ManagedUserResponse = { ... }
```

## How to Find Route Mappings
To determine the correct `HTTP_VERB /path` for each public method, read `packages/backend/start/routes.ts`.

Route declarations follow this pattern:

```typescript
router.get("/datasets/:dataset_id", [DatasetsController, "show"])
router.post("/organizations/:organization_id/users", [OrganizationUsersController, "store"])
```

Match each controller method name to its registered route entry. Use the **exact path string** from the routes file, including parameter tokens like `:organization_id`.

For routes registered inside a `router.group()` with a prefix, prepend that prefix to the path. Example: a group with prefix `/api/v1` and a route `/datasets` → full path is `/api/v1/datasets`.

For routes registered with `.resource()`, the conventional mapping is:
- `index` → `GET /resource`
- `store` → `POST /resource`
- `show` → `GET /resource/:id`
- `update` → `PUT /resource/:id` or `PATCH /resource/:id`
- `destroy` → `DELETE /resource/:id`

## Comment Style Rules
Apply the following rules from the project's comment style guide (see `.claude/commands/format_comments.md` for the full reference):

1. **Natural prose only** — no bullet points or dash-separated lists inside JSDoc
2. **Always end with a period** — every JSDoc block must close with a period
3. **Backticks for code references** — wrap class names, method names, types, and identifiers in backticks inside JSDoc (e.g. `` `client_managed` ``, `` `HttpContext` ``)
4. **No emojis**
5. **"Note:" / "Notes:" for side information** — use a blank line before the note block
6. **Replace " - " with ", "** — use commas, not dashes, to chain clauses
7. **Capitalize only the first word** of the description (after the route line if present)
8. **Remove AI slop** — strip "Step X" markers, `---- comment ----` dividers, and redundant phrasing

## Scope
**Default scope**: Format only controllers that have been modified in the last 16 commits (use `git log --name-only -16` to find them). Ask the user if they want to expand this to all controllers.

**Per-file process**:
1. Read the controller file
2. Read `packages/backend/start/routes.ts` (once, cache in memory)
3. For each JSDoc block:
   - If it belongs to a public method with a registered route: ensure the first line is `HTTP_VERB /path`, then rewrite the description to follow the style rules
   - If it belongs to a private method or a type: ensure it is description-only, rewrite to follow the style rules
   - If a public method has **no JSDoc at all**: add one with the route line and a brief description inferred from the method name and body
4. Edit the file with the minimal diff — do not touch code, only JSDoc blocks
5. After editing, verify no JSDoc block is missing a trailing period

## Output
After processing, report:
- Which files were changed
- How many JSDoc blocks were added or modified per file
- Any public methods where the route could not be found in `routes.ts` (flag these for manual review)
