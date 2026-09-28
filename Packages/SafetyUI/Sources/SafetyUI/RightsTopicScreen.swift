import SafetyContent
import SwiftUI

/// One rights topic: the law in plain English, then who has to look further and how.
///
/// `NationPreference` is read here rather than passed in, so the split between "here"
/// and "elsewhere" follows the nation even when it changes on another tab while this
/// screen is open. `RootView` must inject it into the Environment.
struct RightsTopicScreen: View {

    let topic: RightsTopic

    @Environment(NationPreference.self) private var nationPreference

    var body: some View {
        let points = Self.points(of: topic, for: nationPreference.nation)
        List {
            ProseSection(text: topic.summary)

            Section {
                ForEach(Array(points.here.enumerated()), id: \.offset) { _, point in
                    RightsPointRow(point: point)
                }
            } header: {
                Text("rights.whatTheLawSays", bundle: .module)
            }

            if !points.elsewhere.isEmpty {
                Section {
                    // Hidden until opened, never removed: someone may be about to move, or
                    // be helping a friend in another nation. `DisclosureGroup` starts
                    // collapsed and manages its own expansion state, so none is kept here.
                    DisclosureGroup {
                        ForEach(Array(points.elsewhere.enumerated()), id: \.offset) { _, point in
                            RightsPointRow(point: point)
                        }
                    } label: {
                        Text("rights.elsewhere", bundle: .module)
                    }
                    .accessibilityIdentifier("rights.elsewhere")
                }
            }

            ProseSection(header: "rights.whatYouCanDo", text: topic.whatYouCanDo)

            if let differences = topic.nationDifferences {
                ProseSection(header: "rights.differences", text: differences)
            }

            Section {
                // No cap on how many sources a topic lists — this must stay readable
                // and scrollable even at the largest accessibility text size, which a
                // List row already handles.
                ForEach(topic.sources, id: \.url) { source in
                    if let url = URL(string: source.url) {
                        // The system browser, not an in-app web view (age rating).
                        Link(destination: url) {
                            Text(source.title).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } header: {
                Text("rights.sources", bundle: .module)
            } footer: {
                // General information, not legal advice — stated again here, at the
                // end of the topic, not only in the list's footer above it.
                Text("rights.disclaimer", bundle: .module)
            }
        }
        .navigationTitle(topic.title)
    }
}

extension RightsTopicScreen {

    /// The points to show first, and those collapsed under "Different elsewhere in the
    /// UK". If the chosen nation has no point of its own here, every point is shown
    /// rather than none. Learn never lists such a topic, but the nation can change on
    /// another tab while this screen is open.
    static func points(of topic: RightsTopic, for nation: Nation?) -> RightsMatch {
        let match = ContentFilter.split(topic, for: nation)
        return match.here.isEmpty ? ContentFilter.split(topic, for: nil) : match
    }
}

/// One point of law, with the nations it applies in. Always shown, never implied: the law
/// differs by nation.
private struct RightsPointRow: View {

    let point: RightsPoint

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.tight) {
            Text(point.text).fixedSize(horizontal: false, vertical: true)
            Label {
                Text(NationCopy.appliesIn(point.nations))
            } icon: {
                Image(systemName: "mappin.and.ellipse")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
