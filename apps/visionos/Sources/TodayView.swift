import SwiftUI
import UniformTypeIdentifiers

/// The Today tool. The daily-note editor is a solid white card (surrounded by the
/// window's glass, which reads as a glass outline); the right pane stays glass and holds
/// the month calendar plus the day's agenda.
struct TodayView: View {
    @Bindable var model: TodayModel
    @State private var editorFocused = false
    @State private var formatState = FormatState()
    @State private var controller = EditorController()
    @State private var hideTask: Task<Void, Never>?
    // References use the editor's inline `[[` popup (no modal); only file embeds need host UI.
    @State private var showFileImporter = false

    private var bridge: EditorBridge {
        EditorBridge(
            search: { model.linkSearchJSON(query: $0, type: $1) },
            lookup: { model.linkLookupJSON(id: $0) },
            documentDataURL: { model.documentDataURLJSON(id: $0) }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            DailyNoteEditor(
                model: model,
                date: model.selectedDate,
                controller: controller,
                bridge: bridge,
                onFocusChange: handleFocus,
                onFormatState: { formatState = $0 }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)

            TodayAside(model: model)
                .frame(width: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Darken the whole window glass (behind the white note card and the calendar/agenda
        // pane alike) so the brand orange and secondary text read against the passthrough.
        .background(Brand.gray950.opacity(0.32))
        // Floating formatting toolbar: a bottom ornament shown only while the editor is
        // focused (the visionOS analogue of the mobile keyboard toolbar).
        .ornament(visibility: editorFocused ? .visible : .hidden, attachmentAnchor: .scene(.bottom)) {
            FormatToolbar(
                state: formatState,
                controller: controller,
                onEmbed: { showFileImporter = true }
            )
            .padding(.top, 12)
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item]) { result in
            if case let .success(url) = result { embedFile(url) }
        }
        .overlay(alignment: .bottom) {
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .padding(12)
                    .background(.regularMaterial, in: .capsule)
                    .foregroundStyle(.red)
                    .padding(.bottom, 16)
            }
        }
    }

    // Debounce blur so tapping a toolbar button (which can momentarily blur the WebView)
    // doesn't dismiss the toolbar out from under the tap.
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

    // Copy the picked file somewhere the core can read, ingest it into a document, and
    // insert the embed chip (PLAN §6.9).
    private func embedFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: tmp)
        guard (try? FileManager.default.copyItem(at: url, to: tmp)) != nil else { return }
        if let doc = model.ingestFile(path: tmp.path, filename: url.lastPathComponent, mime: "application/octet-stream") {
            controller.insertDocumentEmbed(id: doc.id, filename: doc.filename)
        }
    }
}

/// The daily note: a full-date heading over the shared ProseMirror editor, inside a white
/// card (the window glass shows through the surround as a glass outline). The editor owns
/// its content after seeding, so it's keyed on `date` to reseed when the day changes;
/// edits flow back out through the model's debounced autosave.
private struct DailyNoteEditor: View {
    let model: TodayModel
    let date: String
    let controller: EditorController
    let bridge: EditorBridge
    var onFocusChange: (Bool) -> Void
    var onFormatState: (FormatState) -> Void

    @State private var tableMenu: TableMenuModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "star.fill").foregroundStyle(Brand.accent)
                Text(ISODate.fullDate(date))
                    .font(.largeTitle.bold())
                    .foregroundStyle(Brand.textPrimary)
            }
            .padding([.horizontal, .top], 32)

            ProseMirrorEditor(
                markdown: model.note(for: date)?.contentMd ?? "",
                controller: controller,
                bridge: bridge,
                onChange: { model.scheduleSave(date: date, contentMd: $0) },
                onFocusChange: onFocusChange,
                onFormatState: onFormatState,
                onTableMenu: { tableMenu = $0 }
            )
            .id(date)
            .overlay { tableMenuOverlay }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Brand.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .brandShadow(Brand.Shadow.lg)
    }

    // Presents the native table cell menu at the editor-relative anchor, clamped in bounds.
    @ViewBuilder private var tableMenuOverlay: some View {
        if let menu = tableMenu {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    // Transparent backdrop to catch outside taps.
                    Color.black.opacity(0.001)
                        .contentShape(.rect)
                        .onTapGesture {
                            controller.dismissTableMenu()
                            tableMenu = nil
                        }
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
}

/// The glass right pane: month calendar on top, the selected day's agenda beneath.
private struct TodayAside: View {
    let model: TodayModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MonthCalendar(model: model)
            Divider()
            Agenda(model: model)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// The day's events, laid out chronologically. Empty on a fresh database.
private struct Agenda: View {
    let model: TodayModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agenda")
                .font(.headline)
                .foregroundStyle(.secondary)

            if model.events.isEmpty {
                Text("Nothing scheduled")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(model.events) { event in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(event.timeLabel)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 68, alignment: .leading)
                        Text(event.title)
                            .font(.body)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

/// A month grid. Past days and today are selectable (selecting never creates a note — the
/// note is created only when the user types); future days are disabled; days that already
/// have a note show a dot.
private struct MonthCalendar: View {
    let model: TodayModel
    @State private var visibleMonth: Date = Date()

    private let calendar = ISODate.calendar
    private var todayISO: String { ISODate.today() }

    var body: some View {
        VStack(spacing: 14) {
            header
            weekdayRow
            grid
        }
        .onAppear {
            if let d = ISODate.date(from: model.selectedDate) { visibleMonth = d }
        }
    }

    private var header: some View {
        HStack {
            Text(monthTitle)
                .font(.title3.bold())
            Spacer()
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
        }
        .buttonStyle(.borderless)
    }

    private var weekdayRow: some View {
        HStack {
            ForEach(shortWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let iso = ISODate.string(from: date)
        let isSelected = iso == model.selectedDate
        let isToday = iso == todayISO
        let isFuture = iso > todayISO
        return Button {
            model.selectedDate = iso
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.callout)
                    .foregroundStyle(isSelected ? AnyShapeStyle(Brand.onAccent) : AnyShapeStyle(.primary))
                Circle()
                    .fill(model.hasNote(on: iso) ? Brand.accent : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 10))
            .overlay {
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 10).stroke(.tint, lineWidth: 1)
                }
            }
            // Match the gaze/hover highlight to the selected-day shape (a rounded rect),
            // instead of the plain button's default full-bounds rectangle.
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .opacity(isFuture ? 0.35 : 1)
    }

    // MARK: - Month math

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"   // "July 2026"
        return f.string(from: visibleMonth)
    }

    private var shortWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var monthCells: [Date?] {
        guard
            let interval = calendar.dateInterval(of: .month, for: visibleMonth),
            let dayCount = calendar.range(of: .day, in: .month, for: visibleMonth)?.count
        else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            if let d = calendar.date(byAdding: .day, value: offset, to: interval.start) {
                cells.append(d)
            }
        }
        return cells
    }

    private func shiftMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: visibleMonth) {
            visibleMonth = d
        }
    }
}
