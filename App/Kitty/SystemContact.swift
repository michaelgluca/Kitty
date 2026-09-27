import SafetyDomain
import SafetyServices
import UIKit

/// Opens the system dialler.
///
/// Deliberately thin. The URL — `tel:`, never `telprompt:` — is built and tested in
/// SafetyDomain; this only hands it to the system. There is no `canOpenURL` probe
/// first: that API is deprecated in iOS 27, and the right pattern is to attempt the
/// action and report honestly when it fails, which the caller does.
struct SystemDialler: Dialling {
    @MainActor
    func dial(_ number: PhoneNumber) async -> Bool {
        guard let url = number.callURL else { return false }
        return await UIApplication.shared.open(url)
    }
}

/// Opens Messages to a number, with nothing pre-filled.
struct SystemTextOpener: TextOpening {
    @MainActor
    func openText(to number: PhoneNumber) async -> Bool {
        guard let url = number.textURL else { return false }
        return await UIApplication.shared.open(url)
    }
}

struct SystemSettingsOpener: SettingsOpening {
    @MainActor func openAppSettings() async -> Bool {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return false }
        return await UIApplication.shared.open(url)
    }
}
