import SwiftUI

struct SettingsScreen: View {

    @Environment(TestModeSession.self) private var testMode

    var body: some View {
        @Bindable var testMode = testMode
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $testMode.isOn) {
                        Text("settings.testMode.toggle", bundle: .module)
                    }
                    .accessibilityIdentifier("settings.testMode")
                } footer: {
                    Text("settings.testMode.footer", bundle: .module)
                }
            }
            .navigationTitle(Text("tab.settings", bundle: .module))
        }
    }
}
