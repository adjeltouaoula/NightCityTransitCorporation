module NCTC

// Input Loader uses the overridableUI identifiers below to keep its native
// action mapping synchronized with Mod Settings. Keeping keyboard and gamepad
// values separate lets players rebind either control without changing the
// vanilla phone / notification bindings.
public class NCTCStopRequestSettings {
  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Request next stop — keyboard")
  @runtimeProperty("ModSettings.description", "Keyboard key used to request the next NCTC stop while riding a service bus.")
  @runtimeProperty("ModSettings.category", "Controls")
  @runtimeProperty("ModSettings.category.order", "-20")
  public let NCTC_RequestNextStop_Keyboard: EInputKey = EInputKey.IK_U;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Request next stop — gamepad")
  @runtimeProperty("ModSettings.description", "Gamepad button used to request the next NCTC stop while riding a service bus.")
  @runtimeProperty("ModSettings.category", "Controls")
  public let NCTC_RequestNextStop_Gamepad: EInputKey = EInputKey.IK_Pad_DigitDown;
}
