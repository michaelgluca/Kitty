import Foundation
import SafetyDomain
import Testing

@testable import SafetyServices

// The Keychain I/O itself is deliberately not tested here: it needs a real keychain,
// which a headless CI runner does not reliably have, and a flaky test on a
// safety-critical path is worse than none. What IS tested is the part that can lose
// data — encoding, decoding and version migration.

@Suite("Contact envelope")
struct ContactEnvelopeTests {

    // A stored constant, not a computed property: TrustedContact mints a fresh UUID
    // per instance, so a computed `sample` would return different identities on each
    // access and never compare equal to itself.
    private let sample: [TrustedContact] = [
        TrustedContact(displayName: "Alice", phoneNumber: PhoneNumber("+447700900001")!),
        TrustedContact(displayName: "Bob", phoneNumber: PhoneNumber("+447700900002")!),
    ]

    @Test("Round-trips without losing a contact or reordering them")
    func roundTrip() throws {
        let data = try ContactEnvelope.encode(sample)
        let decoded = try ContactEnvelope.decode(data)
        #expect(decoded == sample)
        #expect(decoded.map(\.displayName) == ["Alice", "Bob"])
    }

    @Test("An empty list round-trips as empty, not as a failure")
    func emptyRoundTrip() throws {
        let decoded = try ContactEnvelope.decode(try ContactEnvelope.encode([]))
        #expect(decoded.isEmpty)
    }

    @Test("Stamps the current schema version on write")
    func stampsVersion() throws {
        let data = try ContactEnvelope.encode(sample)
        let payload = try JSONDecoder().decode(ContactEnvelope.Payload.self, from: data)
        #expect(payload.schemaVersion == ContactEnvelope.currentSchemaVersion)
    }

    @Test("Refuses data from a newer build rather than guessing at its shape")
    func futureSchemaIsRefused() throws {
        // The user downgraded, or restored a backup from a newer install. Returning
        // an empty list here would read as "no contacts set", which is a silent
        // failure at the exact moment it matters.
        let future = ContactEnvelope.Payload(schemaVersion: ContactEnvelope.currentSchemaVersion + 1, contacts: sample)
        let data = try JSONEncoder().encode(future)

        #expect(throws: ContactEnvelope.Failure.futureSchema(ContactEnvelope.currentSchemaVersion + 1)) {
            try ContactEnvelope.decode(data)
        }
    }

    @Test("Rejects a nonsense version rather than accepting the contacts")
    func zeroVersionIsRejected() throws {
        let bogus = ContactEnvelope.Payload(schemaVersion: 0, contacts: sample)
        let data = try JSONEncoder().encode(bogus)
        #expect(throws: ContactEnvelope.Failure.malformed) { try ContactEnvelope.decode(data) }
    }

    @Test("Reports corrupt bytes as malformed rather than crashing")
    func garbageIsMalformed() {
        #expect(throws: ContactEnvelope.Failure.malformed) {
            try ContactEnvelope.decode(Data("not json at all".utf8))
        }
        #expect(throws: ContactEnvelope.Failure.malformed) {
            try ContactEnvelope.decode(Data())
        }
    }
}
