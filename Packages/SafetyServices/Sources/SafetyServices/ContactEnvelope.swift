import Foundation
import SafetyDomain

/// The on-disk shape of the trusted-contact list, separated from the Keychain I/O
/// that carries it.
///
/// Split out so the part that can lose data is testable without a keychain. Silently
/// dropping someone's emergency contacts is the worst outcome this app has, and it
/// would be invisible until the moment they needed them.
enum ContactEnvelope {

    enum Failure: Error, Equatable {
        /// Written by a newer build than this one.
        case futureSchema(Int)
        case malformed
    }

    static let currentSchemaVersion = 1

    struct Payload: Codable, Equatable {
        var schemaVersion: Int
        var contacts: [TrustedContact]
    }

    static func encode(_ contacts: [TrustedContact]) throws -> Data {
        try JSONEncoder().encode(Payload(schemaVersion: currentSchemaVersion, contacts: contacts))
    }

    static func decode(_ data: Data) throws -> [TrustedContact] {
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw Failure.malformed
        }
        return try migrate(payload)
    }

    static func migrate(_ payload: Payload) throws -> [TrustedContact] {
        switch payload.schemaVersion {
        case currentSchemaVersion:
            return payload.contacts
        case let version where version > currentSchemaVersion:
            // A newer build wrote this — the user downgraded, or restored a backup.
            // Refusing is safer than guessing at a shape we do not know, and far
            // safer than returning an empty list, which reads as "no contacts set".
            throw Failure.futureSchema(version)
        default:
            throw Failure.malformed
        }
    }
}
