---
name: zcl-codegen
description: Define and regenerate ZCL/Matter data models with project-chip/zap (ZCL Advanced Platform) and connectedhomeip codegen scripts — the .zap ↔ .matter duality, launching the ZAP GUI vs headless regen, adding a cluster/attribute/command, choosing attribute storage (RAM/NVM/External), and reading the generated C++ (zap-generated/, IDL). Use when editing a .zap or .matter file, when someone says "ZAP tool", "run_zaptool", "zap_regen_all", "regenerate cluster code", "add a custom attribute", "manufacturer-specific cluster", "ZCL codegen", "endpoint_config.h", or when generated cluster stubs are out of sync with the model. Reusable by both Matter (matter-device) and Zigbee ZCL work.
---

# zcl-codegen

The data-model codegen layer shared by Matter and Zigbee firmware. **ZAP** (Zigbee
Cluster-configurator / ZCL Advanced Platform, `project-chip/zap`) is an
Electron/Node tool that edits a `.zap` project and runs templates to emit C/C++.
connectedhomeip drives ZAP through wrapper scripts and its own template set.

**Versions move fast.** As of 2026-07 ZAP is versioned by date/tag and is
vendored into connectedhomeip (~v1.5.x) as `third_party/zap` /
`scripts/tools/zap`. Script names have been renamed across releases — verify
against the checked-out tree (`ls $CHIP_ROOT/scripts/tools/zap`) and pin the
command that worked in this skill dir.

## The two files

- **`<app>.zap`** — JSON project. The editable source of truth: which endpoints
  exist, each endpoint's device type, and per-cluster which
  attributes/commands/events are enabled, plus attribute storage policy and
  default/min/max. Edited via the ZAP GUI (or careful JSON edits).
- **`<app>.matter`** — the **IDL**, a readable text projection of the model
  generated from the `.zap`. This is the code-review artifact and, in newer
  connectedhomeip, itself an input to codegen (`codegen.py`). Keep it committed
  next to the `.zap`.

Golden rule: **edit `.zap`, regenerate, commit `.zap` + `.matter` + generated
output together.** Never hand-edit generated files; never let them drift.

## The .zpt / template + zcl metadata inputs

Codegen needs two more things, already wired in the SDK:
- the **ZCL metadata**: `src/app/zap-templates/zcl/zcl.json` (Matter) — the
  master list of standard clusters/attributes ZAP offers you.
- the **templates**: `src/app/zap-templates/templates/app/gen-templates.json`
  (Matter app codegen) and the IDL templates.
The wrapper scripts pass these for you; you only supply the `.zap`.

## Launch the GUI

```
$CHIP_ROOT/scripts/tools/zap/run_zaptool.sh examples/<app>/<app>.zap
```
This opens the ZAP UI on the given project with the Matter zcl metadata
preloaded. In the UI: pick an endpoint → enable/disable clusters (client/server)
→ per cluster, toggle attributes and commands, set **storage option** and
default values. Save writes back the `.zap`.

Standalone ZAP (outside CHIP) for Zigbee ZCL work:
```
zap --zcl <zcl.json> [<file>.zap]
```

## Headless regen (CI / no display)

Regenerate a single app's generated code from its `.zap`:
```
$CHIP_ROOT/scripts/tools/zap/generate.py examples/<app>/<app>.zap
```
Regenerate every app in the tree (after a template or zcl-metadata change):
```
$CHIP_ROOT/scripts/tools/zap/regen_all.py
```
Older trees name this `zap_regen_all.py` — check `ls scripts/tools/zap` if the
first form is missing. Both are pure code-gen (no hardware, safe to run
anywhere). To (re)generate just the `.matter` IDL from templates, newer trees
expose `scripts/codegen.py`.

## Adding to the model

**A standard cluster on an endpoint:** GUI → select endpoint → check the cluster
(server), enable its mandatory attributes/commands, regen.

**A custom / manufacturer-specific cluster:** define it in an **XML extension**
loaded alongside the standard `zcl.json`. Add a `<cluster>` (with a manufacturer
code and a cluster ID in the MS range), its `<attribute>`/`<command>` elements,
point the metadata at your XML, then enable it in the `.zap` and regen. Matter
custom clusters must sit in the manufacturer-extensible ID range; give attributes
explicit IDs and types.

**A new attribute on an existing cluster:** enable it in the GUI (standard) or
add `<attribute code=... type=... writable=... >` to your extension XML (custom),
then set its storage:
- **RAM** — stack keeps the value in the Ember attribute table (default).
- **NVM / persisted** — survives reboot; used for config attributes.
- **External** — you own storage; the stack calls
  `emberAfExternalAttributeRead/WriteCallback`. Choose this when the value is
  really a hardware register or lives in your own datastore.

**A command:** enable the standard command, or declare it in the extension XML;
implement the generated handler
(`emberAf<Cluster>Cluster<Command>Callback` / `CommandHandlerInterface`).

## What gets generated and where

For a connectedhomeip app, regen writes into the app's `zap-generated/` (and
shared `src/app/zap-generated` for cross-cutting tables). Files you'll read:
- **`endpoint_config.h`** — the compile-time endpoint/cluster/attribute tables
  (the "GENERATED_*" macros). This is the canonical description of what the
  device exposes; grep here to confirm an attribute actually made it in.
- **`gen_config.h` / `af-gen-event.h`** — feature and event wiring.
- **`IDL`/`.matter`** — the readable model.
- cluster **`Clusters.h` / `Ids.h`** under `zap-generated/app-common` — the
  `app::Clusters::<Cluster>::Attributes::<Attr>::{Get,Set}` accessors and
  cluster/attribute ID constants you call from firmware.

Verify a change landed by diffing `endpoint_config.h` and the `.matter`, not by
rebuilding blind.

## Zigbee (non-Matter) ZCL note

The same ZAP tool drives classic Zigbee ZCL codegen (Silicon Labs' original use
case) with a Zigbee `zcl.json`. The `.zap` model and GUI are the same; templates
and generated output differ (Zigbee `zap-generated` command/attribute tables).
For ESP Zigbee you usually define clusters via the `esp_zb_...` runtime API
instead (see zigbee-device) rather than ZAP — ZAP is mainly the Matter and
EmberZNet path.

## Pin your references
- Output of `ls $CHIP_ROOT/scripts/tools/zap` + the exact regen command used.
- Your custom-cluster extension XML and its manufacturer code.
- A before/after `endpoint_config.h` diff for the last model change, as a
  known-good reference.

## Gotchas
- Regen is per-app: editing one `.zap` and running `generate.py` on a different
  one silently leaves your change ungenerated.
- Stale committed `zap-generated/` compiles fine but ships the old model — the
  `.matter` diff is your tripwire.
- Custom cluster/attribute IDs outside the manufacturer range collide with
  standard ones on regen.
- One command per harness call; a single read-only filter pipe only.
