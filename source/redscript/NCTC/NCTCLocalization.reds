module NCTC.Localization

import Codeware.Localization.*

public class NCTCLocalizationProvider extends ModLocalizationProvider {
  public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
    return new NCTCEnglish();
  }

  public func GetFallback() -> CName {
    return n"en-us";
  }
}

public class NCTCEnglish extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    this.Text("UI-MappinTypes-NCTCStops", "Transport Corp Lines");
  }
}
