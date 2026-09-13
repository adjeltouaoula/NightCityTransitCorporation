@wrapMethod(NCTCServiceBusController)
public func GetCurrentSpeed() -> Float {
  let speed: Float = wrappedMethod();
  let crowd: ref<gameCrowdMemberComponent>;
  let pos: Vector4;
  let e05: Int32;
  let e10: Int32;
  let e15: Int32;
  if !this.IsReady() { return speed; };
  pos = this.GetWorldPosition();
  if Vector4.Distance(pos, new Vector4(-2161.30, -1030.12, pos.Z, 0.00)) > 85.00 { return speed; };
  crowd = this.bus.GetCrowdMemberComponent();
  if !IsDefined(crowd) { return speed; };
  e05 = crowd.CheckEmptyPath(5.00) ? 1 : 0;
  e10 = crowd.CheckEmptyPath(10.00) ? 1 : 0;
  e15 = crowd.CheckEmptyPath(15.00) ? 1 : 0;
  GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_crowd_empty_5", e05);
  GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_crowd_empty_10", e10);
  GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_crowd_empty_15", e15);
  LogChannel(n"DEBUG", "[NCTC r381c crowd-probe] e5=" + ToString(e05) + " e10=" + ToString(e10) + " e15=" + ToString(e15));
  return speed;
}
