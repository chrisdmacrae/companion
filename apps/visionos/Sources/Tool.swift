import Foundation

/// The navigable tools in the rail. A trimmed, visionOS-specific set: Notes + Tasks are
/// reached through a single "Inboxes" launcher, and Areas & Projects is its own tab.
enum Tool: String, CaseIterable, Identifiable {
    // `quickAdd` is a tab-bar action (opens the quick-add sheet), not a navigable view.
    case quickAdd, today, chat, inboxes, areasProjects, graph, trash, settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .quickAdd: "Add"
        case .today: "Today"
        case .chat: "Chat"
        case .inboxes: "Inboxes"
        case .areasProjects: "Areas & Projects"
        case .graph: "Graph"
        case .trash: "Trash"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .quickAdd: "plus.circle.fill"
        case .today: "sun.max"
        case .chat: "bubble.left.and.bubble.right"
        case .inboxes: "tray.2"
        case .areasProjects: "folder"
        case .graph: "point.3.connected.trianglepath.dotted"
        case .trash: "trash"
        case .settings: "gearshape"
        }
    }
}

/// Which tools the user has enabled. Drives the rail's contents (visionOS caps the rail at
/// 8). Everything is on by default for now; a Tools settings section can toggle these later.
struct EnabledTools {
    var today = true
    var chat = true
    var notes = true
    var tasks = true
    var graph = true

    static let current = EnabledTools()

    /// The rail tabs, in order, honoring enablement. Inboxes appears when Notes or Tasks is
    /// enabled; Areas & Projects, Trash, and Settings are always shown.
    var railTools: [Tool] {
        var tools: [Tool] = [.quickAdd]   // the quick-add action leads the rail
        if today { tools.append(.today) }
        if chat { tools.append(.chat) }
        if notes || tasks { tools.append(.inboxes) }
        tools.append(.areasProjects)
        if graph { tools.append(.graph) }
        tools.append(.trash)
        tools.append(.settings)
        return tools
    }
}
