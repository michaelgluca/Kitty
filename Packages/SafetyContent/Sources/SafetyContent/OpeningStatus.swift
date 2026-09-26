import Foundation

/// Whether a service can actually be reached right now.
///
/// Structured rather than a rendered string: the wording belongs in the String
/// Catalog, and the decision belongs here where it can be tested.
public enum OpeningStatus: Sendable, Equatable {
    case openNow
    case closedNow
    /// The service publishes no fixed hours, so the app must not guess either way.
    case unknown
}

public extension Availability {

    /// UK helplines keep UK hours.
    ///
    /// The evaluation deliberately uses the service's own time zone rather than the
    /// device's. A UK survivor travelling abroad, checking at their local 3am, may
    /// well be inside UK opening hours — and telling them a line is shut when it is
    /// open is the failure that matters here.
    static let ukTimeZone = TimeZone(identifier: "Europe/London") ?? .gmt

    func status(at date: Date, in timeZone: TimeZone = Availability.ukTimeZone) -> OpeningStatus {
        switch self {
        case .allHours:
            return .openNow
        case .seeWebsite:
            return .unknown
        case let .weekdays(openHour, closeHour):
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
            guard let weekday = parts.weekday, let hour = parts.hour else { return .unknown }

            // Calendar weekday: 1 = Sunday, 7 = Saturday.
            let isWeekday = (2...6).contains(weekday)
            guard isWeekday else { return .closedNow }

            // closeHour is exclusive: a line closing at 16 is shut at 16:00.
            return (openHour..<closeHour).contains(hour) ? .openNow : .closedNow
        }
    }
}
