import SafetyDomain
import SwiftUI

/// Choosing who the alert goes to.
struct ContactsScreen: View {

    @Environment(ContactsModel.self) private var model
    @Environment(AlertModel.self) private var alert

    @State private var pendingRemoval: TrustedContact?
    @State private var confirmNewList = false
    /// Guards the picker button against a double tap starting two pickers at once.
    @State private var isPicking = false

    var body: some View {
        List {
            Section {
                Text("contacts.explainer", bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            switch model.loadState {
            case .unreadable:
                Section {
                    VStack(alignment: .leading, spacing: Design.Space.tight) {
                        Label {
                            Text("contacts.unreadable.title", bundle: .module).font(.headline)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .foregroundStyle(.orange)
                        Text("contacts.unreadable.body", bundle: .module)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(role: .destructive) {
                            confirmNewList = true
                        } label: {
                            Text("contacts.unreadable.startNew", bundle: .module)
                        }
                    }
                }

            case .notLoaded, .loaded:
                Section {
                    if model.contacts.isEmpty {
                        Text("contacts.empty", bundle: .module).foregroundStyle(.secondary)
                    }
                    ForEach(model.contacts) { contact in
                        HStack(spacing: Design.Space.tight) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.displayName)
                                Text(contact.phoneNumber.raw)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("contact.\(contact.displayName)")

                            Spacer(minLength: Design.Space.tight)

                            // A visible, one-tap way to remove a contact, alongside the
                            // swipe action below — not everyone discovers swipe-to-delete,
                            // and US-2 asks for a visible tap plus confirmation.
                            if model.canEdit {
                                Button {
                                    pendingRemoval = contact
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                        .frame(minWidth: Design.minimumTapTarget, minHeight: Design.minimumTapTarget)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(
                                    Text(String(format: Strings.localized("contacts.remove.row"), contact.displayName))
                                )
                                .accessibilityIdentifier("contact.remove.\(contact.displayName)")
                            }
                        }
                        // Not role: .destructive — that animates the row away before
                        // the person has confirmed, and it springs back on Cancel.
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button { pendingRemoval = contact } label: {
                                Text("contacts.remove.action", bundle: .module)
                            }
                            .tint(.red)
                        }
                    }
                    .onMove { model.move(fromOffsets: $0, toOffset: $1) }
                }

                if model.canEdit {
                    Section {
                        Button {
                            guard !isPicking else { return }
                            isPicking = true
                            Task {
                                await model.addFromPicker()
                                isPicking = false
                            }
                        } label: {
                            Label {
                                Text("contacts.add", bundle: .module)
                            } icon: {
                                Image(systemName: "person.crop.circle.badge.plus")
                            }
                        }
                        .disabled(isPicking)
                        .accessibilityIdentifier("contacts.add")
                    }
                }
            }
        }
        .navigationTitle(Text("contacts.title", bundle: .module))
        .toolbar {
            #if os(iOS)
            if model.contacts.count > 1 { EditButton() }
            #endif
        }
        .confirmationDialog(
            Text(pendingRemoval.map { String(format: Strings.localized("contacts.remove.title"), $0.displayName) } ?? ""),
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { contact in
            Button(Strings.localized("contacts.remove.confirm"), role: .destructive) { model.remove(id: contact.id) }
            Button(Strings.localized("help.callConfirm.cancel"), role: .cancel) {}
        } message: { _ in
            Text("contacts.remove.message", bundle: .module)
        }
        .confirmationDialog(
            Text("contacts.unreadable.confirmTitle", bundle: .module),
            isPresented: $confirmNewList,
            titleVisibility: .visible
        ) {
            Button(Strings.localized("contacts.unreadable.startNew"), role: .destructive) { model.startNewList() }
            Button(Strings.localized("help.callConfirm.cancel"), role: .cancel) {}
        } message: {
            Text("contacts.unreadable.confirmMessage", bundle: .module)
        }
        .alert(
            Text(model.problem?.message ?? ""),
            isPresented: Binding(get: { model.problem != nil }, set: { if !$0 { model.problem = nil } })
        ) {
            Button(Strings.localized("help.ok"), role: .cancel) {}
        }
        .onChange(of: model.contacts) { _, _ in clearStaleAlertResult() }
        .onChange(of: model.loadState) { _, _ in clearStaleAlertResult() }
    }

    /// A change made here can leave the Alert tab showing a result that is no longer
    /// true — "no contacts" after one was just added, or "unreadable" after starting a
    /// new list — so it is cleared rather than left to mislead on return.
    private func clearStaleAlertResult() {
        switch alert.phase {
        case .finished(.needsContacts), .finished(.contactsUnreadable):
            alert.reset()
        default:
            break
        }
    }
}
