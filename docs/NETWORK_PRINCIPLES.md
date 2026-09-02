# Network principles

## Source of truth

The Cyberpunk 2020 bus lines define NCTC's identity: route purpose, districts,
major historical places and overlaps between lines.

## Translation to 2077

Each historic stop is first mapped to its equivalent 2077 neighbourhood or
place. If that place still exists in recognisable form, it remains an NCTC
stop even if no fast-travel terminal is beside it.

If the historic place has disappeared, been substantially rebuilt, or cannot
support a credible passenger stop in 2077, NCTC adapts it to the nearest
appropriate fast-travel point or NCART station.

## Fast travel and NCART

Fast-travel terminals and NCART stations are practical anchors for the first
implementation: discoverable map locations, player access and future call
points. They are not the rule that decides whether a lore stop exists.

## Implementation order

1. Translate all historic lines to 2077.
2. Publish green NCTC map markers with an independent visibility filter.
3. Validate street-side terminal, kerb and approach positions.
4. Place physical NCTC terminals where needed.
5. Implement each line as a bus service.

Transports of Night City is deliberately not a source for this network.
