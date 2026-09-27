import SafetyDomain
import SwiftUI

/// A call button. It only reports the tap; it presents nothing itself.
///
/// It used to own its confirmation dialog, one per row. Found on device: with a
/// dialog attached to every row of a List, SwiftUI presented stale state — tapping
/// The Rowan's button produced "Call Rape Crisis Scotland Helpline?", anchored to
/// the wrong row, and each dialog belonged to the PREVIOUS tap. Confirming would
/// have called the wrong service. Presentation now lives in one place, in the
/// screen, driven by data captured at the moment of the tap. See `HelpScreen`.
struct CallButton: View {

    let number: PhoneNumber
    let serviceName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(String(format: Strings.localized("help.call"), number.raw))
            } icon: {
                Image(systemName: "phone.fill")
            }
            .font(.body.weight(.medium))
            .frame(minHeight: Design.minimumTapTarget, alignment: .leading)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text(String(format: Strings.localized("help.call"), number.raw)))
        .accessibilityHint(Text(verbatim: serviceName))
    }
}

/// Shown when the app does not believe the user is in the UK.
///
/// Informational, not a gate. The alert and trusted-contact features work anywhere,
/// so blocking the app would remove working functionality to make a point about
/// content that is merely not applicable.
struct NonUKNotice: View {
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
