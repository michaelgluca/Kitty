import SafetyDomain
import SafetyServices
import SwiftUI

/// Places a call, but only after the user confirms.
///
/// Three rules, all deliberate:
/// - **Never dial automatically.** Every call needs an explicit action, and the
///   confirmation states plainly that the app is not making the call for you.
/// - **`tel:`, never `telprompt:`**, so the system's own call confirmation is also
///   shown. `telprompt:` skips it.
/// - **A failed dial is visible.** If the dialler cannot open, the number is shown so
///   it can be dialled by hand, rather than the button appearing to do nothing.
struct CallButton: View {

    let number: PhoneNumber
    let serviceName: String

    @Environment(\.services) private var services
    @State private var confirming = false
    @State private var failed = false

    private var displayNumber: String { number.raw }

    var body: some View {
        Button {
            confirming = true
        } label: {
            Label {
                Text(String(format: Strings.localized("help.call"), displayNumber))
            } icon: {
                Image(systemName: "phone.fill")
            }
            .font(.body.weight(.medium))
            .frame(minHeight: Design.minimumTapTarget, alignment: .leading)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text(String(format: Strings.localized("help.call"), displayNumber)))
        .accessibilityHint(Text(verbatim: serviceName))
        .confirmationDialog(
            Text(String(format: Strings.localized("help.callConfirm.title"), serviceName)),
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button(Strings.localized("help.callConfirm.confirm")) { placeCall() }
            Button(Strings.localized("help.callConfirm.cancel"), role: .cancel) {}
        } message: {
            Text("help.callConfirm.message", bundle: .module)
        }
        .alert(
            Text(String(format: Strings.localized("help.callFailed"), displayNumber)),
            isPresented: $failed
        ) {
            Button(Strings.localized("help.callConfirm.cancel"), role: .cancel) {}
        }
    }

    private func placeCall() {
        let dialler = services.dialler
        Task { @MainActor in
            let opened = await dialler.dial(number)
            if !opened { failed = true }
        }
    }
}

/// Shown when the app does not believe the user is in the UK.
///
/// Informational, not a gate. The alert and trusted-contact features work anywhere,
/// so blocking the app would remove working functionality to make a point about
/// content that is merely not applicable.
struct NonUKNotice: View {
    @Environment(\.regionStance) private var region

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.tight) {
            Label {
                Text("region.notice.title", bundle: .module).font(.headline)
            } icon: {
                Image(systemName: "globe")
            }
            Text("region.notice.body", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Design.Space.tight)
        .accessibilityElement(children: .combine)
    }
}
