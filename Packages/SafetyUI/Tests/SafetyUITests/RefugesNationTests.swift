import SafetyContent
import Testing

@testable import SafetyUI

private typealias UnsavedChoice = NationPreference.UnsavedChoice

@MainActor
@Suite("Refuges: which nation is listed")
struct RefugesNationTests {

    @Test("Refuges lists the saved nation, then a pick of a nation that could not be saved, then the detected one, and otherwise asks", arguments: [
        // The nation chosen on Get help or Learn is the one listed, even after a move.
        (Nation?.some(.scotland), UnsavedChoice?.none, Nation?.some(.england), NationShown(nation: .scotland, isFromLocation: false, isUnsavedPick: false)),
        // Until the person chooses, the nation found from their location is listed and labelled.
        (nil, nil, .england, NationShown(nation: .england, isFromLocation: true, isUnsavedPick: false)),
        // A pick that could not be saved is kept for this screen, not labelled as from the location.
        (nil, UnsavedChoice(nation: .wales), .england, NationShown(nation: .wales, isFromLocation: false, isUnsavedPick: true)),
        // A failed pick of "all of the UK" is not a nation to list: it falls through.
        (nil, UnsavedChoice(nation: nil), .england, NationShown(nation: .england, isFromLocation: true, isUnsavedPick: false)),
        (nil, UnsavedChoice(nation: nil), nil, NationShown(nation: nil, isFromLocation: false, isUnsavedPick: false)),
        // With nothing chosen and nothing detected, the screen asks.
        (nil, nil, nil, NationShown(nation: nil, isFromLocation: false, isUnsavedPick: false)),
    ])
    func nationShown(saved: Nation?, unsavedChoice: NationPreference.UnsavedChoice?, detected: Nation?, expected: NationShown) {
        #expect(RefugesScreen.nationShown(saved: saved, unsavedChoice: unsavedChoice, detected: detected) == expected)
    }

    @Test("A read failure always uses the refuges-specific wording: it has no pick to misattribute")
    func couldNotReadIsAlwaysRefugesWording() {
        #expect(RefugesScreen.problemText(.couldNotRead, shown: NationShown(nation: .england, isFromLocation: true, isUnsavedPick: false))
                == FilterCopy.refugesProblem(.couldNotRead))
        #expect(RefugesScreen.problemText(.couldNotRead, shown: NationShown(nation: nil, isFromLocation: false, isUnsavedPick: false))
                == FilterCopy.refugesProblem(.couldNotRead))
    }

    /// Every combination that could misattribute a failure: the failed pick itself may be
    /// "all of the UK" (`nil`), a nation that is what Refuges lists, or a nation that
    /// isn't — each crossed with a detected nation present or absent. `nationShown` is
    /// used to derive what Refuges would actually show for each combination, so this
    /// exercises the whole pipeline, not a hand-picked `NationShown` that might drift
    /// from what the precedence rules would really produce.
    @Test("The 'used on this screen only' wording appears only when the failed pick is genuinely what is shown", arguments: [
        // (saved, failed pick, detected, attributable to what's shown?)
        (Nation?.none, Nation?.none, Nation?.some(.england), false), // failed pick was "all of the UK"; detected present
        (Nation?.none, Nation?.none, Nation?.none, false), // failed pick was "all of the UK"; detected absent
        (Nation?.none, Nation?.some(.wales), Nation?.some(.england), true), // failed pick is what's listed; detected present
        (Nation?.none, Nation?.some(.wales), Nation?.none, true), // failed pick is what's listed; detected absent
        (Nation?.some(.scotland), Nation?.some(.wales), Nation?.some(.england), false), // failed pick isn't what's listed; detected present
        (Nation?.some(.scotland), Nation?.some(.wales), Nation?.none, false), // failed pick isn't what's listed; detected absent
    ])
    func couldNotSaveWordingMatchesWhatIsShown(saved: Nation?, failedPick: Nation?, detected: Nation?, isAttributable: Bool) {
        let shown = RefugesScreen.nationShown(saved: saved, unsavedChoice: UnsavedChoice(nation: failedPick), detected: detected)
        let expected = isAttributable ? FilterCopy.refugesProblem(.couldNotSave) : FilterCopy.refugesCouldNotSaveElsewhere
        #expect(RefugesScreen.problemText(.couldNotSave, shown: shown) == expected)
    }
}
