---
profile: firmware-esp32
projectType: firmware
stackComponents: [ESP-IDF/ESP32, ESPHome, generic embedded]
secretsBackend: env
securityToolingAuthorized: false
---

# Profile: firmware-esp32

ESP32-family firmware: ESP-IDF and/or ESPHome, PlatformIO. Covers
ESPHome + Meshtastic firmware and general ESP32 work.

## Skills enabled
esp32-workbench, esptool-flash, firmware-size, mcu-debug, embeddedskills,
esphome, i2c-bringup, sensor-fusion, meshtastic, systematic-debugging,
verification-before-completion, git-pr-workflow, docs-diagrams, skill-creator.
Add matter-device / zigbee-device / thread-device if the project targets
those protocols on C6/H2.

## MCP servers
esp-idf (built-in `idf.py mcp-server`), esp-idf-monitor, platformio,
embedded-debugger, context7, github.

## permissions.allow (starting point — merge, don't replace)
```json
[
  "Read(//**)",
  "Bash(idf.py build)",
  "Bash(idf.py size)",
  "Bash(idf.py size-components)",
  "Bash(idf.py menuconfig)",
  "Bash(idf.py set-target *)",
  "Bash(esptool.py chip_id)",
  "Bash(esptool.py flash_id)",
  "Bash(esphome config *)",
  "Bash(esphome compile *)",
  "Bash(pio run *)",
  "Bash(pio device list)",
  "Bash(git status)",
  "Bash(git diff *)"
]
```

## Safety notes to write into AGENTS.md ## Project
- Flashing (`idf.py flash`, `esptool.py write_flash`, `esphome run`) and
  `erase_flash` mutate the device — confirm the target port/device first.
- Note the exact ESP32 variant (S3/C6/H2/...) in AGENTS.md; GPIO maps and radio
  capabilities differ.
