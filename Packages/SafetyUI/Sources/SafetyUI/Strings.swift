import Foundation
import SafetyDomain

/// Localised text, resolved from the String Catalog.
///
/// The domain owns the rules about which lines appear; this owns their wording, so
/// `SafetyDomain` stays free of bundles and localisation machinery. See ADR-0003.
public enum Strings {

    static func localized(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }

    public static var alert: AlertStrings {
        AlertStrings(
            header: localized("alert.body.header"),
            sentAt: localized("alert.body.sentAt"),
            locationLink: localized("alert.body.locationLink"),
            coordinates: localized("alert.body.coordinates"),
            locationUnavailable: localized("alert.body.locationUnavailable"),
            battery: localized("alert.body.battery"),
            disclaimer: localized("alert.body.disclaimer"),
            testNotice: localized("alert.body.testNotice")
        )
    }
}
