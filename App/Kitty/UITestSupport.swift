#if DEBUG
import Foundation
import SafetyDomain
import SafetyServices

/// Launch switches for the UI tests. Compiled only into debug builds, so none of
/// this exists in anything shipped to the App Store.
///
/// - `-kitty.uiTest`: use a separate Keychain item for trusted contacts, so running
///   the tests never touches a developer's real list.
/// - `-kitty.resetContacts`: start with no trusted contacts.
/// - `-kitty.seedContacts`: start with two contacts on Ofcom drama numbers.
enum UITestSupport {

    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var isActive: Bool { arguments.contains("-kitty.uiTest") }

    static func prepare(_ store: any TrustedContactStoring) {
        guard isActive else { return }
        do {
            if arguments.contains("-kitty.resetContacts") {
                try store.save([])
            }
            if arguments.contains("-kitty.seedContacts") {
                try store.save([
                    TrustedContact(displayName: "Alice", phoneNumber: .drama(1)),
                    TrustedContact(displayName: "Bob", phoneNumber: .drama(2)),
                ])
            }
        } catch {
            // A UI test that silently ran against the wrong data would prove nothing.
            fatalError("UI test setup could not prepare trusted contacts: \(error)")
        }
    }
}
#endif
