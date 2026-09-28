import SafetyContent
import SwiftUI

/// The filter controls at the head of the filterable part of Get help and Learn. It holds
/// where the person is, the topic chips, and, whenever anything is narrowed, a line
/// saying so with Clear.
///
/// A List section rather than an overlay or a toolbar, so it scrolls with the content,
/// never covers it, and is reached by VoiceOver before the results. On Get help it sits
/// below the 999 routes, which are never filtered.
struct FilterSection: View {

    let preference: NationPreference
    /// Where Nearby found the person, if it has. Offered, never applied.
    let detected: Nation?
    let filter: ScreenFilter

    var body: some View {
        Section {
            NationMenu(preference: preference, detected: detected)
            if let problem = preference.problem {
                NationProblemRow(text: FilterCopy.problem(problem))
            }
            // The person may have moved since choosing. Shown as a row, not only inside the
            // menu, so it is seen; never applied without a tap.
            if let detected, preference.isStale(detected: detected) {
                NationOfferButton(nation: detected) { preference.choose(detected) }
            }
            TopicChips(selected: filter.topics) { filter.toggle($0) }
            if let summary = FilterCopy.summary(nation: preference.nation, topics: filter.topics, query: filter.query) {
                FilterSummary(text: summary, onClear: filter.canClear ? { filter.clear() } : nil)
            }
        }
    }
}

/// Where the person is: All of the UK, or one nation. The detected nation, when there is
/// one and it is not already chosen, is the first item.
struct NationMenu: View {

    let preference: NationPreference
    let detected: Nation?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        @Bindable var preference = preference
        Menu {
            if let offer = preference.offer(detected: detected) {
                Button { preference.choose(offer) } label: { Text(FilterCopy.offer(offer)) }
            }
            Picker(selection: $preference.selection) {
                Text(FilterCopy.allOfTheUK).tag(Nation?.none)
                ForEach(Nation.allCases) { nation in
                    Text(NationCopy.name(nation)).tag(Optional(nation))
                }
            } label: {
                Text("filter.nation.title", bundle: .module)
            }
            .pickerStyle(.inline)
        } label: {
            label
        }
        .accessibilityIdentifier("filter.nation")
    }

    /// Side by side at normal sizes, and stacked at accessibility sizes, like `ServiceRow`.
    private var label: some View {
        (Design.adaptiveStack(at: typeSize)) {
            Label {
                Text("filter.nation.title", bundle: .module)
            } icon: {
                Image(systemName: "mappin.and.ellipse")
            }
            .foregroundStyle(.primary)
            if !typeSize.isAccessibilitySize { Spacer(minLength: Design.Space.tight) }
            Text(FilterCopy.nationName(preference.nation))
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: Design.minimumTapTarget)
        .contentShape(Rectangle())
        // Otherwise VoiceOver reads "Where you are" and the chosen nation as two
        // separate swipes inside what is really one control (the menu's label).
        .accessibilityElement(children: .combine)
    }
}

/// "Use England — detected from your location", as its own row.
struct NationOfferButton: View {

    let nation: Nation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(FilterCopy.offer(nation)).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "location.fill")
            }
            .frame(minHeight: Design.minimumTapTarget)
        }
        .accessibilityIdentifier("filter.offer")
    }
}

/// The saved nation could not be read or saved. Never silent.
struct NationProblemRow: View {

    let text: String

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
        .font(.footnote)
        // Otherwise VoiceOver reads the icon and the problem as two separate swipes
        // inside what is really one line, the way FilterSummary's label does.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("filter.nation.problem")
    }
}

/// The eight topic chips, wrapping onto as many rows as they need.
struct TopicChips: View {

    let selected: Set<Topic>
    let toggle: (Topic) -> Void

    var body: some View {
        ChipFlowLayout(spacing: Design.Space.tight) {
            ForEach(TopicCopy.chips) { chip in
                TopicChip(name: chip.name, isSelected: selected.contains(chip.topic)) { toggle(chip.topic) }
                    .accessibilityIdentifier("filter.topic.\(chip.topic.rawValue)")
            }
        }
        .padding(.vertical, Design.Space.tight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("filter.topics.label", bundle: .module))
    }
}

/// A toggle button. VoiceOver reads its selected state; sighted people see a checkmark as
/// well as the fill, so selection never depends on colour alone.
struct TopicChip: View {

    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Design.Space.tight / 2) {
                if isSelected {
                    Image(systemName: "checkmark").accessibilityHidden(true)
                }
                Text(name)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Design.Space.base)
            .padding(.vertical, Design.Space.tight)
            .frame(minWidth: Design.minimumTapTarget, minHeight: Design.minimumTapTarget)
        }
        // A non-default style, so each chip takes its own taps inside a List row rather
        // than the whole row acting as one button.
        .buttonStyle(ChipStyle(isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ChipStyle: ButtonStyle {

    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Design.Radius.control, style: .continuous)
        return configuration.label
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? AnyShapeStyle(.background) : AnyShapeStyle(.primary))
            .background { shape.fill(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.clear)) }
            .overlay { shape.strokeBorder(.tint, lineWidth: 1) }
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// "Showing Scotland · Stalking & harassment", with Clear when there are topics or a
/// search to clear. Clear keeps the nation.
struct FilterSummary: View {

    let text: String
    let onClear: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        (Design.adaptiveStack(at: typeSize)) {
            Label {
                Text(text).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .font(.subheadline.weight(.medium))
            // Otherwise VoiceOver reads the icon and the summary as two separate
            // swipes inside what is really one line, the way NationMenu's label does.
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("filter.summary")
            if !typeSize.isAccessibilitySize { Spacer(minLength: Design.Space.tight) }
            if let onClear {
                Button(action: onClear) {
                    Text("filter.clear", bundle: .module)
                        .frame(minWidth: Design.minimumTapTarget, minHeight: Design.minimumTapTarget)
                }
                .buttonStyle(.borderless)
                .accessibilityHint(Text("filter.clear.hint", bundle: .module))
                .accessibilityIdentifier("filter.clear")
            }
        }
    }
}

/// Said instead of an empty list, with a way back.
struct NoMatchesView: View {

    let scope: NoMatchesScope
    /// The nation chosen, if any: it may be why nothing matches.
    let nation: Nation?
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.tight) {
            Label {
                Text(FilterCopy.noMatchesTitle(scope)).font(.headline)
            } icon: {
                Image(systemName: "magnifyingglass")
            }
            Text(FilterCopy.noMatchesBody(scope, nation: nation))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onClear) {
                Text("filter.clearFilters", bundle: .module)
                    .frame(minHeight: Design.minimumTapTarget)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("filter.noMatches.clear")
        }
        .padding(.vertical, Design.Space.tight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("filter.noMatches")
    }
}

extension View {

    /// The standard iOS search field, always visible rather than hidden until the list is
    /// pulled down, so nobody has to know the gesture. It searches only the bundled pack,
    /// so it works offline.
    func filterSearchable(text: Binding<String>) -> some View {
        #if os(iOS)
        searchable(text: text, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("filter.search.prompt", bundle: .module))
        #else
        searchable(text: text, prompt: Text("filter.search.prompt", bundle: .module))
        #endif
    }

    /// Tells VoiceOver how many results there are each time the number changes, so a
    /// person who cannot see the list knows what a chip or a word did.
    func announcesResultCount(_ count: Int) -> some View {
        modifier(ResultCountAnnouncement(count: count))
    }
}

/// Announces only while its screen is on screen. The nation is shared, so choosing one
/// changes the count on every tab, and tabs the person has visited stay alive: without
/// this, Learn could announce its count over Get help's, or a screen pushed on top
/// could be talked over by the one beneath it.
struct ResultCountAnnouncement: ViewModifier {

    let count: Int

    @State private var isOnScreen = false

    func body(content: Content) -> some View {
        content
            .onAppear { isOnScreen = true }
            .onDisappear { isOnScreen = false }
            .onChange(of: count) { _, newCount in
                if let announcement = Self.announcement(for: newCount, isOnScreen: isOnScreen) {
                    AccessibilityNotification.Announcement(announcement).post()
                }
            }
    }

    static func announcement(for count: Int, isOnScreen: Bool) -> String? {
        isOnScreen ? FilterCopy.resultCount(count) : nil
    }
}
