# Night City Transit Corporation

NCTC is a lore-led public bus network for Cyberpunk 2077.

This project deliberately replaces the earlier prototype. It begins with the
network map: historic Cyberpunk 2020 service patterns translated to current
Night City, green map markers, and an \"NCTC Stops\" map filter. Vehicle
spawning, boarding and physical terminals come only after every stop has a
verified street-side position and approach lane.

## Network basis

The initial network is derived from the historic 2020 lines 17, 22, 23, 51, 68
and 72. Fast-travel terminals and NCART stations are practical anchors where
2077 requires an adaptation; they do not define the lore network. See
`docs/NETWORK_PRINCIPLES.md`.

## Current phase

1. Put every candidate stop on a green NCTC map layer. These are deliberately
   labelled as map-planning candidates, not final physical terminals.
2. Verify each candidate in-world: passenger pavement, bus-side kerb and
   inbound traffic lane.
3. Create the physical NCTC terminals.
4. Implement lines one at a time.

## Dev test r372n — generation-safe rolling passage handoff

This experimental build is reset from the r371 calm/adaptive-speed baseline and
reapplies only the rolling-passage experiment plus two safeguards discovered
from the r372m telemetry:

- near-identical passage points on the same leg are merged on load;
- re-recording the same passage updates it rather than appending a duplicate;
- every deferred native drive command carries a monotonically increasing
  generation; callbacks from older route decisions are rejected before
  `SendCommand` can run;
- the outgoing 100 m corridor and +20 m rolling handoff remain unchanged so
  this test isolates command ownership rather than changing geometry again.

Runtime marker: `NCTC runtime build=37214 r372n generation-safe rolling handoff`.
