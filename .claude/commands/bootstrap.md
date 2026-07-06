---
description: Interview the user and rewrite this harness for the current project's stack
argument-hint: "[light] [--profile <name>] [--reconfigure]"
---

# /bootstrap — adapt the harness to this project

You are configuring the claude-harness for **this specific repo**. Work through
the phases below. Be decisive; ask only what you cannot infer. Everything you
change is inside this repo — never touch `~/.claude` from here.

Arguments: `$ARGUMENTS`
- `light` (or `--light`): **skip the interview entirely** and do the minimal
  setup for a simple project. See "Light mode" below. This is the in-session
  equivalent of `bin/harness-init.sh`.
- `--profile <name>`: skip the interview and load answers from
  `docs/stack-profiles/<name>.md`. Valid names: list the files in that dir.
- `--reconfigure`: re-run using the existing `.harness-manifest.json` as the
  starting point; confirm/adjust rather than ask from scratch. Must be
  idempotent — do not duplicate skills, permissions, or MCP entries.

## Light mode (`/bootstrap light`)
If `light`/`--light` is in the arguments, do ONLY this and stop — no interview,
no questions, no MCP, no stack profile:
1. **Keep `AGENTS.md` as-is** — leave the generic `## Project` section (the
   stack-agnostic contract is all a simple project needs). Do not fill it in.
2. **Prune `.claude/skills/` to the core-dev set only** (same 5 as
   `bin/harness-init.sh`), copied from `skills-catalog/`, licenses preserved:
   `_vendored/MIT/superpowers-test-driven-development`,
   `_vendored/MIT/superpowers-systematic-debugging`,
   `_vendored/MIT/superpowers-verification-before-completion`,
   `_custom/git-pr-workflow`, `_custom/secrets-hygiene`.
   Remove any other skills already staged in `.claude/skills/`.
3. **Ensure `.gitignore`** has the secrets essentials (`.env`, `*.key`, `*.pem`,
   `kubeconfig`, `.claude/settings.local.json`) — add if missing, don't dup.
4. **Leave `.claude/settings.json` at defaults** — keep the compound-command
   hook block; do not write a stack permission profile.
5. **Record** in `.harness-manifest.json`: `bootstrapped: true`,
   `profile: "light"`, `projectType: "simple"`, `enabledSkills` = the 5 above,
   empty `enabledMcpServers`, `bootstrappedAt` = session date (don't invent one).
6. **Suggest** trimming the staging catalog to stay lean:
   `echo "skills-catalog/_vendored/" >> .gitignore` (and optionally
   `rm -rf skills-catalog/_vendored`), since only `.claude/skills/` is needed now.
7. Report what was set up in 2–3 lines. Do not commit. Then STOP — skip all
   phases below.

## Phase 0 — Orient
1. Read `.harness-manifest.json`. If `bootstrapped` is already true and
   `--reconfigure` was NOT passed, tell the user it's already bootstrapped and
   ask whether to reconfigure; stop unless they confirm.
2. Look around the repo (existing files, languages, IaC dirs, `*.yaml`,
   `platformio.ini`, `Chart.yaml`, `inventory/`, `talconfig`, etc.) to
   pre-fill likely answers before asking.

## Phase 1 — Interview
If `--profile` was given, load that profile's answers and skip to Phase 2.
Otherwise use the AskUserQuestion tool (grouped, multi-select where sensible):

- **Project type** (one): infra / webapp / firmware / red-team engagement /
  mixed.
- **Stack components** (multi): Talos, Longhorn, ArgoCD, Ansible, Proxmox,
  OPNsense, Kubernetes (generic), Home Assistant, ESPHome, Meshtastic,
  ESP-IDF/ESP32, Nordic/Zephyr, Matter, Thread, Zigbee, generic web frontend,
  generic embedded, other.
- **Deploy/target**: e.g. Talos cluster name, Proxmox node, ESP32 variant,
  nRF target — free text, may be "n/a".
- **Secrets backend** (one): env (default) / 1Password / Bitwarden.
- **Security tooling authorized here?** (yes/no) — gates whether offensive
  security skills/agents are enabled. If yes, note that authorization applies
  only to systems the user owns or is contracted to test.

## Phase 2 — Rewrite AGENTS.md
Replace the content between the `<!-- BOOTSTRAP:PROJECT -->` and
`<!-- /BOOTSTRAP:PROJECT -->` markers in `AGENTS.md` with a concrete `## Project`
body: the stack in play, key endpoints/hosts (from the interview), repo
conventions you observed, and stack-specific safety notes (e.g. "this cluster is
production — no `kubectl delete` without confirmation"). Keep the markers.

## Phase 3 — Prune skills
Copy only the relevant skills from `skills-catalog/` into `.claude/skills/`:
- Map each chosen stack component to its skills using the table in
  `docs/stack-profiles/_skill-map.md`.
- For vendored skills, copy from `skills-catalog/_vendored/<LICENSE>/<skill>/`
  and preserve the skill's `LICENSE`/attribution.
- Do not copy skills for components that weren't selected.
- On `--reconfigure`, remove skills for now-deselected components too.

## Phase 4 — Permissions
Write `.claude/settings.json` `permissions.allow` for the stack, starting from
the matching profile in `docs/stack-profiles/<profile>.md` (`permissions`
block). Default posture: allow read-only verbs, leave writes to prompt. Keep the
existing `hooks` block (the compound-command hook) intact. Merge — never drop —
any pre-existing allow entries.

## Phase 5 — MCP servers
From `mcp/.mcp.json.template`, copy the entries for the chosen components into a
project `.mcp.json`. Populate `mcp/.env.example` names the user will need; if
`.env` doesn't exist, create it from `.env.example` and tell the user which vars
to fill. Set `secrets.sh`'s backend to the chosen secrets option.

## Phase 6 — Record + report
Update `.harness-manifest.json`: set `bootstrapped: true`, `bootstrappedAt`
(ask the user for the date or use the session date — do not invent one),
`profile`, `projectType`, `stackComponents`, `enabledSkills`,
`enabledMcpServers`, `permissionProfile`, `secretsBackend`,
`securityToolingAuthorized`.

Then report concisely: what stack was detected/selected, which skills and MCP
servers are now active, which `.env` vars still need values, and any safety
notes you wrote into AGENTS.md. Do not commit anything.
