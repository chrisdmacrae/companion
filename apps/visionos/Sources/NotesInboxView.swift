import SwiftUI
import UniformTypeIdentifiers

/// The Notes inbox: a sidebar (filter dropdown + note rows) on the window glass, and a
/// white card on the right holding either the empty state or the ProseMirror editor for the
/// selected note. The sidebar shares the window glass with the detail surround (no separate
/// material).
struct NotesInboxView: View {
    let core: CompanionCore
    let onBack: () -> Void

    @State private var notes: [Note] = []
    @State private var filedNotes: Set<String> = []
    @State private var filter: NoteFilter = .unsorted
    @State private var selectedId: String?
    @State private var error: String?

    // Editor state (mirrors the Today editor).
    @State private var controller = EditorController()
    @State private var editorFocused = false
    @State private var formatState = FormatState()
    @State private var hideTask: Task<Void, Never>?
    @State private var saveTask: Task<Void, Never>?
    @State private var showFileImporter = false
    @State private var tableMenu: TableMenuModel?

    private var bridge: EditorBridge {
        EditorBridge(
            search: { core.invokeJSON("graph.search", ["query": $0, "type": $1, "limit": 20], fallback: "[]") },
            lookup: { core.invokeJSON("graph.lookup", ["id": $0]) },
            documentDataURL: { core.invokeJSON("documents.dataUrl", ["id": $0]) }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 340)
            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ornament(visibility: editorFocused ? .visible : .hidden, attachmentAnchor: .scene(.bottom)) {
            FormatToolbar(state: formatState, controller: controller, onEmbed: { showFileImporter = true })
                .padding(.top, 12)
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item]) { result in
            if case let .success(url) = result { embedFile(url) }
        }
        .onAppear(perform: reload)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.headline)
                }
                .padding(.leading, 16)
                .buttonStyle(.plain)
                Text("Notes").font(.title2.bold())
                Spacer()
            }
            .foregroundStyle(.white)

            filterMenu

            ScrollView {
                LazyVStack(spacing: 4) {
                    if filteredNotes.isEmpty {
                        Text("No notes").font(.subheadline).foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                    }
                    ForEach(filteredNotes) { note in
                        noteRow(note)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // Full-width dropdown field. The popup items use the adaptive `.primary` color so they
    // stay readable on the system popup's background (no white-on-white), and the hover
    // effect is clipped to the field shape.
    private var filterMenu: some View {
        Menu {
            Picker("Filter", selection: $filter) {
                ForEach(NoteFilter.allCases) { f in
                    Text(f.label).tag(f)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(filter.label).foregroundStyle(.white)
                Image(systemName: "chevron.down").font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(.white.opacity(0.1), in: .rect(cornerRadius: 10))
            .contentShape(.rect(cornerRadius: 10))
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 10))
        }
        .menuStyle(.borderlessButton)
        .tint(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func noteRow(_ note: Note) -> some View {
        Button { selectedId = note.id } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(excerpt(note))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                selectedId == note.id ? AnyShapeStyle(.white.opacity(0.14)) : AnyShapeStyle(.clear),
                in: .rect(cornerRadius: 10)
            )
            .contentShape(.rect(cornerRadius: 10))
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        // A flat highlight clipped to the row rect — the default lift effect rounds/clips
        // the two-line content.
        .hoverEffect(.highlight)
    }

    // MARK: Detail (white card)

    private var detail: some View {
        Group {
            if let note = selectedNote {
                editorPane(note)
            } else {
                // Explicit dark colors (ContentUnavailableView renders vibrant-white on the
                // card) and centered in the card.
                VStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 44))
                        .foregroundStyle(Brand.textTertiary)
                    Text("Select a note")
                        .font(.title2.bold())
                        .foregroundStyle(Brand.textPrimary)
                    Text("Choose a note from the list to view or edit it.")
                        .font(.subheadline)
                        .foregroundStyle(Brand.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Brand.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .brandShadow(Brand.Shadow.lg)
        .environment(\.colorScheme, .light)
        .padding(20)
    }

    private func editorPane(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.largeTitle.bold())
                .foregroundStyle(Brand.textPrimary)
                .padding([.horizontal, .top], 32)

            ProseMirrorEditor(
                markdown: note.contentMd,
                controller: controller,
                bridge: bridge,
                onChange: { save(id: note.id, markdown: $0) },
                onFocusChange: handleFocus,
                onFormatState: { formatState = $0 },
                onTableMenu: { tableMenu = $0 }
            )
            .id(note.id)   // reseed the editor when the selected note changes
            .overlay { tableMenuOverlay }
        }
    }

    @ViewBuilder private var tableMenuOverlay: some View {
        if let menu = tableMenu {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.001)
                        .contentShape(.rect)
                        .onTapGesture { controller.dismissTableMenu(); tableMenu = nil }
                    TableMenuCard(
                        items: menu.items,
                        onSelect: { id in controller.runTableAction(id); tableMenu = nil },
                        onDismiss: { controller.dismissTableMenu(); tableMenu = nil }
                    )
                    .offset(
                        x: min(max(menu.anchor.x, 8), max(8, geo.size.width - TableMenuCard.width - 8)),
                        y: min(max(menu.anchor.y, 8), max(8, geo.size.height - 320))
                    )
                }
            }
        }
    }

    // MARK: Data + editing

    private var selectedNote: Note? { notes.first { $0.id == selectedId } }

    private var filteredNotes: [Note] {
        let base: [Note]
        switch filter {
        case .all: base = notes
        case .unsorted: base = notes.filter { !filedNotes.contains($0.id) }
        }
        return base.sorted { $0.createdAt > $1.createdAt }
    }

    private func excerpt(_ note: Note) -> String {
        let cleaned = note.contentMd
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "No additional text" : String(cleaned.prefix(140))
    }

    private func reload() {
        do {
            notes = try core.invoke("notes.list", as: [Note].self)
            filedNotes = Set(try core.invoke("projects.memberEntityIds", args: ["entityType": "note"], as: [String].self))
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Debounced autosave of the edited note's content; also refreshes the local excerpt.
    private func save(id: String, markdown: String) {
        if let i = notes.firstIndex(where: { $0.id == id }) { notes[i].contentMd = markdown }
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            _ = try? core.invoke("notes.update", args: ["id": id, "contentMd": markdown])
        }
    }

    private func handleFocus(_ focused: Bool) {
        hideTask?.cancel()
        if focused {
            editorFocused = true
        } else {
            hideTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                if !Task.isCancelled { editorFocused = false }
            }
        }
    }

    private func embedFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: tmp)
        guard (try? FileManager.default.copyItem(at: url, to: tmp)) != nil else { return }
        struct Doc: Decodable { let id: String; let filename: String? }
        let json = core.invokeJSON("documents.ingestFile", ["path": tmp.path, "filename": url.lastPathComponent, "mime": "application/octet-stream"])
        if let data = json.data(using: .utf8), let doc = try? JSONDecoder().decode(Doc.self, from: data) {
            controller.insertDocumentEmbed(id: doc.id, filename: doc.filename ?? url.lastPathComponent)
        }
    }
}

enum NoteFilter: String, CaseIterable, Identifiable {
    case unsorted, all   // Unsorted is the default (the inbox)
    var id: String { rawValue }
    var label: String {
        switch self {
        case .unsorted: "Unsorted notes"
        case .all: "All notes"
        }
    }
}
