import Foundation

/// The localised text used to build an alert.
///
/// Supplied by the presentation layer from the String Catalog. The domain does not
/// own strings — that would drag a bundle and a localisation mechanism into a layer
/// that has to stay platform-neutral — but it does own the rules about which of them
/// appear and in what order. See ADR-0003.
public struct AlertStrings: Sendable {
    public var header: String
    /// One `%@`: the time the alert was composed.
    public var sentAt: String
    /// One `%@`: a maps link.
    public var locationLink: String
    /// One `%@`: plain decimal coordinates.
    public var coordinates: String
    public var locationUnavailable: String
    /// One `%@`: the battery level as a percentage.
    public var battery: String
    public var disclaimer: String
    /// The first line of a message composed in Test Mode, so nobody who receives one
    /// mistakes it for a real alert.
    public var testNotice: String

    public init(
        header: String,
        sentAt: String,
        locationLink: String,
        coordinates: String,
        locationUnavailable: String,
        battery: String,
        disclaimer: String,
        testNotice: String
    ) {
        self.header = header
        self.sentAt = sentAt
        self.locationLink = locationLink
        self.coordinates = coordinates
        self.locationUnavailable = locationUnavailable
        self.battery = battery
        self.disclaimer = disclaimer
        self.testNotice = testNotice
    }
}

/// Everything known at the moment the user raises an alert.
public struct AlertContext: Sendable {
    public var sentAt: Date
    /// Absent when no fix arrived in time. The alert is never blocked on location.
    public var location: LocationFix?
    /// 0…1, or `nil` when unknown.
    public var batteryFraction: Double?
    /// Composed in Test Mode: the message says so on its first line.
    public var isTest: Bool

    public init(sentAt: Date, location: LocationFix?, batteryFraction: Double?, isTest: Bool = false) {
        self.sentAt = sentAt
        self.location = location
        self.batteryFraction = batteryFraction
        self.isTest = isTest
    }

    /// The fix to put in the message, or `nil`.
    ///
    /// A fix that is implausible, reduced-accuracy or stale is no location at all:
    /// presenting any of them as "where I am" would send someone to the wrong place.
    /// This is the one definition, used both to write the message and to tell the
    /// person whether it included their location.
    public var usableLocation: LocationFix? {
        guard let fix = location, fix.isUsable, fix.isFresh(at: sentAt) else { return nil }
        return fix
    }
}

/// Builds the body of an alert message.
///
/// Pure, synchronous and total: it always returns a message. There is no failure
/// path, because a user raising an alert must never be met with an error instead of
/// a message they can send.
public enum AlertMessageRenderer {

    /// Coordinates are always formatted with a full stop, whatever the device
    /// locale. A French or German device would otherwise produce `51,50853`, which
    /// breaks the maps URL and reads ambiguously to a human.
    private static let coordinateLocale = Locale(identifier: "en_US_POSIX")

    public static func format(_ value: Double) -> String {
        String(format: "%.5f", locale: coordinateLocale, value)
    }

    public static func mapsLink(for coordinate: Coordinate) -> String {
        let pair = "\(format(coordinate.latitude)),\(format(coordinate.longitude))"
        // Only digits, '.', '-' and ',' — all legal unencoded in a query component,
        // so this needs no escaping and cannot produce a malformed URL.
        return "https://maps.apple.com/?ll=\(pair)&q=\(pair)"
    }

    public static func render(
        _ context: AlertContext,
        strings: AlertStrings,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        var lines: [String] = []
        if context.isTest { lines.append(strings.testNotice) }
        lines.append(strings.header)

        var timeStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)
        timeStyle.locale = locale
        timeStyle.timeZone = timeZone
        lines.append(String(format: strings.sentAt, context.sentAt.formatted(timeStyle)))

        // See AlertContext.usableLocation for what counts as a location.
        if let fix = context.usableLocation {
            let pair = "\(format(fix.coordinate.latitude)), \(format(fix.coordinate.longitude))"
            lines.append(String(format: strings.locationLink, mapsLink(for: fix.coordinate)))
            lines.append(String(format: strings.coordinates, pair))
        } else {
            lines.append(strings.locationUnavailable)
        }

        if let fraction = context.batteryFraction {
            let percent = Int((fraction * 100).rounded())
            lines.append(String(format: strings.battery, "\(percent)%"))
        }

        lines.append(strings.disclaimer)
        return lines.joined(separator: "\n")
    }
}
