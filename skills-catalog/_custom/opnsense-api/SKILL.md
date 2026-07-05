---
name: opnsense-api
description: Operate an OPNsense firewall/router through its REST API — inspect and change firewall rules, aliases, NAT, interfaces, DHCP leases, and gateways — plus network-hygiene review (over-broad rules, VLAN segmentation, exposed management/services, WAN exposure). Use when working with OPNsense (firewall rules, aliases, NAT, port-forwards, VLANs, DHCP, gateways) or auditing network security posture. Trigger on "opnsense", "firewall rule", "port forward", "NAT", "alias", "VLAN", "DHCP lease", "gateway down", "am I exposed", "any-any rule", "apply config", even when the API isn't named explicitly.
---

# opnsense-api

OPNsense is driven by a REST API where the model is **stage then apply**: writes
mutate the staged config, and nothing takes effect until you call the
component's apply/reconfigure endpoint. This skill is **read-first** and
**lockout-aware**: a bad firewall or NAT change can cut your own access, so
prefer reversible paths and always know the apply step.

## Golden rules
1. **Read before write.** Enumerate current rules/aliases/interfaces before
   changing them; know exactly which rule/UUID you're touching.
2. **Firewall changes can lock you out.** Never narrow/remove a rule that could
   include your own management path without confirming an out-of-band way back
   in. Prefer add-then-verify-then-remove over edit-in-place on access rules.
3. **Stage ≠ live — call out the apply step.** A POST to add/edit/delete a rule
   only stages it. It goes live only after the apply endpoint (e.g.
   `POST /api/firewall/filter/apply`). Always state whether you're staging or
   applying, and confirm before applying.
4. **Confirm every mutation.** Adding/editing/deleting a firewall rule, alias,
   or NAT/port-forward, and any `apply`/`reconfigure`, changes reachability —
   name the exact object and effect and get a yes first.
5. API calls obey the harness command rule — one command per call, and a single
   pipe into a read-only filter only (no `&&`, `||`, `;`, `$()`, backticks, or
   redirects). Use one `curl` GET/POST per call.

## Inspect (safe — GET endpoints)
- Firewall rules: `GET /api/firewall/filter/searchRule`
- Aliases: `GET /api/firewall/alias/searchItem` ·
  `GET /api/firewall/alias/get` (resolve an alias's members)
- NAT / port-forwards: `GET /api/firewall/source_nat/searchRule` and the
  port-forward search endpoint
- Interfaces: `GET /api/interfaces/overview/interfacesInfo` ·
  `GET /api/diagnostics/interface/getInterfaceStatistics`
- DHCP leases: `GET /api/dhcpv4/leases/searchLease`
- Gateways: `GET /api/routes/gateway/status` (up/down, loss/latency)
- General state: `GET /api/diagnostics/interface/getInterfaceNames`,
  ARP/NDP tables via the diagnostics endpoints.
- Auth is an API key/secret pair over HTTPS — treat it as a secret; never log it.

## Mutations (confirm first, then apply as a separate step)
- **Add/edit/delete a firewall rule**: `POST /api/firewall/filter/addRule` /
  `setRule/{uuid}` / `delRule/{uuid}` — stages only. Confirm the rule, then
  **apply**: `POST /api/firewall/filter/apply`.
- **Alias changes**: `addItem`/`setItem`/`delItem`, then
  `POST /api/firewall/alias/reconfigure`. Aliases fan out into many rules —
  confirm the blast radius.
- **NAT / port-forward**: staging + apply on the source_nat/port-forward
  endpoints. Opening a port-forward can expose an internal service to WAN —
  confirm the source scope and destination explicitly.
- **Prefer reversible**: for risky access-rule edits, add the new (permissive)
  rule, verify you still have access, then remove the old — don't edit the rule
  your session depends on.

## Network hygiene review (read-only audit)
- **Over-broad rules**: flag `any`→`any` (or any-source to sensitive dest) allow
  rules; every broad allow should have a justification. Prefer alias-scoped
  source/dest.
- **VLAN segmentation**: verify inter-VLAN traffic is default-deny with explicit
  allows, not a flat any-any between zones. Check that IoT/guest/untrusted VLANs
  can't reach management or server VLANs.
- **Exposed management**: ensure the OPNsense web UI/SSH and other management
  interfaces (Proxmox, IPMI, switches) are NOT reachable from untrusted zones —
  they belong on a management VLAN with tightly scoped access.
- **WAN exposure**: enumerate port-forwards and any WAN-interface allow rules;
  flag anything reachable from the internet, especially management or
  unauthenticated services. Confirm each is intentional.
- **Default-deny posture**: confirm each interface ends in an implicit/explicit
  deny and that logging is on for denies you care about.

## Notes
- No official OPNsense MCP exists; this skill wraps the REST API (via `curl`)
  deliberately. The web UI edits the same staged config — the API's stage/apply
  split mirrors the UI's "Save" then "Apply changes" banner.
- Pair with `homelab-runbook` when a "service down" symptom is actually a
  firewall/NAT/gateway problem rather than the service itself.
