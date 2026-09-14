from pathlib import Path

path = Path("source/redscript/NCTC/NCTCTransitSystem.reds")
s = path.read_text(encoding="utf-8")

old = '''  // r383e: rolling handoff after native JoinTraffic. Unlike the older
  // DriveToTrafficAfterSpline path, do not pulse NoDriver after vanilla has
  // just reacquired a traffic lane; keep DriverReady and submit the successor
  // command with the measured rolling speed.
  public func DriveToTrafficAfterJoin(target: Vector4, minimumDistance: Float, startSpeed: Float) -> Bool {
    let callback: ref<NCTCDeferredDriveCommand>;
    let driverReady: ref<AIEvent>;
    let speedProfile: Int32;
    let speedLimit: Float;
    let generation: Int32;
    if !this.IsReady() { return false; };

    generation = this.NextDriveGeneration();
    this.previousRouteCommand = this.activeRouteCommand;
    this.activeRouteCommand = null;
    this.activeSplineCommand = null;
    this.activeJoinTrafficCommand = null;

    driverReady = new AIEvent();
    driverReady.name = n"DriverReady";
    this.bus.QueueEvent(driverReady);
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(
      n"nctc_dev_command_forced_start_speed_mm",
      Cast<Int32>(MaxF(startSpeed, 0.00) * 1000.00)
    );

    callback = new NCTCDeferredDriveCommand();
    speedLimit = this.ResolveTrafficSpeed(target, speedProfile);
    callback.Configure(
      this.bus,
      this,
      target,
      minimumDistance,
      speedLimit,
      speedProfile,
      MaxF(startSpeed, 0.00),
      generation
    );
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.030, false);
    return true;
  }'''

new = '''  // r386b: after vanilla JoinTraffic reports a lane, explicitly pulse the
  // native driver lifecycle before the successor DriveToPoint command. The
  // r383e shortcut (DriverReady only) can leave the command Active while the
  // Mahir remains physically idle at 0 m/s. Preserve the measured join speed
  // and use the same short cross-frame NoDriver -> DriverReady sequence as the
  // validated rolling-passage handoff.
  public func DriveToTrafficAfterJoin(target: Vector4, minimumDistance: Float, startSpeed: Float) -> Bool {
    let callback: ref<NCTCDeferredDriveCommand>;
    let noDriver: ref<AIEvent>;
    let driverReady: ref<AIEvent>;
    let speedProfile: Int32;
    let speedLimit: Float;
    let generation: Int32;
    if !this.IsReady() { return false; };

    generation = this.NextDriveGeneration();
    this.previousRouteCommand = this.activeRouteCommand;
    this.activeRouteCommand = null;
    this.activeSplineCommand = null;
    this.activeJoinTrafficCommand = null;

    noDriver = new AIEvent();
    driverReady = new AIEvent();
    noDriver.name = n"NoDriver";
    driverReady.name = n"DriverReady";
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEventNextFrame(this.bus, noDriver);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEvent(this.bus, driverReady, 0.030);
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 38602);
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(
      n"nctc_dev_command_forced_start_speed_mm",
      Cast<Int32>(MaxF(startSpeed, 0.00) * 1000.00)
    );

    callback = new NCTCDeferredDriveCommand();
    speedLimit = this.ResolveTrafficSpeed(target, speedProfile);
    callback.Configure(
      this.bus,
      this,
      target,
      minimumDistance,
      speedLimit,
      speedProfile,
      MaxF(startSpeed, 0.00),
      generation
    );
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.060, false);
    return true;
  }'''

if old not in s:
    if 'nctc_dev_build_revision", 38602' in s and 'DelayEventNextFrame(this.bus, noDriver)' in s:
        raise SystemExit(0)
    raise SystemExit("r383e post-join block not found")

path.write_text(s.replace(old, new, 1), encoding="utf-8", newline="\n")
