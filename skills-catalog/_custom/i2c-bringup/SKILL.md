---
name: i2c-bringup
description: >-
  Bring up and debug I2C/SPI sensors and peripherals from a Linux host (Pi or
  dev board), often over SSH. Use when the user says "scan the I2C bus", "the
  sensor doesn't ACK", "wrong I2C address", "read/write a register", "decode
  this I2C/SPI capture", "dump a register map", or mentions i2cdetect, i2cget,
  i2cset, i2ctransfer, or a logic analyzer / sigrok. Wraps Linux i2c-tools
  (i2cdetect, i2cget, i2cset, i2ctransfer) for live bus poking and sigrok-cli
  for logic-analyzer protocol decode. Register-map-driven debugging and address
  scanning. i2cset/i2ctransfer WRITE to a live device and can change config or
  brick a sensor — confirm bus number and address before any write.
---

# I2C / SPI peripheral bring-up

Senior-engineer stance: bring-up is a chain — power, address/ACK, register access,
then data. Test each link in order. Existing MCP options for raw bus poking are
immature, so this wraps the proven Linux CLIs plus sigrok for signal-level truth.

Run these on a Linux host wired to the peripheral (commonly a Raspberry Pi over
SSH). Enable the controller first (`raspi-config` → I2C, or `dtparam=i2c_arm=on`).

## Read-only vs mutating

- **Safe (read):** `i2cdetect`, `i2cget`, `i2ctransfer` with only read segments,
  `i2cdump`.
- **Mutating (write):** `i2cset`, and `i2ctransfer` with a write segment. These
  hit real registers — a wrong register/value can reconfigure or damage the part.
  Always confirm the bus number and 7-bit address, and check the datasheet, before
  writing.

## Step 1 — scan for the device

List buses:

```
i2cdetect -l
```

Scan bus N (usually 1 on a Pi). `-y` skips the interactive confirm:

```
i2cdetect -y 1
```

A cell shows the 7-bit address that ACKed. No device where you expect one ⇒
wiring/power, missing pull-ups, wrong address strap, or the part holds the bus.
`UU` = a kernel driver already owns that address (unbind it or use the driver).

Caveat: `i2cdetect` probes with quick-write/read; on a few write-sensitive parts
that itself can trigger action. `-r` (read mode) is gentler when in doubt.

## Step 2 — confirm identity via WHO_AM_I

Read the ID register (address 0x68, register 0x75 example — MPU-style):

```
i2cget -y 1 0x68 0x75
```

Compare against the datasheet's expected value. Match ⇒ addressing and basic
comms are good. Mismatch ⇒ wrong device, wrong register width, or bus errors.

Byte vs word, and read modes:

```
i2cget -y 1 0x68 0x75 b
```

## Step 3 — dump the register map

Eyeball the whole map to spot config/status at a glance:

```
i2cdump -y 1 0x68
```

For 16-bit register addresses (many modern sensors), `i2cdump` can't; use
`i2ctransfer` (below).

## Step 4 — write a register (MUTATING)

Confirm bus + address + register + value first. Wake an MPU6050 (PWR_MGMT_1 =
reg 0x6B, value 0x00):

```
i2cset -y 1 0x68 0x6B 0x00
```

Read it back with `i2cget` to verify the write took.

## Step 5 — arbitrary transactions with i2ctransfer

The tool for 16-bit register pointers, block reads, and repeated-start sequences.
`w<n>@addr` = write n bytes; `r<n>` = read n bytes; a `w` immediately followed by
`r` produces a repeated start (the standard "set pointer, then read" pattern).

Write 2-byte register pointer 0x0100, repeated-start, read 4 bytes from 0x40:

```
i2ctransfer -y 1 w2@0x40 0x01 0x00 r4
```

Pure read of 6 bytes (no pointer set):

```
i2ctransfer -y 1 r6@0x40
```

Add `-v` to see the segments. Omit `-y` if you want a confirmation prompt before
a write segment executes.

## Logic-analyzer decode with sigrok-cli

When ACK/timing/SPI-mode is in question, capture the wire. sigrok-cli drives most
cheap logic analyzers (fx2lafw for the ubiquitous Saleae clones, plus real Saleae,
DreamSourceLab, etc.).

List devices / probe the connected analyzer:

```
sigrok-cli --scan
```

Capture and decode I2C (map your channels to SCL/SDA):

```
sigrok-cli -d fx2lafw --config samplerate=1M --samples 1M -C D0,D1 -P i2c:scl=D0:sda=D1 -A i2c
```

`-P` selects the protocol decoder and pin mapping; `-A i2c` prints only the
decoded annotation (address, R/W, data, ACK/NAK) instead of raw samples. Sample
at ≥10x the bus clock (≥1 MHz for 100 kHz I2C).

SPI decode (clk/mosi/miso/cs):

```
sigrok-cli -d fx2lafw --config samplerate=8M --samples 4M -C D0,D1,D2,D3 -P spi:clk=D0:mosi=D1:miso=D2:cs=D3 -A spi
```

List a decoder's options/annotation classes when you need to tune polarity/word
size:

```
sigrok-cli --show --protocol-decoder spi
```

## Common failure signatures

- **No ACK anywhere**: no power, SDA/SCL swapped, or missing pull-ups (need
  ~4.7k to the correct VDD; none = lines never rise, everything NAKs).
- **ACK but garbage data**: wrong register width (8- vs 16-bit pointer), wrong
  endianness, or clock-stretching the master ignores.
- **Intermittent NAKs / stuck bus**: pull-ups too weak for the capacitance/speed,
  or a slave holding SDA low (power-cycle; clock out 9 pulses to release).
- **SPI reads all 0x00/0xFF**: wrong CPOL/CPHA (mode 0 vs 3), CS not asserted,
  MISO not connected, or clock too fast. sigrok settles it immediately.

## Workflow

`i2cdetect` (does it ACK?) → `i2cget` WHO_AM_I (right part?) → `i2cdump` /
`i2ctransfer` reads (register map sane?) → `i2cset`/`i2ctransfer` writes to
configure → if any step is ambiguous, put sigrok on the wire and read the truth.
