import SwiftUI

/// Quick capture, opened from the rail's "+" action — the visionOS analogue of the
/// desktop's Cmd/Ctrl+Shift+N capture window (`CaptureForm`/`useCaptureController`). A
/// two-question flow: note or task, then the entry for that kind. Notes use the simple
/// ProseMirror editor (so `[[` links / `![[` embeds work); tasks take a title plus
/// natural-language due + reminder fields with a resolved-date confirmation.
struct QuickAddSheet: View {
    let core: CompanionCore
    @Environment(\.dismiss) private var dismiss

    enum Kind: String, CaseIterable, Identifiable {
        case note, task
        var id: String { rawValue }
        var label: String { self == .note ? "Note" : "Task" }
        var symbol: String { self == .note ? "note.text" : "checklist" }
    }

    @State private var kind: Kind = .note
    @State private var noteDraft = ""
    @State private var taskTitle = ""
    @State private var due = ""
    @State private var remind = ""
    @State private var dueResolved: String?
    @State private var remindResolved: String?
    @State private var dueFailed = false
    @State private var remindFailed = false
    @State private var busy = false
    @State private var error: String?
    @State private var editorController = EditorController()
    @FocusState private var taskTitleFocused: Bool

    private var bridge: EditorBridge {
        EditorBridge(
            search: { core.invokeJSON("graph.search", ["query": $0, "type": $1, "limit": 20], fallback: "[]") },
            lookup: { core.invokeJSON("graph.lookup", ["id": $0]) },
            documentDataURL: { core.invokeJSON("documents.dataUrl", ["id": $0]) }
        )
    }

    private var canSubmit: Bool {
        kind == .note
            ? !noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : !taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                kindToggle

                if kind == .note {
                    noteBox
                } else {
                    taskFields
                }

                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout).foregroundStyle(Brand.danger)
                }

                HStack(spacing: 12) {
                    // Cancel is a neutral glass capsule; only the primary Save action
                    // carries the brand orange (a solid-orange Cancel read as an error).
                    Button { dismiss() } label: {
                        Text("Cancel").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)

                    Button { submit() } label: {
                        Text(kind == .note ? "Save note" : "Save task").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.accent)
                    .disabled(!canSubmit || busy)
                }
                .controlSize(.large)
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle("Quick add")
        }
        .frame(minWidth: 560)
        // Darken the system glass sheet to match the app (every tool sits on this same
        // scrim over the window glass).
        .background(Brand.gray950.opacity(0.32))
        .onAppear { if kind == .task { taskTitleFocused = true } }
    }

    // MARK: Q1 — note or task

    private var kindToggle: some View {
        HStack(spacing: 4) {
            ForEach(Kind.allCases) { k in
                let active = kind == k
                Button { kind = k } label: {
                    HStack(spacing: 6) {
                        Image(systemName: k.symbol)
                        Text(k.label)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(active ? AnyShapeStyle(Brand.onAccent) : AnyShapeStyle(.white.opacity(0.7)))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(active ? AnyShapeStyle(Brand.accent) : AnyShapeStyle(.clear), in: .capsule)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.white.opacity(0.1), in: .capsule)
    }

    // MARK: Q2 — note

    private var noteBox: some View {
        ProseMirrorEditor(
            markdown: noteDraft,
            controller: editorController,
            bridge: bridge,
            variant: "simple",
            placeholder: "Type anything. Use [[ to link or ![[ to embed.",
            onChange: { noteDraft = $0 }
        )
        .frame(height: 200)
        .background(Brand.surfaceCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Q2 — task

    private var taskFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            field("What do you need to do?") {
                fieldInput("e.g. Email the design draft", text: $taskTitle)
                    .focused($taskTitleFocused)
            }
            field("When is this due?",
                  hint: dueResolved,
                  error: dueFailed ? "Couldn’t read a date — try “next friday”." : nil) {
                fieldInput("Natural language, e.g. tomorrow", text: $due, icon: "calendar")
                    .onChange(of: due) { _, _ in previewDue() }
            }
            field("Do you want me to remind you?",
                  hint: remindResolved,
                  error: remindFailed ? "Couldn’t read a time — try “tomorrow 9am”." : nil) {
                fieldInput("Natural language, e.g. in 2 hours", text: $remind, icon: "calendar")
                    .onChange(of: remind) { _, _ in previewRemind() }
            }
        }
    }

    private func field<Content: View>(_ label: String, hint: String? = nil, error: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.8))
            content()
            if let error {
                Text(error).font(.caption).foregroundStyle(Brand.accent)
            } else if let hint {
                Text(hint).font(.caption).foregroundStyle(Brand.success)
            }
        }
    }

    private func fieldInput(_ placeholder: String, text: Binding<String>, icon: String? = nil) -> some View {
        HStack(spacing: 8) {
            if let icon { Image(systemName: icon).foregroundStyle(.white.opacity(0.5)) }
            TextField(placeholder, text: text)
                .foregroundStyle(.white)
                .autocorrectionDisabled()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.white.opacity(0.1), in: .rect(cornerRadius: 10))
    }

    // MARK: Natural-language dates

    /// Parse a NL date field: (ISO or nil when empty, invalid when unparseable).
    private func parseNl(_ text: String) -> (iso: String?, invalid: Bool) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return (nil, false) }
        struct R: Decodable { let at: String }
        let json = core.invokeJSON("dates.parse", ["text": t])
        if let data = json.data(using: .utf8), let r = try? JSONDecoder().decode(R.self, from: data) {
            return (r.at, false)
        }
        return (nil, true)
    }

    private func previewDue() {
        let r = parseNl(due)
        dueFailed = r.invalid
        dueResolved = r.iso.flatMap(ISODate.parseRFC3339).map(Self.formatResolved)
    }

    private func previewRemind() {
        let r = parseNl(remind)
        remindFailed = r.invalid
        remindResolved = r.iso.flatMap(ISODate.parseRFC3339).map(Self.formatResolved)
    }

    private static func formatResolved(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: Submit

    private func submit() {
        busy = true; error = nil
        do {
            switch kind {
            case .note:
                let text = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { busy = false; return }
                let firstLine = text.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? text
                let title = String(firstLine.prefix(60))
                _ = try core.invoke("notes.create", args: ["title": title, "contentMd": text])
            case .task:
                let title = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { busy = false; return }
                let d = parseNl(due), r = parseNl(remind)
                if d.invalid { dueFailed = true; busy = false; return }
                if r.invalid { remindFailed = true; busy = false; return }
                var args: [String: Any] = ["title": title]
                if let iso = d.iso { args["dueAt"] = iso }
                if let iso = r.iso { args["remindAt"] = iso }
                _ = try core.invoke("tasks.create", args: args)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        busy = false
    }
}
