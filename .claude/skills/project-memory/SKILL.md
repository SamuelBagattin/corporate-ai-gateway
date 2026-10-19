---
name: project-memory
description: Maintains and self-improves docs/PROJECT.md, docs/ARCHITECTURE.md, and docs/JOURNAL.md. Use at the end of any non-trivial work unit, before /clear or /compact, when the user says "log this", "wrap up", "save progress", or "update memory", at the start of a session if docs look stale, and when the user says "review memory" to run the self-improvement audit.
---

# Project Memory Maintenance

Three files, three jobs. Be ruthless about brevity. Token cost compounds — every line you add is paid every future session.

## When invoked

Decide which mode applies:

- **Log mode** (default at end of work unit): append to JOURNAL.md, propagate any architectural decisions to ARCHITECTURE.md, update PROJECT.md only if status/scope shifted.
- **Audit mode** (user says "review memory" or roughly every 10 sessions): self-improvement pass over all four files.

## Log mode

### 1. JOURNAL.md — append, never rewrite

Prepend a new entry at the top of the entries (under the file header):

```
## YYYY-MM-DD — <one-line title summarizing the work>
- **Did:** <2–4 concrete bullets>
- **Why:** <1 line, only if non-obvious>
- **Decisions:** <only if architectural — also propagate to ARCHITECTURE.md>
- **Open:** <known unfinished threads>
- **Lessons:** <only if Claude got something wrong and was corrected>
```

Use today's actual date. If nothing meaningful happened, write `**Did:** housekeeping` — do not inflate.

If JOURNAL.md exceeds ~80 entries, move the oldest quarter's entries to `docs/journal-archive/YYYY-QN.md` (create the dir if needed).

### 2. ARCHITECTURE.md — update only if a decision was made

If the work unit produced an architectural decision (stack change, structural choice, library swap, pattern adoption), prepend to "Key decisions":

```
### YYYY-MM-DD — <decision title>
<One paragraph: what was decided, why, what was rejected.>
```

Update Stack/Structure/Conventions/Known gotchas sections inline if reality changed. Replace stale content; do not append duplicates.

### 3. PROJECT.md — update only if scope/status shifted

If today's work changed Status, Scope-in, Scope-out, or Next milestone, edit those sections in place. Otherwise leave it alone.

## Audit mode (self-improvement)

Triggered by "review memory" or proactively every ~10 sessions if the user agrees.

1. Read the last 10 JOURNAL.md entries, plus PROJECT.md, ARCHITECTURE.md, CLAUDE.md.
2. Identify:
   - **Repeated lessons** (same correction across multiple journal entries) → promote to ARCHITECTURE.md > Conventions or to CLAUDE.md > Hard rules.
   - **Unrecorded decisions** — decisions visible in the journal but missing from ARCHITECTURE.md > Key decisions.
   - **Drifted PROJECT.md** — claims that no longer match what the journal shows happened.
   - **Violated CLAUDE.md rules** — rules that were broken more than once → reword more sharply or strengthen with `IMPORTANT:` prefix.
   - **Bloat** — sections in any file that have grown past their useful size.
3. Show a unified diff of proposed changes. Wait for approval before writing.

## Hard rules

- Never write secrets, tokens, full file paths containing user identifiers, or API keys.
- Use the actual current date. Never invent dates.
- One short user quote is enough to capture intent — never paste long blocks.
- If asked to log something but you didn't actually do work, say so and do nothing.
- Keep PROJECT.md under ~100 lines, ARCHITECTURE.md focused (links out for deep detail), CLAUDE.md under ~80 lines for fast load.
- Never edit JOURNAL.md entries after creation — append only.
