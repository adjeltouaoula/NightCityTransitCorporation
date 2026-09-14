from pathlib import Path
import re


def patch_passenger() -> None:
    p = Path("source/cet/nctc_passenger/init.lua")
    s = p.read_text(encoding="utf-8")

    if "UpdateInputHintEvent.new()" in s and "nctc_dev_bay_wait_self_possible" not in s:
        # Passenger side already patched in a local/test checkout.
        return

    s = s.replace(", stopRequestVisible = false, stopRequestHub = nil }", ", stopRequestVisible = false }")

    pat = re.compile(r"local function makeStopRequestHub\(\).*?\nlocal function hideChoice\(\)", re.S)
    repl = '''local STOP_REQUEST_HINT_SOURCE = "NCTCStopRequest"
local STOP_REQUEST_HINT_CONTAINER = "GameplayInputHelper"
local STOP_REQUEST_ACTION = CName.new("NCTC_RequestNextStop")

local function hideStopRequestHint()
    if not NCBN.stopRequestVisible then return end
    NCBN.stopRequestVisible = false
    local evt = DeleteInputHintBySourceEvent.new()
    evt.source = STOP_REQUEST_HINT_SOURCE
    evt.targetHintContainer = STOP_REQUEST_HINT_CONTAINER
    Game.GetUISystem():QueueEvent(evt)
end

local function showStopRequestHint()
    if NCBN.stopRequestVisible then return end
    if getFact("nctc_player_in_service_bus") ~= 1 or getFact("nctc_display_stop_requested") == 1 then return end
    local evt = UpdateInputHintEvent.new()
    local data = InputHintData.new()
    data.action = STOP_REQUEST_ACTION
    data.source = STOP_REQUEST_HINT_SOURCE
    data.localizedLabel = "Demander le prochain arrêt"
    data.enableHoldAnimation = false
    data.sortingPriority = 1
    evt.data = data
    evt.show = true
    evt.targetHintContainer = STOP_REQUEST_HINT_CONTAINER
    Game.GetUISystem():QueueEvent(evt)
    NCBN.stopRequestVisible = true
end

local function hideChoice()'''
    s, n = pat.subn(repl, s, count=1)
    if n != 1:
        raise RuntimeError(f"stop-request ChoiceHub block replacement count={n}")

    s = s.replace(" or (NCBN.stopRequestVisible and NCBN.stopRequestHub)", "")
    s = s.replace("            if NCBN.stopRequestVisible and NCBN.stopRequestHub then table.insert(hubs, NCBN.stopRequestHub) end\n", "")
    s = s.replace("        if NCBN.stopRequestVisible then return wrapped(0) end\n", "")
    s = s.replace("        if NCBN.stopRequestVisible and NCBN.stopRequestHub then return wrapped(NCBN.stopRequestHub.id) end\n", "")

    tail = s.rfind("    if #seats > 0 and not NCBN.choiceVisible then")
    if tail < 0:
        raise RuntimeError("final seat/stop-request UI block not found")
    s = s[:tail] + '''    if #seats > 0 and not NCBN.choiceVisible then
        NCBN.choiceVisible = true
        showChoice()
    elseif #seats == 0 then
        hideChoice()
    end
    -- Real GameplayInputHelper hint: unlike a ChoiceHub this resolves the
    -- NCTC_RequestNextStop binding itself, so the HUD shows U / D-pad Down (or
    -- the user's rebound key) rather than the generic F / X interaction glyph.
    if inside and getFact("nctc_display_stop_requested") == 0 then
        showStopRequestHint()
    else
        hideStopRequestHint()
    end
end)
'''

    if "77903" in s or "makeStopRequestHub" in s or "stopRequestHub" in s:
        raise RuntimeError("legacy stop-request ChoiceHub survived patch")
    if "UpdateInputHintEvent.new()" not in s or "data.action = STOP_REQUEST_ACTION" not in s:
        raise RuntimeError("native input hint was not installed")
    p.write_text(s, encoding="utf-8")


def patch_transit() -> None:
    p = Path("source/redscript/NCTC/NCTCTransitSystem.reds")
    s = p.read_text(encoding="utf-8")
    if "nctc_dev_bay_wait_self_possible" not in s:
        pat = re.compile(
            r"    if this\.bayParkingActive && Equals\(this\.bayParkingStage, 15\) \{.*?\n    if this\.bayParkingActive && Equals\(this\.bayParkingStage, 10\) \{",
            re.S,
        )
        repl = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 15) {
      // r387b: after ArriveAtStop the Mahir can coast a few metres across P1.
      // The broad Vehicle overlap then sees the Mahir itself and stage 15 can
      // wait forever. Before P1, overlap remains authoritative. Once our pivot
      // is inside the bay, combine it with the native self-filtered forward-path
      // probe and require two consecutive clear samples before entering.
      let waitLateral: Float;
      let waitProgress: Float = this.GetBayProgress(waitLateral);
      let waitOccupied: Bool = this.IsBayOccupiedByVehicle();
      let bayLength: Float = Vector4.Distance(this.GetBayEntryPoint(), this.GetBayExitPoint());
      let overlapCanBeSelf: Bool = waitProgress >= -1.00 && waitProgress <= bayLength + 2.00;
      let forwardProbeDistance: Float = ClampF(Vector4.Distance(this.controller.GetWorldPosition(), this.GetBayExitPoint()) + 4.00, 10.00, 35.00);
      let nativeForwardClear: Bool = this.controller.IsVanillaDeparturePathClear(forwardProbeDistance);
      quests.SetFact(n"nctc_dev_bay_wait_overlap", waitOccupied ? 1 : 0);
      quests.SetFact(n"nctc_dev_bay_wait_self_possible", overlapCanBeSelf ? 1 : 0);
      quests.SetFact(n"nctc_dev_bay_wait_forward_clear", nativeForwardClear ? 1 : 0);
      quests.SetFact(n"nctc_dev_bay_wait_progress_mm", Cast<Int32>(waitProgress * 1000.00));
      quests.SetFact(n"nctc_dev_bay_wait_lateral_mm", Cast<Int32>(waitLateral * 1000.00));

      if waitOccupied && (!overlapCanBeSelf || !nativeForwardClear) {
        this.bayParkingRetryCount = 0;
        this.ScheduleDispatch(0.25);
        return;
      };
      if waitOccupied && overlapCanBeSelf {
        this.bayParkingRetryCount += 1;
        if this.bayParkingRetryCount < 2 {
          this.ScheduleDispatch(0.25);
          return;
        };
      } else {
        this.bayParkingRetryCount = 0;
      };

      let waitSplinePath: String = this.NCTCBayArrivalSplinePath();
      if Equals(waitSplinePath, "") {
        this.bayParkingActive = false;
        this.bayParkingStage = 0;
        this.ScheduleDispatch(0.25);
        return;
      };
      this.bayParkingStage = 10;
      this.bayParkingWasEntered = true;
      this.bayParkingRetryCount = 0;
      this.driveCommandSent = this.controller.DriveOnBaySpline(waitSplinePath, 2.00, true);
      this.PublishLoopDiagnostic(this.driveCommandSent ? 92 : 33, this.requestedStopId);
      this.ScheduleDispatch(0.10);
      return;
    };

    if this.bayParkingActive && Equals(this.bayParkingStage, 10) {'''
        s, n = pat.subn(repl, s, count=1)
        if n != 1:
            raise RuntimeError(f"bay stage 15 replacement count={n}")

    s = s.replace('nctc_dev_build_revision", 38401', 'nctc_dev_build_revision", 38702')
    s = s.replace('nctc_dev_build_revision", 38602', 'nctc_dev_build_revision", 38702')
    if 'nctc_dev_build_revision", 38702' not in s:
        raise RuntimeError("r387b revision marker missing")
    p.write_text(s, encoding="utf-8")


patch_passenger()
patch_transit()
print("r387b test patch applied")
