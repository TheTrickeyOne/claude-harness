---
name: matter-device
description: Build Matter accessory firmware (the device, not commissioning) with connectedhomeip (project-chip), esp-matter, NCS sdk-nrf, or SiliconLabs/matter — scaffold from examples/, define the data model (endpoints/clusters), edit the .matter IDL + .zap file pair, wire data-model callbacks (Ember emberAf... and esp_matter convenience layer), run ZAP codegen, and bring up Matter-over-Thread via an RCP + OTBR. Use when building a Matter light/switch/sensor/plug on ESP32-C6/H2/S3, nRF52/nRF53/nRF54, or EFR32; when someone says "Matter device", "Matter accessory", "CHIP firmware", "matter cluster callback", "esp_matter", "MatterPostAttributeChangeCallback", "zap file", ".matter IDL", "Matter over Thread". For pure ZAP/ZCL codegen mechanics see the zcl-codegen skill; for OTA/cert see matter-zigbee-ota.
---

# matter-device

Authoring firmware for a Matter accessory. This is the flagship skill for the
device side: you define a data model, generate cluster code, implement the
application callbacks, and flash it to a dev board. Commissioning and
`chip-tool` are test-harness concerns, not covered here except as bring-up.

**Versions move fast.** As of 2026-07: connectedhomeip is ~v1.5.x, esp-matter
tracks ESP-IDF v5.x/6.x, nRF Connect SDK (sdk-nrf) ~v3.x, Silicon Labs Matter
extension tracks its own release train. Pin your SDK, and keep the exact
commands/snippets you verified in this skill directory (see "Pin your
references"). Always confirm the command against the SDK revision the project
actually checked out (`git -C $CHIP_ROOT describe --tags`).

## Mental model

A Matter device is a tree: **node → endpoints → clusters → attributes /
commands / events**. Endpoint 0 is the mandatory Root Node (Basic Information,
General Commissioning, Network Commissioning, OTA Requestor, etc.). Application
functionality lives on endpoints 1..N, each with a **device type** (e.g. On/Off
Light `0x0100`, Contact Sensor `0x0015`) that mandates a set of clusters.

The data model has a **dual source of truth you must keep in sync**:
- `*.zap` — the editable ZAP project (JSON). Source of truth for which
  clusters/attributes/commands are enabled on which endpoint.
- `*.matter` — the generated IDL, a human-readable text projection of the same
  model. Committed alongside the `.zap`; code review happens here.

You edit `.zap` (usually in the ZAP GUI), regenerate, and the `.matter` +
`zap-generated/` C++ update together. Never hand-edit generated files.

## Pick your platform path

| Platform | SDK | Boards | Transport |
|---|---|---|---|
| Espressif | **esp-matter** (wraps connectedhomeip) | ESP32-C6, ESP32-H2, ESP32-S3, C3 | H2/C6 = Thread (802.15.4); S3/C3 = Wi-Fi |
| Nordic | **nRF Connect SDK** (`sdk-nrf`, Zephyr) | nRF52840, nRF5340, nRF54L15 | Thread or Wi-Fi (nRF7002) |
| Silicon Labs | **SiliconLabs/matter** (Gecko SDK / Simplicity) | EFR32MG24, MG26 | Thread |
| Bare connectedhomeip | **project-chip/connectedhomeip** | Linux/host, some SoCs | any |

esp-matter and NCS both vendor a copy of connectedhomeip as a submodule — the
data model and ZAP flow are identical; only the build system and the
convenience API differ.

## Scaffold from examples/ (do not start from scratch)

connectedhomeip and every vendor SDK ship a matrix of working examples. Copy the
nearest device type and mutate it.

- connectedhomeip: `examples/lighting-app`, `examples/lock-app`,
  `examples/thermostat`, `examples/all-clusters-app`,
  `examples/temperature-measurement-app`. Each has per-platform subdirs
  (`esp32/`, `nrfconnect/`, `silabs/`, `linux/`).
- esp-matter: `examples/light`, `examples/light_switch`, `examples/zap_light`,
  `examples/sensors`, `examples/generic_switch`.
- NCS: `samples/matter/light_bulb`, `light_switch`, `lock`, `window_covering`,
  `template`.

Start from the device type closest to yours; changing the device type later
means re-picking the mandatory clusters in ZAP.

## Build & flash

Set up the environment once per shell (each is a single command):

```
# connectedhomeip host/esp
source $CHIP_ROOT/scripts/activate.sh
```
```
# esp-matter (after IDF export)
source $IDF_PATH/export.sh
```
```
source $ESP_MATTER_PATH/export.sh
```

esp-matter / ESP-IDF build:
```
idf.py set-target esp32c6
```
```
idf.py build
```
Flashing **mutates the device** — it erases and rewrites flash. Confirm the
serial port maps to the intended board before running:
```
idf.py -p /dev/ttyACM0 flash monitor
```
A full-chip erase (below) also wipes the Matter fabric/commissioning data and
factory partition — confirm the target, it forces re-commissioning:
```
idf.py -p /dev/ttyACM0 erase-flash
```

NCS build/flash (west) — `west flash` reprograms the SoC, confirm the board:
```
west build -b nrf52840dk/nrf52840 -- -DFILE_SUFFIX=release
```
```
west flash
```

Silicon Labs: build via the connectedhomeip `gn`/`ninja` flow under
`examples/<app>/silabs`, flash the resulting `.s37`/`.hex` with `commander flash`
(Simplicity Commander) or the `chip-` build's `.flashbundle`. Flashing rewrites
the EFR32 — confirm the J-Link serial.

## Editing the data model

Full mechanics live in the **zcl-codegen** skill. The short loop:
1. Open the app's `.zap` in the ZAP GUI:
   `./scripts/tools/zap/run_zaptool.sh examples/<app>/<app>.zap`
2. Add/remove clusters on the endpoint, toggle attributes, set command
   enablement, set attribute storage (RAM vs NVM/`External`).
3. Regenerate for that one app:
   `./scripts/tools/zap/generate.py examples/<app>/<app>.zap` (writes
   `zap-generated/`), or regenerate everything with
   `./scripts/tools/zap/regen_all.py` (older trees: `zap_regen_all.py`).
4. Diff the `.matter` — the review artifact. Commit `.zap` + `.matter` + the
   regenerated `zap-generated/` together.

esp-matter has its own generated-data-model app (`examples/zap_light`) plus a
code-first path (below) where you build endpoints in C++ at runtime instead of
via a `.zap`.

## Data-model callbacks — the actual firmware work

Two layers, depending on SDK.

### Ember layer (connectedhomeip, all platforms)
Generated code invokes weakly-linked `emberAf...` hooks. The two you almost
always implement:

- **Writes from the fabric → your hardware.** The stack calls
  `MatterPostAttributeChangeCallback(const ConcreteAttributePath &path,
  uint8_t type, uint16_t size, uint8_t *value)` after an attribute write.
  Switch on `path.mClusterId` / `path.mAttributeId` and drive the peripheral
  (GPIO, PWM, etc.). This is where an On/Off write becomes a relay toggle.
- **External-storage reads/writes.** If an attribute is marked `External` in
  ZAP, implement `emberAfExternalAttributeReadCallback` /
  `...WriteCallback` to back it with your own store instead of the Ember RAM/NVM
  attribute table.

Push local state (button press, sensor sample) back into the model with the
generated cluster setters, e.g.
`app::Clusters::OnOff::Attributes::OnOff::Set(endpoint, value)` or
`...::BooleanState::Attributes::StateValue::Set(...)`. Do attribute writes on
the Matter/CHIP task via `DeviceLayer::SystemLayer().ScheduleLambda(...)` or
`PlatformMgr().LockChipStack()` — the data model is not thread-safe.

Invoke command handlers by implementing the cluster's
`emberAf<Cluster>Cluster<Command>Callback(...)` or, in newer trees, a
`CommandHandlerInterface`/cluster server object.

### esp_matter convenience layer (Espressif)
esp-matter wraps Ember with a friendlier C API and an optional **code-first**
model (no `.zap` needed):

```
esp_matter::node_t *node = esp_matter::node::create(&node_config, app_cb, NULL);
esp_matter::endpoint::on_off_light::config_t cfg;
esp_matter::endpoint_t *ep = esp_matter::endpoint::on_off_light::create(node, &cfg, ...);
```
Register one attribute-update callback:
```
esp_err_t app_cb(attribute::callback_type_t type, uint16_t endpoint_id,
                 uint32_t cluster_id, uint32_t attribute_id,
                 esp_matter_attr_val_t *val, void *priv);
```
`type == PRE_UPDATE` fires before the value is committed (drive hardware here /
reject). Update state programmatically with
`esp_matter::attribute::update(endpoint_id, cluster_id, attribute_id, &val)`.
Add clusters/attributes with `cluster::create`, `attribute::create`,
`command::create`. This path skips ZAP entirely; the `zap_light` example is the
ZAP-driven alternative if you prefer the generated model.

## Bring-up for Matter-over-Thread (H2/C6, nRF, EFR32)

A Thread-radio device (802.15.4, no native IP) needs a **Thread Border Router**
to reach IP networks. For development you stand up an **OpenThread Border Router
(OTBR)** backed by an **RCP** (Radio Co-Processor):

1. Flash a spare 802.15.4 board with RCP firmware (OpenThread `ot-rcp`, or
   ESP `esp_ot_rcp`). This is a separate build — see the thread-device skill.
2. Run `otbr-agent` on a Linux host/Raspberry Pi against that RCP; it forms/join
   a Thread network and bridges to your LAN.
3. Commission the accessory onto that Thread network (test harness:
   `chip-tool pairing ble-thread ...` with the OTBR's active dataset). This is
   the commissioning step — out of scope here, but you need it to smoke-test the
   firmware end to end.

Wi-Fi accessories (S3/C3, nRF7002) skip all of this and join the AP directly.

## Certification (separate, know it exists)

Product shipping needs **CSA Matter certification**: a Vendor ID from the CSA,
Device Attestation Certificates (DAC/PAI) provisioned into a factory partition,
and passing the **Matter Test Harness**. `chip-cert` (built in the CHIP tree)
generates test certs and the Certification Declaration for development. This is
a program/compliance workflow, not day-to-day firmware — the matter-zigbee-ota
skill covers the conformance side. For dev you use test/development DACs shipped
with the SDK; do not ship those.

## Pin your references

Because these SDKs churn, drop version-pinned material next to this file:
- `git -C $CHIP_ROOT describe --tags` output and the esp-matter/NCS tags.
- The exact `.zap` regen command that worked (the script has been renamed
  across releases: `zap_regen_all.py` → `regen_all.py`).
- A known-good `MatterPostAttributeChangeCallback` and `app_cb` snippet for
  your device type.
- Your endpoint/cluster map (device type IDs, cluster IDs, attribute storage).

## Gotchas
- ZAP GUI and generated code drift silently — if the build sees a cluster the
  `.matter` doesn't declare, you forgot to regen or committed a stale
  `zap-generated/`.
- Attribute writes off the CHIP task corrupt state — always schedule onto it.
- Changing an endpoint's device type mid-project leaves orphaned mandatory
  clusters; re-derive from the example rather than patching.
- Test DACs/PAA are for development only; real commissioning against a
  production ecosystem needs CSA-issued attestation.
- One command per harness call; only a single read-only filter pipe is allowed.
