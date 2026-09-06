# NCTC backlog

- Remove the AutoDrive interaction from the service bus; NCTC must never expose player AutoDrive controls.
- Preserve manual-stop coordinates exactly as recorded. A nearby metro or fast-travel anchor may supply a display name, but must never move or snap the stop; nearby stops on different lines must still form a hub.
- Add a separate developer-only "replace selected stop" action. It must preserve the selected stop's position in its line while replacing its anchor, LocKey, display name, and map position; spawn/approach/berth capture data must remain unchanged, and it must never share the normal "add stop" binding.
- Finish the dynamic passenger information on the service bus: display its line number and its next stop, with no technical locKeys.
- Ensure NCTC service-bus actions are never attributed to V: collisions, property damage, pedestrian injuries/deaths, combat escalation, police response, and wanted level must belong to the autonomous bus (or remain unassigned), never to the passenger.
- Investigate and repair the Mahir coach's front collision/traffic-detection volume: the bus can drive into vehicles ahead before braking. Rear underpass collision is fixed, but the front detection/collider must reliably cause traffic avoidance and stopping.
