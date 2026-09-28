import SafetyContent
import Testing

@testable import SafetyUI

@MainActor
@Suite("Refuges: which nation is listed")
struct RefugesNationTests {

    @Test("The nation chosen on Get help or Learn is the one listed, even after a move")
    func savedBeatsDetected() {
        #expect(RefugesScreen.nationShown(saved: .scotland, unsaved: nil, detected: .england)
                == NationShown(nation: .scotland, isFromLocation: false))
    }

    @Test("Until the person chooses, the nation found from their location is listed and labelled")
    func detectedWhenNothingChosen() {
        #expect(RefugesScreen.nationShown(saved: nil, unsaved: nil, detected: .england)
                == NationShown(nation: .england, isFromLocation: true))
    }

    @Test("A pick that could not be saved is kept for this screen, and not labelled as from the location")
    func unsavedPickIsKept() {
        #expect(RefugesScreen.nationShown(saved: nil, unsaved: .wales, detected: .england)
                == NationShown(nation: .wales, isFromLocation: false))
    }

    @Test("With nothing chosen and nothing detected, the screen asks")
    func nothing() {
        #expect(RefugesScreen.nationShown(saved: nil, unsaved: nil, detected: nil)
                == NationShown(nation: nil, isFromLocation: false))
    }
}
