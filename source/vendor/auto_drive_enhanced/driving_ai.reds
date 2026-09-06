module AutoDriveEnhanced
import AutoDriveEnhanced.Debug.*

// func L(const text: script_ref<String>) -> Void{ FTLog(text); }

func CreateColor(r: Int32, g: Int32, b: Int32, a: Int32) -> Color {
    return Color(Cast<Uint8>(r), Cast<Uint8>(g), Cast<Uint8>(b), Cast<Uint8>(a));
}

func WithinRange(position: Vector4, range: Float, target: Vector4) -> Bool {
    return Vector4.Distance2D(position, target) < range;
}

struct SpeedRange {
    public let max: Float;
    public let min: Float;
    public static func New(max: Float, min: Float) -> SpeedRange {
        let speed: SpeedRange;
        speed.max = max;
        speed.min = min;
        return speed;
    }
}

struct SpeedLimitArea {
    public let id: String;
    public let position: Vector4;
    public let range: Float;
    public let yaw: Float;
    public let yawDot: Float = 1.1;
    public let speed: SpeedRange;
    public static func New(id: String, position: Vector4, range: Float) -> SpeedLimitArea {
        let area: SpeedLimitArea;
        area.id = id;
        area.position = position;
        area.range = range;
        area.speed = SpeedRange.New(5.0, 2.0);
        return area;
    }
    public static func New(id: String, position: Vector4, range: Float, maxSpeed: Float, minSpeed: Float) -> SpeedLimitArea {
        let area = SpeedLimitArea.New(id, position, range);
        area.speed = SpeedRange.New(maxSpeed, minSpeed);
        return area;
    }
    public static func New(id: String, position: Vector4, range: Float, yaw: Float, yawDot: Float, maxSpeed: Float, minSpeed: Float) -> SpeedLimitArea {
        let area = SpeedLimitArea.New(id, position, range, maxSpeed, minSpeed);
        area.yaw = yaw;
        area.yawDot = yawDot;
        return area;
    }
    public static func WithinRange(self: SpeedLimitArea, target: wref<GameObject>) -> Bool {
        return WithinRange(self.position, self.range, target.GetWorldPosition());
    }
    private static func Yaw(yaw: Float) -> EulerAngles {
        let a:EulerAngles;
        a.Yaw = yaw;
        return a;
    }
}

public struct Rectangle2D {
    public let center: Vector4;
    public let axisX: Vector4; 
    public let axisY: Vector4; 
    public let halfWidth: Float;
    public let halfHeight: Float;

    public static func New(center: Vector4, forward: Vector4, width: Float, height: Float) -> Rectangle2D {
        let rect: Rectangle2D;
        
        let fwd2D = Vector4.Normalize(Vector4(forward.X, forward.Y, 0.0, 0.0));
        
        let globalUp = Vector4(0.0, 0.0, 1.0, 0.0);
        let right2D = Vector4.Normalize(Vector4.Cross(globalUp, fwd2D));

        rect.center = Vector4(center.X, center.Y, 0.0, 0.0);
        rect.axisY = fwd2D;   // 進行方向軸
        rect.axisX = right2D; // 右方向軸
        rect.halfWidth = width / 2.0;
        rect.halfHeight = height / 2.0;
        
        return rect;
    }

    public static func Overlap(a: Rectangle2D, b: Rectangle2D) -> Bool {
        let diff = b.center - a.center;
        let vDiff = Vector4(diff.X, diff.Y, 0.0, 0.0);

        if Rectangle2D.IsAxisSeparated(vDiff, a.axisX, a, b) { return false; }
        if Rectangle2D.IsAxisSeparated(vDiff, a.axisY, a, b) { return false; }
        if Rectangle2D.IsAxisSeparated(vDiff, b.axisX, a, b) { return false; }
        if Rectangle2D.IsAxisSeparated(vDiff, b.axisY, a, b) { return false; }

        return true; 
    }

    private static func IsAxisSeparated(diff: Vector4, axis: Vector4, a: Rectangle2D, b: Rectangle2D) -> Bool {
        let dist = AbsF(Vector4.Dot(diff, axis));
        let rA = AbsF(Vector4.Dot(a.axisX, axis)) * a.halfWidth + AbsF(Vector4.Dot(a.axisY, axis)) * a.halfHeight;
        let rB = AbsF(Vector4.Dot(b.axisX, axis)) * b.halfWidth + AbsF(Vector4.Dot(b.axisY, axis)) * b.halfHeight;
        return dist > (rA + rB + 0.01);
    }
}

public abstract class AutoDriveSpeed {
    protected let m_component: ref<AutoDriveComponent>;
    protected let m_destination: Vector4;
    protected let m_startPoint: Vector4;

    protected func GetComponent() -> ref<AutoDriveComponent> {
        return this.m_component;
    }
    protected func GetSystem() -> ref<DrivingAISystem> {
        return this.GetComponent().GetSystem();
    }
    protected func GetSettings() -> ref<Settings> {
        return this.GetComponent().GetSettings();
    }
    protected func GetVehicle() -> ref<VehicleObject> {
        return this.GetComponent().GetVehicle();
    }

    public func Init(component: ref<AutoDriveComponent>) -> ref<AutoDriveSpeed> {
        this.m_component = component;
        this.m_destination = component.GetDestination();
        this.m_startPoint = component.GetVehicle().GetWorldPosition();
        return this;
    }
    // 循環参照になってしまうので、できれば AutoDriveComponent でなくパラメータクラスを用意して、それで受け取りたい.
    public func Uninit() -> Void {
        this.m_component = null;
    }

    public func GetSpeed() -> SpeedRange;
    public func Match() -> Bool;
}

public class StartingSpeed extends AutoDriveSpeed {
    public func GetSpeed() -> SpeedRange {
        return this.GetComponent().GetStartingSpeedRange();
    }
    public func Match() -> Bool {
        return WithinRange(this.m_startPoint, this.GetComponent().GetStartingDistance(), this.GetVehicle().GetWorldPosition());
    }
}

public class StoppingSpeed extends AutoDriveSpeed {
    public func GetSpeed() -> SpeedRange {
        return this.GetComponent().GetStoppingSpeedRange();
    }
    public func Match() -> Bool {
        return WithinRange(this.m_destination, this.GetComponent().GetStoppingDistance(), this.GetVehicle().GetWorldPosition());
    }
}

public class SpeedControlAreaSpeed extends AutoDriveSpeed {
    public func GetSpeed() -> SpeedRange {
        return this.matchedArea.speed;
    }
    private let matchedArea: SpeedLimitArea;
    public func Match() -> Bool {
        return this.GetSystem().CheckSpeedLimitAreaForNormalAI(this.matchedArea);
    }
}

public class CruisingSpeed extends AutoDriveSpeed {
    public func GetSpeed() -> SpeedRange {
        return this.GetComponent().GetCruisingSpeedRange();
    }
    public func Match() -> Bool {
        return true;
    }
}

public abstract class SpeedSelector {
    public func Select() -> SpeedRange;
    public func Uninit() -> Void {}
}

public class SimpleSpeedSelector extends SpeedSelector {
    private let m_speed: SpeedRange;
    public func Init(speed: SpeedRange) -> ref<SimpleSpeedSelector> {
        this.m_speed = speed;
        return this;
    }
    public func Select() -> SpeedRange {
        return this.m_speed;
    }
}

public class NormalSpeedSelector extends SpeedSelector {
    private let speeds: array<ref<AutoDriveSpeed>>;
    private let defaultSpeed: SpeedRange;
    public func Init(component: ref<AutoDriveComponent>) -> ref<NormalSpeedSelector> {
        ArrayPush(this.speeds, new StartingSpeed().Init(component));
        ArrayPush(this.speeds, new StoppingSpeed().Init(component));
        ArrayPush(this.speeds, new SpeedControlAreaSpeed().Init(component));
        ArrayPush(this.speeds, new CruisingSpeed().Init(component));
        this.defaultSpeed = component.GetCruisingSpeedRange();
        return this;
    }
    public func Select() -> SpeedRange {
        for speed in this.speeds {
            if speed.Match() {
                return speed.GetSpeed();
            }
        }
        return this.defaultSpeed;
    }
    public func Uninit() -> Void {
        super.Uninit();
        for spd in this.speeds {
            spd.Uninit();
        }
        this.speeds = [];
    }
}

public class SyncSpeed extends AutoDriveSpeed {
    private let speedSelector: ref<SpeedSelector>;
    private let brakingFactor: Float;
    private let lastOrient: Quaternion;
    private let lastTime: Float;

    public func Init(component: ref<AutoDriveComponent>, speedSelector: ref<SpeedSelector>) -> ref<SyncSpeed> {
        super.Init(component);
        this.speedSelector = speedSelector;
        this.brakingFactor = this.GetBrakingFactor();
        this.lastTime = 0.0;
        return this;
    }
    public func Uninit() -> Void {
        super.Uninit();
        if IsDefined(this.speedSelector) {
            this.speedSelector.Uninit();
            this.speedSelector = null;
        }
    }

    protected func GetPlayer() -> ref<PlayerPuppet> {
        return this.GetComponent().GetPlayer();
    }

    private func GetBrakingFactor() -> Float {
        let wheelSetup = this.GetVehicle().GetRecord().VehDriveModelData().WheelSetup();
        let brakingTorque = (wheelSetup.FrontPreset().MaxBrakingTorque() + wheelSetup.BackPreset().MaxBrakingTorque()) / 2.0;
        let massFactor = MaxF(this.GetVehicle().GetTotalMass() / 1300.0 * this.GetSettings().syncMaxSpeedVehicleInFrontDistanceMassFactor, 1.0);
        let brakingFactor = this.GetSettings().syncMaxSpeedVehicleInFrontDistanceBrakingTorqueFactor;
        if brakingTorque > 0.0 {
            brakingFactor = brakingFactor * ClampF(400.0 / brakingTorque, 0.70, 2.0);
        } else {
            // おそらく二輪車、ブレーキ性能低いので、1.3くらいにしておく.
            brakingFactor = 1.3;
        }
        return brakingFactor * massFactor;
    }

    private func GetDebugDrawer() -> ref<DebugDrawerSystem> {
        return DebugDrawerSystem.GetInstance(this.GetVehicle().GetGame());
    }

    public func GetSpeed() -> SpeedRange {
        if !this.GetSettings().syncMaxSpeed {
            this.lastTime = 0.0;
            return this.speedSelector.Select();
        }
        let range = this.GetSearchRange(this.GetVehicle().GetCurrentSpeed());
        let speed = this.speedSelector.Select();
        let maxSpeed = speed.max;
        let trans = this.GetVehicle().GetWorldTransform();
        let currentSpeed = this.GetVehicle().GetCurrentSpeed();

        let orient = this.GetVehicle().GetWorldOrientation();
        let now = EngineTime.ToFloat(GameInstance.GetTimeSystem(this.GetVehicle().GetGame()).GetSimTime());
        let turning = 0.0;
        let dt = now - this.lastTime;

        if dt > 0.0 {
            if this.lastTime > 0.0 {
                let diffQuat = Quaternion.MulInverse(this.lastOrient, orient);
                let diffEuler = Quaternion.ToEulerAngles(diffQuat);
                let yawRate = diffEuler.Yaw / dt;
                turning = ClampF(yawRate / 30.0, -1.0, 1.0);
            }
        }
        this.lastOrient = orient;
        this.lastTime = now;

        // 旋回中はちょっと補正.
        if AbsF(turning) > 0.05 && currentSpeed > 0.1 {
            // 向き
            let euler = WorldTransform.GetOrientation(trans).ToEulerAngles();
            euler.Yaw -= (turning * 10.0);
            WorldTransform.SetOrientation(trans, EulerAngles.ToQuat(euler));
            // 位置
            let currentPos = WorldPosition.ToVector4(WorldTransform.GetWorldPosition(trans));
            let shift = WorldTransform.GetRight(trans) * (turning * 0.3);
            WorldTransform.SetPosition(trans, currentPos + shift);
        }
        let corrPos = WorldPosition.ToVector4(WorldTransform.GetWorldPosition(trans));
        let playerRect = this.CreateRect(corrPos, WorldTransform.GetForward(trans), this.GetBaseSize(this.GetVehicle()),
            range, -(this.GetVehicle().GetCurrentSpeed() / 6.0), 0.8); // fExt, bExt, wExt

        // Settings.OnModSettingsChange()で設定してもいいが, 設定側がDebugに依存したくないので, ここで.
        // CETで無駄なネイティブコールを避けるため, OnEnabledChangedを走らせる.
        let debugSys = this.GetDebugDrawer();
        debugSys.SetEnabled(this.GetSettings().showDebugInfoForSync);

        if this.GetSettings().showDebugInfoForSync {
            debugSys.ClearAll();
            // 補正のもととなる旋回値.
            debugSys.DrawText2D(Vector2(0.02, 0.02), s"Sync Info:\n turning: \(turning)\n speed: \(currentSpeed)", gameDebugViewETextAlignment.Left, CreateColor(0, 255, 0, 255), 1.0);

            // 1. 現在の車の向き（青色）
            let lineStart = this.GetVehicle().GetWorldPosition();
            lineStart.Z += 1.5; // 少し浮かせる
            let lineEndNormal = lineStart + (this.GetVehicle().GetWorldForward() * 3.0);
            debugSys.DrawLine(lineStart, lineEndNormal, CreateColor(0, 0, 255, 255), 1.0); 

            // 2. 補正後の理想の向き（緑色）
            lineStart = WorldPosition.ToVector4(WorldTransform.GetWorldPosition(trans));
            lineStart.Z += 1.5; // 少し浮かせる
            lineEndNormal = lineStart + (WorldTransform.GetForward(trans) * 3.0);
            debugSys.DrawLine(lineStart, lineEndNormal, CreateColor(0, 255, 0, 255), 0.1); 

            // Overlap判定用のRectangle2D
            debugSys.DrawOrientedBox(
                Vector4(playerRect.center.X, playerRect.center.Y, corrPos.Z, 1.0), Quaternion.BuildFromDirectionVector(playerRect.axisY), 
                Vector4(playerRect.halfWidth * 2.0, playerRect.halfHeight * 2.0, 1.0, 0.0), CreateColor(0, 255, 0, 255), 1.0);
        }

        let vehicles = this.SearchVehicles(range);
        for veh in vehicles {
            let syncSpeed = maxSpeed;
            if this.CalcSyncSpeed(veh, trans, turning, playerRect, range, syncSpeed) {
                maxSpeed = MinF(maxSpeed, syncSpeed);
            }
        }
        speed.max = ClampF(maxSpeed, 0.0, speed.max);
        speed.min = ClampF(speed.min, 0.0, speed.max);
        return speed;
    }

    private func GetSearchRange(speed: Float) -> Float {
        return speed * speed * 0.07 * this.brakingFactor * this.GetSettings().syncMaxSpeedVehicleInFrontDistanceSpeedFactor + this.GetSettings().syncMaxSpeedVehicleInFrontBaseDistance;
    }

    public func Match() -> Bool {
        return true;
    }

    private func SearchVehicles(range: Float) -> [ref<VehicleObject>] {
        return this.GetPlayer().GetAroundVehicles_ADE(range + 10.0); // 大きめに指定しないと、なぜか拾わない.
    }

    private func CalcSyncSpeed(vehicle: ref<VehicleObject>, correctedPlayerTransform: WorldTransform, turning: Float, playerRect: Rectangle2D, range: Float, out speed: Float) -> Bool {
        let pp = this.GetVehicle().GetWorldPosition();
        let vp = vehicle.GetWorldPosition();
        let localPos = this.GetLocalPoint(vehicle);
        let distance = Vector4.Distance(vehicle.GetWorldPosition(), this.GetVehicle().GetWorldPosition());
        let inRange = distance < range;
        let corrPos = WorldPosition.ToVector4(WorldTransform.GetWorldPosition(correctedPlayerTransform));

        if vehicle.IsPlayerMounted()
        || !SyncSpeed.InTraffic(vehicle)
        || localPos.Y < 0.0
        || (AbsF(pp.Z - vp.Z) > 8.0 && AbsF(localPos.Z) > 3.0)
        || !inRange {
            return false;
        }
        let distance = Vector4.Distance(vehicle.GetWorldPosition(), this.GetVehicle().GetWorldPosition());

        let targetRect = this.CreateRect(vehicle.GetWorldPosition(), vehicle.GetWorldForward(), this.GetBaseSize(vehicle),
            vehicle.GetCurrentSpeed() + 3.0, MaxF(3.0 - vehicle.GetCurrentSpeed() / 2.0, 0.0), 0.8); // fExt, bExt, wExt
        let overlap = Rectangle2D.Overlap(playerRect, targetRect);

        if overlap {
            let vehicleForwardVelocity = Vector4.Dot(this.GetVehicle().GetWorldOrientation().GetForward(), vehicle.GetLinearVelocity());
            if vehicleForwardVelocity < -10.0 {
                // 多分対向車なので無視.
                if this.GetSettings().showDebugInfoForSync {
                    vehicle.Highlight_ADE(this.GetPlayer(), true, EFocusForcedHighlightType.QUEST, EFocusOutlineType.QUEST);
                }
                return false;
            } else {
                // 前方方向の速度に同期. コマンドの入れ直しが発生しないように近い値は揃える.
                speed = ClampF(SyncSpeed.Floor(vehicleForwardVelocity, 0.5) - 0.5, this.GetSettings().syncMaxSpeedApproachSpeed, speed);
            }

            if distance < this.GetSettings().syncMaxSpeedDistanceToStopApproaching && !this.GetSettings().clearTrafficOnPath {
                // 停止距離まで近づいて、同じ車線か相手が動いている場合は止める.
                if this.IsInSameLane(vehicle)
                || vehicle.GetCurrentSpeed() > 1.0 {
                    speed = 0.0;
                }
            }

            if this.GetSettings().showDebugInfoForSync {
                vehicle.Highlight_ADE(this.GetPlayer(), true, EFocusForcedHighlightType.FRIENDLY, EFocusOutlineType.FRIENDLY);
            }
        }
        if this.GetSettings().showDebugInfoForSync {
            let debugSys = this.GetDebugDrawer();
            let color = overlap ? (speed < this.GetSettings().syncMaxSpeedApproachSpeed ? CreateColor(255, 0, 0, 255) : CreateColor(255, 128, 0, 255)) : CreateColor(255, 255, 0, 255);
            debugSys.DrawOrientedBox(
                Vector4(targetRect.center.X, targetRect.center.Y, corrPos.Z, 1.0), Quaternion.BuildFromDirectionVector(targetRect.axisY), 
                Vector4(targetRect.halfWidth * 2.0, targetRect.halfHeight * 2.0, 1.0, 0.0), color, 1.0);
        }
        if overlap {
            return true;
        }

        let angle = Vector4.Dot(Vector4.Normalize2D(WorldTransform.GetForward(correctedPlayerTransform)), Vector4.Normalize2D(vehicle.GetWorldPosition() - this.GetVehicle().GetWorldPosition()));

        if this.GetVehicle().GetCurrentSpeed() > this.GetSettings().syncMaxSpeedApproachSpeed && AbsF(turning) > 0.1 && distance < 20.0 && angle > 0.70 {
            // 旋回中に近くに居たら徐行.
            if this.GetSettings().showDebugInfoForSync {
                vehicle.Highlight_ADE(this.GetPlayer(), true, EFocusForcedHighlightType.HOSTILE, EFocusOutlineType.HOSTILE);
            }
            speed = this.GetSettings().syncMaxSpeedApproachSpeed;
            return true;
        }
        return false;
    }

    private static func Floor(value: Float, unit: Float) -> Float {
        return Cast<Float>(FloorF(value / unit)) * unit;
    }

    private func GetBaseSize(obj: ref<GameObject>) -> Vector4 {
        let veh = obj as VehicleObject;
        if IsDefined(veh) {
            let vType = veh.GetRecord().Type().Type();

            if Equals(vType, gamedataVehicleType.Bike) {
                return Vector4(0.85, 2.1, 0.0, 0.0);
            }
            return Vector4(2.0, 4.5, 0.0, 0.0); 
        }

        // NPCなど
        if IsDefined(obj as gamePuppetBase) {
            return Vector4(0.6, 0.4, 0.0, 0.0);
        }
        return Vector4(1.0, 1.0, 0.0, 0.0);
    }

    private func CreateRect(pos: Vector4, fwd: Vector4, baseSize: Vector4, opt fExt: Float, opt bExt: Float, opt wExt: Float) -> Rectangle2D {
        let fwd2D = Vector4.Normalize2D(fwd);
        
        let w = baseSize.X + wExt;
        let l = baseSize.Y + fExt + bExt;

        let offset = ((baseSize.Y / 2.0 + fExt) - (baseSize.Y / 2.0 + bExt)) / 2.0;
        let center = pos + (fwd2D * offset);

        return Rectangle2D.New(center, fwd2D, w, l);
    }

    private func IsInSameLane(vehicle: ref<VehicleObject>) -> Bool {
        let localPos = this.GetLocalPoint(vehicle);
        return 
            !vehicle.IsPlayerMounted()
            && SyncSpeed.InTraffic(vehicle)
            && Vector4.Dot(this.GetVehicle().GetWorldForward(), vehicle.GetWorldForward()) > 0.75
            && AbsF(localPos.X) < 3.5
            ;
    }

    private static func InTraffic(vehicle: ref<VehicleObject>) -> Bool {
        return vehicle.IsInTrafficLane() || vehicle.GetCurrentSpeed() > 0.01;
    }

    private func GetLocalPoint(vehicle: ref<VehicleObject>) -> Vector4 {
        return WorldTransform.TransformInvPoint(this.GetVehicle().GetWorldTransform(), vehicle.GetWorldPosition());
    }
}

public class SyncSpeedSelector extends SpeedSelector {
    private let syncSpeed: ref<SyncSpeed>;
    public func Init(component: ref<AutoDriveComponent>, baseSpeedSelector: ref<SpeedSelector>) -> ref<SyncSpeedSelector> {
        this.syncSpeed = new SyncSpeed().Init(component, baseSpeedSelector);
        return this;
    }
    public func Uninit() -> Void {
        super.Uninit();
        if IsDefined(this.syncSpeed) {
            this.syncSpeed.Uninit();
            this.syncSpeed = null;
        }
    }
    public func Select() -> SpeedRange {
        return this.syncSpeed.GetSpeed();
    }
}

public abstract class AICommandFactory {
    protected let m_component: ref<AutoDriveComponent>;
    protected let m_destination: Vector4;
    protected let m_settings: ref<Settings>;
    public func Init(component: ref<AutoDriveComponent>) -> ref<AICommandFactory> {
        this.m_component = component;
        this.m_settings = component.GetSettings();
        this.m_destination = component.GetDestination();
        return this;
    }
    public func Uninit() -> Void {
        this.m_component = null;
        this.m_settings = null;
    }
    public func Create() -> ref<AIVehicleDriveToPointAutonomousCommand>;
    public func Update(ticks: Uint32) -> Bool;
}

public class NormalAICommandFactory extends AICommandFactory {

    private let m_speedSelector: ref<SpeedSelector>;
    private let m_speed: SpeedRange;

    public func Init(component: ref<AutoDriveComponent>) -> ref<AICommandFactory> {
        super.Init(component);
        this.m_speedSelector = new SyncSpeedSelector().Init(component, new NormalSpeedSelector().Init(component));
        return this;
    }
    public func Uninit() -> Void {
        super.Uninit();
        this.m_speedSelector.Uninit();
        this.m_speedSelector = null;
    }
    public func Update(ticks: Uint32) -> Bool {
        let speed = this.m_speedSelector.Select();
        let updated = NotEquals(this.m_speed, speed);
        this.m_speed = speed;
        return updated;
    }
    public func Create() -> ref<AIVehicleDriveToPointAutonomousCommand> {
        let cmd = new AIVehicleDriveToPointAutonomousCommand();
        cmd.clearTrafficOnPath = this.m_settings.clearTrafficOnPath;
        cmd.driveDownTheRoadIndefinitely = this.m_settings.driveDownTheRoadIndefinitely;
        cmd.useKinematic = this.m_settings.useKinematic;
        cmd.minimumDistanceToTarget = this.m_settings.minimumDistanceToTarget;
        cmd.maxSpeed = this.m_speed.max;
        cmd.minSpeed = this.m_speed.min;
        cmd.targetPosition = Vector4.Vector4To3(this.m_destination);
        return cmd;
    }
}

public class TrafficAICommandFactory extends AICommandFactory {

    private let m_init: Bool = false;    
    private let m_enteredStoppingRange: Bool = false;
    private let m_matchedArea: SpeedLimitArea;
    private let m_limitAreaMatch: Bool;
    private let m_speedSum: Float;
    private let m_speedSumTicks: Uint32;

    public func Update(ticks: Uint32) -> Bool {
        if !this.m_init {
            this.m_init = true;
            this.m_speedSum = 0.0;
            return true;
        }
        if !this.m_enteredStoppingRange {
            this.m_enteredStoppingRange = WithinRange(this.m_destination, this.m_settings.stoppingDistanceForTrafficAI, this.m_component.GetVehicle().GetWorldPosition());
        }
        if this.m_enteredStoppingRange {
            this.m_speedSum = 0.0;
            return true;
        }
        if NotEquals(this.m_limitAreaMatch, this.m_component.GetSystem().CheckSpeedLimitAreaForTrafficAI(this.m_matchedArea)) {
            this.m_limitAreaMatch = !this.m_limitAreaMatch;
            this.m_speedSum = 0.0;
            return true;
        }
        this.m_speedSum += this.m_component.GetVehicle().GetCurrentSpeed() * Cast<Float>(ticks - this.m_speedSumTicks);
        this.m_speedSumTicks = ticks;
        return false;
    }
    public func Create() -> ref<AIVehicleDriveToPointAutonomousCommand> {
        if this.m_enteredStoppingRange {
            return null;
        }
        let cmd: ref<AIVehicleDriveToPointAutonomousCommand>;
        if this.m_limitAreaMatch {
            cmd = new AIVehicleDriveToPointAutonomousCommand();
            cmd.maxSpeed = this.m_matchedArea.speed.max;
            cmd.minSpeed = this.m_matchedArea.speed.min;
        } else {
            let tpCmd = new AIVehicleDriveToPointCommand();
            tpCmd.secureTimeOut = this.m_settings.secureTimeOut;
            tpCmd.useTraffic = this.m_settings.useTraffic;
            tpCmd.speedInTraffic = this.m_settings.speedInTraffic;
            tpCmd.forceGreenLights = this.m_settings.forceGreenLights;
            tpCmd.trafficTryNeighborsForStart = this.m_settings.trafficTryNeighborsForStart;
            tpCmd.trafficTryNeighborsForEnd = this.m_settings.trafficTryNeighborsForEnd;
            cmd = tpCmd;
        }
        cmd.targetPosition = Vector4.Vector4To3(this.m_destination);
        return cmd;
    }
}


public abstract class AutoDriveCommandHandler {
    protected let m_component: ref<AutoDriveComponent>;
    protected let m_settings: ref<Settings>;

    protected func Init(component: ref<AutoDriveComponent>) -> ref<AutoDriveCommandHandler> {
        this.m_component = component;
        this.m_settings = component.GetSettings();
        return this;
    }
    public func Uninit() -> Void {
        this.m_component = null;
        this.m_settings = null;
        this.m_command = null;
    }

    protected func GetTickRate() -> Uint32 { return 15u; }

    protected func GetVehicle() -> ref<VehicleObject> {
        return this.m_component.GetVehicle();
    }

    protected let m_command: ref<AIVehicleCommand>;

    protected func QueueAICommand() -> Void {
        let cmd = this.CreateAICommand();
        if IsDefined(cmd) {
            let evt = new AICommandEvent();
            evt.command = cmd;
            this.m_command = cmd;
            this.GetVehicle().QueueEvent(evt);
            this.GetVehicle().GetAIComponent().SetInitCmd(cmd);
        } else {
            this.StopAICommand();
        }
    }

    protected func StopAICommand() -> Void {
        if !IsDefined(this.m_command) {
            return;
        }
        this.GetVehicle().GetAIComponent().CancelCommand(this.m_command);
        this.GetVehicle().GetAIComponent().StopExecutingCommand(this.m_command, true);
        this.m_command = null;
    }

    public func Requeue() -> Void {
        this.Stop();
        this.Queue();
    }

    public func Queue() -> Void {
        this.QueueAICommand();
    }

    public func Stop() -> Void {
        this.StopAICommand();
    }

    public func Tick(ticks: Uint32) -> Bool {
        if ticks % this.GetTickRate() != 0u {
            return false;
        }
        let updated = this.Update(ticks);
        if updated {
            this.Requeue();
        } else {
            if IsDefined(this.m_command) && this.IsCompleted() {
                this.StopAICommand();
            }
        }
        return true;
    }

    public func IsCompleted() -> Bool {
        if !IsDefined(this.m_command) {
            return true;
        }
        return Equals(this.m_command.state, AICommandState.Cancelled)
            || Equals(this.m_command.state, AICommandState.Interrupted)
            || Equals(this.m_command.state, AICommandState.Success)
            || Equals(this.m_command.state, AICommandState.Failure);
    }

    protected func Update(ticks: Uint32) -> Bool;
    protected func CreateAICommand() -> ref<AIVehicleCommand>;
}

public abstract class AutoDriveToPointCommandHandler extends AutoDriveCommandHandler {
    protected let m_normalAICommandFactory: ref<AICommandFactory>;
    protected let m_trafficAICommandFactory: ref<AICommandFactory>;

    protected func Init(component: ref<AutoDriveComponent>) -> ref<AutoDriveToPointCommandHandler> {
        super.Init(component);
        this.m_normalAICommandFactory = new NormalAICommandFactory().Init(component);
        this.m_trafficAICommandFactory = new TrafficAICommandFactory().Init(component);
        return this;
    }
    public func Uninit() -> Void {
        super.Uninit();
        if IsDefined(this.m_normalAICommandFactory) {
            this.m_normalAICommandFactory.Uninit();
            this.m_normalAICommandFactory = null;
        }
        if IsDefined(this.m_trafficAICommandFactory) {
            this.m_trafficAICommandFactory.Uninit();
            this.m_trafficAICommandFactory = null;
        }
    }
    protected func GetAICommandFactory() -> ref<AICommandFactory> {
        if this.m_component.IsTrafficAI() {
            return this.m_trafficAICommandFactory;
        } else {
            return this.m_normalAICommandFactory;
        }
    }
}

public class GoToTrackedPointCommandHandler extends AutoDriveToPointCommandHandler {
    protected func Update(ticks: Uint32) -> Bool { return this.GetAICommandFactory().Update(ticks); }
    protected func CreateAICommand() -> ref<AIVehicleCommand> { return this.GetAICommandFactory().Create(); }
}

public class AutoDriveComponent {
    private let m_vehicle: ref<VehicleObject>;
    private let m_player: ref<PlayerPuppet>;
    private let m_system: ref<DrivingAISystem>;

    public func Initialize(player: ref<PlayerPuppet>, vehicle: ref<VehicleObject>) -> Void {
        this.m_player = player;
        this.m_vehicle = vehicle;
        this.m_system = DrivingAISystem.GetInstance(player.GetGame());
    }

    public func Uninitialize() -> Void {
        this.CancelAutoDrive(false);
        this.m_player = null;
        this.m_vehicle = null;
        this.m_system = null;
    }

    public func GetDelaySystem() -> ref<DelaySystem> {
        return GameInstance.GetDelaySystem(this.GetPlayer().GetGame());
    }

    public func GetVehicle() -> ref<VehicleObject> {
        return this.m_vehicle;
    }

    public func GetPlayer() -> ref<PlayerPuppet> {
        return this.m_player;
    }

    public func GetSystem() -> ref<DrivingAISystem> {
        return this.m_system;
    }

    public func GetSettings() -> ref<Settings> {
        return this.m_system.GetSettings();
    }

    public func GetCruisingSpeedRange() -> SpeedRange {
        if this.GetSystem().GetSettings().autoSpeedControl {
            let maxSpeed = this.GetVehicleMaxSpeed() * this.GetSystem().GetSettings().autoSpeedControlMaxSpeedRatio;
            let minSpeed = MinF(MaxF(this.GetSteeringFactor() * 10.0, 3.0), maxSpeed * 0.75);
            // L(s"AutoCruisingSpeed: max=\(maxSpeed) min=\(minSpeed)");
            return SpeedRange.New(maxSpeed, minSpeed);
        } else {
            return SpeedRange.New(this.GetSettings().cruisingMaxSpeed, this.GetSettings().cruisingMinSpeed);
        }
    }

    public func GetStartingDistance() -> Float {
        if this.GetSystem().GetSettings().autoSpeedControl {
            return 15.0;
        } else {
            return this.GetSettings().startingDistance;
        }
    }

    public func GetStartingSpeedRange() -> SpeedRange {
        if this.GetSystem().GetSettings().autoSpeedControl {
            return SpeedRange.New(10.0, 3.0);
        } else {
            return SpeedRange.New(this.GetSettings().startingMaxSpeed, this.GetSettings().startingMinSpeed);
        }
    }

    public func GetStoppingDistance() -> Float {
        if this.GetSystem().GetSettings().autoSpeedControl {
            let distance = 10.0 + (this.GetStoppingFactor() * 15.0);
            // L(s"stopping distance: \(distance)");
            return distance;
            // return 50.0;
        } else {
            return this.GetSettings().stoppingDistance;
        }
    }

    public func GetStoppingSpeedRange() -> SpeedRange {
        if this.GetSystem().GetSettings().autoSpeedControl {
            return SpeedRange.New(8.0, 3.0);
        } else {
            return SpeedRange.New(this.GetSettings().stoppingMaxSpeed, this.GetSettings().stoppingMinSpeed);
        }
    }

    public func GetStoppingFactor() -> Float {
        let wheelSetup = this.GetVehicle().GetRecord().VehDriveModelData().WheelSetup();
        let brakingTorque = (wheelSetup.FrontPreset().MaxBrakingTorque() + wheelSetup.BackPreset().MaxBrakingTorque()) / 2.0;
        let spd = this.GetSettings().forceBrakesSpeedFactor;
        let mass = this.GetSettings().forceBrakesMassFactor;
        let bt = this.GetSettings().forceBrakesBrakingTorqueFactor;
        if this.GetSystem().GetSettings().autoSpeedControl {
            spd = 1.0;
            mass = 1.0;
            bt = 1.0;
        }
        let speedFactor = spd * AbsF(this.GetVehicle().GetCurrentSpeed() / 16.0);
        let massFactor = MaxF(this.GetVehicle().GetTotalMass() / 1000.0 * mass, 1.0);
        let brakingFactor = bt;
        if brakingTorque > 0.0 {
            brakingFactor = brakingFactor * ClampF(400.0 / brakingTorque, 0.70, 2.0);
        } else {
            // おそらく二輪車、ブレーキ性能低いので、1.5くらいにしておく.
            brakingFactor = 1.5;
        }
        let stoppingFactor = speedFactor * massFactor * brakingFactor;
        // L(s"stoppingFactor: factor=\(stoppingFactor) speedFactor=\(speedFactor) massFactor=\(massFactor) brakingFactor=\(brakingFactor)");
        return stoppingFactor;
    }

    public func GetSteeringFactor() -> Float {
        // よく分からんので簡易的に。。。
        let dmd = this.GetVehicle().GetRecord().VehDriveModelData();
        if !IsDefined(dmd) {
            return 1.0;
        }
        if dmd.WheelTurnMaxAddPerSecond() + dmd.WheelTurnMaxSubPerSecond() == 0.0 {
            return 1.0;
        }
        return (dmd.WheelTurnMaxAddPerSecond() + dmd.WheelTurnMaxSubPerSecond()) / 2.0 / 100.0;
    }

    public func GetBrakingTime() -> Float {
        let baseTime = this.GetSettings().forceBrakesBaseTime;
        if this.GetSystem().GetSettings().autoSpeedControl {
            baseTime = 0.5;
        }
        let brakingTime = baseTime + this.GetStoppingFactor();
        return brakingTime;
    }

    private func GetVehicleMaxSpeed() -> Float {
        let gears: [wref<VehicleGear_Record>];
        this.GetVehicle().GetRecord().VehEngineData().Gears(gears);
        let max = 0.0;
        for gear in gears {
            max = MaxF(max, gear.MaxSpeed());
        }
        return max;
    }

    public func StartAutoDrive(opt trafficAI: Bool) -> Void {
        this.m_ticksTimeout = this.GetSettings().ticksTimeout;
        // this.m_destination = Vector4.Vector3To4(AutoDriveSystem.GetInstance(this.GetVehicle().GetGame()).GetAutodriveDestination());
        this.m_destination = DrivingAISystem.GetInstance(this.GetVehicle().GetGame()).GetTrackedPoint();
        this.m_trafficAI = trafficAI;
        this.m_commandHandler = new GoToTrackedPointCommandHandler().Init(this);
        this.StartAutoDriveInternal(true, false);
    }

    // NCTC integration: start ADE's complete command handler with an explicit
    // route-owned destination instead of reading the player's tracked mappin.
    public func StartAutoDriveToNCTC(destination: Vector4, opt trafficAI: Bool) -> Bool {
        if !IsDefined(this.m_vehicle) || !IsDefined(this.m_player) || Vector4.IsXYZZero(destination) {
            return false;
        }
        if this.IsAutoDriving() {
            this.CancelAutoDrive(false);
        }
        this.m_ticksTimeout = this.GetSettings().ticksTimeout;
        this.m_destination = destination;
        this.m_trafficAI = trafficAI;
        this.m_commandHandler = new GoToTrackedPointCommandHandler().Init(this);
        this.StartAutoDriveInternal(true, false);
        return true;
    }

    public func GetDestination() -> Vector4 {
        return this.m_destination;
    }

    public func IsTrafficAI() -> Bool {
        return this.m_trafficAI;
    }

    private let m_commandHandler: ref<AutoDriveCommandHandler>;
    private let m_ticksTimeout: Float = 600.0;
    private let m_destination: Vector4;

    public func StartAutoDriveInternal(stopOnFinish: Bool, playStartSound: Bool) -> Void {
        this.InitializeAutoDrive();

        let evt = new AutoDriveTickEvent();
        this.m_tickID = this.GetDelaySystem().TickOnEvent(this.GetVehicle(), evt, this.m_ticksTimeout);
        this.m_tickEnable = true;
        this.SetAutoDriving(true);
    }

    private func InitializeAutoDrive() -> Void {
        this.GetDelaySystem().CancelTick(this.m_tickID);
        this.m_tickEnable = false;
        // this.m_commandHandler.Stop();
        this.SetAutoDriving(false);
        this.m_ticks = 0u;
        this.m_paused = false;

        // ISSUE: 助手席から強奪した時に動作しないので DriverReady を送る.
        this.SendEvent(n"DriverReady");
    }

    private let m_tickID: DelayID;
    private let m_tickEnable: Bool;
    private let m_autoDriving: Bool = false;
    private let m_ticks: Uint32;
    private let m_paused: Bool;
    private let m_trafficAI: Bool;

    public func CancelAutoDrive(stop: Bool) -> Void {
        if !this.IsAutoDriving() {
            return;
        }
        this.GetDelaySystem().CancelTick(this.m_tickID);
        this.m_tickEnable = false;
        this.m_commandHandler.Stop();
        this.m_commandHandler.Uninit();
        this.m_commandHandler = null;
        this.m_trafficAI = false;
        this.m_destination = Vector4.EmptyVector();
        this.SetAutoDriving(false);
        if stop {
            this.GetVehicle().ForceBrakesUntilStoppedOrFor(this.GetBrakingTime());
        }
    }

    public func Requeue() -> Void {
        this.m_commandHandler.Requeue();
    }

    public func OnTick() -> Void {
        if this.m_tickEnable && IsDefined(this.m_commandHandler) && this.m_commandHandler.Tick(this.m_ticks) {
            if this.m_commandHandler.IsCompleted() {
                if this.GetVehicle() == this.GetPlayer().GetMountedVehicle() {
                    // プレイヤーが乗っている場合のみ、AutoDriveSystemへ通知し、制御を委託する.
                    if this.m_trafficAI {
                        if Vector4.Distance(this.GetVehicle().GetWorldPosition(), this.GetDestination()) < this.GetSettings().stoppingDistanceForTrafficAI + 5.0 {
                            // NCTC experimental route bridge. The normal ADE
                            // event remains untouched; this fact lets the
                            // bus route loop consume ADE's own arrival test.
                            GameInstance.GetQuestsSystem(this.GetVehicle().GetGame()).SetFact(n"nctc_ade_destination_reached", 1);
                            AutoDriveSystem.GetInstance(this.GetVehicle().GetGame()).OnDestinationReachedWithModdedAI();
                        } else {
                            AutoDriveSystem.GetInstance(this.GetVehicle().GetGame()).OnStopAutoDriveWithModdedAI();
                        }
                    } else {
                        GameInstance.GetQuestsSystem(this.GetVehicle().GetGame()).SetFact(n"nctc_ade_destination_reached", 1);
                        AutoDriveSystem.GetInstance(this.GetVehicle().GetGame()).OnDestinationReachedWithModdedAI();
                    }
                    this.m_tickEnable = false;
                } else {
                    this.CancelAutoDrive(true);
                }
            }
        }
        this.m_ticks = this.m_ticks + 1u;
    }

    private func Pause() -> Void {
        this.m_paused = true;
        this.m_tickEnable = false;
        this.m_commandHandler.Stop();
    }

    public func Resume() -> Void {
        if this.m_paused {
            this.m_commandHandler.Queue();
            this.m_tickEnable = true;
            this.m_paused = false;
        }
    }

    protected func SetAutoDriving(autoDriving: Bool) -> Void {
        this.m_autoDriving = autoDriving;
        if autoDriving {
            this.requireWorkaroundForIssueOfMovingOnItsOwn = true;
        }
    }

    public func IsAutoDriving() -> Bool {
        return this.m_autoDriving;
    }

    public let requireWorkaroundForIssueOfMovingOnItsOwn: Bool;

    public func OnUnmountingEvent(evt: ref<UnmountingEvent>) -> Void {
        if this.GetSettings().enableWorkaroundForIssueOfMovingOnItsOwn {
            // ISSUE: 降車時に勝手に車(特にバイク)がじりじり動き出す問題
            // 0.5秒後にプレイヤーが降車していれば、"NoDriver" を送信して、その後すぐに "DriverReady" を送信する。
            // SwitchSeatsでもここに入ってくるので要注意。
            // これで動作自体は止まるが、対症療法なのでできれば何とかしたい。。。
            this.GetSystem().GetDelaySystem().DelayCallback(new WorkaroundForIssueOfMovingOnItsOwn().Init(this), 0.5, true);
        }
    }

    public func SendEvent(eventName: CName) -> Void {
        let aiEvent = new AIEvent();
        aiEvent.name = eventName;
        this.GetVehicle().QueueEvent(aiEvent);
    }

    public func SendEventDelayed(eventName: CName, seconds: Float) -> Void {
        this.GetSystem().GetDelaySystem().DelayCallback(new DelayedSendEvent().Init(this, eventName), seconds, true);
    }
}

public class WorkaroundForIssueOfMovingOnItsOwn extends DelayCallback {
    public func Init(component: ref<AutoDriveComponent>) -> ref<WorkaroundForIssueOfMovingOnItsOwn> {
        this.m_component = component;
        return this;
    }
    private let m_component: ref<AutoDriveComponent>;
    public func Call() -> Void {
        if !this.m_component.GetPlayer().GetPlayerStateMachineBlackboard().GetBool(GetAllBlackboardDefs().PlayerStateMachine.MountedToVehicle)
        && this.m_component.requireWorkaroundForIssueOfMovingOnItsOwn {
            this.m_component.SendEvent(n"NoDriver");
            this.m_component.SendEventDelayed(n"DriverReady", 1.0);
            this.m_component.requireWorkaroundForIssueOfMovingOnItsOwn = false;
        }
    }
}

public class DelayedSendEvent extends DelayCallback {
    public func Init(component: ref<AutoDriveComponent>, eventName: CName) -> ref<DelayedSendEvent> {
        this.m_component = component;
        this.m_eventName = eventName;
        return this;
    }
    private let m_component: ref<AutoDriveComponent>;
    private let m_eventName: CName;
    public func Call() -> Void {
        this.m_component.SendEvent(this.m_eventName);
    }
}

public class DrivingAISystem extends ScriptableSystem {

    public func GetSettings() -> ref<Settings> {
        return Settings.GetInstance(this.GetGameInstance());
    }

    private let m_speedLimitAreasForNormalAI: array<SpeedLimitArea>;
    private let m_speedLimitAreasForTrafficAI: array<SpeedLimitArea>;

    public static func GetInstance(game: GameInstance) -> ref<DrivingAISystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(NameOf(DrivingAISystem)) as DrivingAISystem;
    }

    private func OnAttach() -> Void {
        this.AddSpeedLimitAreaForNormalAI(SpeedLimitArea.New("dogtown_gate", new Vector4(-2059.910400, -2319.379395, 20.799999, 1.000000), 70.0, 10.0, 5.0)); // Dogtown Gate.
        this.AddSpeedLimitAreaForTrafficAI(SpeedLimitArea.New("dogtown_gate", new Vector4(-2059.910400, -2319.379395, 20.799999, 1.000000), 70.0, 10.0, 5.0)); // Dogtown Gate.
    }

    private func OnDetach() -> Void {
    }

    private let minimapController: ref<MinimapContainerController>;

    public func SetMinimapController(minimapController: ref<MinimapContainerController>) -> Void {
        this.minimapController = minimapController;
    }

    public func GetSpeedLimitAreasForNormalAI() -> array<SpeedLimitArea> {
        return this.m_speedLimitAreasForNormalAI;
    }
    public func AddSpeedLimitAreaForNormalAI(area: SpeedLimitArea) -> Void {
        ArrayPush(this.m_speedLimitAreasForNormalAI, area);
    }
    public func CheckSpeedLimitAreaForNormalAI(out match: SpeedLimitArea) -> Bool {
        return DrivingAISystem.CheckSpeedLimitArea(this.m_speedLimitAreasForNormalAI, this.GetVehicle(), match);
    }

    public func GetSpeedLimitAreasForTrafficAI() -> array<SpeedLimitArea> {
        return this.m_speedLimitAreasForTrafficAI;
    }
    public func AddSpeedLimitAreaForTrafficAI(area: SpeedLimitArea) -> Void {
        ArrayPush(this.m_speedLimitAreasForTrafficAI, area);
    }
    public func CheckSpeedLimitAreaForTrafficAI(out match: SpeedLimitArea) -> Bool {
        return DrivingAISystem.CheckSpeedLimitArea(this.m_speedLimitAreasForTrafficAI, this.GetVehicle(), match);
    }

    private static func CheckSpeedLimitArea(areas: array<SpeedLimitArea>, target: wref<GameObject>, out match: SpeedLimitArea) -> Bool {
        for area in areas {
            if SpeedLimitArea.WithinRange(area, target) {
                match = area;
                return true;
            }
        }
        return false;
    }

    public func GetPlayer() -> ref<PlayerPuppet> {
        return GetPlayer(this.GetGameInstance());
    }

    public func GetVehicle() -> ref<VehicleObject> {
        return this.GetPlayer().GetMountedVehicle();
    }

    public func GetDelaySystem() -> ref<DelaySystem> {
        return GameInstance.GetDelaySystem(this.GetGameInstance());
    }

    public func Now() -> Float {
        return EngineTime.ToFloat(GameInstance.GetPlaythroughTime(this.GetGameInstance()));
    }

    public func RequestForceAutoSave() -> Void {
        GameInstance.GetAutoSaveSystem(this.GetGameInstance()).RequestForcedCheckpoint();
    }

    public func FindAllMappinControllers() -> array<wref<BaseMinimapMappinController>> {
        if !IsDefined(this.minimapController) || !IsDefined(this.minimapController.GetRootWidget()) {
            return [];
        }
        return this.FindMappinControllers(this.minimapController.GetRootWidget());
    }

    private func FindMappinControllers(w: wref<inkWidget>) -> array<wref<BaseMinimapMappinController>> {
        let controllers: array<wref<BaseMinimapMappinController>> = [];
        let controller = w.GetController() as BaseMinimapMappinController;
        if IsDefined(controller) {
            ArrayPush(controllers, controller);
        } else {
            let container = w as inkCompoundWidget;
            if IsDefined(container) {
                let i = 0;
                while i < container.GetNumChildren() {
                    let children = this.FindMappinControllers(container.GetWidget(i));
                    for c in children {
                        ArrayPush(controllers, c);
                    }
                    i = i + 1;
                }
            }
        }
        return controllers;
    }
    
    public func GetTrackedMappin() -> ref<IMappin> {
        let mappinControllers = this.FindAllMappinControllers();
        let questMappin: ref<IMappin>;
        let customMappin: ref<IMappin>;
        let normalMappin: ref<IMappin>;
        for c in mappinControllers {
            if !Vector4.IsXYZZero(c.GetMappin().GetWorldPosition()) && c.IsTracked() && c.GetMappin().IsActive() {
                if c.IsCustomPositionTracked() && !IsDefined(customMappin) {
                    customMappin = c.GetMappin();
                }
                if c.GetMappin().IsQuestPath() && !IsDefined(questMappin) {
                    questMappin = c.GetMappin();
                }
                if !c.GetMappin().IsQuestPath() && !IsDefined(normalMappin) {
                    normalMappin = c.GetMappin();
                }
            }
        }
        if IsDefined(customMappin) {
            return customMappin;
        }
        if IsDefined(normalMappin) {
            return normalMappin;
        }
        if IsDefined(questMappin) {
            return questMappin;
        }
        return null;
    }

    public func GetTrackedPoint() -> Vector4 {
        let mappin = this.GetTrackedMappin();
        if IsDefined(mappin) {
            return mappin.GetWorldPosition();
        } else {
            return Vector4.EmptyVector();
        }
    }
}

@wrapMethod(MinimapContainerController)
protected cb func OnPlayerAttach(player: ref<GameObject>) -> Bool {
    let result = wrappedMethod(player);
    DrivingAISystem.GetInstance(player.GetGame()).SetMinimapController(this);
    return result;
}

@wrapMethod(MinimapContainerController)
protected cb func OnPlayerDetach(player: ref<GameObject>) -> Bool {
    let result = wrappedMethod(player);
    DrivingAISystem.GetInstance(player.GetGame()).SetMinimapController(null);
    return result;
}

@wrapMethod(VehicleObject)
protected cb func OnUnmountingEvent(evt: ref<UnmountingEvent>) -> Bool {
    let result = wrappedMethod(evt);
    this.GetAutoDriveComponent_ADE().OnUnmountingEvent(evt);
    return result;
}

@addField(VehicleObject)
protected let autoDriveComponent_ADE: ref<AutoDriveComponent>;

@addMethod(VehicleObject)
public func GetAutoDriveComponent_ADE() -> ref<AutoDriveComponent> {
    return this.autoDriveComponent_ADE;
}

public class AutoDriveTickEvent extends TickableEvent {}

@addMethod(VehicleObject)
protected cb func OnAutoDriveTickEvent_ADE(evt: ref<AutoDriveTickEvent>) -> Bool {
    if IsDefined(this.GetAutoDriveComponent_ADE()) {
        this.GetAutoDriveComponent_ADE().OnTick();
    }
}

@wrapMethod(VehicleObject)
protected cb func OnGameAttached() -> Bool {
    let result = wrappedMethod();
    this.autoDriveComponent_ADE = new AutoDriveComponent();
    this.autoDriveComponent_ADE.Initialize(GetPlayer(this.GetGame()), this);
    return result;
}

@wrapMethod(VehicleObject)
protected cb func OnDetach() -> Bool {
    let result = wrappedMethod();
    if IsDefined(this.autoDriveComponent_ADE) {
        this.autoDriveComponent_ADE.Uninitialize();
        this.autoDriveComponent_ADE = null;
    }
    return result;
}

@addMethod(GameObject)
public final func GetAroundVehicles_ADE(range: Float) -> array<ref<VehicleObject>> {
    let searchQuery: TargetSearchQuery;
    searchQuery.testedSet = TargetingSet.Complete;
    searchQuery.maxDistance = range;
    searchQuery.searchFilter = TSF_Any(TSFMV.Obj_Device);
    searchQuery.filterObjectByDistance = range > 0.0;
    searchQuery.ignoreInstigator = true;
    searchQuery.includeSecondaryTargets = false;

    let targetParts: array<TS_TargetPartInfo>;
    GameInstance.GetTargetingSystem(this.GetGame()).GetTargetParts(this, searchQuery, targetParts);

    let targets: array<ref<VehicleObject>> = [];
    for targetingPart in targetParts {
        let targetingComponent = TS_TargetPartInfo.GetComponent(targetingPart);
        if !IsDefined(targetingComponent) {
        } else {
            let target = targetingComponent.GetEntity() as VehicleObject;
            if !IsDefined(target) {
            } else {
                if !ArrayContains(targets, target) {
                    ArrayPush(targets, target);
                };
            };
        };
    };
    return targets;
}

@addField(GameObject)
protected let m_highlightData_ADE: ref<FocusForcedHighlightData>;

@addField(GameObject)
protected let m_highlightCancelID_ADE: DelayID;

public class HighlightCancelEvent extends Event {}

@addMethod(GameObject)
protected cb func OnHighlightCancelEvent_ADE(evt: ref<HighlightCancelEvent>) -> Void {
    this.CancelHighlight_ADE();
}

@addMethod(GameObject)
protected func CancelHighlight_ADE() -> Void {
    let cancelEvt = new ForceVisionApperanceEvent();
    cancelEvt.forcedHighlight = this.m_highlightData_ADE;
    cancelEvt.apply = false;
    this.QueueEvent(cancelEvt);
    this.m_highlightData_ADE = null;
}

@addMethod(GameObject)
protected func QueueHighlight_ADE(source: ref<GameObject>, revealed: Bool, highlightType: EFocusForcedHighlightType, outlineType: EFocusOutlineType) -> ref<FocusForcedHighlightData> {
    let highlightEvt = new ForceVisionApperanceEvent();
    let data = new FocusForcedHighlightData();
    data.sourceID = source.GetEntityID();
    data.sourceName = source.GetClassName();
    data.highlightType = highlightType;
    data.outlineType = outlineType;
    data.priority = EPriority.High;
    data.isRevealed = revealed;
    this.m_highlightData_ADE = data;
    highlightEvt.forcedHighlight = data;
    highlightEvt.apply = true;
    this.QueueEvent(highlightEvt);
    return data;
}

@addMethod(GameObject)
public func Highlight_ADE(source: ref<GameObject>, revealed: Bool, highlightType: EFocusForcedHighlightType, outlineType: EFocusOutlineType) -> Void {
    if !IsDefined(this.m_highlightData_ADE){
        this.QueueHighlight_ADE(source, revealed, highlightType, outlineType);
        this.m_highlightCancelID_ADE = GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, new HighlightCancelEvent(), 1.0);
    } else {
        GameInstance.GetDelaySystem(this.GetGame()).CancelDelay(this.m_highlightCancelID_ADE);
        if Equals(this.m_highlightData_ADE.highlightType, highlightType) && Equals(this.m_highlightData_ADE.outlineType, outlineType) && Equals(this.m_highlightData_ADE.isRevealed, revealed) {
            this.m_highlightCancelID_ADE = GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, new HighlightCancelEvent(), 1.0);
        } else {
            this.CancelHighlight_ADE();
            this.QueueHighlight_ADE(source, revealed, highlightType, outlineType);
            this.m_highlightCancelID_ADE = GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, new HighlightCancelEvent(), 1.0);
        }
    }
}


@addMethod(DefaultTransition)
protected final func GetAutoDriveComponent_ADE(scriptInterface: ref<StateGameScriptInterface>) -> ref<AutoDriveComponent> {
    return this.GetVehicle_ADE(scriptInterface).GetAutoDriveComponent_ADE();
}

@wrapMethod(SwitchSeatsEvents)
protected func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    wrappedMethod(stateContext, scriptInterface);
    if this.GetAutoDriveComponent_ADE(scriptInterface).IsAutoDriving() {
        // ExitingEventsBase.CancelAutoDriveOnEnterExiting でキャンセルしなければ 運転席→助手席では動作するが
        // 助手席→運転席の時にはなぜか 実行中のAICommand コマンドが停止するので、キャンセルしてから席移動後に再実行する.
        this.GetAutoDriveComponent_ADE(scriptInterface).Pause();
    }
}
@wrapMethod(DriveEvents)
protected func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    wrappedMethod(stateContext, scriptInterface);
    this.GetAutoDriveComponent_ADE(scriptInterface).Resume();
}
@wrapMethod(DriverCombatEvents)
protected func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    wrappedMethod(stateContext, scriptInterface);
    this.GetAutoDriveComponent_ADE(scriptInterface).Resume();
}
@wrapMethod(PassengerEvents)
protected func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    wrappedMethod(stateContext, scriptInterface);
    this.GetAutoDriveComponent_ADE(scriptInterface).Resume();
}
