import Foundation

/// Minimal auth client against the sync server (`POST /v1/auth/{login,register}` ->
/// bearer token), mirroring `@companion/core-bridge/auth`. Credentials go straight to the
/// user's server and never touch the Go core; only the resulting token does (via
/// `sync.configure`). E2EE-enabled accounts (prelogin/unlock) are a follow-up.
enum AuthClient {
    struct Result: Decodable { let token: String }
    enum Mode: String { case login, register }

    /// Argon2id KDF parameters the server publishes for an encrypted account.
    struct KDF: Codable { let time: Int; let memoryK: Int; let threads: Int }

    /// Pre-login lookup: whether the account is E2EE and, if so, the salt + KDF params to
    /// derive the login credential from the password (PLAN §E2EE).
    struct Prelogin: Decodable { let encrypted: Bool; let salt: String?; let kdf: KDF? }

    /// The account's wrapped key material, fetched after login to unlock the master key.
    struct KeyMaterial: Decodable {
        let wrappedMasterKey: String
        let kdfSalt: String
        let kdfTime: Int
        let kdfMemoryK: Int
        let kdfThreads: Int
    }

    /// `POST /v1/auth/{login,register}` with a credential (raw password for plaintext accounts,
    /// or the password-derived auth key for encrypted ones).
    static func authenticate(baseURL: String, mode: Mode, email: String, credential: String) async throws -> Result {
        try await post(baseURL, "auth/\(mode.rawValue)", body: ["email": email, "password": credential])
    }

    /// Ask the server how this account authenticates before sending anything.
    static func prelogin(baseURL: String, email: String) async throws -> Prelogin {
        try await post(baseURL, "auth/prelogin", body: ["email": email])
    }

    /// Request a password-reset email (cloud-only; open-core servers may 404). The server
    /// responds the same whether or not the address exists.
    static func forgotPassword(baseURL: String, email: String) async throws {
        guard let url = URL(string: "\(trimSlash(baseURL))/v1/auth/forgot") else { throw AuthError("Invalid server URL") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError(serverError(data) ?? "couldn't send reset email")
        }
    }

    /// Fetch the account's wrapped key material (nil when the account isn't encrypted; 404).
    static func fetchKeys(baseURL: String, token: String) async throws -> KeyMaterial? {
        guard let url = URL(string: "\(trimSlash(baseURL))/v1/keys") else { throw AuthError("Invalid server URL") }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw AuthError("No response from server") }
        if http.statusCode == 404 { return nil }
        guard (200..<300).contains(http.statusCode) else { throw AuthError(serverError(data) ?? "fetch keys failed (\(http.statusCode))") }
        return try JSONDecoder().decode(KeyMaterial.self, from: data)
    }

    /// Store the account's wrapped key material (used by encrypted registration).
    static func putKeys(baseURL: String, token: String, body: [String: Any]) async throws {
        guard let url = URL(string: "\(trimSlash(baseURL))/v1/keys") else { throw AuthError("Invalid server URL") }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError(serverError(data) ?? "put keys failed")
        }
    }

    private static func post<T: Decodable>(_ baseURL: String, _ path: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: "\(trimSlash(baseURL))/v1/\(path)") else { throw AuthError("Invalid server URL") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw AuthError("No response from server") }
        guard (200..<300).contains(http.statusCode) else { throw AuthError(serverError(data) ?? "request failed (\(http.statusCode))") }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func serverError(_ data: Data) -> String? {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
    }

    private static func trimSlash(_ url: String) -> String {
        url.hasSuffix("/") ? String(url.dropLast()) : url
    }

    struct AuthError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}

/// The sync connection, persisted on-device (like the RN shell's device-local sync config).
/// Applied to the core via `sync.configure` on launch so "Sync now" works across sessions.
struct SyncConfig: Codable {
    var baseURL: String
    var token: String
    var email: String

    private static let key = "companion.sync.config"

    static func load() -> SyncConfig? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SyncConfig.self, from: data)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }

    /// Point the core's sync engine at this server + token.
    @MainActor func apply(to core: CompanionCore) {
        _ = core.invokeJSON("sync.configure", ["baseUrl": baseURL, "token": token])
    }
}
