import SafetyDomain
import SwiftUI

/// The 999 button. It only reports the tap: the screen owns the confirmation, so the
/// number confirmed and the number dialled are one captured value, as on the Help
/// screen.
struct EmergencyCallButton: View {

    let plan: EmergencyCallPlan
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(EmergencyCallCopy.buttonTitle(for: plan))
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "phone.fill")
            }
            // White on a solid fill, not tinted text on a faint tint: the fill is a
            // fixed red with no dark variant, so tinted text fell to about 3:1 in
            // dark mode. On the alert path, so it clears the critical target.
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: Design.criticalTapTarget)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.alertFill)
        .accessibilityHint(Text("emergency.call.hint", bundle: .module))
        .accessibilityIdentifier("emergency.call")
    }
}
