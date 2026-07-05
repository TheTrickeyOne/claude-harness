---
name: matter-zigbee-ota
description: Build, sign, serve, and test OTA firmware updates and run conformance/certification for Matter, Thread, and Zigbee devices — the Matter OTA Provider/Requestor model and .ota image format, MCUboot/DFU signed images for ESP-IDF and nRF Connect SDK, the Zigbee2MQTT OTA index for Zigbee, plus CSA Matter Test Harness + chip-cert and Zigbee certification. Use when someone says "OTA update", "firmware update over the air", "OTA Provider/Requestor", "MCUboot", "DFU", "signed image", ".ota file", "ota-image-tool", "Z2M OTA", "Matter Test Harness", "chip-cert", "device certification", or "conformance". Complements matter-device, zigbee-device, and thread-device.
---

# matter-zigbee-ota

The update-and-certify layer for these stacks. Two jobs: (1) get a new image
safely onto a shipped device over the air, and (2) prove the device conforms.
Both are per-stack — Matter, Zigbee, and the MCU bootloader each have their own
mechanism.

**Versions move fast.** As of 2026-07: connectedhomeip ~v1.5.x (OTA tooling under
`src/app/ota-image-tool.py`), MCUboot as vendored by ESP-IDF v5.x/6.x and NCS
~v3.x, `zigbee-herdsman-converters` OTA index ~v26.78. Pin versions; verify tool
names/flags against the checked-out SDK. Keep signing keys and index entries out
of this skill dir (secrets) but keep the *commands* you verified here.

## Two layers of "update"

Don't conflate them:
- **Application-protocol OTA** (Matter OTA cluster / Zigbee OTA cluster) — how
  the *new image is discovered and transferred* over the mesh.
- **Bootloader / image format** (MCUboot, ESP app OTA, DFU) — how the device
  *validates, stores, and swaps* to the new image with rollback. The signed
  bootable artifact is the payload the protocol layer carries.
You generally need both: a bootloader-signed binary, wrapped in the
stack-specific OTA container, served to the device.

## Matter OTA

Model: an **OTA Requestor** (your device, endpoint 0 has the OTA Requestor
cluster) queries an **OTA Provider** (another Matter node — a hub, or the CHIP
`ota-provider-app` for dev) which announces and streams the image.

Build the `.ota` image from the raw app binary:
```
src/app/ota-image-tool.py create -v <VID> -p <PID> -vn <sw-ver-int> -vs "<sw-ver-str>" -da sha256 app.bin app.ota
```
The `-vn` software version integer must be **higher** than what's on the device,
and VID/PID must match the device's Basic Information — the Requestor rejects
otherwise. Inspect an image:
```
src/app/ota-image-tool.py show app.ota
```
Serve it for dev with the provider app:
```
chip/examples/ota-provider-app/linux/out/ota-provider-app --filepath app.ota
```
Then the device (already commissioned) is pointed at the provider's node ID and
runs the query→download→apply flow. Test path: bump `-vn`, build `.ota`, serve,
trigger the Requestor, confirm it downloads, applies, reboots to the new
version, and reports the new `SoftwareVersion`. The underlying stored image must
still be a valid bootloader image (below) or the swap fails and rolls back.

## Zigbee OTA

Zigbee uses the **OTA Upgrade cluster**. The coordinator/hub acts as OTA server;
the device (client) polls for a newer image matching its manufacturer code +
image type. Manufacturers ship an **OTA file** (`.ota`/`.zigbee` with the OTA
header: manufacturer code, image type, file version).

For the Zigbee2MQTT ecosystem the practical path is the **Z2M OTA index**:
- Z2M reads OTA metadata from `zigbee-herdsman-converters` (the
  `ota` index / `index.json` of published images keyed by manufacturer + image
  type + version).
- To ship an update for a custom device you either point Z2M at a local/override
  index (`ota:` config with your `.ota` URL) or PR your image metadata into the
  converters OTA index upstream.
- Trigger from the Z2M frontend/MQTT: "Check for updates" → "Update"; watch the
  device download and re-announce a higher `SW build`.
Test by publishing a higher-`fileVersion` OTA image, updating the index, and
confirming the client pulls and applies it.

## Thread devices

Thread nodes update via whatever runs on top — a Matter-over-Thread device uses
**Matter OTA** (above) over the Thread transport; a bare OpenThread node uses
your own CoAP/UDP transfer plus the MCU bootloader below. There's no separate
"Thread OTA cluster."

## Bootloader / signed image layer

This is where rollback safety lives; get it right or a bad OTA bricks the field.

### ESP-IDF
- **App OTA**: dual OTA partitions (`ota_0`/`ota_1`) + `otata` data; the app
  writes the incoming image with `esp_ota_*` and marks it valid, else rolls
  back. Partition table must have the OTA slots.
- **Secure Boot + Signed OTA**: enable Secure Boot v2 and app signing in
  `menuconfig`; images are signed with your RSA/ECDSA key and rejected if the
  signature fails. Optionally MCUboot as the bootloader (ESP-IDF supports it) for
  a unified flow with NCS. Building/flashing the *bootloader* mutates the device
  irreversibly (Secure Boot burns eFuses) — confirm the target board and that
  you intend to burn eFuses before flashing a secure-boot bootloader.

### nRF Connect SDK
- **MCUboot** is the standard bootloader; images are **signed** with an ECDSA/RSA
  key (`mcuboot`'s `imgtool.py sign ...`, or the NCS `west` build does it via
  the `SB_CONFIG`/sysbuild MCUboot config and `mcuboot_CONF`).
- Update transport is **SMP/DFU** (Bluetooth or serial) or, for Matter, the
  Matter OTA image which NCS packages as an MCUboot-signed binary.
- The signed artifact is `app_update.bin` (a.k.a. `dfu_application.zip` for
  BLE DFU). This is what you wrap in the Matter `.ota` for a Matter-over-Thread
  Nordic device.

Rule: the bytes served by Matter/Zigbee OTA must be a **signed, bootloader-valid
image** for the target, or the swap is rejected and the device rolls back.

## Conformance & certification (separate program, know the tools)

- **Matter**: certification runs through the **CSA** — you need a CSA-issued
  Vendor ID, production **DAC/PAI** attestation certs in a factory partition, and
  a pass on the **Matter Test Harness** (the CSA-hosted/containerized test suite,
  successor tooling to the older CHIP cert harness). For development, `chip-cert`
  (built in the CHIP tree) generates test PAA/PAI/DAC chains and the
  **Certification Declaration**:
  ```
  chip-cert gen-att-cert --type d --subject-cn "Dev DAC" ...
  ```
  Test certs are dev-only — production attestation is issued under your CSA
  membership. Certification is a compliance milestone, not part of the daily
  build.
- **Zigbee**: certification is via the Connectivity Standards Alliance's Zigbee
  program (Zigbee Compliant Platform + product cert), with test houses running
  the Zigbee test tool against the ZCL/BDB behavior. Manufacturer code allocation
  comes from the CSA. Also a program milestone, separate from firmware iteration.

## Test the update path (all stacks)
1. Note the running version on the device.
2. Build a **higher-version** signed image and wrap it (`.ota` for Matter,
   OTA-header file for Zigbee).
3. Serve it (provider app / Z2M index / DFU).
4. Trigger, watch download → apply → reboot.
5. Confirm the reported version incremented and the device still functions
   (attributes, commissioning intact). Force a bad image once to confirm
   rollback works.

## Pin your references
- SDK versions + the exact `ota-image-tool.py` / `imgtool sign` invocations used.
- Partition table (ESP) / sysbuild MCUboot config (NCS) that produced a working
  update.
- Your version-numbering scheme (integer `-vn` vs. string) — mismatches silently
  block updates.
- Keep signing keys OUT of the repo; reference their location, not the keys.

## Gotchas
- Matter OTA silently no-ops if `-vn` isn't strictly greater or VID/PID mismatch.
- Serving an unsigned/wrong-key image → device downloads then refuses to boot it
  and rolls back; looks like "OTA did nothing."
- Zigbee update won't offer if manufacturer code / image type in the OTA header
  don't match the device.
- Secure Boot eFuse burns are irreversible — confirm before flashing that
  bootloader.
- Dev DAC/test certs must never ship; production needs CSA attestation.
- One command per harness call; a single read-only filter pipe only.
