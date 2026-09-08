@addMethod(AutoDriveSystem)
public final func GetAutodriveEnabled() -> Bool {
    return this.GetAutodriveEnabled_ADE();
}

@addMethod(AutoDriveSystem)
public final func SetAutodriveEnabled(enabled: Bool, opt isDelamain: Bool) -> Bool {
    return this.SetAutodriveEnabled_ADE(enabled, isDelamain);
}

@addMethod(AutoDriveSystem)
public final func GetAutodriveVehicle() -> ref<VehicleObject> {
    return this.GetAutodriveVehicle_ADE();
}

@addMethod(AutoDriveSystem)
public final func CheckCurrentLaneValidity() -> gameAutodriveLaneValidityResult {
    return this.CheckCurrentLaneValidity_ADE();
}

// 追加した GetAutodriveEnabled , SetAutodriveEnabled を呼び出すようにreplaceする. コードは同じなので、そのままコピーでよい.
@replaceMethod(AutoDriveSystem)
  public final const func GetDistanceToCurrentDestination() -> Float {
    let playerVehicle: ref<VehicleObject> = this.GetAutodriveVehicle();
    if IsDefined(playerVehicle) && this.GetAutodriveEnabled() {
      return Cast<Float>(FloorF(playerVehicle.GetCurrentSlotLocalPathLength() - playerVehicle.GetCurrentSlotLocalPathProgression()));
    };
    return 0.00;
  }

@replaceMethod(AutoDriveSystem)
  private final func OnStopAutoDriveOnDestinationReachedRequest(request: ref<StopAutoDriveOnDestinationReachedRequest>) -> Void {
    let delamainTaxiSystem: wref<DelamainTaxiSystem>;
    let playerVehicle: ref<VehicleObject> = this.GetAutodriveVehicle();
    let mappinSystem: wref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
    let messagelocKey: String = "LocKey#96672";
    let messageType: SimpleMessageType = SimpleMessageType.Autodrive;
    if IsDefined(playerVehicle) && IsDefined(mappinSystem) && this.GetAutodriveEnabled() {
      this.StopPlayerVehicle();
      if IsDefined(mappinSystem.GetMappin(mappinSystem.GetDelamainTrackedMappinID())) {
        mappinSystem.UnregisterMappin(mappinSystem.GetDelamainTrackedMappinID());
        delamainTaxiSystem = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"DelamainTaxiSystem") as DelamainTaxiSystem;
        delamainTaxiSystem.QueueRequest(new DelamainTaxiArrivedRequest());
        messagelocKey = "LocKey#97066";
        messageType = SimpleMessageType.DelamainTaxi;
      } else {
        if Equals(mappinSystem.GetMappin(mappinSystem.GetManuallyTrackedMappinID()).GetVariant(), gamedataMappinVariant.CustomPositionVariant) {
          mappinSystem.UnregisterMappin(mappinSystem.GetManuallyTrackedMappinID());
        } else {
          mappinSystem.UntrackMappin();
        };
      };
      this.SendNotification(messagelocKey, messageType);
      this.SetAutodriveEnabled(false);
    };
  }

@replaceMethod(AutoDriveSystem)
  private final func OnStopAutoDriveOnTeleportRequest(request: ref<StopAutoDriveOnTeleportRequest>) -> Void {
    let playerVehicle: ref<VehicleObject> = this.GetAutodriveVehicle();
    if IsDefined(playerVehicle) && this.GetAutodriveEnabled() {
      this.StopPlayerVehicle();
      this.SetAutodriveEnabled(false);
    };
  }

@replaceMethod(AutoDriveSystem)
  private final func StopAutodriveIfNecessary(stopVehicleIfDeactivated: Bool) -> Void {
    let delamainTaxiSystem: wref<DelamainTaxiSystem>;
    let mappinSystem: wref<MappinSystem>;
    let request: ref<CancelDelamainRideRequest>;
    if this.GetAutodriveEnabled() && !this.GetAutodriveAvailable() {
      if stopVehicleIfDeactivated {
        this.StopPlayerVehicle();
        if this.GetAutodriveIsDelamain() {
          mappinSystem = GameInstance.GetMappinSystem(this.GetGameInstance());
          mappinSystem.UnregisterMappin(mappinSystem.GetDelamainTrackedMappinID());
          delamainTaxiSystem = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"DelamainTaxiSystem") as DelamainTaxiSystem;
          request = new CancelDelamainRideRequest();
          request.forceExit = false;
          delamainTaxiSystem.QueueRequest(request);
        };
      };
      this.SetAutodriveEnabled(false);
    };
  }

@replaceMethod(GameTimeUtils)
  public final static func CanPlayerTimeSkip(playerPuppet: ref<PlayerPuppet>) -> Bool {
    let autoDriveSystem: wref<AutoDriveSystem>;
    let psmVehicle: Int32;
    let securityData: SecurityAreaData;
    let timeSystem: ref<TimeSystem>;
    let blockTimeSkip: Bool = false;
    let tier: Int32 = playerPuppet.GetPlayerStateMachineBlackboard().GetInt(GetAllBlackboardDefs().PlayerStateMachine.HighLevel);
    let psmBlackboard: ref<IBlackboard> = playerPuppet.GetPlayerStateMachineBlackboard();
    let variantData: Variant = psmBlackboard.GetVariant(GetAllBlackboardDefs().PlayerStateMachine.SecurityZoneData);
    if IsDefined(variantData) {
      securityData = FromVariant<SecurityAreaData>(variantData);
    };
    psmVehicle = psmBlackboard.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Vehicle);
    autoDriveSystem = GameInstance.GetScriptableSystemsContainer(playerPuppet.GetGame()).Get(n"AutoDriveSystem") as AutoDriveSystem;
    blockTimeSkip = psmBlackboard.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Combat) == 1 || StatusEffectSystem.ObjectHasStatusEffectWithTag(playerPuppet, n"NoTimeSkip") || timeSystem.IsPausedState() || playerPuppet.IsMovingVertically() || psmBlackboard.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Swimming) == 2 || psmVehicle == 4 || psmVehicle == 1 && VehicleComponent.GetOwnerVehicleSpeed(playerPuppet.GetGame(), playerPuppet) > 13.80 || tier >= 3 && tier <= 5 || securityData.securityAreaType > ESecurityAreaType.SAFE || GameInstance.GetPhoneManager(playerPuppet.GetGame()).IsPhoneCallActive() || psmBlackboard.GetBool(GetAllBlackboardDefs().PlayerStateMachine.Carrying) || psmBlackboard.GetBool(GetAllBlackboardDefs().PlayerStateMachine.IsInLoreAnimationScene) || playerPuppet.GetPreventionSystem().IsChasingPlayer() || HubMenuUtility.IsPlayerHardwareDisabled(playerPuppet) || autoDriveSystem.GetAutodriveEnabled();
    return !blockTimeSkip;
  }

// ==== Accl/Decel issue in the passenger seat issue ====
// ISSUE: VehicleAutodrivePassenger Context には Accelerate/Decelerate/TurnX を入れていないにも関わらず, ドライバーシートからスイッチシートしてからだと拾ってしまう. ので、ここでドライバーシートかチェックを入れる.
@replaceMethod(AutoDriveController)
  protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    if !this.m_inputHintVisible {
      return true;
    };
    if ListenerAction.IsAction(action, n"HoldAutodrive") && Equals(ListenerAction.GetType(action), gameinputActionType.BUTTON_HOLD_COMPLETE) && !this.IsAnimationPlaying() {
      this.PlayLibraryAnimation(n"onUse");
      if this.m_autoDriveSystem.GetAutodriveEnabled() {
        this.m_autoDriveSystem.QueueRequest(new DisableAutoDriveRequest());
      } else {
        this.m_autoDriveSystem.QueueRequest(new EnableAutoDriveRequest());
      };
    } else {
      if ListenerAction.IsAction(action, n"ToggleAutodrive") && ListenerAction.IsButtonJustReleased(action) {
        if this.m_autoDriveSystem.GetAutodriveEnabled() {
          this.m_autoDriveSystem.QueueRequest(new ToggleFreeRoamRequest());
        };
      } else {
        // if (ListenerAction.IsAction(action, n"Accelerate") || ListenerAction.IsAction(action, n"Decelerate")) && !this.IsAnimationPlaying() {
        if (ListenerAction.IsAction(action, n"Accelerate") || ListenerAction.IsAction(action, n"Decelerate")) && this.m_autoDriveSystem.IsPlayerDriver_ADE() && !this.IsAnimationPlaying() {
          if AbsF(ListenerAction.GetValue(action)) >= 0.10 {
            if this.m_autoDriveSystem.GetAutodriveEnabled() {
              this.m_autoDriveSystem.QueueRequest(new DisableAutoDriveRequest());
            };
          };
        };
      };
    };
    if !this.m_containerVisible {
      return true;
    };
    // if ListenerAction.IsAction(action, n"TurnX") {
    if ListenerAction.IsAction(action, n"TurnX") && this.m_autoDriveSystem.IsPlayerDriver_ADE() {
      this.m_isHoldingDirectionInput = AbsF(ListenerAction.GetValue(action)) >= 0.10;
      this.UpdateSlowCloseAnimationState();
    };
  }
// ==== Accl/Decel issue in the passenger seat issue ====

@replaceMethod(AutoDriveController)
  protected cb func OnSlowCloseAnimationThreshold(target: wref<inkWidget>) -> Bool {
    if this.m_autoDriveSystem.GetAutodriveEnabled() {
      this.m_autoDriveSystem.QueueRequest(new DisableAutoDriveRequest());
      this.m_containerVisible = false;
    };
  } 


@replaceMethod(AutoDriveSystem)
  private final func OnEnableAutoDriveRequest(request: ref<EnableAutoDriveRequest>) -> Void {
    let laneValidity: gameAutodriveLaneValidityResult = this.CheckCurrentLaneValidity();
    if Equals(laneValidity, gameAutodriveLaneValidityResult.NotOnRoad) {
      this.HighlightValidRoadsOnMinimap();
      this.SendNotification("LocKey#96670", SimpleMessageType.Autodrive);
      return;
    };
    if Equals(laneValidity, gameAutodriveLaneValidityResult.NotOnValidLane) {
      this.HighlightValidRoadsOnMinimap();
      this.SendNotification("LocKey#96671", SimpleMessageType.Autodrive);
      return;
    };
    if !request.isDelamain && !this.GetAutodriveAvailable() {
      return;
    };
    this.SetAutodriveEnabled(true, request.isDelamain);
  }

@replaceMethod(AutoDriveSystem)
  private final func OnDisableAutoDriveRequest(request: ref<DisableAutoDriveRequest>) -> Void {
    this.SetAutodriveEnabled(false);
  }

@replaceMethod(AutoDriveSystem)
  public final const func GetEstimatedTimeToArrival() -> Float {
    let playerVehicle: ref<VehicleObject> = this.GetAutodriveVehicle();
    if IsDefined(playerVehicle) {
      return playerVehicle.GetCurrentSlotEstimatedTimeToArrival();
    };
    return 0.00;
  }

@replaceMethod(AutoDriveSystem)
  private final func StopPlayerVehicle() -> Void {
    let callbackListener: ref<AutodriveForceBrakesCallbackListener>;
    let playerVehicle: ref<VehicleObject> = this.GetAutodriveVehicle();
    if IsDefined(playerVehicle) {
      callbackListener = new AutodriveForceBrakesCallbackListener();
      callbackListener.m_autodriveSystem = this;
      this.StartListeningForPlayerMoveInputs();
      playerVehicle.ForceBrakesUntilStoppedOrFor(10.00, callbackListener);
    };
  }


@replaceMethod(AutoDriveSystem)
  private final func OnWeaponStateChange(value: Int32) -> Void {
    if !this.GetAutodriveIsDelamain() {
      if this.GetAutodriveEnabled() && value == 8 {
        this.SendNotification("LocKey#97386", SimpleMessageType.Autodrive);
      };
      this.SignalAutodriveAvailable();
      this.StopAutodriveIfNecessary(false);
    };
  }

@replaceMethod(AutoDriveSystem)
  private final func OnMeleeWeaponStateChange(value: Int32) -> Void {
    if !this.GetAutodriveIsDelamain() {
      if this.GetAutodriveEnabled() && (value == 11 || value == 13 || value == 19) {
        this.SendNotification("LocKey#97386", SimpleMessageType.Autodrive);
      };
      this.SignalAutodriveAvailable();
      this.StopAutodriveIfNecessary(false);
    };
  }

@replaceMethod(AutoDriveSystem)
  private final func OnAutoDriveHitRequest(request: ref<AutoDriveHitRequest>) -> Void {
    this.SendNotification("LocKey#97386", SimpleMessageType.Autodrive);
    this.SetAutodriveEnabled(false);
    this.SignalAutodriveAvailable();
  }


@replaceMethod(WorldMapMenuGameController)
  private final func CanPay() -> Bool {
    let playerMoney: Int32;
    let transactionSystem: ref<TransactionSystem>;
    let gi: GameInstance = this.m_player.GetGame();
    let autoDriveSystem: ref<AutoDriveSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"AutoDriveSystem") as AutoDriveSystem;
    let travelCost: Int32 = this.GetTravelCost();
    if NotEquals(autoDriveSystem.CheckCurrentLaneValidity(), gameAutodriveLaneValidityResult.OnValidLane) {
      return false;
    };
    transactionSystem = GameInstance.GetTransactionSystem(gi);
    playerMoney = transactionSystem.GetItemQuantity(this.m_player, MarketSystem.Money());
    if travelCost > playerMoney {
      return false;
    };
    return true;
  }
