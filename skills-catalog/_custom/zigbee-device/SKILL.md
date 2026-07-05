---
name: zigbee-device
description: Build Zigbee end-device / router / coordinator firmware with esp-zigbee-sdk (ESP32-H2, ESP32-C6) — define endpoints, clusters, attributes, set up attribute reporting, and pick a device role using the esp_zb_... ZCL API. Optional docs-only branches for Silicon Labs EmberZNet (Simplicity Studio, closed source) and Nordic ZBOSS (maintenance). Use when building a Zigbee sensor/switch/bulb, when someone says "esp-zigbee-sdk", "esp_zb_", "Zigbee end device", "ZED/ZR/ZC", "attribute reporting", "Zigbee cluster firmware", "EmberZNet", "ZBOSS", or "Zigbee HA endpoint". Pairs with the ESP-IDF build flow; for making the device work in Zigbee2MQTT see zigbee-z2m-converter.
---

# zigbee-device

Firmware for a Zigbee node. Primary path is **esp-zigbee-sdk** on ESP32-H2 /
ESP32-C6 (native 802.15.4). EmberZNet and ZBOSS are covered as docs-grounded
branches only. Getting the device to expose usefully in Zigbee2MQTT/Home
Assistant is a separate skill (zigbee-z2m-converter).

**Versions move fast.** As of 2026-07 esp-zigbee-sdk tracks ESP-IDF v5.x/6.x and
wraps Espressif's ZBOSS-based `esp-zboss-lib` (a managed component). Pin your
ESP-IDF + esp-zigbee-sdk versions and verify the `esp_zb_*` signatures against
the installed component — the API has churned across 1.x. Keep verified
snippets in this skill dir.

## Device roles

Choose at build time; it shapes power, network behavior, and which
`esp_zb_*_cfg` you use:
- **Coordinator (ZC)** — forms the network, holds the trust center. One per net.
  You rarely build this for a product (the hub is the coordinator), but it's
  used for gateways.
- **Router (ZR)** — mains-powered, always on, relays traffic. Bulbs, plugs.
- **End Device (ZED)** — leaf node. **Sleepy End Device (SED)** polls its parent
  and sleeps between; the low-power battery-sensor case. Non-sleepy ED stays
  awake.

esp-zigbee-sdk config macros mirror this:
`ESP_ZB_ZED_CONFIG()`, `ESP_ZB_ZR_CONFIG()`, `ESP_ZB_ZC_CONFIG()`. For a SED set
`nwk_cfg.zed_cfg.keep_alive` and the poll interval, and enable light sleep in
IDF power management.

## Project shape (ESP-IDF)

Start from an example under `esp-zigbee-sdk/examples/`:
`esp_zigbee_HA_sample/HA_on_off_light`, `HA_on_off_switch`,
`HA_temperature_sensor`, `esp_zigbee_sleepy_end_device`,
`esp_zigbee_gateway`.

Add the SDK as a managed component (`idf_component.yml`):
```
espressif/esp-zigbee-lib: "*"
espressif/esp-zboss-lib: "*"
```
Build/flash (flashing **mutates the device** — erases and rewrites flash;
confirm the serial port maps to the intended board):
```
idf.py set-target esp32h2
```
```
idf.py -p /dev/ttyACM0 build flash monitor
```
A full erase also wipes the Zigbee NVRAM (network keys, bindings) and forces a
re-join — confirm the target first:
```
idf.py -p /dev/ttyACM0 erase-flash
```

## The Zigbee task and stack init

Everything runs on the Zigbee stack task. Standard skeleton:
```
esp_zb_platform_config_t cfg = { .radio_config = ..., .host_config = ... };
esp_zb_platform_config(&cfg);
xTaskCreate(esp_zb_task, "Zigbee_main", 4096, NULL, 5, NULL);
```
Inside `esp_zb_task`:
```
esp_zb_cfg_t zb_cfg = ESP_ZB_ZED_CONFIG();
esp_zb_init(&zb_cfg);
/* build endpoint list (below) */
esp_zb_device_register(ep_list);
esp_zb_core_action_handler_register(zb_action_handler);
esp_zb_set_primary_network_channel_set(ESP_ZB_TRANSCEIVER_ALL_CHANNELS_MASK);
esp_zb_start(false);
esp_zb_stack_main_loop();
```
Signals (join/leave/steer) arrive in `esp_zb_app_signal_handler(...)` — you must
define it; handle `ESP_ZB_BDB_SIGNAL_DEVICE_FIRST_START` /
`ESP_ZB_BDB_SIGNAL_STEERING` to start network steering (BDB commissioning).

## Endpoints, clusters, attributes

Build the model bottom-up with the `esp_zb_*` cluster API, or use the HA
convenience helpers.

Convenience (recommended for standard device types):
```
esp_zb_on_off_light_cfg_t light_cfg = ESP_ZB_DEFAULT_ON_OFF_LIGHT_CONFIG();
esp_zb_ep_list_t *ep_list = esp_zb_on_off_light_ep_create(HA_ENDPOINT, &light_cfg);
```
Manual (custom device / extra clusters):
```
esp_zb_attribute_list_t *basic = esp_zb_basic_cluster_create(&basic_cfg);
esp_zb_basic_cluster_add_attr(basic, ESP_ZB_ZCL_ATTR_BASIC_MANUFACTURER_NAME_ID, mfg);
esp_zb_cluster_list_t *clusters = esp_zb_zcl_cluster_list_create();
esp_zb_cluster_list_add_basic_cluster(clusters, basic, ESP_ZB_ZCL_CLUSTER_ROLE_SERVER);
/* add identify, on_off, temperature_meas, etc. */
esp_zb_ep_list_t *ep_list = esp_zb_ep_list_create();
esp_zb_endpoint_config_t ep_cfg = { .endpoint = HA_ENDPOINT,
  .app_profile_id = ESP_ZB_AF_HA_PROFILE_ID,
  .app_device_id = ESP_ZB_HA_TEMPERATURE_SENSOR_DEVICE_ID, ... };
esp_zb_ep_list_add_ep(ep_list, clusters, ep_cfg);
```
Set the endpoint's `app_device_id` to the correct HA device type — this is what
coordinators use to fingerprint the device.

## Reporting

Two ways an attribute value reaches the coordinator:

1. **Configured reporting** — the coordinator (or you) sets min/max interval and
   reportable change; the stack sends reports automatically when the attribute
   changes. Mark the attribute reportable and update its value:
```
esp_zb_zcl_set_attribute_val(HA_ENDPOINT,
  ESP_ZB_ZCL_CLUSTER_ID_TEMP_MEASUREMENT,
  ESP_ZB_ZCL_CLUSTER_ROLE_SERVER,
  ESP_ZB_ZCL_ATTR_TEMP_MEASUREMENT_VALUE_ID,
  &value, false);
```
   Setting the value triggers a report if reporting is configured and the change
   exceeds the reportable delta.
2. **Manual report** — push immediately with
   `esp_zb_zcl_report_attr_cmd_req(&report_cmd)` (build an
   `esp_zb_zcl_report_attr_cmd_t` naming the endpoint/cluster/attr).

Wrap any stack call made from another task in
`esp_zb_lock_acquire(...)` / `esp_zb_lock_release()` — the stack is not
thread-safe.

## Handling incoming commands / writes

Register `esp_zb_core_action_handler_register(handler)` and switch on
`callback_id`:
- `ESP_ZB_CORE_SET_ATTR_VALUE_CB_ID` — coordinator wrote an attribute (e.g.
  On/Off write → drive the relay). Cast `message` to
  `esp_zb_zcl_set_attr_value_message_t*`.
- report/read-response callbacks for client-role clusters.
Return `ESP_OK` to accept.

## EmberZNet (Silicon Labs) — docs-only branch

Closed source; built in **Simplicity Studio** with the Gecko SDK on EFR32.
Workflow is GUI-first: create a **ZCL Advanced Platform (ZAP)** config in the
project (Studio embeds ZAP), enable clusters, and implement the generated
`emberAf...` callbacks (e.g. `emberAfOnOffClusterServerAttributeChangedCallback`).
Attribute reporting is configured in the ZAP reporting table. Build/flash with
Studio or `commander flash` (Simplicity Commander) — flashing rewrites the
EFR32, confirm the J-Link. There is no open CLI SDK; drive this from Silicon Labs
docs (AN1325/UG491 series) and the in-Studio generated headers, not from memory.

## Nordic ZBOSS — maintenance, low priority

Nordic's Zigbee (nRF Connect SDK `zigbee`/ZBOSS) is in maintenance — Nordic
steers new designs to Matter/Thread. If you must: build with `west` from
`sdk-nrf` Zigbee samples (`samples/zigbee/light_bulb`, `light_switch`), define
clusters via ZBOSS `ZB_ZCL_DECLARE_*` macros, and flash with `west flash`
(rewrites the SoC — confirm the board). Treat it as legacy; prefer esp-zigbee-sdk
for greenfield 802.15.4 Zigbee.

## Pin your references
- ESP-IDF + esp-zigbee-lib + esp-zboss-lib versions (`idf_component.yml` lock).
- A known-good `esp_zb_task` + `esp_zb_app_signal_handler` + action handler for
  your role.
- Your endpoint/cluster/attribute map and HA device ID.

## Gotchas
- Calling `esp_zb_*` off the stack task without the lock corrupts state.
- SED that never sleeps: check IDF power management + keep-alive/poll config.
- `erase-flash` drops the network — the device must re-commission (re-pair).
- Wrong `app_device_id` makes coordinators mis-fingerprint the device; fix it
  before writing a Z2M converter.
- One command per harness call; a single read-only filter pipe only.
