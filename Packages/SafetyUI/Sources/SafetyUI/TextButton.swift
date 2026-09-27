import SafetyDomain
import SwiftUI

/// A text button. It only reports the tap; it presents nothing itself.
///
/// Deliberately a different type from `CallButton`, sharing no code path with it. A
/// text-only destination rendered as a call is the failure this app is most careful
/// about: for someone who cannot speak, it places a voice call.
struct TextButton: View {

    let number: PhoneNumber
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(String(format: Strings.localized("help.text"), number.raw))
            } icon: {
                Image(systemName: "message.fill")
            }
            .font(.body.weight(.medium))
            .frame(minHeight: Design.minimumTapTarget, alignment: .leading)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text(String(format: Strings.localized("help.text"), number.raw)))
    }
}
