# NCTC development workflow

This workflow is mandatory for every NCTC development chat/session.

1. `development` is the stable integration branch. Only user-validated runtime work may be merged into it.
2. Start every new feature/fix from the current `development` branch unless the user explicitly chooses another validated checkpoint.
3. Work in a dedicated `feature/*` or `fix/*` branch.
4. Make one logical runtime change at a time. Every test ZIP must correspond exactly to an identifiable Git commit on that branch; no uncommitted/local-only runtime patching.
5. After each test there are only three paths:
   - works: keep/commit that state as the new validated checkpoint and continue;
   - fails but the new change has a narrow obvious correction: correct only that change and test again;
   - fails/regresses or the approach is wrong: return exactly to the last user-validated commit and try a different approach.
6. Never stack speculative repair-on-repair changes on top of a failed state.
7. Never modify unrelated behavior while implementing a requested feature. Any additional runtime/UI/input/behavior change requires the user's approval first.
8. Do not merge a feature/fix into `development` until the user has validated it.
9. Preserve known-good checkpoints/branches until their replacement has been validated.
10. Real REDscript validation means the Windows self-hosted `scc.exe` compile against installed game scripts; packaging/build success is not REDscript CI.

Current clean restart for native stop-request input: branch `feature/native-stop-request-input-v2`, created from `development` after merging validated r386e. All r387 native-input/UI attempts are rejected history and must not be used as a base.
