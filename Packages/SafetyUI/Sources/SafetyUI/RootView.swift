import SafetyContent
import SafetyServices
import SwiftUI

/// The app shell.
///
/// Four tabs, matching the information architecture the dissertation arrived at,
/// with the alert path first rather than buried behind crime reporting. Standard
/// `TabView` is used deliberately: it picks up Liquid Glass automatically and stays
/// correct as the system design evolves, which a hand-rolled bar would not.
///
/// Owns the three models the tabs share, so the list edited on one tab is the list
/// the alert uses on another.
public struct RootView: View {

    private let services: Services
    private let pack: ContentPack?

    @State private var contacts: ContactsModel
    @State private var alert: AlertModel
    @State private var testMode = TestModeSession()

    @Environment(\.scenePhase) private var scenePhase

    public init(services: Services = .unavailable, pack: ContentPack? = try? ContentLoader.loadUK()) {
        self.services = services
        self.pack = pack
        // Loaded here, before the first frame, so an alert raised immediately after
        // launch sees the saved list rather than an empty one.
        let contacts = ContactsModel(store: services.contacts, picker: services.picker)
        contacts.load()
        _contacts = State(initialValue: contacts)
        _alert = State(initialValue: AlertModel(services: services, strings: Strings.alert))
    }

    public var body: some View {
        TabView {
            Tab { AlertScreen(emergencyNumber: pack?.emergencyNumber) } label: {
                Label { Text("tab.alert", bundle: .module) } icon: { Image(systemName: "exclamationmark.bubble.fill") }
            }
            Tab { HelpScreen(pack: pack) } label: {
                Label { Text("tab.help", bundle: .module) } icon: { Image(systemName: "lifepreserver.fill") }
            }
            Tab { PlaceholderScreen(titleKey: "tab.nearby") } label: {
                Label { Text("tab.nearby", bundle: .module) } icon: { Image(systemName: "map.fill") }
            }
            Tab { SettingsScreen() } label: {
                Label { Text("tab.settings", bundle: .module) } icon: { Image(systemName: "gearshape.fill") }
            }
        }
        .environment(\.services, services)
        .environment(contacts)
        .environment(alert)
        .environment(testMode)
        .onChange(of: scenePhase) { _, phase in testMode.scenePhaseChanged(to: phase) }
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
