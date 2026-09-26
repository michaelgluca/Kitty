import Foundation

/// Someone the user chose to alert.
///
/// Held on device only, in the Keychain, never synced. See ADR-0004.
public struct TrustedContact: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var displayName: String
    public var phoneNumber: PhoneNumber

    public init(id: UUID = UUID(), displayName: String, phoneNumber: PhoneNumber) {
        self.id = id
        self.displayName = displayName
        self.phoneNumber = phoneNumber
    }
}
