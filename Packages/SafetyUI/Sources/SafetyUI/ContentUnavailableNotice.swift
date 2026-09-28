import SwiftUI

/// Said instead of an empty list when the bundled content pack could not be loaded.
///
/// The pack ships inside the app, so this should be unreachable — but it is shown
/// rather than swallowed: an empty list would read as "there is nothing here" rather
/// than "something is wrong". Shared by `HelpScreen` and `LearnScreens`, each keeping
/// its own catalogue keys (`RefugesScreen` reuses Learn's, as it does today).
struct ContentUnavailableNotice: View {

    let titleKey: LocalizedStringKey
    let bodyKey: LocalizedStringKey

    var body: some View {
        ContentUnavailableView {
            Label { Text(titleKey, bundle: .module) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
        } description: {
            Text(bodyKey, bundle: .module)
        }
    }
}
