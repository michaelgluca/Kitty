import SwiftUI

/// The app shell.
///
/// Four tabs, matching the information architecture the dissertation arrived at,
/// with the alert path first rather than buried behind crime reporting. Standard
/// `TabView` is used deliberately: it picks up Liquid Glass automatically and stays
/// correct as the system design evolves, which a hand-rolled bar would not.
public struct RootView: View {

    public init() {}

    public var body: some View {
        TabView {
            Tab { AlertScreen() } label: {
                Label { Text("tab.alert", bundle: .module) } icon: { Image(systemName: "exclamationmark.bubble.fill") }
            }
            Tab { HelpScreen() } label: {
                Label { Text("tab.help", bundle: .module) } icon: { Image(systemName: "lifepreserver.fill") }
            }
            Tab { PlaceholderScreen(titleKey: "tab.nearby") } label: {
                Label { Text("tab.nearby", bundle: .module) } icon: { Image(systemName: "map.fill") }
            }
            Tab { PlaceholderScreen(titleKey: "tab.settings") } label: {
                Label { Text("tab.settings", bundle: .module) } icon: { Image(systemName: "gearshape.fill") }
            }
        }
    }
}

/// The alert screen scaffold. Wiring lands in M3; the layout contract is set now so
/// the accessibility work is not retrofitted.
struct AlertScreen: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Design.Space.loose) {
                    Spacer(minLength: Design.Space.loose)
                    // Bottom-weighted: the control sits in thumb reach for one-handed
                    // use, not at the top of the screen.
                    PrimaryAlertButton {}
                    SafetyDisclaimer()
                }
                .padding(.horizontal, Design.Space.gutter)
                .padding(.bottom, Design.Space.loose)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(Text("tab.alert", bundle: .module))
        }
    }
}

struct PlaceholderScreen: View {
    let titleKey: LocalizedStringKey

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label { Text(titleKey, bundle: .module) } icon: { Image(systemName: "hammer.fill") }
            } description: {
                Text(verbatim: "Not built yet.")
            }
            .navigationTitle(Text(titleKey, bundle: .module))
        }
    }
}

#Preview("Alert") { RootView() }
#Preview("Alert — AX5") {
    RootView().environment(\.dynamicTypeSize, .accessibility5)
}
