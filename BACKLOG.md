# NCTC backlog

- **Priority — called-stop service:** an "await bus" request must reserve that exact stop as a service stop. When the bus reaches it, it must stop, open its doors, wait for boarding, then continue the line. Only unrequested intermediate stops may be passed without stopping.
- **Uninterrupted pass-through:** passage points and unrequested intermediate stops must never visibly dwell, even for a fraction of a second. Hand the traffic command to the next route target early enough that the Mahir crosses the point continuously; this must not alter the separate service-stop behaviour.
- **NCTC map navigation:** selecting an NCTC marker must keep it tracked after closing and reopening the world map. Its first-person waypoint icon is currently the broken red icon with a yellow outline; replace it with a valid NCTC/vanilla navigation visual.
- Expand the developer line-colour picker from 7 to **15 highly distinguishable presets** for map icons and hub text. The renderer itself supports arbitrary RGB/HDR colours; this is an authoring/UI palette task.
- Remove the AutoDrive interaction from the service bus; NCTC must never expose player AutoDrive controls.
- Fix passenger-door service state: doors must not repeatedly open/close during one stop, and when the bus is stopped at a service stop they must open if V, already inside, approaches the exit.
- Add physical collision to the bus doors so V and traffic cannot pass through them.
- Investigate ejection when V boards the bus after stop 1. This is separate from the standing-passenger knockdown fix: mounting must not launch V out of the moving or stopped service bus.
- Preserve manual-stop coordinates exactly as recorded. A nearby metro or fast-travel anchor may supply a display name, but must never move or snap the stop; nearby stops on different lines must still form a hub.
- Add a separate developer-only "replace selected stop" action. It must preserve the selected stop's position in its line while replacing its anchor, LocKey, display name, and map position; spawn/approach/berth capture data must remain unchanged, and it must never share the normal "add stop" binding.
- Finish the dynamic passenger information on the service bus: display its line number and its next stop, with no technical locKeys.
- Ensure NCTC service-bus actions are never attributed to V: collisions, property damage, pedestrian injuries/deaths, combat escalation, police response, and wanted level must belong to the autonomous bus (or remain unassigned), never to the passenger.
- Investigate and repair the Mahir coach's front collision/traffic-detection volume: the bus can drive into vehicles ahead before braking. Rear underpass collision is fixed, but the front detection/collider must reliably cause traffic avoidance and stopping.
- **Cannery Plaza:** on departure, the bus can teleport sideways onto the adjacent lane. Re-survey this stop's spawn/berth first; only investigate the runtime transition if the issue remains with a validated profile.
