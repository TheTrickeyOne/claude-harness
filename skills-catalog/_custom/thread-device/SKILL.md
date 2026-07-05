---
name: thread-device
description: Build Thread node firmware against the OpenThread C API (otInstance, otDataset..., IPv6/UDP/CoAP, FTD/MTD/SED roles, sleepy-end-device polling) on ESP-IDF esp_openthread or nRF Connect SDK samples/openthread — and distinguish end-device firmware from an RCP + otbr-agent border router (spinel co-processor). Use when writing a raw Thread node (not Matter, not Zigbee), when someone says "OpenThread", "otInstance", "otDataset", "RCP", "ot-rcp", "border router", "otbr-agent", "sleepy end device", "MTD/FTD", "esp_openthread", "spinel", "CoAP over Thread", or "join a Thread network in firmware". Emptiest niche — no public skill exists; ground in OpenThread docs.
---

# thread-device

Firmware for a Thread node at the OpenThread **C API** level — you link
`libopenthread`, own an `otInstance`, and drive the network from code. This is
the layer *under* Matter-over-Thread and Zigbee's sibling on 802.15.4. `ot-ctl`
and the OpenThread CLI are test harnesses; this skill is about the API.

**Versions move fast.** As of 2026-07 OpenThread is a rolling `main` with dated
tags (~`thread-reference-2026xxxx` / the 1.4 Thread spec era), vendored into
ESP-IDF (`esp_openthread`) and nRF Connect SDK. Pin the OpenThread SHA your SDK
uses (`git -C <openthread> rev-parse HEAD`) and verify `ot*` signatures against
the checked-out headers in `include/openthread/`. Keep verified snippets here.

## Device roles (pick before you build)

Thread roles map to power/duty-cycle, and to which library features you compile
in via `OPENTHREAD_FTD` / `OPENTHREAD_MTD`:
- **FTD (Full Thread Device)** — routing-eligible, keeps full routing tables,
  can become Router/Leader. Mains-powered. Build with the FTD lib.
- **MTD (Minimal Thread Device)** — never routes, always a child. Smaller lib.
  Two sub-flavors:
  - **MED (Minimal End Device)** — rx-on-when-idle, listens continuously.
  - **SED (Sleepy End Device)** — rx-off between polls; radio sleeps. The
    battery-sensor case. You set the **poll period** and the parent buffers for
    it: `otLinkSetPollPeriod(instance, periodMs)`; child timeout via
    `otThreadSetChildTimeout`.

## Init the stack

Common host-agnostic startup:
```c
otInstance *instance = otInstanceInitSingle();
otAppCliInit(instance);            /* optional: CLI for bring-up */
/* ... configure dataset, IP, callbacks ... */
while (!otSysPseudoResetWasRequested()) {
    otTaskletsProcess(instance);
    otSysProcessDrivers(instance);
}
```
On an RTOS the platform layer (ESP/Zephyr) runs the tasklet + driver pump for
you on a dedicated task; you supply callbacks and app logic. **The OT instance is
single-threaded** — call `ot*` only from the OT task, or marshal onto it (ESP:
`esp_openthread_task_switching_lock_acquire`; NCS: the OT lock /
`openthread_api_mutex_lock`).

## Network credentials — the dataset

A node joins by having the **Active Operational Dataset** (network name, PAN ID,
extended PAN ID, channel, network key, PSKc). In firmware you either receive it
(commissioning / MeshCoP joiner) or set it directly for a fixed deployment:
```c
otOperationalDataset ds;
memset(&ds, 0, sizeof(ds));
otDatasetCreateNewNetwork(instance, &ds);      /* or fill fields yourself */
otDatasetSetActive(instance, &ds);
```
Then bring the interface up and start Thread:
```c
otIp6SetEnabled(instance, true);
otThreadSetEnabled(instance, true);
```
Watch role changes with `otSetStateChangedCallback` and check
`otThreadGetDeviceRole(instance)` (`OT_DEVICE_ROLE_CHILD/ROUTER/LEADER`). For
in-field joining use the MeshCoP joiner API (`otJoinerStart(...)`) with a
commissioner on the network, or import a dataset over the border router.

## Application traffic: UDP / CoAP over IPv6

Thread is IPv6; each node has a Mesh-Local EID and link-local addresses. Typical
sensor firmware sends CoAP to a service:
- **UDP:** `otUdpOpen`/`otUdpBind`/`otUdpSend` with an `otMessage` from
  `otUdpNewMessage`. Read the peer via the `otMessageInfo`.
- **CoAP:** `otCoapStart(instance, port)`, build a request with
  `otCoapMessageInit`/`otCoapMessageAppendUriPathOptions`, send with
  `otCoapSendRequest(instance, msg, &messageInfo, responseHandler, ctx)`.
  Server side: register resources with `otCoapAddResource`.
Get addresses to talk to via SRP/DNS (`otSrpClient*`, `otDnsClient*`) or
service discovery; the border router advertises the mesh to the LAN.

## End-device firmware vs. RCP + otbr-agent (the key distinction)

These are two *different* builds and it's easy to conflate them:

- **End-device / SoC firmware (this skill's main job)** — OpenThread runs
  **fully on the chip**: MAC/PHY, IPv6, and your app in one image. The 802.15.4
  radio and the stack are on the same MCU. Build for MTD/FTD, flash, done.
- **RCP (Radio Co-Processor)** — the chip runs **only** the 802.15.4 radio and
  speaks the **Spinel** protocol over UART/SPI to a host. The full OpenThread
  stack runs on the host (a Linux box / Raspberry Pi) as part of the **Border
  Router**. You flash `ot-rcp` firmware to the radio chip and run
  **`otbr-agent`** on the host, which owns the `otInstance` and bridges Thread ↔
  IPv6 LAN (this is what a Matter-over-Thread setup and every hub uses).

Rule of thumb: a *product node* is an SoC/NCP build; a *border router* is
RCP-firmware + `otbr-agent`. Don't build RCP firmware when you meant a sensor,
and don't expect an RCP image to run your app — it can't, the app is on the host.

## Flavor: ESP-IDF (esp_openthread)

Examples: `esp-idf/examples/openthread/ot_cli`, `ot_rcp`, `ot_br`, and the
`esp_ot_sleepy_device`. `esp_openthread` wraps the stack; you init with
`esp_openthread_init(&config)` and run the mainloop on the OT task. Boards:
ESP32-H2 / C6 (native radio) for SoC nodes; ESP32-S3 + an H2/C6 RCP for the ESP
Thread Border Router. Build/flash (flashing **mutates the device** — erases and
rewrites flash; confirm the port maps to the intended board):
```
idf.py set-target esp32h2
```
```
idf.py -p /dev/ttyACM0 build flash monitor
```
Full erase wipes stored Thread credentials/dataset (forces re-join) — confirm
first:
```
idf.py -p /dev/ttyACM0 erase-flash
```

## Flavor: nRF Connect SDK (samples/openthread)

Zephyr-based. Samples: `samples/openthread/cli`, `coprocessor` (the RCP/NCP
build), plus the OpenThread integration used by Matter/CoAP samples. Build with
`west`; the OT lib comes from the NCS-vendored OpenThread. Flash reprograms the
SoC — confirm the board:
```
west build -b nrf52840dk/nrf52840 samples/openthread/cli
```
```
west flash
```
The `coprocessor` sample is the RCP image for an nRF-based border router — same
SoC-vs-RCP distinction as above.

## Pin your references
- OpenThread SHA/tag your SDK vendors (`git -C <ot> rev-parse HEAD`).
- Whether you're building SoC (FTD/MTD) or RCP — state it in AGENTS.md.
- A known-good init + dataset-set + state-changed-callback snippet.
- Your poll period / child timeout for SEDs.

## Gotchas
- Calling `ot*` off the OT task races the stack — always take the platform lock.
- SED that drains battery: `otLinkSetPollPeriod` too short, or you left rx-on
  (MED not SED), or app timers keep the CPU/radio awake.
- Built `ot-rcp` and wondered why your app never runs — RCP has no app; the
  stack is on the host `otbr-agent`.
- No dataset = never attaches; confirm `otDatasetSetActive` ran and
  `otThreadGetDeviceRole` leaves `DISABLED/DETACHED`.
- Wrong FTD/MTD lib selection vs. role causes link/build mismatches.
- One command per harness call; a single read-only filter pipe only.
