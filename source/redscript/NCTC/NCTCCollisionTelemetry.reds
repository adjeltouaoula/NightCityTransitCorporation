import NCTC.*

// This is the earliest script-visible vehicle-impact event.  Vanilla turns it
// into Attacks.CarHitPlayer afterwards, so the original vehicle ID is only
// available here.
@wrapMethod(PlayerPuppet)
protected cb func OnCarHitPlayer(evt: ref<OnCarHitPlayer>) -> Bool {
  if !IsDefined(evt) { return wrappedMethod(evt); };
  // Diagnostic control: leave the vanilla collision response intact. This
  // tests whether suppressing PlayerPuppet.OnCarHitPlayer caused the later
  // standing-passenger ejection.

  return wrappedMethod(evt);
}
