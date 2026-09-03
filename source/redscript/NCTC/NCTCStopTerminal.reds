module NCTC

// A data terminal's in-world interaction widget is built specifically for
// OpenWorldMapDeviceAction.  Keep that native action shape so the prompt is
// rendered, then intercept the click below before it can open the map.
public class NCTCRequestServiceAction extends OpenWorldMapDeviceAction {
  public func SetProperties() -> Void {
    this.actionName = n"NCTCRequestService";
    this.prop = DeviceActionPropertyFunctions.SetUpProperty_Bool(
      n"NCTCRequestService", true,
      n"Request NCTC service",
      n"Request NCTC service"
    );
  }

  public func GetTweakDBChoiceRecord() -> String {
    return "NCTCRequestW01";
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
  let action: ref<NCTCRequestServiceAction>;
  if !result || !IsDefined(player) { return result; };
  markers = NCTCMapMarkerSystem.GetInstance(this.GetGameInstance());
  if !IsDefined(markers) || !markers.GetNearestService(player.GetWorldPosition(), line, stop) { return result; };
  index = ArraySize(actions) - 1;
  while index >= 0 {
    mapAction = actions[index] as OpenWorldMapDeviceAction;
    if IsDefined(mapAction) { ArrayErase(actions, index); };
    index -= 1;
  };
  action = new NCTCRequestServiceAction();
  action.SetUp(this);
  action.SetProperties();
  action.AddDeviceName(this.GetDeviceName());
  action.CreateActionWidgetPackage();
  ArrayPush(actions, action);
  return true;
}

@wrapMethod(DataTerm)
private final func RequestFastTravelMenu() -> Void {
  let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGame())
    .GetLocalPlayerMainGameObject() as PlayerPuppet;
  let markers: ref<NCTCMapMarkerSystem>;
  let line: String;
  let stop: Vector4;

  if IsDefined(player) {
    markers = NCTCMapMarkerSystem.GetInstance(this.GetGame());
    if IsDefined(markers) && markers.GetNearestService(player.GetWorldPosition(), line, stop) {
      NCTCTransitSystem.Get(this.GetGame()).RequestService(line, stop);
      return;
    };
  };

  wrappedMethod();
}
