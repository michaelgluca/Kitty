import SafetyContent
import SwiftUI

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
    let guides: [SafetyGuide]

    @State private var filter = ScreenFilter()

    var body: some View {
        let shown = ContentFilter.guides(guides, matching: filter.criteria(nation: nil))
        List {
            if let summary = FilterCopy.summary(nation: nil, topics: [], query: filter.query) {
                Section { FilterSummary(text: summary) { filter.clear() } }
            }
            if shown.isEmpty {
                Section { NoMatchesView(scope: .features, nation: nil) { filter.clear() } }
            } else {
                SafetyFeaturesList(guides: shown)
            }
        }
        .navigationTitle(Text("learn.features.header", bundle: .module))
        .filterSearchable(text: $filter.query)
        .announcesResultCount(shown.count)
    }
}

struct SafetyFeatureScreen: View {

    let guide: SafetyGuide

    var body: some View {
        List {
            ProseSection(text: guide.summary)

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
                ProseSection(header: "feature.use", text: use)
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
                ProseSection(header: "feature.requirements", text: requirements)
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
