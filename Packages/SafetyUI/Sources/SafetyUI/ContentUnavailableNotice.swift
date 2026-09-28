import SwiftUI

/// Said instead of an empty list when the bundled content pack could not be loaded.
///
/// The pack ships inside the app, so this should be unreachable — but it is shown
/// rather than swallowed: an empty list would read as "there is nothing here" rather
/// than "something is wrong". The title and body are parameters, not fixed keys, so
/// a screen keeps its own catalogue wording instead of sharing one generic line.
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
