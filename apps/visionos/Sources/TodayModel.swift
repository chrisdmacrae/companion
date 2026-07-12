import Foundation
import Observation

/// View model for the Today tool. Owns the core handle, the loaded notes, and the
/// selected day; exposes create-on-type autosave for the daily note. Mirrors the shared
/// TodayScreen logic (derive everything from the already-loaded notes list; a day's note
/// is created lazily on the first edit) rather than adding a `getByDate` core method.
@MainActor
@Observable
final class TodayModel {
    private let core: CompanionCore

    /// All (non-trashed) notes, refreshed from `notes.list`. The calendar reads dots and
    /// the detail reads the selected day's note out of this.
    private(set) var notes: [Note] = []
    /// Calendar events for `selectedDate`, shown in the agenda beside the note.
    private(set) var events: [CalendarEvent] = []
    var selectedDate: String {
        didSet { reloadEvents() }   // note the calendar is stable; only the day's events refetch
    }
    var errorMessage: String?

    /// Guards against creating two notes for the same day when edits arrive before the
    /// first `notes.create` has returned.
    private var creating: Set<String> = []
    private var saveTask: Task<Void, Never>?
    private var eventsTask: Task<Void, Never>?

    init(core: CompanionCore, date: String = ISODate.today()) {
        self.core = core
        self.selectedDate = date
        reload()
        reloadEvents()      // didSet doesn't fire for the initial assignment
        observeEvents()
    }

    func note(for date: String) -> Note? { notes.first { $0.date == date } }
    func hasNote(on date: String) -> Bool { note(for: date) != nil }

    // MARK: Editor bridge (references + embeds)

    /// Wikilink autocomplete search, as raw `GraphNode[]` JSON for the editor.
    func linkSearchJSON(query: String, type: String) -> String {
        core.invokeJSON("graph.search", ["query": query, "type": type, "limit": 20], fallback: "[]")
    }

    /// Resolve a pasted UUID to a link target, as raw JSON for the editor.
    func linkLookupJSON(id: String) -> String {
        core.invokeJSON("graph.lookup", ["id": id])
    }

    /// Resolve one embedded document to a renderable data URL, as raw JSON for the editor.
    func documentDataURLJSON(id: String) -> String {
        core.invokeJSON("documents.dataUrl", ["id": id])
    }

    /// Ingest a picked file into a document (PLAN §6.9); returns `(id, filename)` for the embed.
    func ingestFile(path: String, filename: String, mime: String) -> (id: String, filename: String)? {
        struct Doc: Decodable { let id: String; let filename: String? }
        let json = core.invokeJSON("documents.ingestFile", ["path": path, "filename": filename, "mime": mime])
        guard let data = json.data(using: .utf8), let doc = try? JSONDecoder().decode(Doc.self, from: data) else { return nil }
        return (doc.id, doc.filename ?? filename)
    }

    /// Loads the selected day's calendar events (local midnight-to-midnight) for the
    /// agenda. Empty on a fresh database — the panel shows an empty state.
    func reloadEvents() {
        guard let start = ISODate.date(from: selectedDate) else { events = []; return }
        let end = ISODate.calendar.date(byAdding: .day, value: 1, to: start) ?? start
        struct RangeIn: Encodable { let from: String; let to: String }
        do {
            let loaded = try core.invoke("calendar.range",
                payload: JSONEncoder().encode(RangeIn(from: ISODate.rfc3339(start), to: ISODate.rfc3339(end))),
                as: [CalendarEvent].self)
            events = loaded.sorted { $0.sortKey < $1.sortKey }
        } catch {
            events = []
            errorMessage = "\(error)"
        }
    }

    /// Reloads the notes list from the core. Cheap and idempotent — also the handler for
    /// `notes.changed`/`data.changed` events. Does not touch any in-flight editor buffer
    /// (the detail view keeps its own text state), so a reload mid-edit is safe.
    func reload() {
        do {
            notes = try core.invoke("notes.list", as: [Note].self)
            errorMessage = nil
        } catch {
            errorMessage = "\(error)"
        }
    }

    /// Debounced autosave of the daily note for `date`. Creates the note on the first
    /// edit (create-on-type), then routes later edits to `notes.update`.
    func scheduleSave(date: String, contentMd: String) {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.commitSave(date: date, contentMd: contentMd)
        }
    }

    private func commitSave(date: String, contentMd: String) {
        do {
            if let existing = note(for: date) {
                struct UpdateIn: Encodable { let id: String; let contentMd: String }
                _ = try core.invoke("notes.update",
                                    payload: JSONEncoder().encode(UpdateIn(id: existing.id, contentMd: contentMd)))
            } else {
                guard !creating.contains(date) else { return }
                creating.insert(date)
                defer { creating.remove(date) }
                struct CreateIn: Encodable { let title: String; let contentMd: String; let date: String }
                let created = try core.invoke("notes.create",
                                    payload: JSONEncoder().encode(CreateIn(title: ISODate.fullDate(date), contentMd: contentMd, date: date)),
                                    as: Note.self)
                notes.append(created)
            }
            errorMessage = nil
        } catch {
            errorMessage = "\(error)"
        }
    }

    private func observeEvents() {
        let events = core.events
        eventsTask = Task { [weak self] in
            for await event in events {
                guard let self else { return }   // stops the loop once the model is gone
                switch event.name {
                case "notes.changed", "data.changed":
                    self.reload()
                    self.reloadEvents()
                case "calendar.changed":
                    self.reloadEvents()
                default:
                    break
                }
            }
        }
    }
}
