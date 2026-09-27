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
                Button(Strings.localized("alert.location.allow"), action: onAllow)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("alert.location.allow")
            case .openSettings?:
                Button(Strings.localized("alert.location.openSettings"), action: onOpenSettings)
                    .buttonStyle(.bordered)
            case nil:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}
