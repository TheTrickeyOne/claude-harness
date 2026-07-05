# License map

The harness's own files (hooks, custom skills, commands, docs) are the owner's
to license as they see fit. Vendored public skills keep their upstream licenses,
tracked here and in `skills-catalog/_vendored/ATTRIBUTION.md`.

## Obligations cheat-sheet

| License | Where | What you must do |
|---|---|---|
| **MIT** | `_vendored/MIT/` | Keep the LICENSE + copyright notice. Easiest. |
| **Apache-2.0** | `_vendored/APACHE/` | Keep LICENSE + NOTICE; note modifications. |
| **CC-BY-SA-4.0** | `_vendored/CC-BY-SA/` | Attribute the author (Trail of Bits) **and** license derivatives under CC-BY-SA (share-alike). Isolated in its own dir so this obligation doesn't spread. |
| **GPL-3.0** | `_vendored/GPL/` | Copyleft. Fine for private/personal use. If the combined repo is ever redistributed, GPL attaches to the combined work — keep isolated; prefer re-deriving over copying (done for `ansible-bestpractices`). |
| **MPL-2.0** | `_vendored/MPL/` | File-level copyleft: modified MPL files stay MPL and must be shared if distributed. Unmodified use is unencumbered. |
| **Proprietary** | not vendored | anthropics Office skills — reference only, never redistribute. |
| **No license** | not vendored | All-rights-reserved by default — cannot redistribute. Re-derive ideas. |

## Custom skills
`skills-catalog/_custom/*` are original to this harness. The
`ansible-bestpractices` skill is deliberately re-derived from general best
practice rather than copied from the GPL `leogallego/claude-ansible-skills`, so
it carries no copyleft obligation.

## Practical stance for personal use
For a private, non-distributed harness on your own machines, copyleft
obligations are effectively dormant (they trigger on distribution). The
per-license isolation and this map exist so that IF the repo is ever shared, the
obligations are already contained and documented rather than tangled through the
whole tree.
