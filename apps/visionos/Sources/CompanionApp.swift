import SwiftUI

/// Native visionOS app entry point. Boots the shared Go core (`CompanionCore`) and shows
/// the selected tool. Only the Go core is shared with desktop/mobile/web; the UI here is
/// native SwiftUI.
@main
struct CompanionApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // Default (glass) window style — the system glass plate wraps the whole Today
        // view; the note sits on it as a white card, the calendar/agenda pane stays glass.
        // (`.plain` would strip that glass, which is why an earlier version had none.)
        .defaultSize(width: 1100, height: 820)
    }
}

/// Opens the core once, then routes between tools with a `TabView`. On visionOS a
/// `TabView` renders as a floating vertical rail on the window's leading edge: collapsed
/// to icons, it expands to reveal each tool's label when the user looks at (or points at)
/// it. That gaze-driven expansion is done by the system — an app can't observe gaze for
/// privacy, so this native tab bar is the only way to get "labels on hover" here (a
/// custom `.onHover` rail never fires for eye input).
private struct RootView: View {
    @State private var selection: Tool = .today
    @State private var core: CompanionCore?
    @State private var model: TodayModel?
    @State private var bootError: String?

    var body: some View {
        Group {
            if let bootError {
                ContentUnavailableView {
                    Label("Couldn’t open Companion", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(bootError)
                }
            } else if let core, let model {
                // The modern `Tab(value:)` API + adaptable sidebar shows all tools +
                // Settings (the classic `.tabItem`/`.tag` tab bar dropped tabs past ~8).
                TabView(selection: $selection) {
                    ForEach(Tool.railTools) { tool in
                        Tab(tool.label, systemImage: tool.symbol, value: tool) {
                            toolView(tool, core: core, model: model)
                        }
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
            } else {
                ProgressView("Opening…")
                    .task { boot() }
            }
        }
        .tint(Brand.accent)   // brand orange drives selection/accent across the app
    }

    @ViewBuilder private func toolView(_ tool: Tool, core: CompanionCore, model: TodayModel) -> some View {
        switch tool {
        case .today: TodayView(model: model)
        case .settings: SettingsScreen(core: core)
        default: ToolPlaceholder(tool: tool)
        }
    }

    @MainActor private func boot() {
        do {
            let core = try CompanionCore()
            SyncConfig.load()?.apply(to: core)   // re-point the sync engine at the saved server
            self.core = core
            self.model = TodayModel(core: core)
        } catch {
            bootError = "\(error)"
        }
    }
}

/// Stand-in for tools whose native screen isn't built yet. Keeps the rail navigable end
/// to end without blocking on every tool's UI.
private struct ToolPlaceholder: View {
    let tool: Tool

    var body: some View {
        ContentUnavailableView {
            Label(tool.label, systemImage: tool.symbol)
        } description: {
            Text("Coming soon on visionOS.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
