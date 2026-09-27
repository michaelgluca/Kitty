import Foundation
import Testing

@testable import SafetyDomain

@Suite("Call and text URLs")
struct ContactURLTests {

    @Test("101 is dialable — a real three-digit police number")
    func shortServiceNumbers() {
        // PhoneNumber used to demand five digits, which silently made 101 — the
        // police non-emergency number — impossible to call.
        #expect(PhoneNumber("101")?.dialable == "101")
    }

    @Test("Two digits is still rejected")
    func tooShort() {
        #expect(PhoneNumber("12") == nil)
    }

    @Test("Calls use tel:, never telprompt:")
    func callURL() throws {
        // telprompt: skips the system's own call confirmation. tel: keeps it, which
        // is the second safeguard behind the app's own confirmation dialog.
        let url = try #require(PhoneNumber("0808 2000 247")?.callURL)
        #expect(url.scheme == "tel")
        #expect(url.absoluteString == "tel:08082000247")
    }

    @Test("An international number keeps its leading plus")
    func internationalCall() throws {
        let url = try #require(PhoneNumber("+44 7700 900001")?.callURL)
        #expect(url.absoluteString == "tel:+447700900001")
    }

    @Test("Text URLs open Messages to the number with no pre-filled body")
    func textURL() throws {
        // The documented sms: scheme takes a number only. The widely copied "&body="
        // is undocumented — Apple's own reference says the URL "must not include any
        // message text" — and the 2023 build used it wrongly, with "&" where "?" was
        // needed. Nothing is appended.
        let url = try #require(PhoneNumber("61016")?.textURL)
        #expect(url.scheme == "sms")
        #expect(url.absoluteString == "sms:61016")
        #expect(!url.absoluteString.contains("body"))
        #expect(!url.absoluteString.contains("?"))
        #expect(!url.absoluteString.contains("&"))
    }

    @Test("A call URL and a text URL for the same number are never interchangeable")
    func callAndTextAreDistinct() throws {
        // The failure this guards: a text-only destination rendered as a call. For
        // someone who cannot speak, that places a voice call — the opposite of what
        // they chose.
        let n = try #require(PhoneNumber("61016"))
        #expect(n.callURL?.scheme != n.textURL?.scheme)
    }
}
