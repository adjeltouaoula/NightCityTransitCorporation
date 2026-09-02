# Night City Transit Corporation

NCTC is a lore-led public bus network for Cyberpunk 2077.

This project deliberately replaces the earlier prototype. It begins with the
network map: historic Cyberpunk 2020 service patterns, current-Night-City stop
names, green map markers, and a dedicated NCTC map filter. Vehicle spawning,
boarding and physical terminals come only after every stop has a verified
street-side position and approach lane.

## Network basis

The initial network is derived from the historic 2020 lines 17, 22, 23, 51, 68
and 72. It is not a copy of the six-stop Transports of Night City pilot:
that pilot is useful reference material for a waterfront route, but does not
define the NCTC network.

## Current phase

1. Put every candidate stop on a green NCTC map layer.
2. Verify each candidate in-world: passenger pavement, bus-side kerb and
   inbound traffic lane.
3. Create the physical NCTC terminals.
4. Implement lines one at a time.
