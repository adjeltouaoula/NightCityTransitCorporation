module NCTC

public class NCTCRequestServiceAction extends ActionBool {
  public func SetProperties() -> Void {
    this.actionName = n"NCTCRequestService";
    this.prop = DeviceActionPropertyFunctions.SetUpProperty_Bool(
      n"NCTCRequestService", true,
      n"Request NCTC service",
      n"Request NCTC service"
    );
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

@addMethod(DataTermControllerPS)
protected cb func OnActionNCTCRequestServiceAction(evt: ref<NCTCRequestServiceAction>) -> EntityNotificationType {
  let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
  let markers: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(this.GetGameInstance());
  let line: String;
  let stop: Vector4;
  if IsDefined(player) && IsDefined(markers) && markers.GetNearestService(player.GetWorldPosition(), line, stop) {
    NCTCTransitSystem.Get(this.GetGameInstance()).RequestService(line, stop);
  };
  return EntityNotificationType.DoNotNotifyEntity;
}
