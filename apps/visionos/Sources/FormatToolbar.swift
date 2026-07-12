import SwiftUI

/// The floating formatting toolbar, shown as an ornament while the note editor is focused.
/// Each button injects `window.__format(name)` via the `EditorController` and reflects the
/// editor's live active/enabled state. Same command set as the web/mobile toolbars.
struct FormatToolbar: View {
    let state: FormatState
    let controller: EditorController
    var onEmbed: () -> Void

    private struct Item { let name: String; let symbol: String; let label: String }
    private static let items: [Item] = [
        Item(name: "bold", symbol: "bold", label: "Bold"),
        Item(name: "italic", symbol: "italic", label: "Italic"),
        Item(name: "strike", symbol: "strikethrough", label: "Strikethrough"),
        Item(name: "code", symbol: "chevron.left.forwardslash.chevron.right", label: "Code"),
        Item(name: "codeBlock", symbol: "curlybraces", label: "Code block"),
        Item(name: "blockquote", symbol: "text.quote", label: "Blockquote"),
        Item(name: "bulletList", symbol: "list.bullet", label: "Bulleted list"),
        Item(name: "orderedList", symbol: "list.number", label: "Numbered list"),
    ]

    var body: some View {
        HStack(spacing: 4) {
            // Insert group: reference (inline `[[` popup), table, embed (file import).
            actionButton(symbol: "link", label: "Insert reference") { controller.insertReference() }
            actionButton(symbol: "tablecells", label: "Insert table") { controller.insertTable() }
            actionButton(symbol: "paperclip", label: "Attach file", action: onEmbed)

            Divider().frame(height: 30).padding(.horizontal, 4)

            ForEach(Self.items, id: \.name) { item in
                let active = state.isActive(item.name)
                let enabled = state.isEnabled(item.name)
                Button {
                    controller.format(item.name)
                } label: {
                    Image(systemName: item.symbol)
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 46, height: 46)
                        .foregroundStyle(active ? AnyShapeStyle(Brand.accent) : AnyShapeStyle(.primary))
                        .background(
                            active ? AnyShapeStyle(Brand.accentSoft) : AnyShapeStyle(.clear),
                            in: .rect(cornerRadius: 12)
                        )
                        .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.35)
                .accessibilityLabel(item.label)
            }
        }
        .padding(8)
        .glassBackgroundEffect()
    }

    private func actionButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 46, height: 46)
                .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
