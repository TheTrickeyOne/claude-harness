---
name: pico-sdk
description: >-
  Build, flash, and debug Raspberry Pi Pico / RP2040 / RP2350 firmware. Use when
  the user mentions Pico, Pico W, Pico 2, RP2040, RP2350, pico-sdk, picotool, UF2,
  BOOTSEL, debugprobe, or asks to build/flash bare-metal firmware for these
  chips. Wraps the pico-sdk CMake build flow, picotool (info/load/reboot/save),
  OpenOCD with rp2040.cfg/rp2350.cfg over a Raspberry Pi Debug Probe (CMSIS-DAP),
  and UF2 drag-drop flashing. Covers BOOTSEL mass-storage vs SWD debugging.
  Loading firmware (picotool load, UF2 copy, OpenOCD program) MUTATES the device
  flash — confirm the target serial/port and that it's the intended board first.
---

# Raspberry Pi Pico / RP2040 / RP2350 firmware

Senior-engineer stance: the Pico has two independent paths — the built-in BOOTSEL
USB bootloader (zero hardware, drag-drop) and SWD via a debug probe (real
debugging, RTT/gdb). Use BOOTSEL to get going, SWD once you need to step code.

## Toolchain setup

Need: `pico-sdk` cloned, `PICO_SDK_PATH` exported, arm-none-eabi-gcc, CMake,
`picotool`, and (for debug) OpenOCD built with the CMSIS-DAP + rp2040/rp2350
support (the Raspberry Pi fork). Pico 2 / RP2350 needs a current SDK (≥2.0) and
matching OpenOCD.

Point the build at the SDK (per-shell; the harness resets cwd between calls, so
prefer absolute paths and single commands):

```
export PICO_SDK_PATH=/opt/pico-sdk
```

## Build (CMake)

Standard out-of-tree build. Select the board with `PICO_BOARD`
(`pico`, `pico_w`, `pico2`, `pico2_w`):

```
cmake -S . -B build -DPICO_BOARD=pico -DPICO_SDK_PATH=/opt/pico-sdk
```

```
cmake --build build -j
```

Products in `build/`: `app.elf` (for gdb/OpenOCD), `app.uf2` (for BOOTSEL),
`app.bin`/`.hex`, plus `.dis`/`.map`. For RP2350 also mind the ARM vs RISC-V core
choice (`PICO_PLATFORM=rp2350-arm-s` or `rp2350-riscv`) and the security/signing
options if you enabled them.

## Flashing

### Path A — BOOTSEL + UF2 (no probe)

1. Hold BOOTSEL, plug in USB (or hold BOOTSEL and tap RUN/reset). Board enumerates
   as `RPI-RP2` (RP2040) / `RP2350` mass-storage.
2. Copy the UF2 onto it; the board reboots into the app automatically. This
   **overwrites flash** — make sure it's the right board.

Copying is a normal file write to the mounted volume. Confirm the mount is the
Pico, not another USB drive, before overwriting.

### Path B — picotool over USB

`picotool` talks to a device that's in BOOTSEL mode, or to a running app that
linked `pico_stdio_usb` / enabled the reset interface.

Identify what's connected (read-only, always safe — do this first):

```
picotool info -a
```

Force a running board into BOOTSEL so picotool can load (needs the reset iface):

```
picotool reboot -u
```

Load firmware (MUTATES flash) — `-x` executes after, `-f`/`-F` forces if a device
is running:

```
picotool load -x build/app.uf2
```

Read flash back out to a file (safe, non-destructive):

```
picotool save -a firmware_backup.uf2
```

If multiple boards are attached, target one with `--bus`/`--address` from
`picotool info -a` — don't guess.

### Path C — OpenOCD over SWD (Debug Probe / picoprobe)

Wire a Raspberry Pi Debug Probe (or a second Pico running debugprobe firmware) to
the target's SWD pins (SWCLK, SWDIO, GND). This gives flashing **plus** halt/step
debug and RTT — the real workflow once you're past blink.

Flash via OpenOCD (`program ... verify reset exit` writes and resets — MUTATING):

```
openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg -c "adapter speed 5000; program build/app.elf verify reset exit"
```

For RP2350 swap the target script:

```
openocd -f interface/cmsis-dap.cfg -f target/rp2350.cfg -c "adapter speed 5000; program build/app.elf verify reset exit"
```

## Debugging with gdb

Leave OpenOCD running as a gdb server (this halts/resets the target):

```
openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg -c "adapter speed 5000"
```

Then attach in a second shell:

```
gdb-multiarch build/app.elf -ex "target extended-remote localhost:3333" -ex "monitor reset init"
```

`load` to flash from gdb, `break main`, `continue`, `monitor reset halt`, etc. On
RP2040 (dual Cortex-M0+) OpenOCD exposes both cores — pick with
`monitor targets` / `thread`.

## RTT / stdio for logs

- Quickest: link `pico_stdio_usb` (or `pico_stdio_uart`) and `printf`; read the
  CDC port with any serial monitor.
- With SWD: SEGGER RTT works through OpenOCD (`rtt setup`, `rtt start`,
  `rtt server start 9090 0`) for logging without a spare UART.

## Gotchas

- **RP2350 is not RP2040**: different OpenOCD target script, SDK ≥2.0, optional
  RISC-V core, and secure-boot/signing can block unsigned images — flash then
  nothing runs is usually a signing/partition config mismatch.
- **No external flash bootloader**: the RP2040/RP2350 boot ROM loads from QSPI
  flash via the second-stage `boot2`; a corrupt image just drops back to BOOTSEL,
  which is your recovery path — hold BOOTSEL and reflash.
- **Pico W radio** needs the CYW43 driver + firmware pulled in via `PICO_BOARD=pico_w`.
- **Probe not detected**: check `picotool info`/`openocd` see the CMSIS-DAP
  adapter; wrong wiring or an old OpenOCD without RP support is the usual cause.

## Workflow

CMake configure with the right `PICO_BOARD` → build → for iteration use BOOTSEL
UF2 or `picotool load`; for debugging wire the Debug Probe and use OpenOCD+gdb
with RTT. Confirm the target board/port before any load/program step.
