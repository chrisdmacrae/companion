import Foundation

/// A calendar event as returned by the core's `calendar.range` (mirrors
/// `domain.CalendarEvent` — only the fields the agenda needs are decoded). Feeds the
/// day-agenda panel beside the daily note.
struct CalendarEvent: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var startsAt: String
    var allDay: Bool

    private var start: Date? { ISODate.parseRFC3339(startsAt) }

    /// Sort key for laying the agenda out chronologically.
    var sortKey: Date { start ?? .distantPast }

    /// Left-hand time label, e.g. "11:00 AM" (or "All-day").
    var timeLabel: String {
        if allDay { return "All-day" }
        guard let start else { return "" }
        return ISODate.timeLabel(start)
    }
}
