---
name: power-profiling
description: >-
  Measure and cut MCU power consumption. Use when the user asks to "measure
  current draw", "profile power", "why is my battery draining", "how long will
  this run on a coin cell", "reduce sleep current", "the device won't reach deep
  sleep", or mentions PPK2, Joulescope, Otii, uA/mA measurement, esp_pm, deep
  sleep, or Zephyr power management. Wraps Nordic Power Profiler Kit II
  (ppk2-api-python), Joulescope (pyjoulescope), and Otii (otii-tcp-client) for
  scripted current capture, and covers ESP32 esp_pm + deep-sleep, Zephyr PM,
  wake sources, and a sleep-mode checklist. Correlates measured current with
  firmware state. Measurement is passive; PPK2 source mode powers the DUT — set
  voltage before enabling output.
---

# Power profiling and low-power design

Senior-engineer stance: you can't optimize what you don't measure. Get a
current-vs-time trace correlated to firmware state first; the sleep-current
offenders are almost always a peripheral or GPIO you forgot, not the CPU.

## Instruments

### Nordic Power Profiler Kit II (PPK2)

Two modes: **Ampere meter** (measure current of an externally powered DUT) and
**Source meter** (PPK2 supplies VDD and measures). Source mode drives the DUT —
set the voltage before enabling output or you can brown-out/over-volt the board.

GUI: nRF Connect for Desktop → Power Profiler. Scripted:

```
pip install ppk2-api
```

```python
from ppk2_api.ppk2_api import PPK2_API
ppk2 = PPK2_API("/dev/ttyACM0")     # confirm the correct serial port first
ppk2.get_modifiers()
ppk2.use_source_meter()             # or use_ampere_meter()
ppk2.set_source_voltage(3300)       # mV — set BEFORE toggling power
ppk2.toggle_DUT_power("ON")
ppk2.start_measuring()
samples = ppk2.get_data()           # raw; convert with get_samples()
```

Range spans nA to ~1 A, so it resolves both deep-sleep leakage and active bursts.

### Joulescope

High dynamic range (nA to A) with fast autoranging — best when the same trace
must capture 2 uA sleep and 200 mA radio TX. GUI or:

```
pip install joulescope
```

```python
from joulescope import scan_require_one
js = scan_require_one(config="auto")
js.open()
data = js.read(contiguous_duration=2.0)   # current & voltage arrays
js.close()
```

Use the GUI's marker tools to integrate charge (mAh/uAh) over a window — that's
your real battery-life number.

### Otii (Qoitech)

Otii Arc/Ace: programmable power supply + high-res measurement + UART capture on
one timeline. Automate via TCP:

```
pip install otii-tcp-client
```

Drive supply voltage, record current, and log the DUT's UART on the same axis so
firmware `printf`s line up with current spikes — the cleanest way to correlate
state to draw.

## Correlating current with firmware state

The whole game. Techniques:

- **GPIO markers**: toggle a spare pin at state transitions (enter/exit sleep,
  radio on/off). Capture it on the analyzer's digital channel (PPK2 has 8 logic
  inputs) or a scope alongside current. Instant visual attribution.
- **UART/RTT timeline**: Otii logs UART inline; for others, timestamp both
  streams from the host and align.
- **Averaging windows**: measure average current per phase (sleep, wake, sense,
  transmit), multiply by phase duration, sum to a per-cycle charge budget.

## Sleep-mode checklist (why you're not hitting datasheet uA)

1. **GPIOs**: floating inputs float and leak; drive unused pins or enable
   pulls. Disable pulls that fight external circuits during sleep.
2. **Peripherals**: sensors/flash/radio left in run mode dominate. Put sensors in
   their own low-power/standby mode; power-gate rails you can.
3. **Regulators/LEDs**: power LEDs and always-on LDOs are classic coin-cell
   killers. Check quiescent current of every regulator.
4. **Clocks**: high-freq oscillators left running. Switch to the low-power RC/
   LFXO for RTC wake.
5. **Pull-ups on buses**: I2C pull-ups sink current if a line is held low or a
   device is powered while the bus rail isn't. Size and gate them.
6. **Debug/USB**: an attached debugger or live USB peripheral inflates sleep
   current — measure a truly standalone board.
7. **Brown-out / RAM retention**: retaining more RAM costs more; retain only what
   you need across deep sleep.

## ESP32 low-power

- **esp_pm** (dynamic freq scaling + automatic light sleep):
  `CONFIG_PM_ENABLE`, `esp_pm_configure()` with max/min CPU freq and
  `light_sleep_enable`. Use `esp_pm_lock` to prevent sleep during critical work.
- **Deep sleep**: `esp_deep_sleep_start()`. Wake sources: timer
  (`esp_sleep_enable_timer_wakeup`), ext0/ext1 GPIO, ULP, touch. Only RTC
  memory/peripherals survive; the app restarts from reset.
- Cut sleep current: `esp_deep_sleep_disable_rom_logging`, isolate RTC GPIOs
  (`rtc_gpio_isolate`) for pins with external pulls, power down RTC peripherals
  you don't need. ESP32 deep sleep is ~10 uA; if you see mA, a rail or GPIO is
  still live.

## Zephyr power management

- **System PM**: `CONFIG_PM=y` auto-enters idle states based on the next timeout;
  define states in devicetree (`power-states`, `min-residency-us`).
- **Device PM**: `CONFIG_PM_DEVICE=y`; drivers suspend/resume; use
  `pm_device_runtime_*` so idle devices power down.
- **Wake sources**: GPIO interrupts, RTC/timer, comparator. On nRF, verify with
  the PPK2 that the SoC actually reaches System OFF/idle (single-digit uA), not a
  higher idle state.
- Prevent premature sleep with `pm_policy_state_lock_get()` around timing-critical
  sections.

## Workflow

1. Wire the DUT into PPK2/Joulescope/Otii; add a GPIO state marker in firmware.
2. Capture one full duty cycle (sleep → wake → work → sleep).
3. Integrate charge per phase; identify the dominant phase.
4. If sleep current is high, walk the sleep checklist. If active is high, shorten
   radio-on time / lower CPU freq / batch work.
5. Re-measure; confirm the per-cycle uAh dropped and compute battery life.
