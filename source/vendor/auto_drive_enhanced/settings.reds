module AutoDriveEnhanced

func SwitchSeatsHintLabel() -> String = "Gameplay-AutoDriveEnhanced-SwitchSeats";

func ModdedNormalAILabel() -> String = "Gameplay-AutoDriveEnhanced-ModdedNormalAI";
func ModdedTrafficAILabel() -> String = "Gameplay-AutoDriveEnhanced-ModdedTrafficAI";
func OldVanilla230AILabel() -> String = "Gameplay-AutoDriveEnhanced-OldVanilla230AI";

func SwitchAIHintLabel_ToVanila() -> String = "Gameplay-AutoDriveEnhanced-SwitchAI_ToVanilla";
func SwitchAIHintLabel_ToModdedNormal() -> String = "Gameplay-AutoDriveEnhanced-SwitchAI_ToModdedNormal";
func SwitchAIHintLabel_ToModdedTraffic() -> String = "Gameplay-AutoDriveEnhanced-SwitchAI_ToModdedTraffic";
func SwitchAIHintLabel_ToOldVanilla230() -> String = "Gameplay-AutoDriveEnhanced-SwitchAI_ToOldVanilla230";

enum DrivingAIType {
    Vanilla = 0,
    ModdedNormal = 1,
    ModdedTraffic = 2,
    OldVanilla230 = 3
}

func IsVanillaAI(aiType: DrivingAIType) -> Bool = Equals(aiType, DrivingAIType.Vanilla) || Equals(aiType, DrivingAIType.OldVanilla230);

func CycleDrivingAIType(aiType: DrivingAIType) -> DrivingAIType {
    let val = EnumInt(aiType);
    return IntEnum<DrivingAIType>((val + 1) % 4);
}

public class Settings extends ScriptableSystem {

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-canSwitchSeats-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-canSwitchSeats-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-GeneralCategory-label")
    @runtimeProperty("ModSettings.category.order", "0")
    public let canSwitchSeats: Bool = true;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-unmountJohnny-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-unmountJohnny-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-GeneralCategory-label")
    public let unmountJohnny: Bool = true;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-dontSwitchSeatsAutoOnEntering-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-dontSwitchSeatsAutoOnEntering-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-GeneralCategory-label")
    public let dontSwitchSeatsAutoOnEntering: Bool = false;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-unrestrictPlayersVehicle-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-unrestrictPlayersVehicle-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-GeneralCategory-label")
    public let unrestrictPlayersVehicle: Bool = true;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-unrestrictNotInCombat-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-unrestrictNotInCombat-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-GeneralCategory-label")
    public let unrestrictNotInCombat: Bool = true;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-unrestrictVehicleHealth-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-unrestrictVehicleHealth-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-GeneralCategory-label")
    public let unrestrictVehicleHealth: Bool = true;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-unrestrictValidLane-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-unrestrictValidLane-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-GeneralCategory-label")
    public let unrestrictValidLane: Bool = false;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-unrestrictUnsavable-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-unrestrictUnsavable-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-GeneralCategory-label")
    public let unrestrictUnsavable: Bool = false;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-restrictVehicles-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-restrictVehicles-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-GeneralCategory-label")
    public let restrictVehicles: Bool = false;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-putElbowOnWindow-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-putElbowOnWindow-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-GeneralCategory-label")
    public let putElbowOnWindow: Bool = true;

    /*** Driving AI ***/
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-drivingAI-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-drivingAI-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAICategory-label")
    @runtimeProperty("ModSettings.category.order", "100")
    @runtimeProperty("ModSettings.displayValues.Vanilla", "UI-AutoDriveEnhanced-Settings-drivingAI.Vanilla-label")
    @runtimeProperty("ModSettings.displayValues.ModdedNormal", "UI-AutoDriveEnhanced-Settings-drivingAI.ModdedNormalAI-label")
    @runtimeProperty("ModSettings.displayValues.ModdedTraffic", "UI-AutoDriveEnhanced-Settings-drivingAI.ModdedTrafficAI-label")
    @runtimeProperty("ModSettings.displayValues.OldVanilla230", "UI-AutoDriveEnhanced-Settings-drivingAI.OldVanilla230-label")
    public let drivingAI: DrivingAIType = DrivingAIType.Vanilla;
    private let drivingAIName: CName = n"drivingAI";

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-canSwitchToNormalAIByInput-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-canSwitchToNormalAIByInput-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAICategory-label")
    public let canSwitchToNormalAIByInput: Bool = false;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-canSwitchToTrafficAIByInput-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-canSwitchToTrafficAIByInput-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAICategory-label")
    public let canSwitchToTrafficAIByInput: Bool = false;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-canSwitchToOldVanila230AIByInput-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-canSwitchToOldVanila230AIByInput-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAICategory-label")
    public let canSwitchToOldVanila230AIByInput: Bool = false;


    /*** Normal AI ***/
    // Ticks timeout
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-TicksTimeout-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-TicksTimeout-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAICategory-label")
    @runtimeProperty("ModSettings.category.order", "110")
    @runtimeProperty("ModSettings.step", "10")
    @runtimeProperty("ModSettings.min", "10.0")
    @runtimeProperty("ModSettings.max", "3600.0")
    public let ticksTimeout: Float = 1200.0;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-ClearTrafficOnPath-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-ClearTrafficOnPath-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAICategory-label")
    public let clearTrafficOnPath: Bool = false;
    private let clearTrafficOnPathName: CName = n"clearTrafficOnPath";

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-AutoSpeedControl-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-AutoSpeedControl-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAICategory-label")
    public let autoSpeedControl: Bool = true;
    private let autoSpeedControlName: CName = n"autoSpeedControl";

    // Set invisible OnRegister func. SetValue OnVarUpdated func.
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    public let autoSpeedControlInvert: Bool = false;
    private let autoSpeedControlInvertName: CName = n"autoSpeedControlInvert";

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-AutoSpeedControlMaxSpeedRatio-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-AutoSpeedControlMaxSpeedRatio-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAICategory-label")
    @runtimeProperty("ModSettings.step", "0.01")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "1.0")
    @runtimeProperty("ModSettings.dependency", "autoSpeedControl")
    public let autoSpeedControlMaxSpeedRatio: Float = 0.7;

    // Starting
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-StartingDistance-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-StartingDistance-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAICategory-label")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "1.0")
    @runtimeProperty("ModSettings.max", "100.0")
    @runtimeProperty("ModSettings.dependency", "autoSpeedControlInvert")
    public let startingDistance: Float = 15.0;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-StartingMaxSpeed-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-StartingMaxSpeed-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAICategory-label")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "1.0")
    @runtimeProperty("ModSettings.max", "200.0")
    @runtimeProperty("ModSettings.dependency", "autoSpeedControlInvert")
    public let startingMaxSpeed: Float = 10.0;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-StartingMinSpeed-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-StartingMinSpeed-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAICategory-label")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "1.0")
    @runtimeProperty("ModSettings.max", "100.0")
    @runtimeProperty("ModSettings.dependency", "autoSpeedControlInvert")
    public let startingMinSpeed: Float = 3.0;

    // Cruising
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-CruisingMaxSpeed-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-CruisingMaxSpeed-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAICategory-label")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "1.0")
    @runtimeProperty("ModSettings.max", "200.0")
    @runtimeProperty("ModSettings.dependency", "autoSpeedControlInvert")
    public let cruisingMaxSpeed: Float = 30.0;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-CruisingMinSpeed-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-CruisingMinSpeed-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAICategory-label")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "1.0")
    @runtimeProperty("ModSettings.max", "100.0")
    @runtimeProperty("ModSettings.dependency", "autoSpeedControlInvert")
    public let cruisingMinSpeed: Float = 10.0;

    // Stopping
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-StoppingDistance-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-StoppingDistance-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAICategory-label")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "1.0")
    @runtimeProperty("ModSettings.max", "100.0")
    @runtimeProperty("ModSettings.dependency", "autoSpeedControlInvert")
    public let stoppingDistance: Float = 50.0;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-StoppingMaxSpeed-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-StoppingMaxSpeed-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAICategory-label")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "1.0")
    @runtimeProperty("ModSettings.max", "200.0")
    @runtimeProperty("ModSettings.dependency", "autoSpeedControlInvert")
    public let stoppingMaxSpeed: Float = 8.0;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-StoppingMinSpeed-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-StoppingMinSpeed-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAICategory-label")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "100.0")
    @runtimeProperty("ModSettings.dependency", "autoSpeedControlInvert")
    public let stoppingMinSpeed: Float = 3.0;

    // Brake
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-BrakeTimeBase-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-BrakeTimeBase-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAICategory-label")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0")
    @runtimeProperty("ModSettings.max", "10")
    @runtimeProperty("ModSettings.dependency", "autoSpeedControlInvert")
    public let forceBrakesBaseTime: Float = 0.5;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-BrakeTimeSpeedFactor-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-BrakeTimeSpeedFactor-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAICategory-label")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0")
    @runtimeProperty("ModSettings.max", "10")
    @runtimeProperty("ModSettings.dependency", "autoSpeedControlInvert")
    public let forceBrakesSpeedFactor: Float = 1.0;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-BrakeTimeMassFactor-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-BrakeTimeMassFactor-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAICategory-label")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0")
    @runtimeProperty("ModSettings.max", "10")
    @runtimeProperty("ModSettings.dependency", "autoSpeedControlInvert")
    public let forceBrakesMassFactor: Float = 1.0;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-BrakeTimeBrakingTorqueFactor-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-BrakeTimeBrakingTorqueFactor-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAICategory-label")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0")
    @runtimeProperty("ModSettings.max", "10")
    @runtimeProperty("ModSettings.dependency", "autoSpeedControlInvert")
    public let forceBrakesBrakingTorqueFactor: Float = 1.0;

    /*** Sync Speed ***/
    // Sync speed.
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeed-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeed-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedCategory-label")
    @runtimeProperty("ModSettings.category.order", "120")
    public let syncMaxSpeed: Bool = true;
    private let syncMaxSpeedName: CName = n"syncMaxSpeed";

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedBaseGap-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedBaseGap-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedCategory-label")
    @runtimeProperty("ModSettings.step", "0.5")
    @runtimeProperty("ModSettings.min", "0")
    @runtimeProperty("ModSettings.max", "50")
    @runtimeProperty("ModSettings.dependency", "syncMaxSpeed")
    public let syncMaxSpeedVehicleInFrontBaseDistance: Float = 20.0;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedAddGapForSpeed-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedAddGapForSpeed-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedCategory-label")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0")
    @runtimeProperty("ModSettings.max", "10")
    @runtimeProperty("ModSettings.dependency", "syncMaxSpeed")
    public let syncMaxSpeedVehicleInFrontDistanceSpeedFactor: Float = 1.0;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedAddGapForMass-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedAddGapForMass-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedCategory-label")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0")
    @runtimeProperty("ModSettings.max", "10")
    @runtimeProperty("ModSettings.dependency", "syncMaxSpeed")
    public let syncMaxSpeedVehicleInFrontDistanceMassFactor: Float = 1.0;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedAddGapForBrake-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedAddGapForBrake-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedCategory-label")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0")
    @runtimeProperty("ModSettings.max", "10")
    @runtimeProperty("ModSettings.dependency", "syncMaxSpeed")
    public let syncMaxSpeedVehicleInFrontDistanceBrakingTorqueFactor: Float = 1.0;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedGapForStopApproaching-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedGapForStopApproaching-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedCategory-label")
    @runtimeProperty("ModSettings.step", "0.5")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "50.0")
    @runtimeProperty("ModSettings.dependency", "syncMaxSpeed")
    public let syncMaxSpeedDistanceToStopApproaching: Float = 15.0;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedApproachingSpeed-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedApproachingSpeed-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedNormalAI-SyncSpeedCategory-label")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "20.0")
    @runtimeProperty("ModSettings.dependency", "syncMaxSpeed")
    public let syncMaxSpeedApproachSpeed: Float = 5.0;

    /*** Traffic AI ***/
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedTrafficAI-stoppingDistanceForTrafficAI-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedTrafficAI-stoppingDistanceForTrafficAI-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-DrivingAI-ModdedTrafficAICategory-label")
    @runtimeProperty("ModSettings.category.order", "150")
    @runtimeProperty("ModSettings.step", "0.5")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "50.0")
    public let stoppingDistanceForTrafficAI: Float = 8.0;

    /*** UI ***/
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-showSwitchSeatsInputHint-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-showSwitchSeatsInputHint-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-UICategory-label")
    @runtimeProperty("ModSettings.category.order", "200")
    public let showSwitchSeatsInputHint: Bool = true;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-showSwitchAIInputHint-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-showSwitchAIInputHint-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-UICategory-label")
    public let showSwitchAIInputHint: Bool = false;

    /*** Keybinds ***/
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-ADE_SwitchSeats_Key-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-ADE_SwitchSeats_Key-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-KeybindsCategory-label")
    @runtimeProperty("ModSettings.category.order", "300")
    public let ADE_SwitchSeats_Key: EInputKey  = EInputKey.IK_V;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-ADE_SwitchAI_Key-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-ADE_SwitchAI_Key-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-KeybindsCategory-label")
    public let ADE_SwitchAI_Key: EInputKey  = EInputKey.IK_Y;

    /*** Cheat ***/
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-noDamage-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-noDamage-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-CheatCategory-label")
    @runtimeProperty("ModSettings.category.order", "400")
    public let noDamage: Bool = false;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-lockHeatLevel-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-lockHeatLevel-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-CheatCategory-label")
    public let lockHeatLevel: Bool = false;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "UI-AutoDriveEnhanced-Settings-disableCheatsInCombat-label")
    @runtimeProperty("ModSettings.description", "UI-AutoDriveEnhanced-Settings-disableCheatsInCombat-desc")
    @runtimeProperty("ModSettings.category", "UI-AutoDriveEnhanced-Settings-CheatCategory-label")
    public let disableCheatsInCombat: Bool = false;


    // don't translate following.
    /*** For dev ***/
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "Show Dev Option (Don't touch, dev only)")
    @runtimeProperty("ModSettings.description", "Show Dev Option (Don't touch, dev only)")
    @runtimeProperty("ModSettings.category", "[For Dev]")
    @runtimeProperty("ModSettings.category.order", "1000")
    public let showForDev: Bool = false;

    // workaround
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "Workaround for stolen car issue.")
    @runtimeProperty("ModSettings.description", "Workaround for stolen car issue.")
    @runtimeProperty("ModSettings.category", "[For Dev] Workaround")
    @runtimeProperty("ModSettings.category.order", "1100")
    @runtimeProperty("ModSettings.dependency", "showForDev")
    public let enableWorkaroundForIssueOfStolenCar: Bool = true;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "Workaround for the issue of moving on its own after getting off the car")
    @runtimeProperty("ModSettings.description", "Workaround for the issue of moving on its own after getting off the car. but vehicle stops when jump out of the car")
    @runtimeProperty("ModSettings.category", "[For Dev] Workaround")
    @runtimeProperty("ModSettings.dependency", "showForDev")
    public let enableWorkaroundForIssueOfMovingOnItsOwn: Bool = true;

    // Modded Normal AI
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "useKinematic")
    @runtimeProperty("ModSettings.description", "useKinematic")
    @runtimeProperty("ModSettings.category", "[For Dev] Modded Normal AI")
    @runtimeProperty("ModSettings.category.order", "10100")
    @runtimeProperty("ModSettings.dependency", "showForDev")
    public let useKinematic: Bool = true;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "driveDownTheRoadIndefinitely")
    @runtimeProperty("ModSettings.description", "driveDownTheRoadIndefinitely")
    @runtimeProperty("ModSettings.category", "[For Dev] Modded Normal AI")
    @runtimeProperty("ModSettings.dependency", "showForDev")
    public let driveDownTheRoadIndefinitely: Bool = false;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "minimumDistanceToTarget")
    @runtimeProperty("ModSettings.description", "minimumDistanceToTarget")
    @runtimeProperty("ModSettings.category", "[For Dev] Modded Normal AI")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "100.0")
    @runtimeProperty("ModSettings.dependency", "showForDev")
    public let minimumDistanceToTarget: Float = 0.0;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "showDebugInfoForSync")
    @runtimeProperty("ModSettings.description", "showDebugInfoForSync")
    @runtimeProperty("ModSettings.category", "[For Dev] Modded Normal AI")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "100.0")
    @runtimeProperty("ModSettings.dependency", "showForDev")
    public let showDebugInfoForSync: Bool = false;

    // Modded Traffic AI
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "secureTimeOut")
    @runtimeProperty("ModSettings.description", "secureTimeOut")
    @runtimeProperty("ModSettings.category", "[For Dev] Modded Traffic AI")
    @runtimeProperty("ModSettings.category.order", "10200")
    @runtimeProperty("ModSettings.step", "10.0")
    @runtimeProperty("ModSettings.min", "10.0")
    @runtimeProperty("ModSettings.max", "3600.0")
    @runtimeProperty("ModSettings.dependency", "showForDev")
    public let secureTimeOut: Float = 1200.0;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "useTraffic")
    @runtimeProperty("ModSettings.description", "useTraffic")
    @runtimeProperty("ModSettings.category", "[For Dev] Modded Traffic AI")
    @runtimeProperty("ModSettings.dependency", "showForDev")
    public let useTraffic: Bool = true;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "speedInTraffic")
    @runtimeProperty("ModSettings.description", "speedInTraffic")
    @runtimeProperty("ModSettings.category", "[For Dev] Modded Traffic AI")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "1.0")
    @runtimeProperty("ModSettings.max", "200.0")
    @runtimeProperty("ModSettings.dependency", "showForDev")
    public let speedInTraffic: Float = 60.0;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "trafficTryNeighborsForStart")
    @runtimeProperty("ModSettings.description", "trafficTryNeighborsForStart")
    @runtimeProperty("ModSettings.category", "[For Dev] Modded Traffic AI")
    @runtimeProperty("ModSettings.dependency", "showForDev")
    public let trafficTryNeighborsForStart: Bool = false;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "trafficTryNeighborsForEnd")
    @runtimeProperty("ModSettings.description", "trafficTryNeighborsForEnd")
    @runtimeProperty("ModSettings.category", "[For Dev] Modded Traffic AI")
    @runtimeProperty("ModSettings.dependency", "showForDev")
    public let trafficTryNeighborsForEnd: Bool = false;

    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "forceGreenLights")
    @runtimeProperty("ModSettings.description", "forceGreenLights")
    @runtimeProperty("ModSettings.category", "[For Dev] Modded Traffic AI")
    @runtimeProperty("ModSettings.dependency", "showForDev")
    public let forceGreenLights: Bool = true;

    @if(ModuleExists("AutoDriveMod"))
    @runtimeProperty("ModSettings.mod", "Auto Drive Enhanced")
    @runtimeProperty("ModSettings.displayName", "Disable Auto drive MOD")
    @runtimeProperty("ModSettings.description", "Disable Auto drive MOD. Uninstall the old Auto drive MOD. Once uninstalled, this item is hidden.")
    @runtimeProperty("ModSettings.category", "Conflict")
    @runtimeProperty("ModSettings.category.order", "90000")
    public let disableAutoDriveMod: Bool = true;

    private func OnAttach() -> Void {
        this.Initialize();
    }

    private func OnDetach() -> Void {
        this.Uninitialize();
    }

    public func Initialize() -> Void {
        Settings.RegisterSettings(this);
        this.OnRegistered();
    }

    public func Uninitialize() -> Void {
        Settings.UnregisterSettings(this);
    }

    public func GetNextDrivingAI() -> DrivingAIType {
        let skipTypes: [DrivingAIType] = [];
        if !this.canSwitchToNormalAIByInput {
            ArrayPush(skipTypes, DrivingAIType.ModdedNormal);
        }
        if !this.canSwitchToTrafficAIByInput {
            ArrayPush(skipTypes, DrivingAIType.ModdedTraffic);
        }
        if !this.canSwitchToOldVanila230AIByInput {
            ArrayPush(skipTypes, DrivingAIType.OldVanilla230);
        }
        let next = CycleDrivingAIType(this.drivingAI);
        while true {
            if !ArrayContains(skipTypes, next) {
                return next;
            }
            next = CycleDrivingAIType(next);
        }
        return DrivingAIType.Vanilla;
    }

    public static func GetInstance(game: GameInstance) -> ref<Settings> {
        // return GameInstance.GetScriptableSystemsContainer(game).Get(NameOf<Settings>()) as Settings;
        return GameInstance.GetScriptableSystemsContainer(game).Get(NameOf<Settings>()) as Settings;
    }

    public func UpdateSyncMaxSpeed() -> Void {
        Settings.UpdateModSettingsBoolVar(this.syncMaxSpeedName, this.syncMaxSpeed);
    }

    public func UpdateClearTrafficOnPath() -> Void {
        Settings.UpdateModSettingsBoolVar(this.clearTrafficOnPathName, this.clearTrafficOnPath);
    }
   
    public func UpdateDrivingAI() -> Void {
        Settings.UpdateModSettingsEnumVar(this.drivingAIName, EnumInt(this.drivingAI));
    }

    public func OnRegistered() -> Void {
        let var = Settings.GetModConfigVar(this.autoSpeedControlInvertName);
        if IsDefined(var) {
            var.SetVisible(false);
        }
    }

    @if(ModuleExists("ModSettingsModule"))
    public func OnModSettingsChange() -> Void {
        let var = Settings.GetModConfigVar(this.autoSpeedControlName) as ModConfigVarBool;
        let invertVar = Settings.GetModConfigVar(this.autoSpeedControlInvertName) as ModConfigVarBool;
        if IsDefined(var) && IsDefined(invertVar) && Equals(var.GetValue(), invertVar.GetValue()) {
            invertVar.Toggle();
        }
    }

    @if(ModuleExists("ModSettingsModule"))
    private static func RegisterSettings(obj: ref<IScriptable>) -> Void {
        ModSettings.RegisterListenerToClass(obj);
        ModSettings.RegisterListenerToModifications(obj);
    }

    @if(!ModuleExists("ModSettingsModule"))
    private static func RegisterSettings(obj: ref<IScriptable>) -> Void {}

    @if(ModuleExists("ModSettingsModule"))
    private static func UnregisterSettings(obj: ref<IScriptable>) -> Void {
        ModSettings.UnregisterListenerToClass(obj);
        ModSettings.UnregisterListenerToModifications(obj);
    }

    @if(!ModuleExists("ModSettingsModule"))
    private static func UnregisterSettings(obj: ref<IScriptable>) -> Void {}

    @if(ModuleExists("ModSettingsModule"))
    private static func UpdateModSettingsBoolVar(name: CName, value: Bool) -> Void {
        let var = Settings.GetModConfigVar(name);
        if IsDefined(var) {
            (var as ModConfigVarBool).SetValue(value);
            ModSettings.AcceptChanges();
        }
    }
    @if(!ModuleExists("ModSettingsModule"))
    private static func UpdateModSettingsBoolVar(name: CName, value: Bool) -> Void {}

    
    @if(ModuleExists("ModSettingsModule"))
    private static func UpdateModSettingsEnumVar(name: CName, index: Int32) -> Void {
        let var = Settings.GetModConfigVar(name);
        if IsDefined(var) {
            (var as ModConfigVarEnum).SetIndex(index);
            ModSettings.AcceptChanges();
        }
    }
    @if(!ModuleExists("ModSettingsModule"))
    private static func UpdateModSettingsEnumVar(name: CName, index: Int32) -> Void {}

    @if(ModuleExists("ModSettingsModule"))
    private static func GetModConfigVar(name: CName) -> ref<ConfigVar> {
        for cate in ModSettings.GetCategories(n"Auto Drive Enhanced") {
            for var in ModSettings.GetVars(n"Auto Drive Enhanced", cate) {
                if Equals(name, var.GetName()) {
                    return var;
                }
            }
        }
        for var in ModSettings.GetVars(n"Auto Drive Enhanced", n"None") {
            if Equals(name, var.GetName()) {
                return var;
            }
        }
        return null;
    }
    @if(!ModuleExists("ModSettingsModule"))
    private static func GetModConfigVar(name: CName) -> ref<ConfigVar> { return null; }

    public func IsVanillaAI() -> Bool = IsVanillaAI(this.drivingAI);

    public func IsModdedAI() -> Bool = !this.IsVanillaAI();
}