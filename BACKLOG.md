# NCTC backlog

- Remove the AutoDrive interaction from the service bus; NCTC must never expose player AutoDrive controls.
- Finish the dynamic passenger information on the service bus: display its line number and its next stop, with no technical locKeys.
- Prevent police/search escalation caused by NCTC service-bus incidents; V must not inherit wanted status from autonomous bus traffic collisions.
- Investigate and repair the Mahir coach's front collision/traffic-detection volume: the bus can drive into vehicles ahead before braking. Rear underpass collision is fixed, but the front detection/collider must reliably cause traffic avoidance and stopping.
