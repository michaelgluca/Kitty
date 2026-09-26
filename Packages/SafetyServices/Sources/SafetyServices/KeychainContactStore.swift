import Foundation
import SafetyDomain
import Security

/// Trusted contacts, in the Keychain, on this device only.
///
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` is load-bearing rather than a
/// detail. Without `ThisDeviceOnly` the item is eligible for iCloud Keychain and
/// encrypted-backup migration, which would carry a user's list of who they would
/// turn to onto a device an abuser may control. See ADR-0004.
public struct KeychainContactStore: TrustedContactStoring {

    public enum Failure: Error, Equatable {
        case unexpectedStatus(OSStatus)
        case corruptData
    }

    private static let currentSchemaVersion = ContactEnvelope.currentSchemaVersion

    private let service: String
    private let account = "trusted-contacts"

    public init(service: String) {
        self.service = service
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public func load() throws -> [TrustedContact] {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw Failure.unexpectedStatus(status) }
        guard let data = item as? Data else { throw Failure.corruptData }

        do {
            return try ContactEnvelope.decode(data)
        } catch {
            throw Failure.corruptData
        }
    }

    public func save(_ contacts: [TrustedContact]) throws {
        let data = try ContactEnvelope.encode(contacts)

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }

        guard updateStatus == errSecItemNotFound else {
            throw Failure.unexpectedStatus(updateStatus)
        }

        var insert = baseQuery
        insert.merge(attributes) { _, new in new }
        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw Failure.unexpectedStatus(addStatus) }
    }
}
