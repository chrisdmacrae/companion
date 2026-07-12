import SwiftUI

/// Native table cell menu, presented when the editor's "…" table button posts a
/// `tableMenu` request. Mirrors the RN `TableMenuSheet`: a floating card with in-place
/// drill-down for the grouped submenus ("Copy table as", "Align column"). Selecting a leaf
/// runs the action back in the editor; tapping outside dismisses it.
struct TableMenuCard: View {
    let items: [TableMenuItem]
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    @State private var submenu: TableMenuItem?

    static let width: CGFloat = 260

    var body: some View {
        let list = submenu?.children ?? items
        VStack(alignment: .leading, spacing: 0) {
            if let submenu {
                row(label: submenu.label ?? "", leading: "chevron.left") { self.submenu = nil }
                Divider().padding(.vertical, 3)
            }
            ForEach(Array(list.enumerated()), id: \.offset) { _, item in
                if item.separator == true {
                    Divider().padding(.vertical, 4)
                } else {
                    itemRow(item)
                }
            }
        }
        .padding(6)
        .frame(width: Self.width)
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
    }

    @ViewBuilder private func itemRow(_ item: TableMenuItem) -> some View {
        let disabled = item.enabled == false
        let hasChildren = !(item.children?.isEmpty ?? true)
        Button {
            if hasChildren { submenu = item }
            else if let id = item.id { onSelect(id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.caption)
                    .opacity(item.checked == true ? 1 : 0)
                    .foregroundStyle(Brand.accent)
                    .frame(width: 14)
                Text(item.label ?? "")
                    .foregroundStyle(disabled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                Spacer(minLength: 0)
                if hasChildren {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 10)
            .contentShape(.rect(cornerRadius: 8))
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .hoverEffect()
    }

    private func row(label: String, leading: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: leading).font(.caption).foregroundStyle(.secondary)
                Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
