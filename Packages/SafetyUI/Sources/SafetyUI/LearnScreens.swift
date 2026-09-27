import SafetyContent
import SwiftUI

/// The Learn tab: your rights, and the iPhone's own safety features. Entirely offline.
struct LearnScreen: View {

    let pack: ContentPack?

    var body: some View {
        NavigationStack {
            List {
                if let pack {
                    Section {
                        ForEach(pack.rights) { topic in
                            NavigationLink {
                                RightsTopicScreen(topic: topic)
                            } label: {
                                TopicLabel(title: topic.title, summary: topic.summary)
                            }
                            .accessibilityIdentifier("learn.rights.\(topic.id)")
                        }
                    } header: {
                        Text("learn.rights.header", bundle: .module)
                    } footer: {
                        Text("learn.rights.footer", bundle: .module)
                    }

                    SafetyFeaturesList(guides: pack.guides)
                } else {
                    ContentUnavailableView {
                        Label { Text("learn.unavailable.title", bundle: .module) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                    } description: {
                        Text("learn.unavailable.body", bundle: .module)
                    }
                }
            }
            .navigationTitle(Text("tab.learn", bundle: .module))
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

/// The destination of the Help tab's "iPhone safety features" link.
struct SafetyFeaturesScreen: View {
    let pack: ContentPack?

    var body: some View {
        List {
            if let pack { SafetyFeaturesList(guides: pack.guides) }
        }
        .navigationTitle(Text("learn.features.header", bundle: .module))
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

struct RightsTopicScreen: View {

    let topic: RightsTopic

    var body: some View {
        List {
            Section {
                Text(topic.summary).fixedSize(horizontal: false, vertical: true)
            }

            Section {
                ForEach(Array(topic.points.enumerated()), id: \.offset) { _, point in
                    VStack(alignment: .leading, spacing: Design.Space.tight) {
                        Text(point.text).fixedSize(horizontal: false, vertical: true)
                        // Always shown, never implied: the law differs by nation.
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
            } header: {
                Text("rights.whatTheLawSays", bundle: .module)
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
