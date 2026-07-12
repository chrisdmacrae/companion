import Foundation

/// A note as returned by the core's `notes.list` / `notes.create` / `notes.update`
/// (mirrors `domain.Note` — only the fields the Today view needs are decoded; Codable
/// ignores the rest). A "daily note" is an ordinary note stamped with `date`
/// (`YYYY-MM-DD`), which is how the shared Today tool models a day (see the desktop/mobile
/// TodayScreen).
struct Note: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var contentMd: String
    var date: String?
}

/// Local-date helpers. Daily notes are keyed by a `YYYY-MM-DD` string in the user's
/// current calendar, so all conversions go through these (POSIX locale, current timezone)
/// to stay consistent with what the other shells write.
enum ISODate {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let full: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full   // e.g. "Monday, July 12, 2026"
        f.timeStyle = .none
        return f
    }()

    /// Today as `YYYY-MM-DD`.
    static func today() -> String { string(from: Date()) }

    static func string(from date: Date) -> String { iso.string(from: date) }

    /// Midnight of the given `YYYY-MM-DD` in the current timezone.
    static func date(from string: String) -> Date? { iso.date(from: string) }

    /// A `YYYY-MM-DD` rendered as a full human date for the note heading.
    static func fullDate(_ string: String) -> String {
        guard let d = date(from: string) else { return string }
        return full.string(from: d)
    }

    private static let rfc3339Out: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return f
    }()

    /// A local `Date` serialized as RFC3339 with offset, the format the core's
    /// `calendar.range` (Go `time.RFC3339`) expects for its `from`/`to` bounds.
    static func rfc3339(_ date: Date) -> String { rfc3339Out.string(from: date) }

    /// Parses an RFC3339 timestamp from the core (with or without fractional seconds).
    static func parseRFC3339(_ string: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: string) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: string)
    }

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = .current
        f.dateFormat = "h:mm a"   // "11:00 AM"
        return f
    }()

    static func timeLabel(_ date: Date) -> String { time.string(from: date) }
}
