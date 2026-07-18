import SwiftUI
import WebKit

/// Hosts the shared React Flow graph (bundled from `@companion/graph` into
/// apps/visionos/Resources/graph.{js,css} by `make visionos-graph`) inside a `WKWebView` —
/// the visionOS analogue of `GraphCanvas.tsx`'s react-native-webview host. The webview
/// posts `ready`, then this host seeds the full graph from the core; node opens post back.
struct GraphCanvasView: UIViewRepresentable {
    let core: CompanionCore
    var onOpenNode: (_ type: String, _ id: String) -> Void = { _, _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let ucc = WKUserContentController()
        ucc.add(context.coordinator, name: "graph")
        // The bundle posts via `window.ReactNativeWebView.postMessage` (its RN contract).
        ucc.addUserScript(WKUserScript(
            source: "window.ReactNativeWebView={postMessage:function(m){window.webkit.messageHandlers.graph.postMessage(m);}};",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        let config = WKWebViewConfiguration()
        config.userContentController = ucc

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false   // React Flow handles its own pan/zoom
        context.coordinator.webView = web
        web.loadHTMLString(Coordinator.html(), baseURL: nil)
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.configuration.userContentController.removeScriptMessageHandler(forName: "graph")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: GraphCanvasView
        weak var webView: WKWebView?
        init(_ parent: GraphCanvasView) { self.parent = parent }

        func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
            guard
                let body = message.body as? String,
                let data = body.data(using: .utf8),
                let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let type = obj["type"] as? String
            else { return }
            switch type {
            case "ready":
                pushGraph()
            case "openNode":
                if let p = obj["payload"] as? [String: Any],
                   let t = p["type"] as? String, let id = p["id"] as? String {
                    parent.onOpenNode(t, id)
                }
            default:
                break
            }
        }

        /// Fetch the full graph from the core and hand it to the canvas.
        private func pushGraph() {
            let json = parent.core.invokeJSON("graph.full", fallback: #"{"nodes":[],"edges":[]}"#)
            let escaped = json.replacingOccurrences(of: "<", with: "\\u003c")
            webView?.evaluateJavaScript("window.__setGraph && window.__setGraph(\(escaped));")
        }

        static func html() -> String {
            let css = resource("graph", "css")
            let js = resource("graph", "js")
            return """
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
            <style>html,body{margin:0;padding:0;height:100%;width:100%;background:#f5f5f3;}#graph{position:absolute;inset:0;}\(css)</style>
            </head>
            <body>
            <div id="graph"></div>
            <script>window.__FOCUS_KEY__ = null;</script>
            <script>\(js)</script>
            </body>
            </html>
            """
        }

        private static func resource(_ name: String, _ ext: String) -> String {
            guard
                let url = Bundle.main.url(forResource: name, withExtension: ext),
                let contents = try? String(contentsOf: url, encoding: .utf8)
            else { return "" }
            return contents
        }
    }
}

/// The Graph tool: a full-bleed React Flow canvas of the note/task/project graph.
struct GraphToolView: View {
    let core: CompanionCore

    var body: some View {
        GraphCanvasView(core: core)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .padding(16)
    }
}
