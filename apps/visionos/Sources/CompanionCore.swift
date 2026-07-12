import Foundation
import Core

/// Swift wrapper around the gomobile-bound Go core (`Core.xcframework`, built from
/// core/cmd/mobile by `make visionos-artifacts`). This is the visionOS analogue of the
/// mobile Expo module (apps/mobile/modules/companion-core/ios/CompanionCoreModule.swift),
/// minus Expo: the native SwiftUI app talks to `CompanionCore` directly instead of
/// through a JS bridge.
///
/// The core's API is the universal "string method + JSON bytes in/out + event stream"
/// surface (PLAN §3.1): `invoke(method:payload:)` dispatches a call, and `events`
/// streams data-changed / sync / LLM-token notifications.
@MainActor
final class CompanionCore {
    /// Errors surfaced from the Go core or from opening the database.
    struct CoreError: LocalizedError {
        let message: String
        var errorDescription: String? { "Companion core error: \(message)" }
    }

    private let core: MobileCore
    private let forwarder: CoreEventForwarder

    /// Async stream of core events (`name`, JSON `payload`). Feed a UI observer from here.
    let events: AsyncStream<CoreEvent>

    struct CoreEvent: Sendable {
        let name: String
        let payload: Data
    }

    /// Opens (or creates) the SQLite database at `dbPath` and registers the event sink.
    /// The default path lives under the app's Application Support directory — a writable,
    /// per-app location, the visionOS equivalent of the mobile documents dir the Expo
    /// module uses.
    init(dbPath: String = CompanionCore.defaultDatabasePath()) throws {
        var error: NSError?
        guard let core = MobileNew(dbPath, &error) else {
            throw CoreError(message: error?.localizedDescription ?? "failed to open core at \(dbPath)")
        }
        self.core = core

        var continuation: AsyncStream<CoreEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.forwarder = CoreEventForwarder { name, payload in
            continuation.yield(CoreEvent(name: name, payload: payload))
        }
        core.setEventHandler(forwarder)
    }

    /// Dispatches a core method: JSON payload in, JSON result out. gomobile bridges the
    /// Go `([]byte, error)` return with the ObjC error convention, so this imports as
    /// `throws -> Data` (non-optional) — every handler returns either an error or
    /// non-nil JSON bytes.
    func invoke(_ method: String, payload: Data = Data()) throws -> Data {
        do {
            return try core.invoke(method, payload: payload)
        } catch let err as NSError {
            throw CoreError(message: err.localizedDescription)
        }
    }

    /// Convenience: decode the JSON result of an invoke into a `Decodable`.
    func invoke<T: Decodable>(_ method: String, payload: Data = Data(), as type: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: invoke(method, payload: payload))
    }

    /// Invoke returning the raw JSON result string (or a JS-safe fallback on error). Used by
    /// the editor bridge, which passes core results straight back into the WebView as JSON.
    func invokeJSON(_ method: String, _ args: [String: Any] = [:], fallback: String = "null") -> String {
        let payload = (try? JSONSerialization.data(withJSONObject: args)) ?? Data()
        guard let data = try? invoke(method, payload: payload) else { return fallback }
        return String(data: data, encoding: .utf8) ?? fallback
    }

    /// Invoke with a JSON-object argument and decode the result (throws on core/decode error).
    func invoke<T: Decodable>(_ method: String, args: [String: Any], as type: T.Type) throws -> T {
        let data = try invoke(method, payload: JSONSerialization.data(withJSONObject: args))
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Invoke with a JSON-object argument, ignoring the result (throws on core error).
    @discardableResult
    func invoke(_ method: String, args: [String: Any]) throws -> Data {
        try invoke(method, payload: JSONSerialization.data(withJSONObject: args))
    }

    func close() {
        core.setEventHandler(nil)
        try? core.close()
    }

    // `nonisolated` so it can be used as a default argument to `init` (default-argument
    // expressions evaluate in a nonisolated context). Only touches thread-safe FileManager.
    nonisolated static func defaultDatabasePath() -> String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Companion", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("companion.db").path
    }
}

/// Conforms to the gomobile-generated event-handler protocol and forwards each Go core
/// event into the Swift `AsyncStream`, normalizing a nil payload to empty `Data`.
///
/// gomobile emits both a `@protocol MobileEventHandler` and a same-named
/// `@class MobileEventHandler` (the proxy for Go-side values). As with NSObject's own
/// class/protocol clash, Swift imports the protocol with a `Protocol` suffix; conforming
/// to the bare `MobileEventHandler` would instead pick the class and fail with "multiple
/// inheritance from classes 'NSObject' and 'MobileEventHandler'".
private final class CoreEventForwarder: NSObject, MobileEventHandlerProtocol {
    private let forward: (String, Data) -> Void
    init(_ forward: @escaping (String, Data) -> Void) { self.forward = forward }

    func onEvent(_ name: String?, payload: Data?) {
        forward(name ?? "", payload ?? Data())
    }
}
