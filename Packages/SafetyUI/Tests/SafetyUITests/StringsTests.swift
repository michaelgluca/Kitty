import Foundation
import SafetyDomain
import Testing

@testable import SafetyUI

@Suite("Localised strings")
struct StringsTests {

    /// A missing String Catalog entry does not crash — SwiftUI renders the key
    /// itself. In the alert body that would send a contact the literal text
    /// "alert.body.header", which is why this is checked rather than eyeballed.
    @Test("Every alert string resolves to real text, not its key")
    func alertStringsResolve() {
        let s = Strings.alert
        let values = [
            s.header, s.sentAt, s.locationLink, s.coordinates,
            s.locationUnavailable, s.battery, s.disclaimer,
        ]
        for value in values {
            #expect(!value.isEmpty)
            #expect(!value.hasPrefix("alert.body."), "Unresolved String Catalog key: \(value)")
        }
    }

    @Test("Format strings carry exactly the placeholders the renderer supplies")
    func placeholderArity() {
        let s = Strings.alert
        // Each of these is passed exactly one argument. A catalogue edit that drops
        // or duplicates a %@ would silently mangle the message.
        for format in [s.sentAt, s.locationLink, s.coordinates, s.battery] {
            #expect(format.components(separatedBy: "%@").count == 2, "Expected one %@ in: \(format)")
        }
        // These take none.
        for plain in [s.header, s.locationUnavailable, s.disclaimer] {
            #expect(!plain.contains("%@"), "Unexpected placeholder in: \(plain)")
        }
    }

    @Test("The disclaimer says the app does not contact emergency services")
    func disclaimerIsHonest() {
        #expect(Strings.alert.disclaimer.lowercased().contains("does not contact emergency services"))
    }
}

@Suite("Region-aware disclaimer")
struct DisclaimerTests {

    @Test("Outside the UK the disclaimer never tells anyone to call 999")
    func elsewhereDoesNotSay999() {
        // Found by testing on an en_US simulator: the Alert tab told a US user to call
        // 999, which does not work there. Pinned so it cannot quietly come back.
        let text = Strings.localized("disclaimer.persistent.elsewhere")
        #expect(!text.contains("999"))
        #expect(text.lowercased().contains("local emergency number"))
        #expect(text.lowercased().contains("does not contact emergency services"))
    }

    @Test("In the UK the disclaimer names 999")
    func ukSays999() {
        #expect(Strings.localized("disclaimer.persistent").contains("999"))
    }
}
