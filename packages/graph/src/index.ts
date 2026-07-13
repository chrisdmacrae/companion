// The reusable graph renderer: the React Flow canvas (DOM-only) plus the offline WebView
// bundle native hosts embed. Web/desktop import `GraphView` directly; native hosts
// (mobile, visionOS) embed `@companion/graph/bundle` (GRAPH_JS/GRAPH_CSS) in a WebView.
export * from "./GraphView.web";
export { GRAPH_JS, GRAPH_CSS } from "./graphBundle.generated";
