import Foundation
import SafetyContent
import Testing

@testable import SafetyUI

@Suite("Rights points: here and elsewhere")
@MainActor
struct RightsPointsTests {

    private func topic(_ id: String) throws -> RightsTopic {
        try #require(try ContentLoader.loadUK().rights.first { $0.id == id })
    }

    @Test("Scotland's points come first; the rest are set aside, none lost")
    func scotland() throws {
        let t = try topic("what-counts-as-domestic-abuse")
        let points = RightsTopicScreen.points(of: t, for: .scotland)
        #expect(points.here.allSatisfy { $0.nations.contains(.scotland) })
        #expect(!points.elsewhere.isEmpty)
        #expect(points.here.count + points.elsewhere.count == t.points.count)
    }

    @Test("With all of the UK, every point is shown and nothing is set aside")
    func allOfTheUK() throws {
        let t = try topic("what-counts-as-domestic-abuse")
        let points = RightsTopicScreen.points(of: t, for: nil)
        #expect(points.here == t.points)
        #expect(points.elsewhere.isEmpty)
    }

    @Test("A nation with no point of its own sees every point, never an empty section")
    func noPointHere() throws {
        let json = #"{"id":"t","title":"T","summary":"S","points":[{"text":"England only.","nations":["england"]}],"whatYouCanDo":"W","sources":[{"title":"GOV.UK","url":"https://www.gov.uk/"}],"topics":["work"]}"#
        let t = try JSONDecoder().decode(RightsTopic.self, from: Data(json.utf8))
        let points = RightsTopicScreen.points(of: t, for: .scotland)
        #expect(points.here == t.points)
        #expect(points.elsewhere.isEmpty)
    }
}
