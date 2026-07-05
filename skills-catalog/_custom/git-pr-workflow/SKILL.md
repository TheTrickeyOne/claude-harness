---
name: git-pr-workflow
description: >-
  Git commit, branch, and pull-request workflow for clean history. Use when
  committing changes, writing a commit message, creating a branch, opening a PR,
  drafting a PR description or changelog entry, squashing/rebasing, or cleaning
  up branch state. Triggers on "commit this", "write a commit message", "open a
  PR", "make a branch", "conventional commit", "changelog", "squash", "rebase",
  "tidy my git history". Enforces conventional commits, atomic commits, branch
  hygiene, and never committing or pushing unless explicitly asked.
---

# Git + PR workflow

Senior-operator runbook for turning a working tree into clean, reviewable history.
The prime directive: **you stage and describe; the human decides when to write history.**

## Golden rules

- **NEVER `git commit` or `git push` unless the user explicitly asks in this
  turn.** "Fix the bug" is not permission to commit. Do the work, then stop and
  report what you'd commit. Wait for "commit it" / "push it".
- **Read before write.** Before any commit, run `git status` and `git diff
  --staged` (and `git diff` for unstaged) and actually look at what is about to
  land. Never commit a diff you have not read.
- **Confirm destructive actions by naming the target.** Before `git push`,
  `git rebase`, `git reset --hard`, or a branch delete, state the exact ref and
  effect: "This will force-update `origin/feature-x`, overwriting 3 remote
  commits — confirm?" Get an explicit yes.
- **Force-push is extra scary.** `git push --force` / `--force-with-lease` can
  destroy a teammate's work. Never run it unprompted. Prefer
  `--force-with-lease` over `--force`, and only after confirming the branch is
  not shared or the user owns it. Never force-push a default branch.
- **Branch before committing on a default branch.** If `git status` shows you're
  on `main`/`master`/`trunk`, create a feature branch first (`git switch -c
  <type>/<short-desc>`) — do not commit directly to the default branch.
- **One command per call.** No `&&`, `||`, `;`, `$(...)`, backticks, or
  redirects. A single pipe into a read-only filter (`grep`, `head`, `cat`,
  `wc`) is the only allowed pipe. Sequence multi-step git work as separate calls
  so each is auditable.

## Safe vs. confirm

| Safe (read-only, run freely) | Confirm first (mutating) |
| --- | --- |
| `git status` | `git commit` |
| `git diff`, `git diff --staged` | `git push`, `git push --force-with-lease` |
| `git log --oneline -20` | `git rebase`, `git rebase -i` |
| `git branch`, `git branch -a` | `git reset --hard` |
| `git show <ref>` | `git switch -c` on top of dirty state / branch delete |
| `git remote -v` | `git cherry-pick`, `git revert` (writes a commit) |

`git add` is reversible (`git restore --staged`) so staging is low-risk, but
still show the user what you staged.

## Branch hygiene

- Name branches `<type>/<scope-or-slug>`: `feat/mesh-psk-rotation`,
  `fix/argocd-sync-loop`, `chore/bump-deps`.
- One logical change per branch. If you notice unrelated work, branch again.
- Start from an up-to-date base: `git fetch` then `git switch -c newbranch
  origin/main` (two calls). Don't branch off stale local `main` silently.
- Delete merged branches only after confirming they're merged (`git branch
  --merged`).

## Conventional commit messages

Format: `<type>(<scope>): <imperative summary>` — summary <= ~72 chars, no
trailing period.

Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `perf`, `test`, `build`,
`ci`. Scope is the affected area (`firmware`, `argocd`, `nginx`, `mesh`).

Body (optional, wrap ~72 cols): explain **why**, not what the diff already
shows. Breaking changes get a `BREAKING CHANGE:` footer or a `!` after the
type/scope (`feat(api)!: drop v1 auth`).

Examples:

```
fix(argocd): stop sync loop on out-of-band label writes

The app-of-apps controller rewrote the managed-by label every reconcile,
which the tenant controller reverted, causing a hot loop. Ignore that
label in the diff.
```

```
feat(mesh): add per-channel PSK rotation helper
```

Keep commits **atomic**: each commit builds and tells one story. If a change
mixes a refactor and a behavior change, split it with `git add -p` (staging is
safe) into two commits — but still only commit when asked.

**Trailers / Co-Authored-By follow the repo's existing convention.** Check
recent history (`git log -10 --format='%an %s%n%b'`) before inventing trailers.
If the repo uses `Signed-off-by`, sign off; if it uses `Co-Authored-By`, match
that. Do not add trailers the repo doesn't already use unless asked.

## PR description

Structure the PR body as **What / Why / How to test**:

```markdown
## What
One-paragraph summary of the change.

## Why
The problem or motivation. Link the issue (Fixes #123).

## How to test
1. Concrete steps a reviewer runs.
2. Expected result.

## Notes
Risks, rollout/rollback, follow-ups.
```

Use `gh pr create --title "..." --body-file <file>` (write the body to a file
first — cleaner than shell-escaping). Set base/head explicitly if not obvious.
Creating a PR still needs the "open a PR" ask; don't do it as a side effect.

## Changelog entries

If the repo has a `CHANGELOG.md` (Keep a Changelog style), add a bullet under
`## [Unreleased]` grouped by `Added` / `Changed` / `Fixed` / `Removed`. Write
for a human reader, referencing user-visible impact, not internal function
names. Match whatever format the file already uses.
