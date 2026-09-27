import SafetyServices
import SwiftUI

/// Whether the alert will say where the person is — shown before they need it, with
/// the one action that changes it.
struct LocationStatusRow: View {

    let authorization: LocationAuthorization
    let onAllow: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.tight) {
            Label {
                Text(LocationCopy.message(for: authorization))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: authorization == .authorizedWhenInUse ? "location.fill" : "location.slash")
            }

            switch LocationCopy.action(for: authorization) {
            case .allow?:
                Button(action: onAllow) {
                    Text(Strings.localized("alert.location.allow"))
                        .frame(minHeight: Design.minimumTapTarget)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("alert.location.allow")
            case .openSettings?:
                Button(action: onOpenSettings) {
                    Text(Strings.localized("alert.location.openSettings"))
                        .frame(minHeight: Design.minimumTapTarget)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("alert.location.openSettings")
            case nil:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}
