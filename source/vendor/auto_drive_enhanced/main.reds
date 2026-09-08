module AutoDriveEnhanced

// func L(const text: script_ref<String>) -> Void{ FTLog(text); }

func SwitchSeatsActionName() -> CName = n"VehADESwitchSeats";
func SwitchAIActionName() -> CName = n"VehADESwitchAI";
func ToggleVehCameraActionName() -> CName = n"ToggleVehCamera";

@if(ModuleExists("AutoDriveMod"))
func AutoDriveModIsInstalled() -> Bool = true;

@if(!ModuleExists("AutoDriveMod"))
func AutoDriveModIsInstalled() -> Bool = false;


@addMethod(AutoDriveSystem)
public static func GetInstance(game: GameInstance) -> ref<AutoDriveSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(NameOf<AutoDriveSystem>()) as AutoDriveSystem;
}

@if(ModuleExists("AutoDriveMod"))
@wrapMethod(VehicleObject)
public func CanAutoDrive() -> Bool { return !Settings.GetInstance(this.GetGame()).disableAutoDriveMod; }

@addMethod(VehicleObject)
public func IsDelamainTaxi_ADE() -> Bool {
    return IsDefined(this.FindComponentByName(n"taxiComponent"));
}

@addMethod(VehicleObject)
public func CanAutoDrive_ADE() -> Bool {
    if this.IsDelamainTaxi_ADE() {
        return true;
    }
    if this.RecordHasTag(n"CannotAutoDrive") {
        return false;
    }
    let settings = Settings.GetInstance(this.GetGame());
    if settings.restrictVehicles {
        if !this.RecordHasTag(n"CanAutoDrive") {
            return false;
        }
    }
    return true;
}

@addField(UI_AutodriveDataDef)
public let DrivingAI_ADE: BlackboardID_Int;

@addMethod(AutoDriveSystem)
public func GetSettings() -> ref<Settings> {
    return Settings.GetInstance(this.GetGameInstance());
}

@addMethod(AutoDriveSystem)
private func IsPlayerDriver_ADE() -> Bool {
    if IsDefined(GetPlayer(this.GetGameInstance()))
    && IsDefined(GetPlayer(this.GetGameInstance()).GetMountedVehicle()) {
        let vehicle = GetPlayer(this.GetGameInstance()).GetMountedVehicle();
        let driver = VehicleComponent.GetDriverMounted(vehicle.GetGame(), vehicle.GetEntityID()) as ScriptedPuppet;
        return IsDefined(driver) && driver.IsPlayer();
    }
    return false;
}

@addMethod(AutoDriveSystem)
private func IsDelamainTaxi_ADE() -> Bool {
    if IsDefined(GetPlayer(this.GetGameInstance()))
    && IsDefined(GetPlayer(this.GetGameInstance()).GetMountedVehicle()) {
        let vehicle = GetPlayer(this.GetGameInstance()).GetMountedVehicle();
        return vehicle.IsDelamainTaxi_ADE();
    }
    return false;
}

@addField(AutoDriveSystem)
private let m_drivingAI_ADE: DrivingAIType;

@addMethod(AutoDriveSystem)
public final func GetDrivingAI_ADE() -> DrivingAIType {
    return this.m_drivingAI_ADE;
}

@addMethod(AutoDriveSystem)
private final func SetDrivingAI_ADE(drivingAI: DrivingAIType) -> Void {
    if NotEquals(this.m_drivingAI_ADE, drivingAI) {
        this.m_drivingAI_ADE = drivingAI;
        let autodriveBB = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_AutodriveData);
        autodriveBB.SetInt(GetAllBlackboardDefs().UI_AutodriveData.DrivingAI_ADE, EnumInt(drivingAI));
    }
}

@addMethod(AutoDriveSystem)
public final func GetModdedDrivingAIEnabled_ADE() -> Bool {
    return !this.GetVanillaAIEnabled_ADE();
}

@addMethod(AutoDriveSystem)
public final func GetVanillaAIEnabled_ADE() -> Bool {
    return IsVanillaAI(this.GetDrivingAI_ADE());
}

@addMethod(AutoDriveSystem)
public final func GetAutodriveEnabled_ADE() -> Bool {
    // replacement から呼び出される.
    if this.GetModdedDrivingAIEnabled_ADE() {
        return GetPlayer(this.GetGameInstance()).GetMountedVehicle().GetAutoDriveComponent_ADE().IsAutoDriving();
    } else {
        return super.GetAutodriveEnabled();
    }
}

public class SetAutodriveEnabledRequest extends ScriptableSystemRequest {
    public let enabled: Bool;
    public let isDelamain: Bool;
    public let forceVanilla: Bool;
    public let silent: Bool;
    public func Init(enabled: Bool, opt isDelamain: Bool, opt forceVanilla: Bool, opt silent: Bool) -> ref<SetAutodriveEnabledRequest> {
        this.enabled = enabled;
        this.isDelamain = isDelamain;
        this.forceVanilla = forceVanilla;
        this.silent = silent;
        return this;
    }
}

@addMethod(AutoDriveSystem)
public final func SetAutodriveEnabled_ADE(enabled: Bool, opt isDelamain: Bool, opt forceVanilla: Bool, opt silent: Bool) -> Bool {
    // replacement から呼び出される.
    let settings = this.GetSettings();
    // L(s"SetAutodriveEnabled_ADE: \(enabled) \(isDelamain) \(forceVanilla) \(silent) \(settings.drivingAI)");
    if isDelamain {
        this.SetDrivingAI_ADE(DrivingAIType.Vanilla);
        return super.SetAutodriveEnabled(enabled, isDelamain);
    }
    let player = GetPlayer(this.GetGameInstance());
    let vehicle = player.GetMountedVehicle();
    vehicle.SetGodMode_ADE(enabled && settings.noDamage && (!player.IsInCombat() || !settings.disableCheatsInCombat));

    if enabled {
        if !silent {
            GameObject.PlaySound(player, n"ui_auto_drive_start");
        }
        if !this.GetAutodriveEnabled() {
            if settings.IsModdedAI() && !forceVanilla && !Vector4.IsXYZZero(Vector4.Vector3To4(this.GetAutodriveDestination())) {
                this.SetDrivingAI_ADE(settings.drivingAI);
                vehicle.GetAutoDriveComponent_ADE().StartAutoDrive(Equals(this.GetSettings().drivingAI, DrivingAIType.ModdedTraffic));
                let autodriveBB = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_AutodriveData);
                autodriveBB.SetBool(GetAllBlackboardDefs().UI_AutodriveData.AutoDriveEnabled, true);
                this.OnAutodriveToggled(true, false);
                return true;
            } else {
                if forceVanilla || settings.IsModdedAI() {
                    this.SetDrivingAI_ADE(DrivingAIType.Vanilla);
                } else {
                    // Old Vanilal.
                    this.SetDrivingAI_ADE(settings.drivingAI);
                }
                // 助手席では動作しないので、DriverReady を送る. PassengerEvents.OnEnter で制御した方がよいのかな？
                vehicle.SendEvent_ADE(n"DriverReady");
                return super.SetAutodriveEnabled(enabled, isDelamain);
            }
        }
    } else {
        if !silent {
            GameObject.PlaySound(player, n"ui_auto_drive_stop");
        }
        let result = false;
        if this.GetModdedDrivingAIEnabled_ADE() {
            vehicle.GetAutoDriveComponent_ADE().CancelAutoDrive(false);
            this.OnAutodriveToggled(false, false);
            let autodriveBB = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_AutodriveData);
            autodriveBB.SetBool(GetAllBlackboardDefs().UI_AutodriveData.AutoDriveEnabled, false);
        } else {
            result = super.SetAutodriveEnabled(enabled, isDelamain);
        }
        this.SetDrivingAI_ADE(DrivingAIType.Vanilla);
        return result;
    }
    return false;
}

@wrapMethod(AutoDriveSystem)
private final func OnPlayerStateChange(value: Int32) -> Void {
    wrappedMethod(value);
    if this.GetAutodriveEnabled() {
        let settings = this.GetSettings();
        let inCombat = value == EnumInt(gamePSMCombat.InCombat);
        GetPlayer(this.GetGameInstance()).GetMountedVehicle().SetGodMode_ADE(settings.noDamage && (!inCombat || !settings.disableCheatsInCombat));
    }
}

@addMethod(AutoDriveSystem)
public final func RequestSetAutodriveEnabled_ADE(enabled: Bool, opt isDelamain: Bool, opt forceVanilla: Bool, opt silent: Bool, opt delay: Float) -> Void {
    let req = new SetAutodriveEnabledRequest().Init(enabled, isDelamain, forceVanilla, silent);
    // this.QueueRequest(req);
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayScriptableSystemRequest(this.GetClassName(), req, delay, false);
}

@addMethod(AutoDriveSystem)
private final func OnSetAutodriveEnabledRequest_ADE(req: ref<SetAutodriveEnabledRequest>) -> Void {
    this.SetAutodriveEnabled_ADE(req.enabled, req.isDelamain, req.forceVanilla, req.silent);
}

@addMethod(AutoDriveSystem)
public final func GetAutodriveVehicle_ADE() -> ref<VehicleObject> {
    // replacement から呼び出される.
    if this.GetModdedDrivingAIEnabled_ADE() {
        return GetPlayer(this.GetGameInstance()).GetMountedVehicle();
    } else {
        return super.GetAutodriveVehicle();
    }
}

@addMethod(AutoDriveSystem)
public final func CheckCurrentLaneValidity_ADE() -> gameAutodriveLaneValidityResult {
    if !this.IsDelamainTaxi_ADE()
    && this.GetSettings().unrestrictValidLane {
        return gameAutodriveLaneValidityResult.OnValidLane;
    } else {
        return super.CheckCurrentLaneValidity();
    }
}

@wrapMethod(AutoDriveSystem)
private final func OnToggleFreeRoamRequest(request: ref<ToggleFreeRoamRequest>) -> Void {
    if !this.GetFreeRoamEnabled() && this.GetModdedDrivingAIEnabled_ADE() {
        // Modded Driving AI を使ってる場合には、切り替え.
        this.SetAutodriveEnabled(false, this.GetAutodriveIsDelamain());
        this.SetAutodriveEnabled_ADE(true, this.GetAutodriveIsDelamain(), true);
    }
    wrappedMethod(request);
    if !this.GetFreeRoamEnabled() && this.GetSettings().IsModdedAI() && !this.GetAutodriveIsDelamain() {
        // Modded Driving AI を使用する設定なら、切り替え.
        this.SetAutodriveEnabled(false, this.GetAutodriveIsDelamain());
        this.SetAutodriveEnabled(true, this.GetAutodriveIsDelamain());
    }
}

@addMethod(AutoDriveSystem)
public func OnDestinationReachedWithModdedAI() -> Void {
    // DrivingAI から呼び出される.
    this.QueueRequest(new StopAutoDriveOnDestinationReachedRequest());
}

@addMethod(AutoDriveSystem)
public func OnStopAutoDriveWithModdedAI() -> Void {
    // DrivingAI から呼び出される.
    this.QueueRequest(new DisableAutoDriveRequest());
}

@replaceMethod(AutoDriveSystem)
public final const func GetAutodriveAvailable() -> Bool {
    let healthThreshold: Float;
    let mountedVehicle: ref<VehicleObject>;
    let psmBB: ref<IBlackboard>;
    let psmMeleeWeaponState: Int32;
    let psmRangedWeaponState: Int32;
    let psmState: Int32;
    let vehicleHealth: Float;
    if !IsDefined(this.m_player) || !IsDefined(this.m_player.GetMountedVehicle()) {
        return false;
    };
    mountedVehicle = this.m_player.GetMountedVehicle();
    if !mountedVehicle.IsPlayerVehicle() {
        if !this.GetSettings().unrestrictPlayersVehicle {
            return false;
        }
    };
    if mountedVehicle.IsVehicleAccelerateQuickhackActive() || mountedVehicle.IsVehicleForceBrakesQuickhackActive() {
        return false;
    };
    psmBB = this.m_player.GetPlayerStateMachineBlackboard();
    psmRangedWeaponState = psmBB.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Weapon);
    if !this.GetSettings().unrestrictNotInCombat {
        if this.GetAutodriveEnabled() && psmRangedWeaponState == EnumInt(gamePSMRangedWeaponStates.Shoot) {
            return false;
        };
        if this.GetAutodriveEnabled() && (psmMeleeWeaponState == EnumInt(gamePSMMeleeWeapon.ComboAttack) || psmMeleeWeaponState == EnumInt(gamePSMMeleeWeapon.StrongAttack) || psmMeleeWeaponState == EnumInt(gamePSMMeleeWeapon.ThrowAttack)) {
            return false;
        };
    }
    psmState = psmBB.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Combat);
    if psmState == 1 { // gamePSMCombat.InCombat
        if !this.GetSettings().unrestrictNotInCombat { 
            return false;
        }
    };
    psmState = psmBB.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Vehicle);
    if psmState != 1 && psmState != 3 && psmState != 6 {
        if this.GetSettings().canSwitchSeats
        && psmState != 2 // gamePSMVehicle.Passenger
        && psmState != 4 { // gamePSMVehicle.Transition
            return false;
        }
    };
    vehicleHealth = GameInstance.GetStatPoolsSystem(this.GetGameInstance()).GetStatPoolValue(Cast<StatsObjectID>(mountedVehicle.GetEntityID()), gamedataStatPoolType.Health, true);
    healthThreshold = TDB.GetFloat(t"Vehicle.autodrive_settings.healthDeactivationThreshold");
    if vehicleHealth <= healthThreshold {
        if !this.GetSettings().unrestrictVehicleHealth { 
            return false;
        }
    };
    if GameInstance.GetQuestsContentSystem(this.GetGameInstance()).IsTokensActivationBlockedBySource(n"sq024_race_active") {
        return false;
    };
    if NotEquals(this.CheckCurrentLaneValidity(), gameAutodriveLaneValidityResult.OnValidLane) {
        return false;
    };
    if !mountedVehicle.CanAutoDrive_ADE() {
        return false;
    };
    return true;
}

@wrapMethod(AutoDriveSystem)
private final func OnWeaponStateChange(value: Int32) -> Void {
    if !this.GetSettings().unrestrictNotInCombat { 
        wrappedMethod(value);
    }
}

@wrapMethod(AutoDriveSystem)
private final func OnMeleeWeaponStateChange(value: Int32) -> Void {
    if !this.GetSettings().unrestrictNotInCombat { 
        wrappedMethod(value);
    }
}

@wrapMethod(AutoDriveSystem)
private final func OnAutoDriveHitRequest(request: ref<AutoDriveHitRequest>) -> Void {
    if !this.GetSettings().unrestrictNotInCombat { 
        wrappedMethod(request);
    }
}

@wrapMethod(AutoDriveSystem)
private final func OnAutodriveToggled(enabled: Bool, isDelamain: Bool) -> Void {
    // base\open_world\autodrive\scenes\autodrive.scene
    // サウンドや武器装備チェックはしない. スクリプト側でするため.
    SetFactValue(this.GetGameInstance(), n"autodrive_enhanced_play_sound", 0);
    SetFactValue(this.GetGameInstance(), n"autodrive_enhanced_check_weapon", 0);

    wrappedMethod(enabled, isDelamain);
    if !isDelamain {
        SetFactValue(this.GetGameInstance(), n"autodrive_enhanced_play_anim", this.GetSettings().putElbowOnWindow ? 1 : 0);
        if enabled {
            if this.GetSettings().unrestrictNotInCombat {
                SetFactValue(this.GetGameInstance(), n"disable_combat_events", 0);
            }
            if this.GetSettings().unrestrictUnsavable {
                SaveLocksManager.RequestSaveLockRemove(this.m_player.GetGame(), n"Autodrive");
            }
        }
    }
}

@wrapMethod(AutoDriveSystem)
private final func OnDisableAutoDriveRequest(request: ref<DisableAutoDriveRequest>) -> Void {
    if !this.IsDelamainTaxi_ADE() && !this.IsPlayerDriver_ADE() {
        this.StopPlayerVehicle();
    }
    wrappedMethod(request);
}

@wrapMethod(AutoDriveController)
private final func ShouldInputHintBeVisible() -> Bool {
    /*
    let playerVehicleState: Int32;
    if !IsDefined(this.m_player) {
      return false;
    };
    if Cast<Bool>(GameInstance.GetQuestsSystem(this.m_gameInstance).GetFact(n"q000_started")) && !Cast<Bool>(GameInstance.GetQuestsSystem(this.m_gameInstance).GetFact(n"dpad_hints_visibility_enabled")) {
      return false;
    };
    playerVehicleState = this.m_player.GetPlayerStateMachineBlackboard().GetInt(GetAllBlackboardDefs().PlayerStateMachine.Vehicle);
    if playerVehicleState != 1 && playerVehicleState != 6 {
      return false;
    };
    if this.m_autodriveBB.GetBool(this.m_autodriveBBDef.CinematicCameraActive) {
      return false;
    };
    return true;
    */
    let result = wrappedMethod();
    if !result
    && IsDefined(this.m_player)
    && !AutoDriveEnhancedSystem.GetInstance(this.m_player.GetGame()).IsADEBlocked()
    && !(Cast<Bool>(GameInstance.GetQuestsSystem(this.m_gameInstance).GetFact(n"q000_started")) && !Cast<Bool>(GameInstance.GetQuestsSystem(this.m_gameInstance).GetFact(n"dpad_hints_visibility_enabled")))
    && !this.m_player.GetMountedVehicle().IsDelamainTaxi_ADE()
    && !this.m_autodriveBB.GetBool(this.m_autodriveBBDef.CinematicCameraActive) {
        let playerVehicleState = this.m_player.GetPlayerStateMachineBlackboard().GetInt(GetAllBlackboardDefs().PlayerStateMachine.Vehicle);
        if playerVehicleState == 3 { // gamePSMVehicle.Passenger
            result = true;
        }
    }
    return result;
}

@addField(AutoDriveController)
private let m_autoDriveDrivingAIChangedCallbackHandle: ref<CallbackHandle>;

@addField(AutoDriveController)
private let m_freeRoamText: String;

@addField(AutoDriveController)
private let m_timeCounterWidget: ref<inkText>;

@wrapMethod(AutoDriveController)
protected cb func OnInitialize() -> Bool {
    let result = wrappedMethod();
    this.m_autoDriveDrivingAIChangedCallbackHandle = this.m_autodriveBB.RegisterListenerInt(this.m_autodriveBBDef.DrivingAI_ADE, this, n"OnAutoDrivingAIChanged_ADE");
    let container = inkWidgetRef.Get(this.m_freeRoamHeaderContainer) as inkCompoundWidget;
    this.m_timeCounterWidget = container.GetWidget(n"timeCounter") as inkText;
    this.m_freeRoamText = this.m_timeCounterWidget.GetText();
    return result;
}

@wrapMethod(AutoDriveController)
protected cb func OnUninitialize() -> Bool {
    let result = wrappedMethod();
    this.m_autodriveBB.UnregisterListenerInt(this.m_autodriveBBDef.DrivingAI_ADE, this.m_autoDriveDrivingAIChangedCallbackHandle);
    return result;
}


@addMethod(AutoDriveController)
private final func OnAutoDrivingAIChanged_ADE(value: Int32) -> Void {
    this.m_drivingAI = IntEnum<DrivingAIType>(value);

    this.UpdateActiveDriveType(true);
}

@addField(AutoDriveController)
private let m_drivingAI: DrivingAIType;

@addMethod(AutoDriveController)
protected func UpdateTimeCounterText_ADE() -> Void {
    if Equals(this.m_activeDriveType, AutoDriveDriveType.FreeRoam) {
        this.m_timeCounterWidget.SetText(this.m_freeRoamText);
    } else {
        if Equals(this.m_drivingAI, DrivingAIType.ModdedNormal) {
            this.m_timeCounterWidget.SetText(ModdedNormalAILabel());
        } else if Equals(this.m_drivingAI, DrivingAIType.ModdedTraffic) {
            this.m_timeCounterWidget.SetText(ModdedTrafficAILabel());
        } else if Equals(this.m_drivingAI, DrivingAIType.OldVanilla230) {
            this.m_timeCounterWidget.SetText(OldVanilla230AILabel());
        } else {
            this.m_timeCounterWidget.SetText(this.m_freeRoamText);
        }
    }
}

@replaceMethod(AutoDriveController)
private final func SetActiveDriveType(type: AutoDriveDriveType, force: Bool) -> Void {
    let vanilla = Equals(IntEnum<DrivingAIType>(this.m_autodriveBB.GetInt(this.m_autodriveBBDef.DrivingAI_ADE)), DrivingAIType.Vanilla);

    let playbackOptions: inkAnimOptions;
    playbackOptions.dependsOnTimeDilation = false;
    if !force && Equals(type, this.m_activeDriveType) {
        return;
    };
    this.m_activeDriveType = type;
    if this.m_headerAnimProxy.IsValid() && this.m_headerAnimProxy.IsPlaying() {
      this.m_headerAnimProxy.Stop();
    };
    if this.m_inputHintDriveTypeAnimProxy.IsValid() && this.m_inputHintDriveTypeAnimProxy.IsPlaying() {
      this.m_inputHintDriveTypeAnimProxy.GotoEndAndStop();
    };
    if Equals(type, AutoDriveDriveType.GoToDestination) {
        if vanilla {
            this.m_remainingDistanceCounterTextParams.UpdateMeasurement("DISTANCE", 0.00, EMeasurementUnit.Meter);
            this.m_remainingTimeCounterTextParams.UpdateTime("TIME", 0);
        }
    }
    if !this.m_autodriveBB.GetBool(this.m_autodriveBBDef.AutoDriveDelamain) {
      this.m_headerAnimProxy = this.PlayLibraryAnimation(Equals(type, AutoDriveDriveType.GoToDestination) && vanilla ? n"showCounters" : n"showFreeRoamHeader", playbackOptions);
      this.m_inputHintDriveTypeAnimProxy = this.PlayLibraryAnimation(Equals(type, AutoDriveDriveType.GoToDestination) && vanilla ? n"switchToGoToDestination" : n"switchToFreeroam", playbackOptions);
    };
    this.UpdateTimeCounterText_ADE();
}

public class AutoDriveEnhancedSystem extends ScriptableSystem {
    public static func GetInstance(game: GameInstance) -> ref<AutoDriveEnhancedSystem> {
        // return GameInstance.GetScriptableSystemsContainer(game).Get(NameOf(AutoDriveEnhancedSystem)) as AutoDriveEnhancedSystem;
        return GameInstance.GetScriptableSystemsContainer(game).Get(NameOf(AutoDriveEnhancedSystem)) as AutoDriveEnhancedSystem;
    }

    public func IsADEBlocked() -> Bool {
        return this.IsInScene() || this.IsExitVehicleBlocked() || this.IsDelamainTaxi();
    }

    // DefaultTransition
    private func IsExitVehicleBlocked() -> Bool {
        let vehicle: ref<VehicleObject>;
        let vehicleWeak: wref<VehicleObject>;
        let player = GetPlayer(this.GetGameInstance());
        if StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"VehicleScene") {
            return true;
        };
        if StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"VehicleCombat") {
            return true;
        };
        if StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"VehicleBlockExit") {
            return true;
        };
        if this.IsInPhotoMode() {
            return true;
        };
        if GameInstance.GetRacingSystem(this.GetGameInstance()).IsRaceInProgress() {
            return true;
        };
        VehicleComponent.GetVehicle(this.GetGameInstance(), player, vehicleWeak);
        vehicle = vehicleWeak;
        if IsDefined(vehicle) && vehicle.IsFlippedOver() && vehicle.RecordHasTag(n"Important") {
            return true;
        };
        return false;
    }

    // DefaultTransition
    protected final func IsInPhotoMode() -> Bool {
        let photoModeSys: ref<PhotoModeSystem> = GameInstance.GetPhotoModeSystem(this.GetGameInstance());
        return photoModeSys.IsPhotoModeActive();
    }

    // VehicleTransition
    private func IsInScene() -> Bool {
        let highLevel: Int32 = GetPlayer(this.GetGameInstance()).GetPlayerStateMachineBlackboard().GetInt(GetAllBlackboardDefs().PlayerStateMachine.HighLevel);
        return highLevel >= 3 && highLevel <= 5;
    }

    private func IsDelamainTaxi() -> Bool {
        let player = GetPlayer(this.GetGameInstance());
        let vehicle: ref<VehicleObject>;
        let vehicleWeak: wref<VehicleObject>;
        VehicleComponent.GetVehicle(this.GetGameInstance(), player, vehicleWeak);
        vehicle = vehicleWeak;
        if IsDefined(vehicle) && vehicle.IsDelamainTaxi_ADE() {
            return true;
        }
        return false;
    }
}

@addMethod(DefaultTransition)
protected final func GetVehicle_ADE(scriptInterface: ref<StateGameScriptInterface>) -> ref<VehicleObject> {
    let vehicle: wref<VehicleObject>;
    VehicleComponent.GetVehicle(scriptInterface.executionOwner.GetGame(), scriptInterface.executionOwner, vehicle);
    return vehicle;
}

@addMethod(DefaultTransition) 
protected func IsADEBlocked(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Bool {
    return AutoDriveEnhancedSystem.GetInstance(scriptInterface.executionOwner.GetGame()).IsADEBlocked();
}

@addMethod(StateGameScriptInterface)
public final func IsActionProcess_ADE(actionName: CName, maxHeldTime: Float) -> Bool {
    return this.IsActionJustReleased(actionName) && this.GetActionPrevStateTime(actionName) < maxHeldTime;
}

@addMethod(InputContextTransitionEvents) 
protected final func ShowADEInputHints(source: CName, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    let vehicle: wref<VehicleObject>;
    if this.GetVehicle(scriptInterface, vehicle) && !this.IsADEBlocked(stateContext, scriptInterface) {
        let vehDataPackage: wref<VehicleDataPackage_Record>;
        VehicleComponent.GetVehicleDataPackage(vehicle.GetGame(), vehicle, vehDataPackage);
        let settings = Settings.GetInstance(vehicle.GetGame());
        if (Equals(source, n"VehicleDriver") || Equals(source, n"VehicleAutodrive") || Equals(source, n"VehiclePassenger")) {
            if settings.canSwitchSeats
            && settings.showSwitchSeatsInputHint
            && !vehDataPackage.DisableSwitchSeats()
            && vehDataPackage.VehSeatSet().GetVehSeatsCount() > 1 {
                this.ShowInputHint(scriptInterface, SwitchSeatsActionName(), source, SwitchSeatsHintLabel());
            } else {
                this.RemoveInputHint(scriptInterface, SwitchSeatsActionName(), source);
            }

            if (settings.canSwitchToNormalAIByInput || settings.canSwitchToTrafficAIByInput || settings.canSwitchToOldVanila230AIByInput)
            && settings.showSwitchAIInputHint {
                if Equals(settings.GetNextDrivingAI(), DrivingAIType.Vanilla) {
                    this.ShowInputHint(scriptInterface, SwitchAIActionName(), source, SwitchAIHintLabel_ToVanila());
                } else if Equals(settings.GetNextDrivingAI(), DrivingAIType.ModdedNormal) {
                    this.ShowInputHint(scriptInterface, SwitchAIActionName(), source, SwitchAIHintLabel_ToModdedNormal());
                } else if Equals(settings.GetNextDrivingAI(), DrivingAIType.ModdedTraffic) {
                    this.ShowInputHint(scriptInterface, SwitchAIActionName(), source, SwitchAIHintLabel_ToModdedTraffic());
                } else if Equals(settings.GetNextDrivingAI(), DrivingAIType.OldVanilla230) {
                    this.ShowInputHint(scriptInterface, SwitchAIActionName(), source, SwitchAIHintLabel_ToOldVanilla230());
                }
            } else {
                this.RemoveInputHint(scriptInterface, SwitchAIActionName(), source);
            }
        }

        if Equals(source, n"VehiclePassenger") {
            this.ShowInputHint(scriptInterface, ToggleVehCameraActionName(), source, "LocKey#36194", inkInputHintHoldIndicationType.FromInputConfig, true);
        } else {
            this.RemoveInputHint(scriptInterface, ToggleVehCameraActionName(), source);
        }
    } else {
        this.RemoveInputHint(scriptInterface, SwitchSeatsActionName(), source);
        this.RemoveInputHint(scriptInterface, SwitchAIActionName(), source);
        this.RemoveInputHint(scriptInterface, ToggleVehCameraActionName(), source);
    }
}

@addMethod(InputContextTransitionEvents) 
protected final func RemoveADEInputHints(source: CName, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    this.RemoveInputHint(scriptInterface, SwitchSeatsActionName(), source);
    this.RemoveInputHint(scriptInterface, SwitchAIActionName(), source);
    this.RemoveInputHint(scriptInterface, ToggleVehCameraActionName(), source);
}

// VehicleDriver
@wrapMethod(InputContextTransitionEvents)
protected final const func ShowVehicleDriverInputHints(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    this.ShowADEInputHints(n"VehicleDriver", stateContext, scriptInterface);
    wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(InputContextTransitionEvents)
protected final func RemoveVehicleDriverInputHints(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    wrappedMethod(stateContext, scriptInterface);
    this.RemoveADEInputHints(n"VehicleDriver", stateContext, scriptInterface);
}

// VehicleDriverCombat
@wrapMethod(InputContextTransitionEvents)
private final const func ShowVehicleDriverCombatInputHintsInternal(source: CName, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    this.ShowADEInputHints(n"VehicleDriverCombat", stateContext, scriptInterface);
    wrappedMethod(source, stateContext, scriptInterface);
}

@wrapMethod(InputContextTransitionEvents)
protected final func RemoveVehicleDriverCombatInputHints(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    wrappedMethod(stateContext, scriptInterface);
    this.RemoveADEInputHints(n"VehicleDriver", stateContext, scriptInterface);
}

// VehicleAutodrive
@wrapMethod(InputContextTransitionEvents)
protected final const func ShowAutodriveInputHints(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    this.ShowADEInputHints(n"VehicleAutodrive", stateContext, scriptInterface);
    wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(InputContextTransitionEvents)
protected final const func RemoveAutodriveInputHints(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    wrappedMethod(stateContext, scriptInterface);
    this.RemoveADEInputHints(n"VehicleAutodrive", stateContext, scriptInterface);
}

// VehiclePassenger
@wrapMethod(InputContextTransitionEvents)
protected final const func ShowVehiclePassengerInputHints(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    this.ShowADEInputHints(n"VehiclePassenger", stateContext, scriptInterface);
    this.UpdateVehicleDrawWeaponInputHint_ADE(n"VehiclePassenger", stateContext, scriptInterface);
    wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(InputContextTransitionEvents)
protected final const func RemoveVehiclePassengerInputHints(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    wrappedMethod(stateContext, scriptInterface);
    this.RemoveVehicleDrawWeaponInputHint_ADE(n"VehiclePassenger", stateContext, scriptInterface);
    this.RemoveADEInputHints(n"VehiclePassenger", stateContext, scriptInterface);
}

@addMethod(InputContextTransitionEvents)
protected final func ShowVehicleDrawWeaponInputHint_ADE(source: CName, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    this.ShowInputHint(scriptInterface, n"EnterCombatMode", source, "LocKey#45381", inkInputHintHoldIndicationType.FromInputConfig, true, 1);
    stateContext.SetPermanentBoolParameter(n"IsVehicleCombatModeBlocked", false, true);
}

@addMethod(InputContextTransitionEvents)
protected final func RemoveVehicleDrawWeaponInputHint_ADE(source: CName, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    this.RemoveInputHint(scriptInterface, n"EnterCombatMode", source);
    stateContext.SetPermanentBoolParameter(n"IsVehicleCombatModeBlocked", true, true);
}

@addMethod(InputContextTransitionEvents)
protected final func UpdateVehicleDrawWeaponInputHint_ADE(source: CName, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    let isVehicleCombatModeBlocked: Bool = this.IsVehicleBlockingCombat(scriptInterface) || this.IsEmptyHandsForced(stateContext, scriptInterface);
    // L(s"isVehicleCombatModeBlocked=\(isVehicleCombatModeBlocked) ADBlocked=\(this.IsAutoDriveBlocked(scriptInterface)) ExitBlocked=\(this.IsExitVehicleBlocked(scriptInterface))");
    if isVehicleCombatModeBlocked || this.IsADEBlocked(stateContext, scriptInterface) {
        this.RemoveVehicleDrawWeaponInputHint_ADE(source, stateContext, scriptInterface);
    } else {
        this.ShowVehicleDrawWeaponInputHint_ADE(source, stateContext, scriptInterface);
    }
}

// VehiclePassengerCombat
@wrapMethod(InputContextTransitionEvents)
protected final const func ShowVehiclePassengerCombatInputHints(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    wrappedMethod(stateContext, scriptInterface);
    if !this.IsADEBlocked(stateContext, scriptInterface) {
        this.ShowInputHint(scriptInterface, n"ExitCombatMode", n"VehiclePassengerCombat", "LocKey#87490", inkInputHintHoldIndicationType.FromInputConfig, true, 5);
    }
}

@wrapMethod(InputContextTransitionEvents)
protected final const func RemoveVehiclePassengerCombatInputHints(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    wrappedMethod(stateContext, scriptInterface);
    if !this.IsADEBlocked(stateContext, scriptInterface) {
        this.RemoveInputHint(scriptInterface, n"ExitCombatMode", n"VehiclePassengerCombat");
    }
}

// Refresh
@addField(InputContextTransitionEvents)
protected let m_drivingAI_ADE: DrivingAIType;
@addField(InputContextTransitionEvents)
protected let m_blocked_ADE: Bool;

@addMethod(InputContextTransitionEvents)
protected final func UpdateRefleshFlag_ADE(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    let settings = Settings.GetInstance(scriptInterface.executionOwner.GetGame());
    if NotEquals(this.m_drivingAI_ADE, settings.drivingAI)
    || NotEquals(this.m_blocked_ADE, this.IsADEBlocked(stateContext, scriptInterface)) {
        this.RequestRefleshHint_ADE(stateContext, scriptInterface);
        this.m_drivingAI_ADE = settings.drivingAI;
        this.m_blocked_ADE = this.IsADEBlocked(stateContext, scriptInterface);
    }
}

@addMethod(InputContextTransitionEvents)
protected final func RequestRefleshHint_ADE(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    stateContext.SetTemporaryBoolParameter(n"ForceRefreshInputHints", true, true);
}

@wrapMethod(VehicleDriverContextEvents)
protected final func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    this.UpdateRefleshFlag_ADE(stateContext, scriptInterface);
    wrappedMethod(timeDelta, stateContext, scriptInterface);
}

@wrapMethod(VehicleDriverCombatContextEvents)
protected final func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    this.UpdateRefleshFlag_ADE(stateContext, scriptInterface);
    wrappedMethod(timeDelta, stateContext, scriptInterface);
}

@wrapMethod(VehiclePassengerContextEvents)
protected final func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    this.UpdateRefleshFlag_ADE(stateContext, scriptInterface);
    wrappedMethod(timeDelta, stateContext, scriptInterface);
}

@wrapMethod(VehicleAutodriveContextEvents)
protected final func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    this.UpdateRefleshFlag_ADE(stateContext, scriptInterface);
    wrappedMethod(timeDelta, stateContext, scriptInterface);
}

// ======================

@wrapMethod(VehicleComponent)
private final func OnGameAttach() -> Void {
    wrappedMethod();
    if this.GetVehicle().IsPlayerVehicle() {
        this.GetPS().UnlockAllDoors_ADE();
    }
}

@addMethod(VehicleComponentPS)
public final func UnlockAllDoors_ADE() -> Void {
    this.UnlockAllVehDoors();
}

@addMethod(VehicleTransition)
public final func UnmountJohnnyIfPresent_ADE(vehicle: ref<VehicleObject>, slotName: CName) -> Void {
    let empty: EntityID;
    let slotID: MountingSlotId;
    slotID.id = slotName;
    let mountingInfo = GameInstance.GetMountingFacility(vehicle.GetGame()).GetMountingInfoSingleWithIds(empty, vehicle.GetEntityID(), slotID);
    let npc = GameInstance.FindEntityByID(vehicle.GetGame(), mountingInfo.childId) as gamePuppet;
    if IsDefined(npc) && Equals(npc.GetRecordID(), t"Character.Silverhand") && !npc.IsPlayer() && !npc.IsPlayerControlled() {
        let req = new UnmountingRequest();
        req.lowLevelMountingInfo = mountingInfo;
        GameInstance.GetMountingFacility(vehicle.GetGame()).Unmount(req);
    }
}

@wrapMethod(DriveDecisions)
public final const func ToSwitchSeats(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
    if scriptInterface.IsActionProcess_ADE(SwitchSeatsActionName(), 0.5) && !this.IsADEBlocked(stateContext, scriptInterface) && Settings.GetInstance(scriptInterface.executionOwner.GetGame()).canSwitchSeats {
        if Settings.GetInstance(scriptInterface.executionOwner.GetGame()).unmountJohnny {
            this.UnmountJohnnyIfPresent_ADE(this.GetVehicle_ADE(scriptInterface), n"seat_front_right");
        }
        stateContext.SetTemporaryBoolParameter(n"switchSeats", true, true);
    }
    return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(PassengerDecisions)
public final const func ToSwitchSeats(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
    if !this.IsADEBlocked(stateContext, scriptInterface) && Settings.GetInstance(scriptInterface.executionOwner.GetGame()).canSwitchSeats {
        if scriptInterface.IsActionProcess_ADE(SwitchSeatsActionName(), 0.5) {
            stateContext.SetTemporaryBoolParameter(n"switchSeats", true, true);
            return wrappedMethod(stateContext, scriptInterface);
        } else {
            // 勝手にDriverSeatへ移動しない.
            return false;
        }
    } else {
        return wrappedMethod(stateContext, scriptInterface);
    }
}

@wrapMethod(EnteringDecisions)
public final const func ToSwitchSeats(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
    // L(s"ExitBlocked=\(this.IsExitVehicleBlocked(scriptInterface)) IsAutoDriveBlocked=\(this.IsAutoDriveBlocked(scriptInterface)) CanAutoDrive=\(this.GetAutoDriveComponent(scriptInterface).CanAutoDrive()) hasOnUpdate=\(this.GetStaticBoolParameterDefault("hasOnUpdate", false))");
    if !this.IsADEBlocked(stateContext, scriptInterface)
    && this.GetVehicle_ADE(scriptInterface).IsPlayerVehicle()
    && Settings.GetInstance(scriptInterface.executionOwner.GetGame()).canSwitchSeats
    && Settings.GetInstance(scriptInterface.executionOwner.GetGame()).dontSwitchSeatsAutoOnEntering {
        if this.IsDriverInVehicle(scriptInterface) {
            return this.DriverSwitchSeatsCondition(stateContext, scriptInterface);
        };
    } else {
        return wrappedMethod(stateContext, scriptInterface);
    }
    return false;
}

@addMethod(VehicleTransition)
protected final func SetPassengerCombatArmsRestrictions_ADE(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>, shouldApply: Bool) -> Void {
    let param = stateContext.GetPermanentBoolParameter(n"adsPassengerCombatArmsRestrictions");
    let applied = param.valid && param.value;
    if shouldApply && !applied {
        this.SetVehicleStatusEffects(stateContext, scriptInterface, false);
        this.SetFirearmsGameplayRestriction(scriptInterface, false); // Firearms は sandevistan が使えないので、付け替える.
        StatusEffectHelper.ApplyStatusEffect(scriptInterface.executionOwner, t"GameplayRestriction.ADEPasengerCombat");
        stateContext.SetPermanentBoolParameter(n"adsPassengerCombatArmsRestrictions", true, true);
    } else if !shouldApply && applied {
        StatusEffectHelper.RemoveStatusEffect(scriptInterface.executionOwner, t"GameplayRestriction.ADEPasengerCombat");
        stateContext.SetPermanentBoolParameter(n"vehicleStatusEffectsApplied", false, false);
        this.SetVehicleStatusEffects(stateContext, scriptInterface, true);
        stateContext.SetPermanentBoolParameter(n"adsPassengerCombatArmsRestrictions", false, true);
    }
}

// ISSUE: なぜか助手席から席移動後にAutoDriveがアクティブにならない. またAutoDrive中に席移動すると止まる.
// これは, Vanilla も Modded Driving AI も同じ. つまり旧AutoDrive MODも同じ問題をかかえている. 2.3から.
// DriveEvents/PassengerEvents の OnEnter/OnExit で制御した方がよいかも？
@addMethod(VehicleObject)
public func WorkaroundForAutoDriveDontStart_ADE() -> Void {
    this.SendEvent_ADE(n"NoDriver", 0.0, true);
    this.SendEvent_ADE(n"DriverReady", 0.1);
}
@addMethod(VehicleObject)
public func SendEvent_ADE(name: CName, opt delay: Float, opt nextFrame: Bool) -> Void {
    let evt = new AIEvent();
    evt.name = name;
    if nextFrame {
        GameInstance.GetDelaySystem(this.GetGame()).DelayEventNextFrame(this, evt);
    } else if delay > 0.0 {
        GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, evt, delay);
    } else {
        this.QueueEvent(evt);
    }
}

@wrapMethod(SwitchSeatsEvents)
protected func OnExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    let vehicle = this.GetVehicle_ADE(scriptInterface);
    wrappedMethod(stateContext, scriptInterface);
    if AutoDriveSystem.GetInstance(vehicle.GetGame()).GetAutodriveEnabled() {
        vehicle.WorkaroundForAutoDriveDontStart_ADE();
    }
}

@replaceMethod(PassengerEvents)
protected func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    let audioEvt: ref<VehicleAudioEvent>;
    let camEvent: ref<vehicleRequestCameraPerspectiveEvent>;
    let fppCamParamsSide: Bool;
    let mountingInfo: MountingInfo;
    super.OnEnter(stateContext, scriptInterface);
    this.SetVehicleStatusEffects(stateContext, scriptInterface, true);
    mountingInfo = scriptInterface.GetMountingInfo(scriptInterface.executionOwner);
    this.SetSide(stateContext, scriptInterface);
    this.ForceIdleVehicle(stateContext);
    this.SetIsInVehicle(stateContext, true);
    this.SetIsCar(stateContext, true);
    if Equals(mountingInfo.slotId.id, n"seat_back_left") {
      fppCamParamsSide = true;
    };
    this.SetVehFppCameraParams(stateContext, scriptInterface, true, fppCamParamsSide);
    this.SendAnimFeature(stateContext, scriptInterface);
    this.SendIsCar(stateContext, scriptInterface);
    audioEvt = new VehicleAudioEvent();
    audioEvt.action = vehicleAudioEventAction.OnPlayerPassenger;
    scriptInterface.owner.QueueEvent(audioEvt);
    if stateContext.GetBoolParameter(n"requestedTPPCamera", true) {
      this.RequestVehicleCameraPerspective(scriptInterface, vehicleCameraPerspective.TPPClose);
      this.SetRequestedTPPCamera(stateContext, false);
    };
    this.noWeaponsRestrictionApplied = false;
    if this.stateMachineInitData.occupiedByNonFriendly {
      if Equals(mountingInfo.slotId.id, n"seat_front_right") {
        this.noWeaponsRestrictionApplied = true;
        StatusEffectHelper.ApplyStatusEffect(scriptInterface.executionOwner, t"GameplayRestriction.NoWeapons");
      };
    };
    this.RemoveMountingRequest(stateContext);
    this.PlayerStateChange(scriptInterface, 3);
    this.SetBlackboardIntVariable(scriptInterface, GetAllBlackboardDefs().PlayerStateMachine.Vehicle, 3);
    //===
    // camEvent = new vehicleRequestCameraPerspectiveEvent();
    // camEvent.cameraPerspective = vehicleCameraPerspective.FPP;
    // scriptInterface.executionOwner.QueueEvent(camEvent);
    if this.GetVehicle_ADE(scriptInterface).IsDelamainTaxi_ADE() || this.IsADEBlocked(stateContext, scriptInterface) {
        camEvent = new vehicleRequestCameraPerspectiveEvent();
        camEvent.cameraPerspective = vehicleCameraPerspective.FPP;
        scriptInterface.executionOwner.QueueEvent(camEvent);
    }
    //===
}

@addField(PassengerEvents)
private let m_jumpToIdleAnim: Bool;

@wrapMethod(PassengerEvents)
protected func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    let vehicle = this.GetVehicle_ADE(scriptInterface);
    wrappedMethod(stateContext, scriptInterface);
    if IsDefined(vehicle) && !this.IsADEBlocked(stateContext, scriptInterface) {
        vehicle.GetVehicleComponent().GetVehicleControllerPS().SetAllowPassengerCameraSwitch(true);
        vehicle.GetVehicleComponent().ToggleCrystalDome_ADE(true, false, false);
        this.SetPassengerCombatArmsRestrictions_ADE(stateContext, scriptInterface, true);
        GameInstance.GetWorkspotSystem(scriptInterface.executionOwner.GetGame()).SendJumpToAnimEnt(scriptInterface.executionOwner, n"idle", true);
        this.m_jumpToIdleAnim = true;
    }
}

@wrapMethod(PassengerEvents)
public final func OnExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    let vehicle = this.GetVehicle_ADE(scriptInterface);
    if this.m_jumpToIdleAnim {
        GameInstance.GetWorkspotSystem(scriptInterface.executionOwner.GetGame()).ResetPlaybackToStart(scriptInterface.executionOwner);
        this.m_jumpToIdleAnim = false;
    }
    wrappedMethod(stateContext, scriptInterface);
    if IsDefined(vehicle) && !this.IsADEBlocked(stateContext, scriptInterface) {
        vehicle.GetVehicleComponent().ToggleCrystalDome_ADE(false, false, false);
        vehicle.GetVehicleComponent().GetVehicleControllerPS().SetAllowPassengerCameraSwitch(false);
    }
    this.SetPassengerCombatArmsRestrictions_ADE(stateContext, scriptInterface, false);
}

@addField(CombatEvents)
private let m_camPerspective: vehicleCameraPerspective;

@wrapMethod(CombatEvents)
protected func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    wrappedMethod(stateContext, scriptInterface);
    this.m_camPerspective = (scriptInterface.owner as VehicleObject).GetCameraManager().GetPersistentPerspective();
    this.RequestVehicleCameraPerspective(scriptInterface, vehicleCameraPerspective.FPP);

    if !this.IsADEBlocked(stateContext, scriptInterface) {
        this.SetPassengerCombatArmsRestrictions_ADE(stateContext, scriptInterface, true);
    }
}

@wrapMethod(CombatEvents)
protected func OnExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    this.RequestVehicleCameraPerspective(scriptInterface, this.m_camPerspective);
    wrappedMethod(stateContext, scriptInterface);
    this.SetPassengerCombatArmsRestrictions_ADE(stateContext, scriptInterface, false);
}

@wrapMethod(DriveEvents)
public final func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    this.HandleInput_ADE(stateContext, scriptInterface);
    wrappedMethod(timeDelta, stateContext, scriptInterface);
}
@wrapMethod(PassengerEvents)
public final func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    this.HandleInput_ADE(stateContext, scriptInterface);
    wrappedMethod(timeDelta, stateContext, scriptInterface);
}
@wrapMethod(DriverCombatEvents)
public final func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    this.HandleInput_ADE(stateContext, scriptInterface);
    wrappedMethod(timeDelta, stateContext, scriptInterface);
}

@addMethod(VehicleEventsTransition)
protected func HandleInput_ADE(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    if !this.IsADEBlocked(stateContext, scriptInterface) {
        let settings = Settings.GetInstance(scriptInterface.executionOwner.GetGame());
        if scriptInterface.IsActionProcess_ADE(SwitchAIActionName(), 0.5) {
            if settings.canSwitchToNormalAIByInput || settings.canSwitchToTrafficAIByInput {
                this.RequestSwitchAI(stateContext, scriptInterface);
            }
        }
    }
}

@addMethod(VehicleEventsTransition)
protected final func RequestSwitchAI(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    let adSys = AutoDriveSystem.GetInstance(scriptInterface.executionOwner.GetGame());
    let enabled = adSys.GetAutodriveEnabled();
    let freeroam = adSys.GetFreeRoamEnabled();
    let delamain = adSys.GetAutodriveIsDelamain();

    let settings = Settings.GetInstance(scriptInterface.executionOwner.GetGame());
    settings.drivingAI = settings.GetNextDrivingAI();
    settings.UpdateDrivingAI();

    if enabled && !freeroam && !delamain {
        adSys.SetAutodriveEnabled_ADE(false, false, false, true);
        adSys.RequestSetAutodriveEnabled_ADE(true, false, false, true, 0.3);
    }
}

@wrapMethod(RadioHotkeyController)
protected cb func OnPlayerEnteredVehicle(value: Int32) -> Bool {
    let result = wrappedMethod(value);
    let delamainTaxiSeatFact: Int32 = GameInstance.GetQuestsSystem(this.m_player.GetGame()).GetFact(n"delamain_taxi_seat");
    let delamainTaxiState: Bool = false;
    if delamainTaxiSeatFact == 1 || delamainTaxiSeatFact == 2 {
        delamainTaxiState = true;
    }
    if value == 3 && !delamainTaxiState {
        this.SetHintController(true);
    }
    return result;
}

@addMethod(VehicleComponent)
public final func ToggleCrystalDome_ADE(toggle: Bool, opt force: Bool, opt instant: Bool, opt instantDelay: Float, opt meshVisibilityDelay: Float, opt fastStop: Bool) -> Void {
    this.ToggleCrystalDome(toggle, force, instant, instantDelay, meshVisibilityDelay, fastStop);
}

// AutodriveAndCinematicCameraContext
@addField(AutodriveAndCinematicCameraContextDecisions)
private let m_psmVehicleCallbackID: ref<CallbackHandle>;

@addField(AutodriveAndCinematicCameraContextDecisions)
protected let m_psmVehicle: gamePSMVehicle;

@wrapMethod(AutodriveAndCinematicCameraContextDecisions)
protected final func OnAttach(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Void {
    this.m_psmVehicleCallbackID = scriptInterface.localBlackboard.RegisterListenerInt(GetAllBlackboardDefs().PlayerStateMachine.Vehicle, this, n"OnVehicleStateChanged");
    wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(AutodriveAndCinematicCameraContextDecisions)
protected final func OnDetach(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Void {
    wrappedMethod(stateContext, scriptInterface);
    scriptInterface.localBlackboard.UnregisterListenerInt(GetAllBlackboardDefs().PlayerStateMachine.Vehicle, this.m_psmVehicleCallbackID);
}

@addMethod(AutodriveAndCinematicCameraContextDecisions)
protected cb func OnVehicleStateChanged(state: Int32) -> Bool {
    this.m_psmVehicle = IntEnum<gamePSMVehicle>(state);
    this.OnStateChanged();
}

@wrapMethod(VehicleAutodriveContextDecisions)
protected func OnStateChanged() -> Void {
    this.EnableOnEnterCondition(this.m_autodriveEnabled && !this.m_cinematicCameraActive && !this.m_delamainTaxi
        && (Equals(this.m_psmVehicle, gamePSMVehicle.Driving) || Equals(this.m_psmVehicle, gamePSMVehicle.Passenger)));
}

// VehiclePassengerContext
@addField(VehiclePassengerContextDecisions)
private let m_cinematicCameraCallbackID: ref<CallbackHandle>;

@addField(VehiclePassengerContextDecisions)
protected let m_cinematicCameraActive: Bool;

@addMethod(VehiclePassengerContextDecisions)
protected final func OnAttach(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Void {
    super.OnAttach(stateContext, scriptInterface);
    let autodriveBB: ref<IBlackboard> = scriptInterface.GetBlackboardSystem().Get(GetAllBlackboardDefs().UI_AutodriveData);
    this.m_cinematicCameraCallbackID = autodriveBB.RegisterListenerBool(GetAllBlackboardDefs().UI_AutodriveData.CinematicCameraActive, this, n"OnCinematicCameraStateChanged");
    this.m_cinematicCameraActive = autodriveBB.GetBool(GetAllBlackboardDefs().UI_AutodriveData.CinematicCameraActive);
    this.OnStateChanged();
}

@addMethod(VehiclePassengerContextDecisions)
protected cb func OnCinematicCameraStateChanged(cinematicCameraActive: Bool) -> Bool {
    this.m_cinematicCameraActive = cinematicCameraActive;
    this.OnStateChanged();
}

@addMethod(VehiclePassengerContextDecisions)
protected final func OnDetach(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Void {
    super.OnDetach(stateContext, scriptInterface);
    let autodriveBB: ref<IBlackboard> = scriptInterface.GetBlackboardSystem().Get(GetAllBlackboardDefs().UI_AutodriveData);
    autodriveBB.UnregisterListenerBool(GetAllBlackboardDefs().UI_AutodriveData.CinematicCameraActive, this.m_cinematicCameraCallbackID);
    this.m_cinematicCameraCallbackID = null;
}

@addMethod(VehiclePassengerContextDecisions)
protected func OnStateChanged() -> Void {
    this.EnableOnEnterCondition(!this.m_cinematicCameraActive);
}

@wrapMethod(VehiclePassengerContextDecisions)
protected const func ExitCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
    if !this.IsOnEnterConditionEnabled() || !this.EnterCondition(stateContext, scriptInterface) {
        return true;
    }
    return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(TimeDilationHelper)
public final static func CanUseTimeDilation(playerGameObject: wref<GameObject>) -> Bool {
    let result = wrappedMethod(playerGameObject);
    if !result {
        let player: ref<PlayerPuppet> = playerGameObject as PlayerPuppet;
        // passnger
        if IsDefined(player) 
        && (    player.GetPlayerStateMachineBlackboard().GetInt(GetAllBlackboardDefs().PlayerStateMachine.Vehicle) == 2 // gamePSMVehicle.Combat
            ||  player.GetPlayerStateMachineBlackboard().GetInt(GetAllBlackboardDefs().PlayerStateMachine.Vehicle) == 3 // gamePSMVehicle.Passenger
        )
        && PlayerDevelopmentSystem.GetData(player).IsNewPerkBoughtAnyLevel(gamedataNewPerkType.Cool_Left_Milestone_1) {
            result = true;
        };
    }
    return result;
}

@addField(HotkeyConsumableWidgetController)
private let m_cinematicCameraToggledListener: ref<CallbackHandle>;

@wrapMethod(HotkeyConsumableWidgetController)
private final func RegisterBlackboardListeners() -> Void {
    wrappedMethod();
    let autodriveBB: ref<IBlackboard> = this.GetBlackboardSystem().Get(GetAllBlackboardDefs().UI_AutodriveData);
    this.m_cinematicCameraToggledListener = autodriveBB.RegisterDelayedListenerBool(GetAllBlackboardDefs().UI_AutodriveData.CinematicCameraActive, this, n"OnCinematicCameraToggled");
}

@wrapMethod(HotkeyConsumableWidgetController)
private final func UnregisterBlackboardListeners() -> Void {
    wrappedMethod();
    if IsDefined(this.m_cinematicCameraToggledListener) {
        this.GetBlackboardSystem().Get(GetAllBlackboardDefs().UI_AutodriveData).UnregisterListenerBool(GetAllBlackboardDefs().UI_AutodriveData.CinematicCameraActive, this.m_cinematicCameraToggledListener);
    };
}

@wrapMethod(HotkeyConsumableWidgetController)
protected cb func OnAutodriveToggled(value: Bool) -> Bool {
    wrappedMethod(value);
    this.SetContainerVisibility(this.GetVisibilityByAutoDrive(), false);
}

@addMethod(HotkeyConsumableWidgetController)
protected cb func OnCinematicCameraToggled(value: Bool) -> Bool {
    this.SetContainerVisibility(this.GetVisibilityByAutoDrive(), false);
}

@addMethod(HotkeyConsumableWidgetController)
private func GetVisibilityByAutoDrive() -> Bool {
    let autodriveBB: ref<IBlackboard> = this.GetBlackboardSystem().Get(GetAllBlackboardDefs().UI_AutodriveData);
    return !autodriveBB.GetBool(GetAllBlackboardDefs().UI_AutodriveData.CinematicCameraActive);
}

@wrapMethod(HotkeyConsumableWidgetController)
private final func RegisterBlackboardListeners() -> Void {
    wrappedMethod();
    let autodriveBB: ref<IBlackboard> = this.GetBlackboardSystem().Get(GetAllBlackboardDefs().UI_AutodriveData);
    if autodriveBB.GetBool(GetAllBlackboardDefs().UI_AutodriveData.AutoDriveEnabled) {
        this.SetContainerVisibility(this.GetVisibilityByAutoDrive(), true);
    }
}

@replaceMethod(WeaponRosterGameController)
  private final func UpdateVehicleRoster(mountingInfo: MountingInfo) -> Void {
    let uiActiveVehicleBlackboard: wref<IBlackboard>;
    let vehicle: ref<VehicleObject>;
    let vehicleDataPackageRecord: ref<VehicleDataPackage_Record>;
    this.m_inVehicle = EntityID.IsDefined(mountingInfo.parentId);
    this.Fold();
    if this.m_inVehicle {
      vehicle = GameInstance.FindEntityByID(this.m_player.GetGame(), mountingInfo.parentId) as VehicleObject;
      vehicleDataPackageRecord = vehicle.GetRecord().VehDataPackageHandle();
      if IsDefined(vehicleDataPackageRecord) {
        this.m_inWeaponizedVehicle = Equals(vehicleDataPackageRecord.DriverCombat().Type(), gamedataDriverCombatType.MountedWeapons);
        // =====
        if this.m_inWeaponizedVehicle && NotEquals(mountingInfo.slotId.id, n"seat_front_left") {
            this.m_inWeaponizedVehicle = false;
        }
        // =====
        if this.m_inWeaponizedVehicle {
          uiActiveVehicleBlackboard = this.GetBlackboardSystem().Get(GetAllBlackboardDefs().UI_ActiveVehicleData);
          this.OnWeaponizedVehicleMachineGunAmmoChanged(uiActiveVehicleBlackboard.GetUint(GetAllBlackboardDefs().UI_ActiveVehicleData.MountedPowerWeaponAmmo));
          if vehicle.CanSwitchWeapons() {
            inkWidgetRef.SetVisible(this.m_weaponizedVehicleMissileLauncherContainer, true);
            this.m_weaponizedVehicleMissileLauncherMaxCharges = Cast<Uint32>(GameInstance.GetStatsSystem(this.m_player.GetGame()).GetStatValue(Cast<StatsObjectID>(this.m_player.GetEntityID()), gamedataStatType.VehicleMissileLauncherMaxCharges));
            this.m_weaponizedVehicleMissileLauncherRechargeTime = GameInstance.GetStatsSystem(this.m_player.GetGame()).GetStatValue(Cast<StatsObjectID>(this.m_player.GetEntityID()), gamedataStatType.VehicleMissileLauncherRechargeDuration);
            this.OnWeaponizedVehicleMissileLauncherChargesChanged(uiActiveVehicleBlackboard.GetUint(GetAllBlackboardDefs().UI_ActiveVehicleData.MountedMissileLauncherAmmo));
          } else {
            inkWidgetRef.SetVisible(this.m_weaponizedVehicleMissileLauncherContainer, false);
          };
        };
      };
    };
  }


@wrapMethod(AutoDriveController)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    let hudManager = GameInstance.GetScriptableSystemsContainer(this.m_gameInstance).Get(n"HUDManager") as HUDManager;
    if IsDefined(hudManager) && hudManager.GetUiScannerVisible() {
        return false;
    }
    return wrappedMethod(action, consumer);
}

@wrapMethod(TestStackPassiveExpression)
public final func CalculateValue(context: ScriptExecutionContext, data: script_ref<TestStackScriptData>) -> Variant {
    let result = wrappedMethod(context, data);
    if Equals(this.SomeNameProperty, n"AutoDriveEnhanced.Use230AI") {
        let useOld = Equals(Settings.GetInstance(context.GetOwner().GetGame()).drivingAI, DrivingAIType.OldVanilla230);
        return ToVariant(useOld);
    }
    return result;
}

// ==== stolen car issue ====
// ISSUE: StealVehicleEvent を QueueEvent すると、なぜか AutoDrive ができなくなるので、別の Event を経由する.
@if(!ModuleExists("AutoDriveMod"))
@replaceMethod(VehicleComponent)
  private final func StealVehicle(opt slotID: MountingSlotId) -> Void {
    let stealEvent: ref<StealVehicleEvent>;
    let vehicleHijackEvent: ref<VehicleHijackEvent>;
    let vehicle: wref<VehicleObject> = this.GetVehicle();
    if !IsDefined(vehicle) {
      return;
    };
    if IsNameValid(slotID.id) {
      vehicleHijackEvent = new VehicleHijackEvent();
      vehicleHijackEvent.driverAllowedToGetAggressive = Equals(slotID.id, n"seat_front_left");
      VehicleComponent.QueueEventToPassenger(vehicle.GetGame(), vehicle, slotID, vehicleHijackEvent);
    };
    stealEvent = new StealVehicleEvent();
    let evt: ref<Event> = stealEvent;
    if Settings.GetInstance(vehicle.GetGame()).enableWorkaroundForIssueOfStolenCar {
        // ISSUE: StealVehicleEvent を QueueEvent すると、なぜか AutoDrive ができなくなるので、別の Event を経由する.
        evt = new StealVehicleWrapEvent().Init(stealEvent);
    }
    vehicle.QueueEvent(evt);
  }

@if(!ModuleExists("AutoDriveMod"))
public class StealVehicleWrapEvent extends Event {
    public func Init(wrapped: ref<StealVehicleEvent>) -> ref<StealVehicleWrapEvent> { this.wrapped = wrapped; return this; }
    public let wrapped: ref<StealVehicleEvent>;
}

@if(!ModuleExists("AutoDriveMod"))
@addMethod(VehicleObject)
protected cb func OnStealVehicleWrapEvent(evt: ref<StealVehicleWrapEvent>) -> Bool {
    this.OnStealVehicleEvent(evt.wrapped);
}
// ==== stolen car issue ====

// ==== Reset Vehicle Camera ====
@wrapMethod(VehicleEventsTransition)
protected final func HandleCameraInput(scriptInterface: ref<StateGameScriptInterface>) -> Void {
    wrappedMethod(scriptInterface);
    if scriptInterface.IsActionJustReleased(n"VehicleCameraReset") && !this.IsVehicleCameraChangeBlocked(scriptInterface) {
        this.ResetVehicleCamera(scriptInterface);
    };
}
// ==== Reset Vehicle Camera ====

// ==== For cheats ====
@wrapMethod(VehicleObject)
protected cb func OnHit(evt: ref<gameHitEvent>) -> Bool {
    let sys = AutoDriveSystem.GetInstance(this.GetGame());
    let godMode = GameInstance.GetGodModeSystem(this.GetGame());
    if this.IsPlayerMounted()
    && godMode.HasGodMode(this.GetEntityID(), gameGodModeType.Invulnerable) {
        this.DestructionResetGlass();
        this.DestructionResetGrid();
    }
    wrappedMethod(evt);
}

@wrapMethod(PreventionSystem)
private final func HeatPipeline(heatChangeReason: String) -> Void {
    let sys = AutoDriveSystem.GetInstance(this.GetGame());
    if sys.GetAutodriveEnabled()
    && sys.GetSettings().lockHeatLevel
    && (!sys.GetSettings().disableCheatsInCombat || !GetPlayer(this.GetGame()).IsInCombat()) {
       return;
    }
    wrappedMethod(heatChangeReason);
}

@addMethod(VehicleObject)
public func SetGodMode_ADE(enabled: Bool) -> Void {
    let godMode = GameInstance.GetGodModeSystem(this.GetGame());
    if NotEquals(godMode.HasGodMode(this.GetEntityID(), gameGodModeType.Invulnerable), enabled) {
        if enabled {
            godMode.AddGodMode(this.GetEntityID(), gameGodModeType.Invulnerable, n"Default");
        } else {
            godMode.RemoveGodMode(this.GetEntityID(), gameGodModeType.Invulnerable, n"Default");
        }
    }
}
// ==== For cheats ====

/*
DogTown gate を助手席で通るため、以下から delamain_taxi_state の条件を削除.
ep1\openworld\combat_zone_gate\combat_zone_gate.questphase 4-6-6 delamain_taxi_state 4
ep1\openworld\combat_zone_gate\combat_zone_gate.questphase 4-6-49 delamain_taxi_state 4
ep1\openworld\combat_zone_gate\combat_zone_gate.questphase 4-6-137 delamain_taxi_state 4
ep1\openworld\combat_zone_gate\combat_zone_gate.questphase 4-6-380 delamain_taxi_state 6
ep1\openworld\combat_zone_gate\combat_zone_gate.questphase 4-8-6 delamain_taxi_state 4
ep1\openworld\combat_zone_gate\combat_zone_gate.questphase 4-8-49 delamain_taxi_state 4
ep1\openworld\combat_zone_gate\combat_zone_gate.questphase 4-8-96 delamain_taxi_state 4
ep1\openworld\combat_zone_gate\combat_zone_gate.questphase 4-8-305 delamain_taxi_state 6
*/
