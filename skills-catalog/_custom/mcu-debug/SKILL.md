---
name: mcu-debug
description: >-
  Vendor-agnostic on-chip debug bring-up over SWD/JTAG. Use when the user wants
  to "attach a debugger", "set a breakpoint", "read a register / memory", "why
  does it hard fault", "flash and run over the probe", "capture RTT logs", or
  mentions probe-rs, OpenOCD, gdb, Cortex-Debug, ST-Link, J-Link, DAPLink/CMSIS-DAP,
  SWD, or JTAG. Thin wrapper that prefers the embedded-debugger MCP when
  available, otherwise drives probe-rs (list/info/run/attach) and OpenOCD+gdb.
  Covers SWD/JTAG basics, RTT logging, memory/register reads, and breakpoints
  across ST-Link / J-Link / DAPLink probes. probe-rs run/reset and OpenOCD
  reset/program HALT and RESET the target (and flashing writes it) — confirm the
  connected chip before running.
---

# On-chip debug bring-up (SWD/JTAG, vendor-agnostic)

Senior-engineer stance: debug bring-up is probe → transport → target. Confirm the
probe enumerates, the transport (SWD is 2-wire SWCLK/SWDIO; JTAG is 4/5-wire) is
right, and the chip is correctly identified before chasing firmware bugs. This is
a thin skill: if an **embedded-debugger MCP** is configured, prefer its tools for
attach/read/breakpoint operations and use the CLIs below as the fallback and for
anything the MCP doesn't cover.

## probe-rs — the fast modern path

One tool for list/info/flash/run/attach/RTT across ST-Link, J-Link, CMSIS-DAP/
DAPLink. Install: `cargo install probe-rs-tools` (or the released binary).

Enumerate probes (read-only — always do this first):

```
probe-rs list
```

Identify the target and confirm SWD/JTAG comms + core (read-only):

```
probe-rs info
```

Flash + run + attach RTT in one shot — this **erases/writes flash and resets the
target**, so confirm the `--chip` matches the connected part:

```
probe-rs run --chip STM32F401RETx target/thumbv7em-none-eabihf/release/app
```

Attach to an already-running target without resetting (least intrusive):

```
probe-rs attach --chip STM32F401RETx app.elf
```

`--chip` must match the real silicon; `probe-rs chip list | grep -i stm32f4`
finds the exact identifier. probe-rs streams RTT (`defmt` too) to the console
during run/attach — no extra viewer needed.

## OpenOCD + gdb — the universal fallback

When probe-rs lacks a chip or you need scriptable JTAG/tap control. Compose an
interface script + target script. Confirm the chip's target `.cfg` matches.

Start the gdb server (this connects to and can halt/reset the target):

```
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg
```

Swap `interface/stlink.cfg` for `interface/jlink.cfg` or `interface/cmsis-dap.cfg`
per probe; swap the target for your MCU family. Add `-c "transport select swd"` if
the target defaults to JTAG.

Attach gdb in a second shell and take control:

```
arm-none-eabi-gdb app.elf -ex "target extended-remote localhost:3333" -ex "monitor reset halt"
```

Core gdb ops once attached (all halt the CPU):

- `load` — flash the image (MUTATING).
- `break main` / `break file.c:42` — set breakpoints (hardware breakpoints are
  limited, typically 6 on Cortex-M — expect "cannot insert breakpoint" past that).
- `continue`, `next`, `step`, `finish`.
- `info registers`, `p/x $pc`, `p/x $lr` — CPU registers.
- `x/16xw 0x20000000` — dump memory (SRAM here); `x/8xw 0x40021000` for a
  peripheral block.
- `monitor reset halt` / `monitor reset init` — reset and hold at reset.

**Cortex-Debug** (VS Code) drives exactly this OpenOCD/J-Link + gdb stack behind a
GUI — same servers, same `monitor` commands; use it when the user is in VS Code.

## RTT logging

SEGGER RTT is the low-overhead log/console channel over SWD (no UART, negligible
timing impact). Firmware links SEGGER RTT (or defmt-rtt, or Zephyr
`CONFIG_LOG_BACKEND_RTT`).

- **probe-rs**: RTT is automatic during `run`/`attach` — logs stream to stdout.
- **OpenOCD**: `monitor rtt setup 0x20000000 0x8000 "SEGGER RTT"`,
  `monitor rtt start`, then `monitor rtt server start 9090 0` and connect a
  terminal to port 9090.
- **J-Link**: `JLinkRTTLogger` / RTT Viewer (see the nrfutil skill).

If RTT is silent: wrong control-block search range, firmware not initializing RTT,
or wrong channel.

## SWD/JTAG basics and wiring

- **SWD**: SWCLK + SWDIO + GND (+ optional SWO for trace/ITM, + reset). Two wires,
  the default for Cortex-M.
- **JTAG**: TCK/TMS/TDI/TDO(+TRST). Needed for chains of multiple TAPs or non-SWD
  parts.
- **NRST**: connect it so the probe can do a hardware reset; some parts need
  `connect under reset` to attach when firmware immediately sleeps or reconfigures
  the debug pins.
- Keep SWCLK slow on long/noisy wiring (`adapter speed 1000`); speed up once
  stable.

## Common failures

- **Probe not found**: driver/permissions (Linux udev rules for ST-Link/J-Link),
  cable, or another process owns the probe.
- **"Error connecting to target" / wrong IDCODE**: SWD vs JTAG mismatch, wrong
  target cfg/`--chip`, or debug port locked (readout protection — clearing it
  usually mass-erases; ST RDP, Nordic APPROTECT).
- **Attaches then target runs away / sleeps**: use `connect under reset` /
  `monitor reset halt` — firmware may be gating clocks to the debug port or
  entering deep sleep.
- **Breakpoint won't set**: out of hardware breakpoint slots, or code is in flash
  you're trying to soft-breakpoint (use HW breakpoints for flash).
- **Flash verify fails**: wrong flash algorithm/chip, or option bytes/write
  protection engaged.

## Workflow

`probe-rs list` / `openocd` startup to confirm the probe → `probe-rs info` /
`monitor reset halt` to confirm the chip and comms → flash + run (probe-rs run or
gdb `load`) → breakpoints, `info registers`, memory dumps to diagnose → RTT for
continuous logs. Prefer the embedded-debugger MCP for attach/read/breakpoint when
it's present; fall back to these CLIs otherwise. Remember run/reset/flash halt and
mutate the target — confirm it's the intended chip.
