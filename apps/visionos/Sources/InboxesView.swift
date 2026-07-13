import SwiftUI

/// A task (mirrors `domain.Task`) — the fields the inbox needs.
struct TaskItem: Decodable, Identifiable, Hashable {
    let id: String
    var title: String
    var status: String
    var dueAt: String?
    var createdAt: String = ""

    var due: Date? { dueAt.flatMap(ISODate.parseRFC3339) }
    var isOpen: Bool { status == "open" }
}

/// Inbox overview: a Notes well and a Tasks well (each shown only if enabled), summarizing
/// counts in chips with the recent items, and a "View inbox" button into the split-view
/// sub-screen. Wells are darker than the window glass (but still translucent); chips are
/// slightly lighter — all with white copy.
struct InboxesView: View {
    let enabled: EnabledTools
    let core: CompanionCore

    @State private var notes: [Note] = []
    @State private var tasks: [TaskItem] = []
    @State private var filedNotes: Set<String> = []
    @State private var filedTasks: Set<String> = []
    @State private var error: String?
    @State private var activeInbox: InboxKind?

    var body: some View {
        switch activeInbox {
        case .notes:
            NotesInboxView(core: core) { activeInbox = nil }
        case .tasks:
            // Shown in place (not pushed) so it owns its own back control.
            InboxDetailView(kind: .tasks) { activeInbox = nil }
        case nil:
            overview
        }
    }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Inboxes")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Brand.danger)
                }

                if enabled.notes {
                    InboxWell(
                        title: "Notes", icon: "note.text",
                        chips: [(unsortedNotes, "Unsorted"), (sortedNotes, "Sorted")],
                        recent: recentTitles(notes.map { ($0.createdAt, $0.title) }),
                        onViewInbox: { activeInbox = .notes }
                    )
                }
                if enabled.tasks {
                    InboxWell(
                        title: "Tasks", icon: "checklist",
                        chips: [
                            (unsortedTasks, "Unsorted"),
                            (upcomingTasks, "Upcoming"),
                            (overdueTasks, "Overdue"),
                            (tasks.count, "Total"),
                        ],
                        recent: recentTitles(tasks.map { ($0.createdAt, $0.title) }),
                        onViewInbox: { activeInbox = .tasks }
                    )
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear(perform: reload)
    }

    // MARK: Counts

    private var unsortedNotes: Int { notes.filter { !filedNotes.contains($0.id) }.count }
    private var sortedNotes: Int { notes.filter { filedNotes.contains($0.id) }.count }
    private var unsortedTasks: Int { tasks.filter { !filedTasks.contains($0.id) }.count }
    private var upcomingTasks: Int {
        let now = Date()
        return tasks.filter { $0.isOpen && ($0.due.map { $0 > now } ?? false) }.count
    }
    private var overdueTasks: Int {
        let now = Date()
        return tasks.filter { $0.isOpen && ($0.due.map { $0 < now } ?? false) }.count
    }

    /// The 5 most recently created titles from `(createdAt, title)` pairs.
    private func recentTitles(_ items: [(String, String)]) -> [String] {
        items.sorted { $0.0 > $1.0 }.prefix(5).map { $0.1 }
    }

    private func reload() {
        do {
            notes = try core.invoke("notes.list", as: [Note].self)
            tasks = try core.invoke("tasks.list", as: [TaskItem].self)
            filedNotes = Set(try core.invoke("projects.memberEntityIds", args: ["entityType": "note"], as: [String].self))
            filedTasks = Set(try core.invoke("projects.memberEntityIds", args: ["entityType": "task"], as: [String].self))
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// One inbox section, rendered as a translucent dark well: header + "View inbox", count
/// chips, and the recently-created list.
private struct InboxWell: View {
    let title: String
    let icon: String
    let chips: [(Int, String)]
    let recent: [String]
    let onViewInbox: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title2).foregroundStyle(Brand.accent)
                Text(title).font(.title2.bold()).foregroundStyle(.white)
                Spacer()
                Button(action: onViewInbox) {
                    HStack(spacing: 6) {
                        Text("View inbox")
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(.white.opacity(0.16), in: .capsule)
                    .contentShape(.hoverEffect, Capsule())
                }
                .buttonStyle(.plain)
                .hoverEffect()
            }

            HStack(spacing: 10) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, c in
                    chip(count: c.0, label: c.1)
                }
            }

            Divider().overlay(.white.opacity(0.15))

            VStack(alignment: .leading, spacing: 10) {
                Text("Recently created")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
                if recent.isEmpty {
                    Text("Nothing yet").font(.subheadline).foregroundStyle(.white.opacity(0.45))
                } else {
                    ForEach(Array(recent.enumerated()), id: \.offset) { _, t in
                        HStack(spacing: 10) {
                            Circle().fill(.white.opacity(0.4)).frame(width: 5, height: 5)
                            Text(t.isEmpty ? "Untitled" : t).foregroundStyle(.white).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Well: darker than the window glass, still translucent.
        .background(Brand.gray950.opacity(0.4), in: .rect(cornerRadius: 20, style: .continuous))
    }

    // Chip: slightly lighter than the well, white copy.
    private func chip(count: Int, label: String) -> some View {
        HStack(spacing: 6) {
            Text("\(count)").font(.subheadline.bold())
            Text(label).font(.subheadline)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .background(.white.opacity(0.16), in: .capsule)
    }
}

enum InboxKind: String, Hashable {
    case notes, tasks

    var title: String { self == .notes ? "Notes" : "Tasks" }
    var symbol: String { self == .notes ? "note.text" : "checklist" }
}

/// The inbox sub-view: a split view (sidebar filters + detail), placeholder for now, with a
/// back control to the inbox overview.
private struct InboxDetailView: View {
    let kind: InboxKind
    let onBack: () -> Void

    @State private var selection: String?

    private var filters: [String] {
        kind == .notes ? ["All", "Unsorted", "Sorted"] : ["All", "Unsorted", "Upcoming", "Overdue"]
    }

    var body: some View {
        NavigationSplitView {
            List(filters, id: \.self, selection: $selection) { filter in
                Text(filter).tag(filter)
            }
            .navigationTitle("\(kind.title) inbox")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onBack()
                    } label: {
                        Label("Inboxes", systemImage: "chevron.left")
                    }
                }
            }
        } detail: {
            ContentUnavailableView {
                Label(selection ?? kind.title, systemImage: kind.symbol)
            } description: {
                Text("This \(kind.title.lowercased()) view is coming soon on visionOS.")
            }
        }
        .onAppear { if selection == nil { selection = filters.first } }
    }
}
