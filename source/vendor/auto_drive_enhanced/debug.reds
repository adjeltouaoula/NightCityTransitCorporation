module AutoDriveEnhanced.Debug

// CET側で、EnumGetMaxで回すので、必ず値は0から1ずつ上げる.
public enum DrawType {
  Line = 0,
  Rect = 1,
  Box = 2,
  Text = 3,
  Text2D = 4
}

public class DebugDrawRequest {
  public let id: Uint32;
  public let type: DrawType;
  public let vertices: [Vector4];
  public let color: Color;
  public let expiration: Float;
  // SetPosition/Scale 用
  public let position: Vector4;
  public let scale: Vector4;

  public let text: String;
  public let textAlign: gameDebugViewETextAlignment;

  // Screen(2D)用
  public let screenPos: Vector2;

  public func IsExpired(game: GameInstance) -> Bool {
    if this.expiration > 0.0 {
      let now = EngineTime.ToFloat(GameInstance.GetTimeSystem(game).GetSimTime());
      return now > this.expiration;
    }
    return false;
  }
}

// DebugVisualizerSystem のパクリ
// 実際のレンダリングは、CETのonDrawで実行する。
public final class DebugDrawerSystem extends ScriptableSystem {
  private let m_storage: ref<inkHashMap>;
  private let m_nextId: Uint32 = 1u;
  private let m_enabled: Bool;

  public func IsEnabled() -> Bool = this.m_enabled;

  public func SetEnabled(enabled: Bool) -> Void {
    if NotEquals(this.m_enabled, enabled) {
      this.m_enabled = enabled;
      this.OnEnabledChanged(enabled);
    }
  }

  protected func OnEnabledChanged(enabled: Bool) -> Void {}

  public static func GetInstance(game: GameInstance) -> ref<DebugDrawerSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(NameOf<DebugDrawerSystem>()) as DebugDrawerSystem;
  }

  // enum値列挙用にluaからコールされる
  public func DrawTypeName() -> CName = NameOf<DrawType>();

  private func OnAttach() -> Void {
    this.m_storage = new inkHashMap();
  }

  private func OnDetach() -> Void {
    this.m_storage.Clear();
    this.m_storage = null;
  }

  public final func DrawLine(start: Vector4, end: Vector4, opt color: Color, opt lifetime: Float) -> Uint32 {
    let v = [start, end];
    return this.AddRequest(DrawType.Line, v, color, lifetime);
  }

  public final func DrawRect(position: Vector4, size: Vector4, opt color: Color, opt lifetime: Float) -> Uint32 {
    let v: array<Vector4>;
    let hX: Float = size.X / 2.0;
    let hY: Float = size.Y / 2.0;
    v = [
      Vector4(position.X - hX, position.Y - hY, position.Z, 1.0),
      Vector4(position.X + hX, position.Y - hY, position.Z, 1.0),
      Vector4(position.X + hX, position.Y + hY, position.Z, 1.0),
      Vector4(position.X - hX, position.Y + hY, position.Z, 1.0)
    ];
    return this.AddRequest(DrawType.Rect, v, color, lifetime);
  }

  public final func DrawOrientedRect(position: Vector4, orientation: Quaternion, size: Vector4, opt color: Color, opt lifetime: Float) -> Uint32 {
    let hW: Float = size.X / 2.0;
    let hH: Float = size.Y / 2.0;

    let vLocal: array<Vector4>;
    ArrayPush(vLocal, Vector4( hW,  hH, 0.0, 0.0)); // 1: Front-Right
    ArrayPush(vLocal, Vector4(-hW,  hH, 0.0, 0.0)); // 2: Front-Left
    ArrayPush(vLocal, Vector4(-hW, -hH, 0.0, 0.0)); // 3: Back-Left
    ArrayPush(vLocal, Vector4( hW, -hH, 0.0, 0.0)); // 4: Back-Right

    let vWorld: array<Vector4>;
    for localPos in vLocal {
      ArrayPush(vWorld, orientation * localPos + position);
    }

    return this.AddRequest(DrawType.Rect, vWorld, color, lifetime);
  }

  public final func DrawWireBox(boxMin: Vector4, boxMax: Vector4, opt color: Color, opt lifetime: Float) -> Uint32 {
    let v = [
      Vector4(boxMin.X, boxMin.Y, boxMin.Z, 1.0), Vector4(boxMax.X, boxMin.Y, boxMin.Z, 1.0),
      Vector4(boxMax.X, boxMax.Y, boxMin.Z, 1.0), Vector4(boxMin.X, boxMax.Y, boxMin.Z, 1.0),
      Vector4(boxMin.X, boxMin.Y, boxMax.Z, 1.0), Vector4(boxMax.X, boxMin.Y, boxMax.Z, 1.0),
      Vector4(boxMax.X, boxMax.Y, boxMax.Z, 1.0), Vector4(boxMin.X, boxMax.Y, boxMax.Z, 1.0)
    ];
    return this.AddRequest(DrawType.Box, v, color, lifetime);
  }

  public final func DrawOrientedBox(position: Vector4, orientation: Quaternion, size: Vector4, opt color: Color, opt lifetime: Float) -> Uint32 {
    let hW: Float = size.X / 2.0;
    let hH: Float = size.Y / 2.0;
    let hZ: Float = size.Z / 2.0;

    // ローカル座標の8頂点
    let vLocal: array<Vector4>;
    ArrayPush(vLocal, Vector4( hW,  hH, -hZ, 0.0));
    ArrayPush(vLocal, Vector4(-hW,  hH, -hZ, 0.0));
    ArrayPush(vLocal, Vector4(-hW, -hH, -hZ, 0.0));
    ArrayPush(vLocal, Vector4( hW, -hH, -hZ, 0.0));
    ArrayPush(vLocal, Vector4( hW,  hH,  hZ, 0.0));
    ArrayPush(vLocal, Vector4(-hW,  hH,  hZ, 0.0));
    ArrayPush(vLocal, Vector4(-hW, -hH,  hZ, 0.0));
    ArrayPush(vLocal, Vector4( hW, -hH,  hZ, 0.0));

    let vWorld: array<Vector4>;
    for localPos in vLocal {
      ArrayPush(vWorld, orientation * localPos + position);
    }

    return this.AddRequest(DrawType.Box, vWorld, color, lifetime);
  }

  public final func DrawText(screenPos: Vector4, text: String, opt textAlign: gameDebugViewETextAlignment, opt color: Color, opt lifetime: Float) -> Uint32 {
    return this.AddRequest(DrawType.Text, Vector2(screenPos.X, screenPos.Y), text, textAlign, color, lifetime);
  }

  public final func DrawText2D(screenNormalizedPos: Vector2, text: String, opt textAlign: gameDebugViewETextAlignment, opt color: Color, opt lifetime: Float) -> Uint32 {
    return this.AddRequest(DrawType.Text2D, screenNormalizedPos, text, textAlign, color, lifetime);
  }

  private func AddRequest(type: DrawType, vertices: [Vector4], color: Color, lifetime: Float) -> Uint32 {
    let req = new DebugDrawRequest();
    req.type = type;
    req.vertices = vertices;
    req.color = color;
    return this.AddRequest(req, lifetime);
  }

  private func AddRequest(type: DrawType, screenPos: Vector2, text: String, opt textAlign: gameDebugViewETextAlignment, opt color: Color, opt lifetime: Float) -> Uint32 {
    let req = new DebugDrawRequest();
    req.type = type;
    req.screenPos = screenPos;
    req.text = text;
    req.textAlign = textAlign;
    req.color = color;
    return this.AddRequest(req, lifetime);
  }

  private func AddRequest(req: ref<DebugDrawRequest>, lifetime: Float) -> Uint32 {
    if !this.IsEnabled() { return 0u; }
    let id = this.m_nextId;
    this.m_nextId += 1u;
    req.id = id;
    let now = EngineTime.ToFloat(GameInstance.GetTimeSystem(this.GetGameInstance()).GetSimTime());
    req.expiration = (lifetime > 0.0) ? (now + lifetime) : -1.0;
    this.m_storage.Insert(Cast<Uint64>(id), req);
    return id;
  }

  public final func ClearLayer(layerId: Uint32) -> Void {
    if !this.IsEnabled() { return; }
    this.m_storage.Remove(Cast<Uint64>(layerId));
  }

  public final func ClearAll() -> Void {
    if !this.IsEnabled() { return; }
    this.m_storage.Clear();
  }

  // CETでコールされて、このデータをもとにCETで描画する
  public final func GetAllRequests() -> [ref<DebugDrawRequest>] {
    let values: [wref<IScriptable>];
    this.m_storage.GetValues(values);
    let requests: [ref<DebugDrawRequest>];
    for v in values {
      let req = v as DebugDrawRequest;
      if IsDefined(req) {
        if req.IsExpired(this.GetGameInstance()) {
          this.m_storage.Remove(Cast<Uint64>(req.id));
        } else {
          ArrayPush(requests, req);
        }
      }
    }

    return requests;
  }
}