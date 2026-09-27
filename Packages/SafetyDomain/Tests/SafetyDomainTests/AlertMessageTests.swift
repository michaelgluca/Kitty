import Foundation
import Testing

@testable import SafetyDomain

// The alert message is the single most important thing this app produces. Every
// branch here is a real failure mode, so each one is pinned by a test before the
// implementation exists.

private let strings = AlertStrings(
    header: "I need help.",
    sentAt: "Sent %@",
    locationLink: "Where I am: %@",
    coordinates: "Coordinates: %@",
    locationUnavailable: "My location is not available.",
    battery: "Phone battery: %@",
    disclaimer: "Sent by hand from Kitty G. This app does not contact emergency services.",
    testNotice: "TEST — please ignore."
)

private let fixedDate = Date(timeIntervalSince1970: 1_758_900_000)

private func london(accuracy: Double = 12) -> LocationFix {
    LocationFix(
        coordinate: Coordinate(latitude: 51.50853, longitude: -0.12574),
        horizontalAccuracy: accuracy,
        timestamp: fixedDate
    )
}

@Suite("Alert message")
struct AlertMessageTests {

    @Test("Includes a maps link, plain coordinates and battery when a good fix exists")
    func fullMessage() {
        let body = AlertMessageRenderer.render(
            AlertContext(sentAt: fixedDate, location: london(), batteryFraction: 0.42),
            strings: strings,
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(identifier: "Europe/London")!
        )

        #expect(body.contains("I need help."))
        #expect(body.contains("https://maps.apple.com/?ll=51.50853,-0.12574"))
        // Plain coordinates matter: not every recipient is on an iPhone, and a UK
        // call handler can read numbers out loud.
        #expect(body.contains("51.50853, -0.12574"))
        #expect(body.contains("42%"))
        #expect(body.contains("does not contact emergency services"))
    }

    @Test("Says so plainly when there is no location, rather than omitting it silently")
    func noLocation() {
        let body = AlertMessageRenderer.render(
            AlertContext(sentAt: fixedDate, location: nil, batteryFraction: 0.9),
            strings: strings,
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(identifier: "Europe/London")!
        )

        #expect(body.contains("My location is not available."))
        #expect(!body.contains("maps.apple.com"))
        #expect(!body.contains("Coordinates:"))
    }

    @Test("Treats a reduced-accuracy fix as no location at all")
    func reducedAccuracyIsNotALocation() {
        // Precise Location off yields readings around 5 km. Sending that as "where I
        // am" would be worse than sending nothing, because it reads as precise.
        let body = AlertMessageRenderer.render(
            AlertContext(sentAt: fixedDate, location: london(accuracy: 5_000), batteryFraction: nil),
            strings: strings,
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(identifier: "Europe/London")!
        )

        #expect(body.contains("My location is not available."))
        #expect(!body.contains("maps.apple.com"))
    }

    @Test("Treats null island as missing data")
    func nullIslandIsNotALocation() {
        let fix = LocationFix(
            coordinate: Coordinate(latitude: 0, longitude: 0),
            horizontalAccuracy: 5,
            timestamp: fixedDate
        )
        let body = AlertMessageRenderer.render(
            AlertContext(sentAt: fixedDate, location: fix, batteryFraction: nil),
            strings: strings,
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(identifier: "Europe/London")!
        )

        #expect(body.contains("My location is not available."))
    }

    @Test("Omits the battery line when the level is unknown")
    func noBattery() {
        let body = AlertMessageRenderer.render(
            AlertContext(sentAt: fixedDate, location: london(), batteryFraction: nil),
            strings: strings,
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(identifier: "Europe/London")!
        )

        #expect(!body.contains("Phone battery"))
    }

    @Test("Formats coordinates with a full stop regardless of the device locale")
    func coordinatesAreLocaleIndependent() {
        // A French or German device formats decimals with a comma. If that reached
        // the maps URL it would produce a broken link, and a comma-separated pair of
        // coordinates is ambiguous to a human reader too.
        let body = AlertMessageRenderer.render(
            AlertContext(sentAt: fixedDate, location: london(), batteryFraction: 0.5),
            strings: strings,
            locale: Locale(identifier: "fr_FR"),
            timeZone: TimeZone(identifier: "Europe/Paris")!
        )

        #expect(body.contains("ll=51.50853,-0.12574"))
        #expect(!body.contains("51,50853"))
    }

    @Test("Produces a link that parses as a URL")
    func linkIsAValidURL() {
        let link = AlertMessageRenderer.mapsLink(for: london().coordinate)
        #expect(URL(string: link) != nil)
        #expect(link.hasPrefix("https://"))
    }

    @Test("Never renders an empty message, even with nothing to report")
    func neverEmpty() {
        let body = AlertMessageRenderer.render(
            AlertContext(sentAt: fixedDate, location: nil, batteryFraction: nil),
            strings: strings,
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(identifier: "Europe/London")!
        )
        #expect(!body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func render(_ context: AlertContext) -> String {
        AlertMessageRenderer.render(
            context,
            strings: strings,
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(identifier: "Europe/London")!
        )
    }

    private func fix(ageInSeconds age: TimeInterval) -> LocationFix {
        LocationFix(
            coordinate: Coordinate(latitude: 51.50853, longitude: -0.12574),
            horizontalAccuracy: 12,
            timestamp: fixedDate.addingTimeInterval(-age)
        )
    }

    @Test("Treats a fix more than two minutes old as no location")
    func staleFixIsNotALocation() {
        // iOS often hands back a cached reading first. An old position sent as
        // "where I am" reads as current, and sends someone to the wrong place.
        let body = render(AlertContext(sentAt: fixedDate, location: fix(ageInSeconds: 121), batteryFraction: nil))
        #expect(body.contains("My location is not available."))
        #expect(!body.contains("maps.apple.com"))
    }

    @Test("A fix exactly two minutes old is still used")
    func twoMinuteBoundary() {
        let body = render(AlertContext(sentAt: fixedDate, location: fix(ageInSeconds: 120), batteryFraction: nil))
        #expect(body.contains("maps.apple.com"))
    }

    @Test("A fix timestamped slightly after sending counts as fresh")
    func clockSkewIsFresh() {
        let body = render(AlertContext(sentAt: fixedDate, location: fix(ageInSeconds: -5), batteryFraction: nil))
        #expect(body.contains("maps.apple.com"))
    }

    @Test("usableLocation agrees with what the message says")
    func usableLocationMatchesMessage() {
        let fresh = AlertContext(sentAt: fixedDate, location: fix(ageInSeconds: 10), batteryFraction: nil)
        let stale = AlertContext(sentAt: fixedDate, location: fix(ageInSeconds: 600), batteryFraction: nil)
        let coarse = AlertContext(sentAt: fixedDate, location: london(accuracy: 5_000), batteryFraction: nil)
        #expect(fresh.usableLocation != nil)
        #expect(stale.usableLocation == nil)
        #expect(coarse.usableLocation == nil)
    }

    @Test("A Test Mode message says so on its first line")
    func testNoticeComesFirst() {
        let body = render(AlertContext(sentAt: fixedDate, location: nil, batteryFraction: nil, isTest: true))
        #expect(body.components(separatedBy: "\n").first == "TEST — please ignore.")
    }

    @Test("A real message carries no test notice")
    func realMessageHasNoTestNotice() {
        let body = render(AlertContext(sentAt: fixedDate, location: london(), batteryFraction: 0.5))
        #expect(!body.contains("TEST"))
        #expect(body.components(separatedBy: "\n").first == "I need help.")
    }
}

@Suite("Phone number")
struct PhoneNumberTests {

    @Test("Keeps a leading plus and strips formatting")
    func normalisation() {
        #expect(PhoneNumber("+44 7700 900123")?.dialable == "+447700900123")
        #expect(PhoneNumber("(020) 7946-0018")?.dialable == "02079460018")
    }

    @Test("Rejects empty and implausibly short input")
    func rejectsJunk() {
        #expect(PhoneNumber("") == nil)
        #expect(PhoneNumber("   ") == nil)
        #expect(PhoneNumber("12") == nil)
    }

    @Test("Recognises Ofcom's reserved drama range, in national and international form")
    func dramaRange() {
        // These cannot reach a real subscriber, which is what makes Test Mode safe.
        #expect(PhoneNumber("07700 900123")?.isReservedForDrama == true)
        #expect(PhoneNumber("+44 7700 900999")?.isReservedForDrama == true)
        #expect(PhoneNumber("07700 800123")?.isReservedForDrama == false)
        #expect(PhoneNumber("+44 20 7946 0018")?.isReservedForDrama == false)
    }
}

@Suite("Coordinate")
struct CoordinateTests {

    @Test("Coarsening rounds to roughly a kilometre")
    func coarsening() {
        let precise = Coordinate(latitude: 51.508530, longitude: -0.125740)
        let coarse = precise.coarsened()
        #expect(coarse.latitude == 51.51)
        #expect(coarse.longitude == -0.13)
    }

    @Test("Rejects out-of-range and null-island coordinates")
    func plausibility() {
        #expect(Coordinate(latitude: 51.5, longitude: -0.12).isPlausible)
        #expect(!Coordinate(latitude: 0, longitude: 0).isPlausible)
        #expect(!Coordinate(latitude: 91, longitude: 0).isPlausible)
        #expect(!Coordinate(latitude: 0, longitude: 181).isPlausible)
    }
}
