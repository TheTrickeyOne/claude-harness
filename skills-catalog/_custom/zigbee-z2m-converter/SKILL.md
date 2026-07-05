---
name: zigbee-z2m-converter
description: Author a zigbee-herdsman-converters external converter so a CUSTOM or unsupported Zigbee device works in Zigbee2MQTT / Home Assistant — the modern DefinitionWithExtend + modernExtend API (m.onOff, m.numeric, m.enumLookup, m.binary, ...), plus lower-level fromZigbee/toZigbee/exposes when a datapoint isn't covered. Covers the Z2M external_converters/ workflow, reading the device interview/exposes to reverse-engineer clusters, and finishing with an upstream PR to Koenkk/zigbee-herdsman-converters. Use when a Zigbee device shows up as "unsupported", when someone says "Z2M converter", "external converter", "zigbee-herdsman-converters", "modernExtend", "fromZigbee/toZigbee", "device not in Z2M", "add device to Zigbee2MQTT", or "Tuya datapoint converter".
---

# zigbee-z2m-converter

Fastest win in this catalog: no firmware build, just a JS/TS definition that
teaches Zigbee2MQTT how to talk to a device. Self-contained — you need a running
Z2M and the physical device paired.

**Versions move fast.** As of 2026-07 `zigbee-herdsman-converters` is ~v26.78 and
the **modernExtend** API is the default authoring surface; the old
`fromZigbee`/`toZigbee` array style still works and is still needed for
uncovered datapoints. Pin the Z2M version you target; verify helper names
(`m.onOff`, `m.numeric`, …) against the installed `zigbee-herdsman-converters` —
they get added/renamed. Keep a copy of your working converter in this skill dir.

## The two authoring APIs

1. **`modernExtend`** (preferred) — a `Definition` whose `extend:` array is
   composed of small building blocks. Each block wires the cluster binding,
   reporting config, `fromZigbee`, `toZigbee`, and `exposes` for one feature.
   Common blocks (imported as `import * as m from 'zigbee-herdsman-converters/lib/modernExtend'`):
   - `m.onOff({powerOnBehavior: false})`
   - `m.numeric({name, cluster, attribute, valueMin, valueMax, unit, description, access})`
   - `m.enumLookup({name, cluster, attribute, lookup})`
   - `m.binary({name, cluster, attribute, valueOn, valueOff})`
   - `m.temperature()`, `m.humidity()`, `m.battery()`, `m.identify()`,
     `m.electricityMeter()`, `m.iasZoneAlarm(...)` for standard clusters.
2. **Low-level `fromZigbee` / `toZigbee` / `exposes`** — drop to this when a
   feature isn't a standard cluster (most **Tuya** devices, which tunnel
   everything over a manufacturer cluster as numbered *datapoints*). Use the
   `tuya` helpers (`tuya.modernExtend.tuyaMagicPacket()`,
   `tuya.fromZigbee.*`, `tuya.valueConverter.*`, `tuya.exposes.*`).

Prefer modernExtend; add raw fz/tz only for the datapoints it can't express.

## Reverse-engineer the device first

Pair the device to Z2M, then read what the stack already knows:
- **Interview** — Z2M logs the endpoints, input/output clusters, and
  manufacturer/model (`manufacturerName`, `modelID` from the Basic cluster).
  These two strings are your `fingerprint`/`zigbeeModel`.
- **Exposes / dev console** — in the Z2M frontend, the device page → "Dev
  console" lets you read/write attributes and watch reports live. Toggle the
  physical device and watch which cluster/attribute (or Tuya DP) changes. That
  mapping *is* the converter.

Note the exact `modelID` and `manufacturerName` — the converter matches on them.

## Minimal converter (modernExtend)

`external_converters/my_switch.js`:
```js
const m = require('zigbee-herdsman-converters/lib/modernExtend');

module.exports = {
    zigbeeModel: ['TS0001'],            // Basic cluster modelID
    model: 'ACME-SW1',                  // your product code
    vendor: 'ACME',
    description: 'Single-channel smart switch',
    extend: [
        m.onOff({powerOnBehavior: true}),
    ],
};
```
A custom-attribute example (numeric config on a real cluster):
```js
extend: [
    m.onOff(),
    m.numeric({
        name: 'reporting_interval',
        cluster: 'genBasic',
        attribute: {ID: 0xf000, type: 0x21},
        valueMin: 1, valueMax: 3600, unit: 's',
        access: 'STATE_SET',
        description: 'Sensor reporting interval',
    }),
],
```
For a Tuya device you typically add `tuya.modernExtend.tuyaMagicPacket()` and one
`tuya.modernExtend.dpNumeric/dpEnumLookup/dpBinary(...)` per datapoint number.

TypeScript form uses `DefinitionWithExtend` and `export default` — same shape,
typed. Match whichever the upstream repo uses when you go to PR.

## Load it in Z2M (external_converters/)

Modern Z2M auto-loads any file in the `external_converters/` folder of the Z2M
data dir (no `configuration.yaml` list needed in current versions; older ones
used `external_converters:`). Steps:
1. Put the file in `<z2m-data>/external_converters/`.
2. Restart Zigbee2MQTT.
3. Re-interview the device (device page → "Reconfigure"/"Interview"). It should
   now resolve to your `model` and render the `exposes` you defined.
Iterate: edit → restart → watch the device page. The dev console confirms
reads/writes land on the right cluster/attribute.

## Test against the real device

- Confirm every expose round-trips: toggle in Home Assistant / MQTT and verify
  the physical device reacts (toZigbee), and physical actuation reports back
  (fromZigbee).
- Check reporting configuration actually applied (Z2M log shows `configure`
  binding + reporting setup). If values only update on manual read, your
  reporting/`m.numeric` access or binding is off.
- Verify battery/last-seen for sleepy devices — you may need
  `m.battery()` and correct polling.

## Ship it upstream (PR to Koenkk/zigbee-herdsman-converters)

External converters are a staging area; the endgame is a PR so everyone gets the
device:
1. Fork `Koenkk/zigbee-herdsman-converters`, add your definition under
   `src/devices/<vendor>.ts` (TypeScript, `DefinitionWithExtend`), matching the
   file's existing style and imports.
2. `npm run build` and `npm test` — the repo has model/expose snapshot tests;
   add/adjust as prompted.
3. Lint (`npm run lint`), open the PR with the device model, a photo/link, and
   the interview output. Maintainers ask for the `manufacturerName`/`modelID` and
   a description of each expose.
Once merged and released, users drop the external converter.

## Pin your references
- Target Z2M + `zigbee-herdsman-converters` version.
- The device interview dump (clusters, modelID, manufacturerName).
- Your working converter file (both the external-converter JS and the upstream
  TS form).

## Gotchas
- `zigbeeModel`/fingerprint must match the Basic cluster strings exactly —
  whitespace and case matter; some devices report a raw `modelID` like `TS0601`
  shared across many products (fingerprint on `manufacturerName` too).
- Tuya devices ignore standard clusters — don't waste time on `genOnOff`; find
  the datapoint numbers.
- External converter loaded but device still "unsupported" → it didn't
  re-interview, or the model string mismatches.
- `access` flags control read vs write vs report; wrong flags make an expose
  read-only or invisible.
- This is JS/Node, not firmware — no flashing, no device mutation here.
- One command per harness call; a single read-only filter pipe only.
