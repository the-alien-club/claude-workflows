---
description: This document defines the natural comment style used throughout the codebase and allow the user to format comments consistently.
---

# Comment Style Guide

You are tasked with ensuring that all comments in the codebase adhere to the defined style guide.

This document defines the natural comment style used throughout the codebase,
its goal is not really to modify the content of the comments but to reformat them in order
for them to follow the original style (before-AI).

**IMPORTANT**: You should first use the Git history (last 16 commits for example) of this repository
in order to only change the latest files and not have to go through the entire codebase.

## JSDoc Comments

### Principles

1. **Use natural prose** - Write comments as flowing sentences, not bullet points
2. **Replace " - " with ", "** - Use commas instead of dashes, with lowercase after the comma
3. **Break long lines naturally** - Split descriptions across multiple lines where it reads well
4. **Use "Note:" for single notes** - Capitalize "Note:" as it starts a new sentence
5. **Use "Notes:" for multiple notes** - Keep it plural when there are multiple points
6. **Always end with a period** - Multi-line comments (/** */) should end with proper punctuation
7. **No emojis** - Never use emojis in comments (exception: UI components displaying emojis)

### Examples

#### Before (avoid)

```typescript
/**
 * Validator for chart version update endpoint.
 * Used to update the Helm chart version for a cluster's tenant.
 *
 * SECURITY: Validates semantic versioning to prevent invalid chart versions.
 */

/**
 * Get user profile
 * - Fetches the user profile from the database
 * - Returns formatted user data
 * - Requires authentication
 */
```

#### After (preferred)

```typescript
/**
 * Validator for chart version update endpoint, used to update the Helm
 * chart version for a cluster's tenant.
 *
 * Note: Validates semantic versioning to prevent invalid chart versions.
 */

/**
 * Get user profile from the database and return formatted user data.
 *
 * Note: Requires authentication.
 */
```

### More Examples

```typescript
/**
 * Get all licenses, with the option to only show the user's registered licenses
 * or the verified ones.
 */

/**
 * Get all licenses with the option to filter by organization ID.
 *
 * Note: This route is only accessible by admins in order to get ALL data.
 */

/**
 * The returned formatted license type.
 */
```

### More Examples from nodes_controller.ts

```typescript
/**
 * Get all the enabled (and for streaming only) registered nodes with the option to filter by category.
 */

/**
 * Get node by ID or by slug.
 */

/**
 * Get a list of nodes by IDs or by slugs.
 */

/**
 * Add one or multiple category tags to a node.
 *
 * Note: This route is only accessible by admins.
 */

/**
 * Remove one or multiple category tags from a node.
 *
 * Note: This route is only accessible by admins.
 */

/**
 * Sync (create or update) a node definition.
 *
 * Note: This route is only accessible via service-to-service calls (XFCC auth),
 * used by workers to seed node definitions from the NODE_MAPPING.
 */
```

## Inline Comments

### Principles

1. **Start with uppercase** - First letter should be capitalized (like a sentence)
2. **Keep them concise** - One line when possible
3. **Be descriptive** - Explain the "why", not the obvious "what"
4. **Never end with a period** - Single-line comments (starting with //) should not have end punctuation
5. **No emojis** - Never use emojis in comments (exception: UI components displaying emojis)
6. **TODOs use uppercase** - Format: `// TODO: description`
7. **Don't change good comments** - Comments that are already clear and follow the format (like "// Relationships" or "// Many-to-many relationship with the `tags` table") should be left as-is

### Examples

#### Before (avoid)

```typescript
// Check If License Exists
const license = await License.find(id)

// Default To All Licenses
licenses = await License.query()
```

#### After (preferred)

```typescript
// Check if any other license with the same name already exists (non-isolated)
const existingLicense = await License.query().where("name", name).first()

// Defaults to all accessible licenses
licenses = await License.query().where(query => {
    if (auth.user?.currentOrganizationId) query.where("organization_id", auth.user.currentOrganizationId)
    else query.where("is_verified", true)
})

// New licenses are not verified by default
isVerified: false
```

### TODO Comments

```typescript
// TODO: We should prevent users from updating verified licenses and/or licenses
// that are referenced anywhere

// TODO: Add pagination support for large datasets
```

### More Inline Examples from nodes_controller.ts

```typescript
// Check if node exists by type (unique identifier)
let node = await Node.query().where("type", type).first()

if (node) {
    // Update existing node
    node.name = name
    node.isVisible = isVisible
    await node.save()
} else {
    // Create new node
    node = await Node.create({
        name,
        type,
        isVisible,
        flowType,
    })
}

// Sync category tags if provided
if (categoryTagSlugs && categoryTagSlugs.length > 0) {
    const categoryTags = await Tag.query().whereIn("slug", categoryTagSlugs)

    if (categoryTags.length > 0) {
        // Replace all existing tags with the new ones
        await node.related("tags").sync(categoryTags.map(tag => tag.id))
    }
}

// Load tags for response
await node.load("tags")
```

## Key Patterns for Natural Comments

### Use Parenthetical Asides

Add context or clarification in parentheses within the main sentence:
```typescript
// Good:
/**
 * Get all the enabled (and for streaming only) registered nodes with the option to filter by category.
 */

// Check if any other license with the same name already exists (non-isolated)
const existingLicense = await License.query().where("name", name).first()

// Check if node exists by type (unique identifier)
let node = await Node.query().where("type", type).first()
```

### Multi-line Notes

When a note needs additional context, continue on the next line naturally:
```typescript
// Good:
/**
 * Sync (create or update) a node definition.
 *
 * Notes:
 * - This route is only accessible via service-to-service calls (XFCC auth).
 * - Used by workers to seed node definitions from `NODE_MAPPING`.
 */
```

### Simple Action Comments

Use simple, direct language for inline comments:
```typescript
// Good:
// Update existing node
node.name = name

// Create new node
node = await Node.create({ name, type })

// Replace all existing tags with the new ones
await node.related("tags").sync(categoryTags.map(tag => tag.id))

// Load tags for response
await node.load("tags")
```

### Avoid Over-explaining

Don't add comments for obvious operations:
```typescript
// Bad (too obvious):
// Save the node to database
await node.save()

// Good (adds context):
// New licenses are not verified by default
isVerified: false
```

## Quick Reference

| Type       | Style                          | Example                                                 |
|------------|--------------------------------|---------------------------------------------------------|
| JSDoc main | Natural prose, comma-separated | `Get all licenses, with the option to filter by status` |
| JSDoc note | Start with "Note:"             | `Note: This route is only accessible by admins`         |
| Inline     | lowercase, concise             | `// Check if license exists before updating`            |
| TODO       | Uppercase TODO                 | `// TODO: Add validation for external URLs`             |

## When to Use Each Type

- **JSDoc** - For functions, classes, types, and exported constants
- **Inline comments** - For complex logic that needs explanation
- **TODO comments** - For future improvements or known limitations
- **No comment** - When the code is self-explanatory

## Punctuation Rules

### End Dots (Periods)

- **Multi-line comments (/** */)** - Always end with a period
- **Single-line comments (//)** - Never end with a period

```typescript
// Correct:
/**
 * Get all licenses with the option to filter by organization ID.
 *
 * Note: This route is only accessible by admins.
 */

// Check if license exists before updating
const license = await License.find(id)

// Incorrect:
/**
 * Get all licenses with the option to filter by organization ID
 */

// Check if license exists before updating.
const license = await License.find(id)
```

## Code References

When you see the name of a class, function, variable, type, or any other code element written as-is in comments:
- **In multi-line comments (JSDoc)** - Surround it with backticks `` (e.g., `ClassName`, `functionName()`)
- **In single-line comments (//)** - Surround it with double quotes "" (e.g., "organizationId", "externalApis")

### Examples

```typescript
// Correct:
/**
 * Validator for tenant configuration updates, matches data-cluster-operator
 * `UpdateTenantRequest` schema.
 */

/**
 * Returns the `ClusterStatus` enum value based on the current state.
 */

// Update the "organizationId" field before saving
organization.organizationId = newId

// Parse the "externalApis" configuration
const apis = JSON.parse(config.externalApis)

// Incorrect:
/**
 * Validator for tenant configuration updates, matches data-cluster-operator
 * "UpdateTenantRequest" schema.
 */

// Update the `organizationId` field before saving
organization.organizationId = newId
```

## Emojis

**Never use emojis in code comments.** If you see emojis in comments, remove them.
**Exception:** Emojis are allowed in UI components where they're displayed to users.

```typescript
// Incorrect:
// Fetch all users from the database (with rocket emoji)
const users = await User.all()

/**
 * Get user profile (with note emoji).
 */
async show() { }

// Correct:
// Fetch all users from the database
const users = await User.all()

/**
 * Get user profile.
 */
async show() { }

// Exception - UI components can have emojis:
return <Button>Save Changes [disk icon]</Button>
```

## Common Replacements

- `- Fetches data` -> `, fetches data`
- `SECURITY:` -> `Note:` (unless multiple, then `Notes:` with a list where each line has "- ")
- `This function does X. - It also does Y.` -> `This function does X, it also does Y`
- `// Check If...` -> `// check if...`
- `// Check if license exists.` -> `// Check if license exists`
- `/** Get user */` -> `/** Get user. */`
- `// [emoji] Launch process` -> `// Launch process`


## Functions JSDoc

- **Always end with a period.**
- **Use the correct tense.**
- **Use descriptive comments.**
- Optional parameters should always have a doc that ends with this: ` (optional, defaults to `<type>`).`

```typescript
/**
 * Verify a token code against its hash (constant-time comparison).
 * @param code The secret code to verify.
 * @param tokenHash The stored hash to compare against.
 * @returns True if the code matches the hash, false otherwise.
 */
export async function verifyTokenCode(code: string, tokenHash: string): Promise<boolean>
```

## AI Slop

- Try to remove `Step X` from the comments, as they can become outdated or irrelevant.
- Remove any `---- comment ----` lines.
