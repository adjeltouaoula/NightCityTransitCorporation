module NCTC

// r382a: H2 keeps the validated r381a direct JoinTraffic departure, but the
// command is deferred until the vehicle's own vanilla CrowdMemberComponent
// reports a clear path. No custom overlap volume and no departure spline.
public class NCTCDeferredVanillaJoinTraffic extends DelayCallback {
  private let controller: wref<NCTCServiceBusController>;
  private let bus: wref<VehicleObject>;
  private let clearPolls: Int32;
  private let totalPolls: Int32;

  public func Configure(controller: ref<NCTCServiceBusController>, bus: ref<VehicleObject>, clearPolls: Int32, totalPolls: Int32) -> ref<NCTCDeferredVanillaJoinTraffic> {
    this.controller = controller;
    this.bus = bus;
    this.clearPolls = clearPolls;
    this.totalPolls = totalPolls;
    return this;
  }

  public func Call() -> Void {
    let crowd: ref<CrowdMemberBaseComponent>;
    let quests: ref<QuestsSystem>;
    let empty05: Bool;
    let empty10: Bool;
    let empty15: Bool;
    let next: ref<NCTCDeferredVanillaJoinTraffic>;

    if !IsDefined(this.controller) || !this.controller.IsReady() || !IsDefined(this.bus) || !this.bus.IsAttached() { return; };

    crowd = this.bus.GetCrowdMemberComponent();
    if !IsDefined(crowd) {
      // Fail open to the already validated r381a behavior if this vehicle has
      // no crowd component at runtime. Missing detection must never deadlock
      // the service bus.
      this.controller.NCTCStartJoinTrafficNow();
      return;
    };

    empty05 = crowd.CheckEmptyPath(5.00);
    empty10 = crowd.CheckEmptyPath(10.00);
    empty15 = crowd.CheckEmptyPath(15.00);
    this.totalPolls += 1;

    quests = GameInstance.GetQuestsSystem(this.bus.GetGame());
    if IsDefined(quests) {
      quests.SetFact(n"nctc_dev_join_guard_revision", 38201);
      quests.SetFact(n"nctc_dev_join_guard_empty_05", empty05 ? 1 : 0);
      quests.SetFact(n"nctc_dev_join_guard_empty_10", empty10 ? 1 : 0);
      quests.SetFact(n"nctc_dev_join_guard_empty_15", empty15 ? 1 : 0);
      quests.SetFact(n"nctc_dev_join_guard_polls", this.totalPolls);
    };

    // 10 m is the actual departure gate. Require two consecutive clear
    // checks (100 ms total) so a single transient frame cannot launch the bus
    // into crossing traffic.
    if empty10 {
      this.clearPolls += 1;
    } else {
      this.clearPolls = 0;
    };

    if IsDefined(quests) {
      quests.SetFact(n"nctc_dev_join_guard_clear_polls", this.clearPolls);
      quests.SetFact(n"nctc_dev_join_guard_waiting", this.clearPolls < 2 ? 1 : 0);
    };

    if this.clearPolls >= 2 {
      this.controller.NCTCStartJoinTrafficNow();
      return;
    };

    next = new NCTCDeferredVanillaJoinTraffic();
    next.Configure(this.controller, this.bus, this.clearPolls, this.totalPolls);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(next, 0.05, false);
  }
}

// Same command body as r381a. It exists separately so the deferred vanilla
// path gate can start JoinTraffic without recursively entering the wrapper.
@addMethod(NCTCServiceBusController)
public func NCTCStartJoinTrafficNow() -> Bool {
  let driverReady: ref<AIEvent>;
  let command: ref<AIVehicleJoinTrafficCommand>;
  let quests: ref<QuestsSystem>;
  if !this.IsReady() { return false; };

  this.NextDriveGeneration();
  this.previousRouteCommand = this.activeRouteCommand;
  this.activeRouteCommand = null;
  this.activeSplineCommand = null;
  this.activeJoinTrafficCommand = null;
  this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
  this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleOnSplineCommand", false, true);

  driverReady = new AIEvent();
  driverReady.name = n"DriverReady";
  this.bus.QueueEvent(driverReady);

  command = new AIVehicleJoinTrafficCommand();
  command.needDriver = false;
  command.useKinematic = true;
  this.bus.GetAIComponent().SendCommand(command);
  this.activeJoinTrafficCommand = command;

  quests = GameInstance.GetQuestsSystem(this.bus.GetGame());
  if IsDefined(quests) {
    quests.SetFact(n"nctc_dev_join_guard_waiting", 0);
    quests.SetFact(n"nctc_dev_join_guard_started", quests.GetFact(n"nctc_dev_join_guard_started") + 1);
  };
  return true;
}

@wrapMethod(NCTCServiceBusController)
public func JoinTrafficDirectFromBerth() -> Bool {
  let crowd: ref<CrowdMemberBaseComponent>;
  let guard: ref<NCTCDeferredVanillaJoinTraffic>;
  let quests: ref<QuestsSystem>;

  if !this.IsReady() { return false; };
  crowd = this.bus.GetCrowdMemberComponent();
  if !IsDefined(crowd) {
    return wrappedMethod();
  };

  // Always sample for at least two frames before releasing the bus. This is
  // intentionally a path query from the vanilla crowd/traffic component, not
  // an NCTC-authored occupancy box.
  quests = GameInstance.GetQuestsSystem(this.bus.GetGame());
  if IsDefined(quests) {
    quests.SetFact(n"nctc_dev_join_guard_revision", 38201);
    quests.SetFact(n"nctc_dev_join_guard_waiting", 1);
    quests.SetFact(n"nctc_dev_join_guard_polls", 0);
    quests.SetFact(n"nctc_dev_join_guard_clear_polls", 0);
  };

  guard = new NCTCDeferredVanillaJoinTraffic();
  guard.Configure(this, this.bus, 0, 0);
  GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(guard, 0.05, false);

  // Return true because the command lifecycle is now owned by the deferred
  // guard. This prevents the transit state machine from falling back to a
  // normal DriveToPoint while it is waiting for a safe gap.
  return true;
}
