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
            LearnContent(pack: $0, criteria: filter.criteria(nation: nationPreference.nation), topicTerms: TopicCopy.searchTerms)
        }
    }

    var body: some View {
        let content = self.content
        NavigationStack {
            List {
                if let content {
                    FilterSection(preference: nationPreference, detected: nearby.detectedNation, filter: filter)

                    Section {
                        if content.rights.isEmpty {
                            // Said here even while iPhone features are still listed below:
                            // they ignore topics, so without this a filter could leave a
                            // screen of features and no word that no right matched.
                            NoMatchesView(scope: content.hasNoMatches ? .everything : .rights, nation: nationPreference.nation) { filter.clear() }
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

/// A title with its summary beneath, for a rights topic or an iPhone feature in a list.
struct TopicLabel: View {
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

/// A section of running text, under an optional header. Wraps rather than truncates at
/// every text size.
struct ProseSection: View {
    var header: LocalizedStringKey?
    let text: String

    var body: some View {
        if let header {
            Section { prose } header: { Text(header, bundle: .module) }
        } else {
            Section { prose }
        }
    }

    private var prose: some View {
        Text(text).fixedSize(horizontal: false, vertical: true)
    }
}
