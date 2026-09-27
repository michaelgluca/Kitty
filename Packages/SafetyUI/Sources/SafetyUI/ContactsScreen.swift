import SafetyDomain
import SwiftUI

/// Choosing who the alert goes to.
struct ContactsScreen: View {

    @Environment(ContactsModel.self) private var model

    @State private var pendingRemoval: TrustedContact?
    @State private var confirmNewList = false

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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.displayName)
                            Text(contact.phoneNumber.raw)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("contact.\(contact.displayName)")
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

                Section {
                    Button {
                        Task { await model.addFromPicker() }
                    } label: {
                        Label {
                            Text("contacts.add", bundle: .module)
                        } icon: {
                            Image(systemName: "person.crop.circle.badge.plus")
                        }
                    }
                    .accessibilityIdentifier("contacts.add")
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
    }
}
