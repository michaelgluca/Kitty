import SafetyContent
import SwiftUI

/// The Learn tab: your rights, and the iPhone's own safety features. Entirely offline.
///
/// Rights can be narrowed by nation, topic and search; iPhone features by search only,
/// because they are the same everywhere (ADR-0014).
///
/// `RootView` must inject the `NationPreference` and `NearbyModel` this screen reads
/// from the Environment.
struct LearnScreen: View {

    @Environment(NationPreference.self) private var nationPreference
    @Environment(NearbyModel.self) private var nearby

    let pack: ContentPack?

    @State private var filter = ScreenFilter()

    /// What the filter leaves. `nil` only without a pack.
    private var content: LearnContent? {
        pack.map {
            LearnContent(pack: $0, criteria: filter.criteria(nation: nationPreference.nation), topicNames: TopicCopy.names)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let content {
                    FilterSection(preference: nationPreference, detected: nearby.detectedNation, filter: filter)

                    Section {
                        if content.rights.isEmpty {
                            // Said here even while iPhone features are still listed below:
                            // they ignore topics, so without this a filter could leave a
                            // screen of features and no word that no right matched.
                            NoMatchesView(scope: content.hasNoMatches ? .everything : .rights) { filter.clear() }
                        } else {
                            ForEach(content.rights) { match in
                                NavigationLink {
                                    RightsTopicScreen(topic: match.topic)
                                } label: {
                                    TopicLabel(title: match.topic.title, summary: match.topic.summary)
                                }
                                .accessibilityIdentifier("learn.rights.\(match.topic.id)")
                            }
                        }
                    } header: {
                        Text("learn.rights.header", bundle: .module)
                    } footer: {
                        Text("learn.rights.footer", bundle: .module)
                    }

                    if !content.guides.isEmpty {
                        SafetyFeaturesList(guides: content.guides)
                    }
                } else {
                    ContentUnavailableNotice(titleKey: "learn.unavailable.title", bodyKey: "learn.unavailable.body")
                }
            }
            .navigationTitle(Text("tab.learn", bundle: .module))
            .filterSearchable(text: $filter.query)
            .announcesResultCount(content?.resultCount ?? 0)
        }
    }
}

/// The iPhone features, as one List section. Used on the Learn tab and behind the
/// Help tab's link, so the same checked content is never kept in two places.
struct SafetyFeaturesList: View {

    let guides: [SafetyGuide]

    var body: some View {
        Section {
            ForEach(guides) { guide in
                NavigationLink {
                    SafetyFeatureScreen(guide: guide)
                } label: {
                    TopicLabel(title: guide.title, summary: guide.summary)
                }
                .accessibilityIdentifier("learn.feature.\(guide.id)")
            }
        } header: {
            Text("learn.features.header", bundle: .module)
        } footer: {
            // Not "help.guides.footer": that line says Kitty G only links to Apple's
            // own instructions, which stopped being true once the steps are shown
            // here rather than left behind a link.
            Text("learn.features.footer", bundle: .module)
        }
    }
}

/// The destination of the Help tab's "iPhone safety features" link. Search only: the
/// features are the same in every nation and for every situation.
struct SafetyFeaturesScreen: View {
    let pack: ContentPack?

    @State private var filter = ScreenFilter()

    var body: some View {
        let guides = pack.map { ContentFilter.guides($0.guides, matching: filter.criteria(nation: nil)) } ?? []
        List {
            if pack != nil {
                if let summary = FilterCopy.summary(nation: nil, topics: [], query: filter.query) {
                    Section { FilterSummary(text: summary) { filter.clear() } }
                }
                if guides.isEmpty {
                    Section { NoMatchesView(scope: .everything) { filter.clear() } }
                } else {
                    SafetyFeaturesList(guides: guides)
                }
            }
        }
        .navigationTitle(Text("learn.features.header", bundle: .module))
        .filterSearchable(text: $filter.query)
        .announcesResultCount(guides.count)
    }
}

private struct TopicLabel: View {
    let title: String
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

/// One rights topic: the law in plain English, then who has to look further and how.
///
/// Read here rather than passed in, so the split between "here" and "elsewhere"
/// follows the nation even when it is changed on another tab while this screen is
/// open. `RootView` must inject the `NationPreference` this screen reads from the
/// Environment.
struct RightsTopicScreen: View {

    let topic: RightsTopic

    @Environment(NationPreference.self) private var nationPreference
    @State private var showsElsewhere = false

    var body: some View {
        let points = Self.points(of: topic, for: nationPreference.nation)
        List {
            Section {
                Text(topic.summary).fixedSize(horizontal: false, vertical: true)
            }

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
                    // be helping a friend in another nation.
                    DisclosureGroup(isExpanded: $showsElsewhere) {
                        ForEach(Array(points.elsewhere.enumerated()), id: \.offset) { _, point in
                            RightsPointRow(point: point)
                        }
                    } label: {
                        Text("rights.elsewhere", bundle: .module)
                    }
                    .accessibilityIdentifier("rights.elsewhere")
                }
            }

            Section {
                Text(topic.whatYouCanDo).fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("rights.whatYouCanDo", bundle: .module)
            }

            if let differences = topic.nationDifferences {
                Section {
                    Text(differences).fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text("rights.differences", bundle: .module)
                }
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
    static func points(of topic: RightsTopic, for nation: Nation?) -> (here: [RightsPoint], elsewhere: [RightsPoint]) {
        let match = ContentFilter.split(topic, for: nation)
        return match.here.isEmpty ? (topic.points, []) : (match.here, match.elsewhere)
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

struct SafetyFeatureScreen: View {

    let guide: SafetyGuide

    var body: some View {
        List {
            Section {
                Text(guide.summary).fixedSize(horizontal: false, vertical: true)
            }

            Section {
                ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
                    Label {
                        Text(step).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Text(verbatim: "\(index + 1)")
                            .font(.headline)
                            .monospacedDigit()
                    }
                    // A bare Label with the step number as its icon is not read out
                    // by VoiceOver on its own, so the step number is spelled out
                    // explicitly here instead of relying on the icon.
                    .accessibilityLabel(Text(String(format: Strings.localized("feature.step"), index + 1, step)))
                }
            } header: {
                Text("feature.setUp", bundle: .module)
            }

            if let use = guide.howToUse {
                Section {
                    Text(use).fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text("feature.use", bundle: .module)
                }
            }

            if let caution = guide.caution {
                Section {
                    // Only the icon is orange. Orange body text is roughly 2:1
                    // contrast, so the caution itself stays the primary text colour.
                    Label {
                        Text(caution)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("feature.caution", bundle: .module)
                }
            }

            if let requirements = guide.requirements {
                Section {
                    Text(requirements).fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text("feature.requirements", bundle: .module)
                }
            }

            if let url = URL(string: guide.url) {
                Section {
                    Link(destination: url) {
                        Text("help.openInstructions", bundle: .module)
                    }
                }
            }
        }
        .navigationTitle(guide.title)
    }
}
