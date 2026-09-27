import Contacts
import ContactsUI
import SafetyServices
import UIKit

/// The system contact picker. It runs out of process and needs no Contacts
/// permission: the app sees only the one contact and number the person picks.
/// There is deliberately no `NSContactsUsageDescription` in Info.plist.
struct SystemContactPicker: ContactPicking {

    func pickContact() async -> ContactPickOutcome {
        // Checked before presenting, not after: `CNContactPickerViewController`
        // delays setting `presentingViewController` until its own presentation
        // animation completes — sometimes by several seconds — so a check made
        // right after `present` cannot tell a refused presentation from a normal,
        // still-animating one. See `Presenter.presentable()`.
        guard let presenter = await Presenter.presentable() else { return .unavailable }

        return await withCheckedContinuation { continuation in
            let picker = CNContactPickerViewController()
            picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
            // Only people who have a number can be chosen...
            picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
            // ...and choosing always opens the card, so the person picks WHICH number.
            picker.predicateForSelectionOfContact = NSPredicate(value: false)
            picker.predicateForSelectionOfProperty = NSPredicate(format: "key == 'phoneNumbers'")
            let delegate = PickerDelegate(continuation)
            picker.delegate = delegate
            presenter.present(picker, animated: true)
        }
    }
}

/// Reports the choice once. Keeps itself alive until then, because the picker holds
/// its delegate weakly. The picker dismisses itself.
private final class PickerDelegate: NSObject, CNContactPickerDelegate {

    private var continuation: CheckedContinuation<ContactPickOutcome, Never>?
    private var keepAlive: PickerDelegate?

    init(_ continuation: CheckedContinuation<ContactPickOutcome, Never>) {
        self.continuation = continuation
        super.init()
        keepAlive = self
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        finish(.cancelled)
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
        // Anything other than a phone number becomes an empty number, which the
        // domain rules refuse with a message — never a silent no-op.
        let number = (contactProperty.value as? CNPhoneNumber)?.stringValue ?? ""
        finish(.picked(PickedContact(displayName: Self.name(of: contactProperty.contact), phoneNumber: number)))
    }

    /// Reads only keys the picker actually returned. Touching a key that was not
    /// fetched raises an Objective-C exception, which Swift cannot catch.
    private static func name(of contact: CNContact) -> String {
        let fullName = CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        if contact.areKeysAvailable([fullName]),
           let name = CNContactFormatter.string(from: contact, style: .fullName),
           !name.isEmpty {
            return name
        }
        if contact.isKeyAvailable(CNContactOrganizationNameKey), !contact.organizationName.isEmpty {
            return contact.organizationName
        }
        // Empty: the domain rules show the number instead.
        return ""
    }

    /// Resumes the continuation exactly once. `CNContactPickerViewController`
    /// itself reports a swipe-down dismissal through `contactPickerDidCancel`, the
    /// same as tapping Cancel, so no separate presentation-controller delegate is
    /// needed here — adding one would only displace the picker's own.
    private func finish(_ outcome: ContactPickOutcome) {
        continuation?.resume(returning: outcome)
        continuation = nil
        keepAlive = nil
    }
}
