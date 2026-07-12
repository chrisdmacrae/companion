import Foundation

/// The navigable tools, mirroring the shared rail registry `TOOLS` in
/// `packages/app/src/ToolVisibilityProvider.tsx` (same ids + order). Icons are mapped to
/// SF Symbols for the native rail. Only Today has a real view so far; the rest are
/// placeholders until their native screens land.
enum Tool: String, CaseIterable, Identifiable {
    case today, chat, calendar, notes, tasks, habits, graph, trash, settings

    var id: String { rawValue }

    /// Tools shown in the navigation rail. visionOS caps the TabView rail at 8 items, so
    /// Trash lives inside Settings (see SettingsSection) rather than as its own rail tab.
    static var railTools: [Tool] { allCases.filter { $0 != .trash } }

    var label: String {
        switch self {
        case .today: "Today"
        case .chat: "Chat"
        case .calendar: "Calendar"
        case .notes: "Notes"
        case .tasks: "Tasks"
        case .habits: "Habits"
        case .graph: "Graph"
        case .trash: "Trash"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .chat: "bubble.left.and.bubble.right"
        case .calendar: "calendar"
        case .notes: "note.text"
        case .tasks: "checklist"
        case .habits: "repeat"
        case .graph: "point.3.connected.trianglepath.dotted"
        case .trash: "trash"
        case .settings: "gearshape"
        }
    }
}
