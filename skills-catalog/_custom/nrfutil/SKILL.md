---
name: nrfutil
description: >-
  Program, reset, and DFU Nordic nRF5x/nRF91 devices, and capture logs over
  SEGGER J-Link RTT. Use when the user mentions nrfutil, nrfjprog, nRF52/nRF53/
  nRF91, J-Link, JLinkExe, JLinkRTTLogger, RTT logging, "program the nRF",
  "erase the chip", "recover a locked nRF", "build a DFU package", or Nordic OTA
  DFU. Wraps nrfutil (device list/program/reset, plus nrfutil dfu), the nrfjprog
  equivalents, and J-Link tools (JLinkExe, JLinkRTTLogger) for RTT capture and
  DFU package creation/signing. Programming, erasing, and recover MUTATE the
  target — confirm the connected device (serial number / snr) before writing.
---

# Nordic flashing, DFU, and J-Link RTT logging

Senior-engineer stance: on Nordic you'll juggle three toolchains — modern
`nrfutil` (subcommand-based), legacy `nrfjprog` (still everywhere), and SEGGER
J-Link (the actual probe + RTT). Know which does what and always target by serial
number when more than one probe is attached.

## Identify the target FIRST (read-only)

Never program blind. List connected debuggers/devices and their serial numbers:

```
nrfutil device list
```

nrfjprog equivalent:

```
nrfjprog --ids
```

Use the printed serial number (`--serial-number <snr>` for nrfutil,
`--snr <snr>` for nrfjprog) on every subsequent command when multiple probes are
present. Reading device/registers is safe; program/erase/recover are not.

Install nrfutil core + the device command: `nrfutil install device` (nrfutil is
now a launcher that installs subcommand plugins).

## Programming (MUTATING — confirm snr)

Flash a HEX (auto-erases the pages it writes; `--options chip_erase_mode` to wipe
all):

```
nrfutil device program --firmware app.hex --serial-number 683112345
```

Reset after programming:

```
nrfutil device reset --serial-number 683112345
```

nrfjprog equivalents (still common in scripts/CI):

```
nrfjprog --program app.hex --sectorerase --verify --reset --snr 683112345
```

Full chip erase (wipes app + SoftDevice + UICR — destructive):

```
nrfjprog --eraseall --snr 683112345
```

### Recovering a locked device (MUTATING, wipes everything)

APPROTECT/readback-protected parts refuse normal access. `recover` erases the
entire chip (including UICR and protection) to regain access — a deliberate, total
wipe:

```
nrfjprog --recover --snr 683112345
```

`nrfutil device recover --serial-number <snr>` does the same. Confirm the device
before running — there is no undo and all firmware/keys are gone.

## SoftDevice + app (BLE stack)

BLE apps run on top of a Nordic SoftDevice at flash base. Flash the SoftDevice
hex, then the app hex (built against that SD version and its flash/RAM offsets).
Mismatched SD/app offsets = hard fault on boot. For nRF Connect SDK (Zephyr),
`west flash` wraps nrfjprog/nrfutil and handles this — prefer it when you have the
NCS build tree; drop to raw tools for prebuilt hex or production programming.

## DFU package creation and signing

Nordic OTA DFU (both legacy nRF5 SDK bootloader and NCS MCUboot) consumes a signed
package/image.

nRF5 SDK secure bootloader — build a signed `.zip` DFU package with nrfutil:

```
nrfutil pkg generate --hw-version 52 --sd-req 0x0100 --application app.hex --application-version 1 --key-file private.pem dfu.zip
```

(`nrfutil pkg`/`dfu` are the legacy plugins; install via `nrfutil install nrf5sdk-tools`.)
Generate the signing key once with `nrfutil keys generate private.pem` and put the
matching public key in the bootloader. **The private key signs every future update
— guard it; losing it means no more OTA to fielded units.**

NCS/MCUboot instead produces `app_update.bin` (signed with `mcuboot/root-rsa` key
via imgtool) served over SMP DFU — different toolchain, same principle: image
signed with the key baked into the bootloader.

Perform the DFU (serial/BLE transport):

```
nrfutil dfu serial --package dfu.zip --port /dev/ttyACM0
```

## J-Link RTT logging

RTT is the fast, non-intrusive log/console channel over SWD — no spare UART, no
timing hit. Firmware writes with SEGGER RTT (or Zephyr `CONFIG_USE_SEGGER_RTT` +
`CONFIG_LOG_BACKEND_RTT`).

Interactive session — connect, then open the RTT viewer/terminal:

```
JLinkExe -device nRF52840_xxAA -if SWD -speed 4000 -autoconnect 1
```

Inside JLinkExe, `connect` establishes the session (this halts/controls the
target). SEGGER's `JLinkRTTViewer` (GUI) or the CLI `JLinkRTTClient` attaches to
the terminal channel.

Capture RTT straight to a file (great for long unattended log runs):

```
JLinkRTTLogger -Device nRF52840_xxAA -If SWD -Speed 4000 -RTTChannel 0 rtt_log.txt
```

Pick the right `-Device` (exact part) or connection fails. Speed 4000 kHz is a
safe default; drop it if the SWD wiring is long/noisy.

## Common failures

- **"No emulator connected" / device not found**: probe not enumerated, wrong
  cable, or another tool holds the J-Link — check `nrfutil device list`.
- **Programs but won't run / hard fault at boot**: SoftDevice/app offset or RAM
  start mismatch, or wrong SD version vs `--sd-req`.
- **Access denied / can't read**: APPROTECT enabled — `--recover` (full wipe) to
  clear it.
- **RTT shows nothing**: firmware not initializing RTT, wrong channel, or the
  RTT control-block search range doesn't cover where it landed in RAM
  (`-RTTAddress` / set search range).
- **DFU rejected**: package signed with a key the bootloader doesn't trust, or
  `--sd-req`/hw-version mismatch.

## Workflow

`nrfutil device list` to get the snr → `device program` + `device reset` (or
`west flash`) targeting that snr → attach `JLinkRTTLogger`/RTT Viewer for logs.
For field updates, build a signed DFU package and guard the signing key. Treat
`--recover`/`--eraseall` as deliberate total wipes.
