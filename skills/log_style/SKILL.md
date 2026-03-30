# Log message style review
Review all log statements in the current file (or the files mentioned by the user) and rewrite any that don't follow these rules.

## Before you start: discover the project's logger
Do not assume a specific import path. First, grep a few nearby files for how they import and call the logger, then use that same pattern consistently. Look for:
- What is imported and from where (e.g. a logger singleton, a `getLogger()` factory, a class instance)
- Whether the logger follows a **structured style** (metadata object + message string, as in pino/winston) or a **printf style** (format string only, as in Python's logging)
- Whether any logging helper utilities exist in the project (e.g. `userLog()`, `tryCatchLog()`) — if so, prefer them over inline equivalents

Apply whatever import and calling convention already exists in the file. Do not introduce a new one.

## No raw console/print output in production code
Replace every `console.log/warn/error/debug()` (JS/TS) or bare `print()` (Python) in non-script, non-test files with the appropriate logger call. A bare console/print that duplicates a logger call right after it should simply be deleted.
- Bad:  `console.log("job completed")`
- Good: `logger.info("job completed")`

## Calling convention
### Structured loggers (pino, winston, etc.)
When you have metadata to attach, put the **object first** and the **message string last**. Never embed IDs or counts into the string when they belong in the metadata object.
- Bad:  `logger.info(\`cluster \${cluster.slug} synced, id=\${cluster.id}\`)`
- Good: `logger.info({ clusterId: cluster.id, clusterSlug: cluster.slug }, "Cluster synced")`

For simple messages with no metadata, a plain string is fine:
- `logger.info("Starting background job scheduler")`

### Printf / interpolation loggers (Python logging, etc.)
Use `%s`/`%d` placeholders or the logger's native interpolation — never pre-format the string with concatenation or f-strings, so the logger can defer formatting when the level is suppressed.
- Bad:  `log.info("Cluster " + cluster.slug + " synced")`
- Good: `log.info("Cluster %s synced", cluster.slug)`

## Rules

1. **Natural sentence, not a field dump.** Write a short English sentence. Do not join key=value pairs with `|` or `,` as if building a structured record.
   - Bad:  `"Accepted message {id} | jobType='{type}' | supported={list}"`
   - Good: `"Accepted message {id} with job type '{type}'"`

2. **Embed context naturally.** Put dynamic values inside the sentence where they make grammatical sense. Use parentheses for secondary context. For structured loggers, prefer moving IDs and counts to the metadata object over embedding them in the string.
   - Bad:  `"Rejected {id} | type='{t}' (not in supported={list}), returned to queue"`
   - Good: `"Rejected message with unsupported type '{t}', returned to queue"` (with `{ id, supported: list }` in metadata)

3. **Sentence case only.** First word capitalized, rest lowercase unless a proper noun or acronym.
   - Bad:  `"PARSE ERROR on message …"`, `"Failed To Connect"`, `"cluster Synced"`
   - Good: `"Parse error on message …"`, `"Failed to connect"`, `"Cluster synced"`

4. **No trailing period.** Log messages are not sentences ending with a full stop.
   - Bad:  `"Connection closed."`, `"Retrying request."`
   - Good: `"Connection closed"`, `"Retrying request"`

5. **No `-` as a separator.** Never use a dash to join two parts of a message. Use a comma or rephrase.
   - Bad:  `"Cache miss for dataset {id} - fetching"`, `"Completed {model} - cost: ${cost}"`
   - Good: `"Cache miss for dataset {id}, fetching"`, `"Completed {model}, cost ${cost}"`

6. **Single quotes around literal identifiers.** Field names, role names, config keys, and other string literals that appear as plain text in the message must be wrapped in single quotes. Interpolated runtime values do not need quoting.
   - Bad:  `"organizationId not in payload"`, `"role user could not be attached"`
   - Good: `"'organizationId' not in payload"`, `"role 'user' could not be attached"`

7. **Choose the right level.**
   - `debug`: internal state useful only when tracing a bug (e.g. per-request detail, low-level polling)
   - `info`: normal lifecycle events an operator might care about (e.g. resource created, job completed)
   - `warn`: something unexpected that the system recovered from (e.g. missing optional config, failed auth attempt)
   - `error`: something that caused an operation to fail (e.g. exception in a service call, unrecoverable state)

8. **No redundant prefixes.** Don't add `[MODULE]` or `[SQS]` tags; the logger name and metadata already carry that context.

9. **No emojis.** Never use emojis in log messages.

10. **Pass errors as objects, not stringified messages.** For structured loggers, pass the raw error under a dedicated key (commonly `err` or `error`) so the logger can serialize the stack trace. For printf loggers, pass the exception as a keyword argument or use the logger's `exc_info` / equivalent mechanism.
    - Bad:  `logger.error(\`Failed to sync: \${error.message}\`)`
    - Good: `logger.error({ err: error, clusterId }, "Failed to sync cluster")`

## What to do
Go through every log/console/print call in the requested scope. For each one that violates a rule above, show:
- The original line
- The rewritten line
- Which rule(s) it violated

Then apply the fixes directly to the file(s).
