---
description: Merge the harness into an existing project without clobbering its files
argument-hint: "[--profile <name>]"
---

# /adopt — merge the harness into an existing repo

Use this when the harness files were copied into a project that ALREADY has its
own `CLAUDE.md`, `.claude/`, or `AGENTS.md`. Goal: add the harness without
destroying anything that's already there. Arguments: `$ARGUMENTS`

## Procedure
1. **Inventory conflicts.** Check for a pre-existing `AGENTS.md`, `CLAUDE.md`,
   `.claude/settings.json`, `.claude/skills/`, `.mcp.json`, `.gitignore`. Read
   each before changing it.

2. **AGENTS.md merge.**
   - No existing `AGENTS.md`: use the harness one as-is.
   - Existing one: preserve its content. Append the harness's stack-agnostic
     contract as a clearly-marked section, or (better) ask whether to fold the
     harness rules in. Never delete the project's own rules.

3. **CLAUDE.md merge.** If the project's `CLAUDE.md` lacks an `@AGENTS.md`
   import, add one at the top. Keep all existing project content.

4. **settings.json merge.** Add the `block-compound-bash` `hooks.PreToolUse`
   entry if absent. Merge `permissions.allow` (union, no dups). Never drop
   existing hooks or permissions.

5. **Skills.** Copy harness skills into `.claude/skills/` only where no
   same-named skill exists; report any name collisions instead of overwriting.

6. **.gitignore.** Union-merge the secrets/`.env` ignore lines if missing.

7. **Then run bootstrap logic** (Phases 1–6 of `/bootstrap`) to tailor the
   stack, but in merge-safe mode: additive only.

8. **Report** every file you touched and every conflict you left for the user to
   resolve. Do not commit.
