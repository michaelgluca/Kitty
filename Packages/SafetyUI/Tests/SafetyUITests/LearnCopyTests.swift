import Foundation
import SafetyContent
import Testing

@testable import SafetyUI

@Suite("Learn copy")
struct LearnCopyTests {

    @Test("Every nation has a name")
    func nationNames() {
        #expect(NationCopy.name(.england) == "England")
        #expect(NationCopy.name(.wales) == "Wales")
        #expect(NationCopy.name(.scotland) == "Scotland")
        #expect(NationCopy.name(.northernIreland) == "Northern Ireland")
    }

    @Test("Says where a point applies, and says UK-wide only when it is true in all four nations")
    func appliesIn() {
        #expect(NationCopy.appliesIn([.england, .wales]) == "Applies in England and Wales")
        #expect(NationCopy.appliesIn([.scotland]) == "Applies in Scotland")
        #expect(NationCopy.appliesIn(Nation.allCases) == "Applies across the UK")
        // Order in the data must not change the wording.
        #expect(NationCopy.appliesIn([.wales, .england]) == "Applies in England and Wales")
    }

    @Test("The rights footer says it is not legal advice")
    func notLegalAdvice() {
        #expect(Strings.localized("learn.rights.footer").contains("not legal advice"))
        #expect(Strings.localized("rights.disclaimer").contains("not legal advice"))
    }

    // The Help tab's guides footer used to say "Kitty G only links to Apple's own
    // instructions" — true when the guides were a bare link list, false now that
    // Learn shows the steps itself. Learn gets its own footer so that claim is never
    // reused somewhere it would be wrong.
    @Test("The iPhone features footer does not claim Kitty G only links out")
    func featuresFooterIsAccurate() {
        let footer = Strings.localized("learn.features.footer")
        #expect(!footer.contains("only links"))
    }

    @Test("Every Learn key resolves", arguments: [
        "tab.learn", "learn.rights.header", "learn.rights.footer", "learn.features.header",
        "rights.whatTheLawSays", "rights.whatYouCanDo", "rights.differences", "rights.sources", "rights.disclaimer",
        "feature.setUp", "feature.use", "feature.caution", "feature.requirements",
        "help.features.link", "learn.unavailable.title", "learn.unavailable.body",
        "learn.features.footer", "feature.step",
    ])
    func keysResolve(key: String) {
        #expect(Strings.localized(String.LocalizationValue(key)) != key, "Missing catalogue entry: \(key)")
    }

    // VoiceOver: a Label whose icon is a plain number is not read as "step one" on
    // its own, so each step needs an explicit accessibility label built from a
    // positional format — "Step %1$d: %2$@" — so the step number is always read
    // before the step's own text, regardless of argument order in a future edit.
    @Test("The step accessibility format names the step number, then the step text")
    func stepAccessibilityFormat() {
        let format = Strings.localized("feature.step")
        let rendered = String(format: format, 3, "Turn on Check In")
        #expect(rendered == "Step 3: Turn on Check In")
    }
}
