module NCTC

public class NCTCWaitForBusAction extends OpenWorldMapDeviceAction {
  public func SetProperties(line: String) -> Void {
    this.actionName = n"NCTCWaitForBus";
    this.prop = DeviceActionPropertyFunctions.SetUpProperty_Bool(
      n"NCTCWaitForBus", true,
      StringToName("Wait for NCTC line " + line),
      StringToName("Wait for NCTC line " + line)
    );
  }

  public func GetTweakDBChoiceRecord() -> String {
    return "NCTCWaitForBus";
  }
}

@wrapMethod(DataTermControllerPS)
public const func GetActions(out actions: array<ref<DeviceAction>>, context: GetActionsContext) -> Bool {
  let result: Bool = wrappedMethod(actions, context);
  let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
  let markers: ref<NCTCMapMarkerSystem>;
  let line: String;
  let stop: Vector4;
  let index: Int32;
  let mapAction: ref<OpenWorldMapDeviceAction>;
  let action: ref<NCTCWaitForBusAction>;
  if !result || !IsDefined(player) { return result; };
  markers = NCTCMapMarkerSystem.GetInstance(this.GetGameInstance());
  if !IsDefined(markers) || !markers.GetNearestService(player.GetWorldPosition(), line, stop) { return result; };
  index = ArraySize(actions) - 1;
  while index >= 0 {
    mapAction = actions[index] as OpenWorldMapDeviceAction;
    if IsDefined(mapAction) { ArrayErase(actions, index); };
    index -= 1;
  };
  action = new NCTCWaitForBusAction();
  action.SetUp(this);
  action.SetProperties(line);
  action.AddDeviceName(this.GetDeviceName());
  action.CreateActionWidgetPackage();
  ArrayPush(actions, action);
  return true;
}

@wrapMethod(DataTerm)
private final func RequestFastTravelMenu() -> Void {
  let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGame())
    .GetLocalPlayerMainGameObject() as PlayerPuppet;
  let markers: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(this.GetGame());
  let line: String;
  let stop: Vector4;
  if IsDefined(player) && IsDefined(markers) && markers.GetNearestService(player.GetWorldPosition(), line, stop) {
    NCTCTransitSystem.Get(this.GetGame()).RequestService(line, stop);
    return;
  };
  wrappedMethod();
}
