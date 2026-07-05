---
name: meshtastic
description: >-
  Operate Meshtastic LoRa mesh nodes via the official `meshtastic` Python CLI and
  config YAML. Use to inspect or change node/channel/region config, manage
  channel PSKs and URLs, send/receive test messages, set position config, pick a
  serial/BLE/TCP interface, or flash firmware. Triggers on "meshtastic",
  "my mesh node", "LoRa node config", "set the region", "channel PSK",
  "seturl", "send a mesh message", "node info", "flash meshtastic firmware".
  Nodes are ESP32/nRF52 based, so this pairs with the esp32/nordic skills.
---

# Meshtastic node operations

Runbook for the official `meshtastic` Python CLI (`pip install meshtastic`).
There is no viable Meshtastic MCP, so this wraps the CLI as subprocess calls.
The CLI is GPL-licensed; **invoking it as a subprocess is fine** (no linking, no
derivative work) — we're a user of the tool, not redistributing it.

Nodes run ESP32 or nRF52 firmware, so firmware-level work pairs with the
esp32 / nordic skills.

## Golden rules

- **Read before write.** Always run `meshtastic --info` first and confirm you're
  talking to the intended node (check the node's user/long name and the
  interface) before any `--set`, `--seturl`, `--configure`, or flash.
- **Confirm every mutation by naming the target and effect.** State the node,
  the field, old value → new value, and the risk before running it. Get an
  explicit yes.
- **Channel / PSK / region changes can drop the node off the mesh.** Changing a
  channel's PSK, the channel URL (`--seturl`), or the LoRa region retunes or
  re-keys the radio — any node not updated in lockstep loses contact. If the
  node is remote (only reachable *over* the mesh), a bad change can strand it
  with no way back except physical access. Call this out explicitly and confirm.
- **Firmware flashing is the most destructive action.** `esptool` / `--flash`
  can brick a node or wipe its config. Confirm the exact firmware file, the
  target chip, and that the user has physical access + USB before proceeding.
  Back up config first (see below).
- **One command per call.** No `&&`, `||`, `;`, `$(...)`, backticks, or
  redirects. A single pipe into a read-only filter (`grep`, `head`) only. Chain
  multi-step config as separate calls.

## Interface selection

Pick exactly one transport; most subcommands accept it:

| Transport | Flag | When |
| --- | --- | --- |
| Serial (USB) | `--port /dev/ttyUSB0` (or `--port COM3`) | Node cabled in. Default if a single serial device is present. |
| BLE | `--ble <name-or-addr>` | Bluetooth-paired node, no cable. Slower. |
| TCP | `--host <ip>` | Node on WiFi/Ethernet exposing the API (`:4403`). |

If multiple serial devices are attached, always pass `--port` explicitly — don't
let it guess.

## Safe reads (run freely)

```
meshtastic --info                       # device, user, region, channels, modules
meshtastic --nodes                      # mesh node list: names, SNR, last heard
meshtastic --get lora                   # a config section (lora/position/power/...)
meshtastic --get lora.region
meshtastic --qr                         # show primary channel QR / URL (read)
```

`--get <config>` sections include `lora`, `position`, `power`, `network`,
`display`, `bluetooth`, `security`. Reading is non-mutating.

## Config changes (confirm first)

```
meshtastic --set lora.region US         # region — retunes radio, mesh-affecting
meshtastic --set device.role CLIENT     # node role
meshtastic --set position.gps_mode ENABLED
meshtastic --set-owner "Base HQ"        # long name
meshtastic --set-owner-short "MHQ"
```

`--set <field> <value>` writes one field. Show the current value from `--get`
first, then the new value.

## Channels and PSK (highest-risk config)

A channel = name + PSK + parameters, shareable as a URL. Getting this wrong
partitions the mesh.

```
meshtastic --ch-index 0 --ch-set psk random     # regenerate primary PSK
meshtastic --ch-index 0 --ch-set psk base64:<key>
meshtastic --ch-set name "ops" --ch-index 1     # add/rename a channel
meshtastic --ch-add "backup"
meshtastic --seturl "https://meshtastic.org/e/#<encoded>"   # replace channel set
```

- `--seturl` **replaces** the node's channel set with the URL's — every peer
  must import the same URL or they can't decrypt each other. Confirm you're
  distributing the new URL to all nodes before applying to a remote one.
- PSK options: `random` (new random key), `none` (unencrypted — warn strongly),
  `default`, or an explicit `base64:` / hex key. Rotating a PSK re-keys the
  channel: every node needs the new key or drops off.
- Treat channel URLs/PSKs as secrets — they grant mesh access. Don't paste them
  into logs or commit them.

## Send / receive text (testing)

```
meshtastic --sendtext "ping from ops runbook"          # broadcast on primary ch
meshtastic --sendtext "hi" --dest '!abcd1234'          # to a specific node id
meshtastic --sendtext "ch1 test" --ch-index 1
```

To watch incoming traffic, run the CLI/`meshtastic --listen` style read while
another node sends; use it to confirm a config change didn't break connectivity.

## Position config

```
meshtastic --get position
meshtastic --set position.gps_mode ENABLED             # or DISABLED for fixed
meshtastic --setlat 40.7128 --setlon -74.0060 --setalt 10   # fixed position
meshtastic --set position.position_broadcast_secs 900
```

Fixed position (GPS disabled + set lat/lon) suits stationary infrastructure
nodes; broadcasting a precise home location on a public channel is a privacy
consideration — mention it.

## Bulk config via YAML

Export, edit, and re-apply the whole config as YAML — good for reproducible /
version-controlled node setups (keep PSKs out of the committed copy):

```
meshtastic --export-config                 # dump current config as YAML (read)
meshtastic --configure node-ops.yaml       # apply a YAML config (MUTATING)
```

`--configure` applies many fields at once — review the YAML line by line and
confirm, since region/channel keys inside it carry the same mesh-dropping risk.
Export a backup with `--export-config` before applying anything or flashing.

## Firmware flashing (most destructive)

ESP32 and nRF52 flash differently — confirm the chip from `--info` first.

- **ESP32**: `esptool` over USB (`esptool.py write_flash ...`), or the web
  flasher. Wrong offset/image bricks the node.
- **nRF52** (e.g. RAK4631, T-Echo): drag-and-drop UF2 to the bootloader mass-
  storage volume, or DFU.

Before any flash: export config backup, confirm firmware version + variant
matches the exact board, confirm physical access. This is where the esp32 /
nordic skills take over for the low-level flashing detail.
