---
name: esptool-flash
description: >-
  Flash, read, provision, and inspect ESP32-family chips at the bootloader level.
  Use when the user mentions esptool, esptool.py, espefuse, "flash the ESP32",
  "erase flash", "read out the firmware", "burn efuse", "read chip id / mac",
  "flash encryption", "secure boot", "partition table", "OTA slots", or
  esp_secure_cert. Wraps esptool.py (chip_id, flash_id, read_flash, write_flash,
  erase_flash, read_mac) and espefuse.py (reads are safe; burning efuses is
  PERMANENT and can brick or lock the chip). Separates safe reads from
  destructive writes. write_flash/erase_flash MUTATE the device and efuse burns
  are IRREVERSIBLE — confirm the serial port and the exact operation first.
---

# ESP32 flashing and provisioning (esptool / espefuse)

Senior-engineer stance: esptool operates below your app, straight on the SPI
flash and efuses. Reads are harmless; writes overwrite flash; **efuse burns are
one-way and can permanently lock or brick the chip.** Always confirm the port and
the operation before anything destructive.

Install (ESP-IDF ships it; standalone): `pip install esptool`. Recent versions
use subcommands without the `.py` (`esptool chip_id`); the `.py` form still works.
Find the port: it's a USB-serial device — `ls /dev/tty.usbserial-*` (macOS) or
`/dev/ttyUSB*` / `/dev/ttyACM*` (Linux). **Confirm it's the ESP32, not another
adapter, before writing.**

## Safe reads (non-destructive) — start here

Identify the chip, revision, features, MAC:

```
esptool.py --port /dev/ttyUSB0 chip_id
```

Flash size and SPI flash JEDEC id (right size matters for partition layout):

```
esptool.py --port /dev/ttyUSB0 flash_id
```

MAC address (useful for provisioning/inventory):

```
esptool.py --port /dev/ttyUSB0 read_mac
```

Read flash back to a file — dump the whole 4 MB (adjust size), fully safe:

```
esptool.py --port /dev/ttyUSB0 read_flash 0x0 0x400000 flash_backup.bin
```

**Always take a full `read_flash` backup before any write or erase.** If flash
encryption is enabled the dump is ciphertext (still worth keeping).

## Destructive writes (MUTATING) — confirm port + intent

Erase the entire flash (wipes app, NVS, everything):

```
esptool.py --port /dev/ttyUSB0 erase_flash
```

Write the standard 3-image layout (bootloader / partition table / app) at the
canonical offsets — offsets differ per target (ESP32 bootloader at 0x1000,
ESP32-S3/C3 at 0x0):

```
esptool.py --port /dev/ttyUSB0 write_flash 0x1000 bootloader.bin 0x8000 partition-table.bin 0x10000 app.bin
```

`idf.py flash` wraps this with the correct offsets from your build — prefer it
when you have the IDF build tree; drop to raw esptool for prebuilt binaries or
field provisioning. `--erase-all`, `-z` (compress), and `--after no_reset` are the
common flags.

## Partition tables and OTA layout

- The partition table lives at 0x8000 (default). Dump and parse it:
  `esptool.py read_flash 0x8000 0xC00 pt.bin`, then `gen_esp32part.py pt.bin` to
  read it as CSV.
- **OTA layout**: `factory` (or `ota_0`) + `ota_1` app slots plus an `otadata`
  partition that records the active slot. OTA writes the inactive slot and flips
  `otadata`; a bad image rolls back. Slot sizes must exceed your app — a too-small
  OTA partition is a classic "OTA fails silently" bug.
- **NVS** holds Wi-Fi creds/config; erasing flash wipes it. Preserve it by backing
  up its region before `erase_flash`, or erase only the app region with a targeted
  `write_flash`.

## esp_secure_cert / provisioning

The `esp_secure_cert` partition stores device certs/keys (often DS-peripheral
protected) for TLS/cloud onboarding. Provision it with `configure_esp_secure_cert.py`
(esp-secure-cert-tool), then flash that partition image to its offset with
`write_flash`. Keep per-device cert images separate and never reuse keys across
units.

## espefuse — READ freely, BURN never casually

Efuses are OTP: burning is **permanent and irreversible**. It's how you enable
flash encryption, secure boot, disable JTAG, and set the MAC — and how you
permanently lock yourself out if wrong.

Read the full efuse summary (safe):

```
espefuse.py --port /dev/ttyUSB0 summary
```

Dump raw efuse blocks (safe):

```
espefuse.py --port /dev/ttyUSB0 dump
```

**Burning (IRREVERSIBLE — hard confirm before running):** commands like
`burn_efuse`, `burn_key`, `burn_bit`, and enabling `FLASH_CRYPT_CNT` /
`SECURE_BOOT_EN` cannot be undone. espefuse requires `--do-not-confirm` to skip
its own prompt — do NOT pass that flag unless the user has explicitly, per-device,
confirmed the exact efuse and value. Before any burn: state which efuse, why it's
permanent, that JTAG/readout may be disabled forever, and get explicit go-ahead.
When in doubt, don't burn.

## Flash encryption / secure boot notes

- Once **flash encryption** is enabled, plain `write_flash` of an unencrypted
  image won't boot — you must flash pre-encrypted images or use
  `--encrypt`, and development vs release mode behave differently (release
  disables re-flashing over UART).
- **Secure boot v2** rejects unsigned bootloaders/apps; sign with your key
  (`espsecure.py sign_data`). Lose the signing key and you can't update the field.
- Verify state with `espefuse.py summary` before assuming a chip is unlocked.

## Common failures

- **"Failed to connect / no serial data"**: hold BOOT (GPIO0 low) during reset to
  enter download mode; auto-reset circuit may be absent on bare modules. Wrong
  port or a busy monitor also causes this.
- **Boots to bootloader loop**: wrong bootloader offset for the target, or app
  flashed at the wrong address.
- **App won't boot after flash encryption/secure boot**: image not
  encrypted/signed with the enrolled key.

## Workflow

`chip_id` + `flash_id` to identify → `read_flash` full backup → `write_flash`
(or `idf.py flash`) with target-correct offsets → verify by booting/monitor. Treat
every efuse burn as a deliberate, confirmed, irreversible act.
