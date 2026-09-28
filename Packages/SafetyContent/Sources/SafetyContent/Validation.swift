import Foundation

public extension ContentPack {

    /// Checks the decoder cannot express. A failure is a content bug caught at load
    /// time and in CI, rather than a blank row, or a rule shown to the wrong nation.
    ///
    /// Points, coverage and topic tags are checked before per-nation completeness, so a defect is
    /// reported by name rather than as a nation that merely looks empty because of it.
    ///
    /// Ids must be unique across rights, guides, refuges and services. A refuge route is
    /// often the same organisation as a helpline in `services`, so refuge ids carry a
    /// `refuge-` prefix (`refuge-national-domestic-abuse-helpline`). Reusing the service
    /// id would fail this check, and with it `ContentLoader.loadUK()` and every tab.
    func validate() throws {
        func fail(_ reason: String) -> ContentLoader.Failure { .malformed(reason) }

        // Topic tags decide what a person sees under a chip, so an untagged item would
        // vanish the moment any chip is chosen. A repeated tag would pass the pinned
        // test's `Set` comparison unnoticed, and is never intentional. `general` means
        // "for anyone in distress", which only a service can be.
        func checkTags(_ tags: [Topic], of item: String, allowsGeneral: Bool) throws {
            if tags.isEmpty { throw fail("\(item) has no topics") }
            if Set(tags).count != tags.count { throw fail("\(item) has a duplicate topic") }
            if !allowsGeneral, tags.contains(.general) { throw fail("\(item) is tagged general") }
        }

        for topic in rights {
            if topic.points.isEmpty { throw fail("rights topic \(topic.id) has no points") }
            if topic.sources.isEmpty { throw fail("rights topic \(topic.id) has no sources") }
            if topic.points.contains(where: { $0.nations.isEmpty }) { throw fail("a point in \(topic.id) names no nation") }
            try checkTags(topic.topics, of: "rights topic \(topic.id)", allowsGeneral: false)
        }
        for guide in guides where guide.steps.isEmpty {
            throw fail("guide \(guide.id) has no steps")
        }
        // Refuge routes are listed by nation alone.
        for route in refuges {
            if route.coverage == nil { throw fail("refuge route \(route.id) names no nation") }
            if !route.topics.isEmpty { throw fail("refuge route \(route.id) has topics; refuges are listed by nation only") }
        }
        for service in services {
            try checkTags(service.topics, of: "service \(service.id)", allowsGeneral: true)
        }
        for route in reporting {
            try checkTags(route.topics, of: "reporting route \(route.id)", allowsGeneral: false)
        }
        for nation in Nation.allCases where refuges(for: nation).isEmpty {
            throw fail("no refuge route for \(nation.rawValue)")
        }
        let ids = rights.map(\.id) + guides.map(\.id) + refuges.map(\.id) + services.map(\.id)
        if Set(ids).count != ids.count { throw fail("duplicate content ids") }
    }
}
