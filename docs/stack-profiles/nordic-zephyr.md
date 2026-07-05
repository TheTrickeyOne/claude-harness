---
profile: nordic-zephyr
projectType: firmware
stackComponents: [Nordic/Zephyr, Matter, Thread, Zigbee, generic embedded]
secretsBackend: env
securityToolingAuthorized: false
---

# Profile: nordic-zephyr

Nordic nRF Connect SDK / Zephyr firmware, including Matter/Thread/Zigbee device
development on nRF52/53/54.

## Skills enabled
zephyr, nrfutil, mcu-debug, firmware-size, embeddedskills, matter-device,
zcl-codegen, thread-device, zigbee-device, matter-zigbee-ota, sensor-fusion,
power-profiling, systematic-debugging, verification-before-completion,
git-pr-workflow, docs-diagrams, skill-creator.

## MCP servers
nordic (official), embedded-debugger (probe-rs/RTT), context7, github.

## permissions.allow (starting point — merge, don't replace)
```json
[
  "Read(//**)",
  "Bash(west build *)",
  "Bash(west list *)",
  "Bash(west boards *)",
  "Bash(nrfutil device list)",
  "Bash(nrfutil --version)",
  "Bash(probe-rs list)",
  "Bash(probe-rs info *)",
  "Bash(git status)",
  "Bash(git diff *)"
]
```

## Safety notes to write into AGENTS.md ## Project
- `west flash`, `nrfutil device program`, `probe-rs run`, and RTT that resets
  the target mutate hardware — confirm the connected device first.
- Matter/Thread/Zigbee here is DEVICE-FIRMWARE development (clusters, ZAP,
  OpenThread API), not commissioning. Record the exact nRF target and SDK
  version in AGENTS.md — these SDKs move fast.
