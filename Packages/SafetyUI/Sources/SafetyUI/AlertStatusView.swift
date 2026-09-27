import SafetyDomain
import SwiftUI

/// What the alert is doing, or what happened. Always visible after a tap: this is
/// where "never fail silently" is kept on the Alert tab.
struct AlertStatusView: View {

    let phase: AlertModel.Phase
    let recipients: [AlertRecipient]
    let onCall: (AlertRecipient) -> Void
    let onAddContacts: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        switch phase {
        case .idle:
            EmptyView()

        case .locating, .composing:
            HStack(spacing: Design.Space.tight) {
                ProgressView()
                Text(AlertCopy.progress(phase) ?? "")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("alert.progress")

        case let .finished(outcome):
            VStack(alignment: .leading, spacing: Design.Space.base) {
                Text(AlertCopy.message(for: outcome))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("alert.result")

                if AlertCopy.offersCalls(outcome) {
                    ForEach(recipients, id: \.number) { recipient in
                        Button { onCall(recipient) } label: {
                            Label {
                                Text(AlertCopy.callButton(for: recipient))
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "phone.fill")
                            }
                            .frame(maxWidth: .infinity, minHeight: Design.minimumTapTarget, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if outcome == .needsContacts || outcome == .contactsUnreadable {
                    Button(Strings.localized("alert.contacts.add"), action: onAddContacts)
                        .buttonStyle(.borderedProminent)
                }

                Button(Strings.localized("alert.result.dismiss"), action: onDismiss)
            }
            .padding(Design.Space.base)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Design.Radius.card, style: .continuous).fill(.quaternary))
        }
    }
}
