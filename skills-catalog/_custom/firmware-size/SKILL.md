---
name: firmware-size
description: >-
  Analyze and shrink firmware flash/RAM footprint on embedded targets. Use when
  the user asks "what's eating my flash", "why is my binary so big", "reduce
  firmware size", "the image doesn't fit", "analyze stack usage", "how much RAM
  am I using", "diff two firmware builds", or wants to inspect a .elf/.map file.
  Wraps bloaty (google/bloaty size profiler and A/B diff), puncover (per-function
  stack + static RAM), idf.py size / idf.py size-components (ESP-IDF), and
  west build -t rom_report / ram_report (Zephyr). Covers linker map reading and
  concrete reduction tactics (LTO, log level, unused components, -Os, GC
  sections). Read-only analysis — no device is touched.
---

# Firmware size analysis and reduction

You are a senior embedded engineer sizing down an image. Everything here is
read-only static analysis of build artifacts — no hardware is flashed. The goal
is always: measure first with numbers, then attack the biggest contributors.

## Which tool for which question

| Question | Tool |
|---|---|
| What symbols/sections eat flash & RAM, ranked? | `bloaty` |
| Did my change grow/shrink the image, and where? | `bloaty new.elf -- old.elf` |
| Per-function stack depth, static RAM by symbol | `puncover` |
| ESP-IDF total + per-component breakdown | `idf.py size`, `idf.py size-components` |
| Zephyr ROM/RAM report | `west build -t rom_report` / `ram_report` |
| Ground truth on section placement | the `.map` file |

## bloaty — the first thing to run

Install: `pip install --user bloaty` or build from google/bloaty. Point it at the
linked `.elf` (not the stripped `.bin` — you want symbols).

Symbols ranked by size, both VM (runtime footprint) and FILE (flash):

```
bloaty -d symbols build/firmware.elf
```

Roll up by compile unit to find the offending source file:

```
bloaty -d compileunits build/firmware.elf
```

Sections (`.text` = code flash, `.rodata` = const flash, `.data` = initialized
RAM copied from flash, `.bss` = zeroed RAM):

```
bloaty -d sections build/firmware.elf
```

Nest dimensions to see, e.g., which sections each compile unit lands in:

```
bloaty -d compileunits,sections build/firmware.elf
```

### A/B diff — did my change cost bytes?

Build baseline, stash the elf, build again, then diff (new first, `--` then old):

```
bloaty -d symbols build/firmware.elf -- /tmp/baseline.elf
```

Positive numbers = growth. This is the fastest way to catch a size regression in
review or bisect which commit bloated the image.

## puncover — stack and static RAM per function

bloaty tells you code/data size; puncover tells you **stack usage**, which bloaty
can't. Essential when you're chasing stack overflows on a small target.

Build with stack-usage output first (adds `.su` files next to objects):

```
CFLAGS += -fstack-usage
```

Then run puncover against the elf + build tree; it serves a browser UI:

```
puncover --elf_file build/firmware.elf --src_root . --build_dir build
```

Open the printed URL. Sort by "Stack" for worst-case per-frame usage (note:
GCC's static estimate excludes recursion and indirect calls — treat deep call
chains and function pointers as unbounded). Sort by "Static" for `.bss`/`.data`
hogs. Cross-check the deepest stack user against your task/thread stack sizes.

## ESP-IDF

Total image and DRAM/IRAM/flash breakdown:

```
idf.py size
```

Per-component ranking — the single most useful ESP-IDF size command, shows which
managed component or library is the pig:

```
idf.py size-components
```

Drill into one archive's symbols:

```
idf.py size-files
```

## Zephyr

West wraps the toolchain's size scripts into interactive HTML/text reports:

```
west build -t rom_report
```

```
west build -t ram_report
```

These give a tree by file/symbol. For a raw view, run `bloaty` directly on
`build/zephyr/zephyr.elf` — same tool, more slicing options.

## Reading the .map file

The linker map is ground truth when a symbol placement surprises you. It is
large; grep it rather than reading top to bottom. (Harness rule: one command per
call, and only a single read-only filter pipe — no chaining.)

Find where a fat symbol was pulled in and by whom:

```
grep -n "my_big_table" build/firmware.map
```

Look at the `Discarded input sections` block to confirm `--gc-sections`
dropped dead code, and the `Memory Configuration` block for region sizes/overflow.

## Reduction tactics, roughly in order of payoff

1. **Log strings dominate `.rodata`.** Raise the log level. ESP-IDF:
   `CONFIG_LOG_MAXIMUM_LEVEL` / `CONFIG_LOG_DEFAULT_LEVEL`. Zephyr:
   `CONFIG_LOG_MAX_LEVEL`. Consider deferred/dictionary logging. Format strings
   and `printf` float support (`%f`) pull in large libc chunks — drop them if
   unused.
2. **Optimize for size.** `-Os` (ESP-IDF `CONFIG_COMPILER_OPTIMIZATION_SIZE`,
   Zephyr `CONFIG_SIZE_OPTIMIZATIONS`). Measure — `-Os` occasionally *grows* hot
   inlined code paths.
3. **LTO** collapses cross-TU dead code. ESP-IDF has per-component LTO options;
   Zephyr `CONFIG_LTO=y`. Verify with a bloaty diff — LTO can complicate debug.
4. **Garbage-collect sections:** `-ffunction-sections -fdata-sections` +
   `-Wl,--gc-sections` so the linker drops unreferenced functions. Confirm in the
   map's discarded-sections list.
5. **Drop unused components/subsystems.** Use `size-components` / `rom_report` to
   find a whole library you don't need (mbedTLS cipher suites, BT, mDNS, JSON) and
   `menuconfig` it out. Trim mbedTLS/TLS cipher lists aggressively.
6. **newlib nano** for printf/malloc (ESP-IDF `CONFIG_NEWLIB_NANO_FORMAT`,
   Zephyr `CONFIG_NEWLIB_LIBC_NANO` / minimal libc) saves several KB.
7. **RAM specifically:** move const tables to flash (`const` / `PROGMEM`-style
   placement, ESP-IDF `__attribute__((section(".rodata")))`), shrink oversized
   static buffers and per-task stacks (size them from puncover, not by guessing),
   cut heap high-water reservations.

## Workflow

1. `bloaty -d compileunits` and `idf.py size-components` / `rom_report` to find
   the top 3 contributors.
2. Attack the biggest with a targeted tactic above.
3. Rebuild, `bloaty ... -- baseline.elf` to confirm the delta went the right way.
4. For RAM/stack problems, run puncover and size stacks off worst-case frames.
