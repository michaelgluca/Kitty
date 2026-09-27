import Foundation

public extension ContentPack {

    /// Checks the decoder cannot express. A failure is a content bug caught at load
    /// time and in CI, rather than a blank row, or a rule shown to the wrong nation.
    ///
    /// Points and coverage are checked before per-nation completeness, so a defect is
    /// reported by name rather than as a nation that merely looks empty because of it.
    ///
    /// Ids must be unique across rights, guides, refuges and services. A refuge route is
    /// often the same organisation as a helpline in `services`, so refuge ids carry a
    /// `refuge-` prefix (`refuge-national-domestic-abuse-helpline`). Reusing the service
    /// id would fail this check, and with it `ContentLoader.loadUK()` and every tab.
    func validate() throws {
        func fail(_ reason: String) -> ContentLoader.Failure { .malformed(reason) }

        for topic in rights {
            if topic.points.isEmpty { throw fail("rights topic \(topic.id) has no points") }
            if topic.sources.isEmpty { throw fail("rights topic \(topic.id) has no sources") }
            if topic.points.contains(where: { $0.nations.isEmpty }) { throw fail("a point in \(topic.id) names no nation") }
        }
        for guide in guides where guide.steps.isEmpty {
            throw fail("guide \(guide.id) has no steps")
        }
        for route in refuges where route.coverage == nil {
            throw fail("refuge route \(route.id) names no nation")
        }
        for nation in Nation.allCases where refuges(for: nation).isEmpty {
            throw fail("no refuge route for \(nation.rawValue)")
        }
        let ids = rights.map(\.id) + guides.map(\.id) + refuges.map(\.id) + services.map(\.id)
        if Set(ids).count != ids.count { throw fail("duplicate content ids") }
    }
}
