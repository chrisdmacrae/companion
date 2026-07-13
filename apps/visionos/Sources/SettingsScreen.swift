import SwiftUI

/// Settings sections shown in the persistent sidebar. Only Sync for now.
enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case sync

    var id: String { rawValue }
    var label: String {
        switch self {
        case .sync: "Sync"
        }
    }
    var symbol: String {
        switch self {
        case .sync: "arrow.triangle.2.circlepath"
        }
    }
}

/// The Settings tool: a persistent sidebar of sections on the window glass (no separate
/// panel material), with the selected section rendered on a white card. A custom sidebar
/// rather than NavigationSplitView so it shares the window glass and uses a dark selection.
struct SettingsScreen: View {
    let core: CompanionCore
    @State private var section: SettingsSection = .sync

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 260)
            ScrollView {
                detailContent
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Brand.surfaceCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .environment(\.colorScheme, .light)   // dark text/controls on the white card
            .padding(24)
        }
        .tint(Brand.accent)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(.largeTitle.bold())
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

            ForEach(SettingsSection.allCases) { item in
                Button { section = item } label: {
                    Label(item.label, systemImage: item.symbol)
                        .font(.body.weight(.medium))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            section == item ? AnyShapeStyle(Brand.gray900.opacity(0.55)) : AnyShapeStyle(.clear),
                            in: .rect(cornerRadius: 10)
                        )
                        .contentShape(.rect(cornerRadius: 10))
                        .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private var detailContent: some View {
        switch section {
        case .sync: SyncSettingsView(core: core)
        }
    }
}

/// Forgot-password entry point, presented as a sheet from Sync settings: requests a reset
/// email for the account address. Completing the reset (from the emailed link + recovery
/// code for E2EE accounts) is a follow-up.
private struct ForgotPasswordSheet: View {
    let baseURL: String
    let initialEmail: String
    let onDismiss: () -> Void

    @State private var email = ""
    @State private var busy = false
    @State private var note: String?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("We'll email a reset link to your account address. Open it on this device to choose a new password.")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Email").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    TextField("you@example.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if let note {
                    Label(note, systemImage: "checkmark.circle.fill").foregroundStyle(Brand.success)
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Brand.danger)
                }

                HStack(spacing: 12) {
                    Button {
                        Task { await send() }
                    } label: {
                        Text("Send reset link").frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(busy || email.isEmpty)
                    if busy { ProgressView() }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle("Forgot password")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onDismiss) }
            }
        }
        .frame(minWidth: 480, minHeight: 380)
        .tint(Brand.accent)
        .onAppear { email = initialEmail }
    }

    private func send() async {
        busy = true; error = nil; note = nil
        defer { busy = false }
        do {
            try await AuthClient.forgotPassword(baseURL: baseURL, email: email)
            note = "If that email has an account, a reset link is on its way."
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Sync settings: connect to a server + account, then sync on demand. Talks to the server's
/// auth endpoint directly for the token, then hands it to the core's `sync.configure`.
private struct SyncSettingsView: View {
    let core: CompanionCore

    private static let defaultBaseURL = "https://portal.companionapp.cloud/api"

    @State private var serverURL = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    @State private var connection: SyncConfig?
    @State private var syncStatus: String?
    @State private var recoveryCode: String?
    @State private var showForgot = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Sync")
                .font(.largeTitle.bold())
                .foregroundStyle(Brand.textPrimary)

            if let recoveryCode {
                recoveryBanner(recoveryCode)
            }

            if let connection {
                connectedView(connection)
            } else {
                signInForm
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(Brand.danger)
            }
        }
        .frame(maxWidth: 560, alignment: .leading)
        .tint(Brand.accent)
        .onAppear { connection = SyncConfig.load() }
        .sheet(isPresented: $showForgot) {
            ForgotPasswordSheet(baseURL: resolvedBaseURL(), initialEmail: email) { showForgot = false }
        }
    }

    // MARK: Connected

    @ViewBuilder private func connectedView(_ config: SyncConfig) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(config.email.isEmpty ? "Connected" : config.email, systemImage: "checkmark.seal.fill")
                .foregroundStyle(Brand.success)
                .font(.headline)
            Text(config.baseURL)
                .font(.subheadline)
                .foregroundStyle(Brand.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.surfaceSunken, in: RoundedRectangle(cornerRadius: 14))

        if let syncStatus {
            Text(syncStatus).font(.callout).foregroundStyle(Brand.textSecondary)
        }

        HStack(spacing: 12) {
            Button {
                Task { await syncNow() }
            } label: {
                Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .disabled(busy)

            Button { signOut() } label: {
                Text("Sign out")
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.danger)   // red button, white text (not red text)
            .disabled(busy)

            if busy { ProgressView() }
        }
    }

    // MARK: Sign in

    @ViewBuilder private var signInForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            field("Server URL", text: $serverURL, placeholder: Self.defaultBaseURL, secure: false)
                .textInputAutocapitalization(.never)
            field("Email", text: $email, placeholder: "you@example.com", secure: false)
                .textInputAutocapitalization(.never)
            field("Password", text: $password, placeholder: "Password", secure: true)
        }

        HStack(spacing: 12) {
            Button {
                Task { await connect(.login) }
            } label: {
                Text("Sign in").frame(minWidth: 90)
            }
            .buttonStyle(.borderedProminent)
            .disabled(busy || email.isEmpty || password.isEmpty)

            Button {
                Task { await connect(.register) }
            } label: {
                Text("Create account")
            }
            .disabled(busy || email.isEmpty || password.isEmpty)

            if busy { ProgressView() }
        }

        Button("Forgot password?") { showForgot = true }
            .buttonStyle(.plain)
            .font(.subheadline)
            .foregroundStyle(Brand.accent)

        Text("Leave the server URL blank to use the hosted cloud.")
            .font(.footnote)
            .foregroundStyle(Brand.textTertiary)
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.medium)).foregroundStyle(Brand.textSecondary)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
        }
    }

    // MARK: Actions

    @MainActor private func connect(_ mode: AuthClient.Mode) async {
        busy = true; error = nil
        defer { busy = false }
        let baseURL = resolvedBaseURL()
        do {
            let token = mode == .register
                ? try await registerEncrypted(baseURL)
                : try await login(baseURL)
            try core.invoke("sync.configure", args: ["baseUrl": baseURL, "token": token])
            let config = SyncConfig(baseURL: baseURL, token: token, email: email)
            config.save()
            password = ""
            connection = config
            await syncNow()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func resolvedBaseURL() -> String {
        let trimmed = serverURL.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? Self.defaultBaseURL : trimmed
    }

    /// Encrypted-account login (PLAN §E2EE): the raw password never authenticates. Prelogin
    /// reveals the KDF params; the core derives the login credential and unlocks the master
    /// key from the fetched wrapped key. Plaintext accounts log in with the raw password.
    @MainActor private func login(_ baseURL: String) async throws -> String {
        let pre = try await AuthClient.prelogin(baseURL: baseURL, email: email)
        guard pre.encrypted, let salt = pre.salt, let kdf = pre.kdf else {
            return try await AuthClient.authenticate(baseURL: baseURL, mode: .login, email: email, credential: password).token
        }
        let derived: AuthKeyResult = try core.invoke("crypto.deriveAuthKey", args: [
            "password": password, "salt": salt,
            "kdf": ["time": kdf.time, "memoryK": kdf.memoryK, "threads": kdf.threads],
        ], as: AuthKeyResult.self)
        let result = try await AuthClient.authenticate(baseURL: baseURL, mode: .login, email: email, credential: derived.authKeyHex)
        if let km = try await AuthClient.fetchKeys(baseURL: baseURL, token: result.token) {
            try core.invoke("crypto.unlock", args: [
                "password": password,
                "wrappedMasterKey": km.wrappedMasterKey,
                "salt": km.kdfSalt,
                "kdf": ["time": km.kdfTime, "memoryK": km.kdfMemoryK, "threads": km.kdfThreads],
            ])
        }
        return result.token
    }

    /// New accounts are end-to-end encrypted: set up keys locally, register with the derived
    /// auth key (server never sees the password), upload the wrapped key, and surface the
    /// one-time recovery code.
    @MainActor private func registerEncrypted(_ baseURL: String) async throws -> String {
        let setup: CryptoSetup = try core.invoke("crypto.setup", args: ["password": password], as: CryptoSetup.self)
        let result = try await AuthClient.authenticate(baseURL: baseURL, mode: .register, email: email, credential: setup.authKeyHex)
        try await AuthClient.putKeys(baseURL: baseURL, token: result.token, body: [
            "wrappedMasterKey": setup.wrappedMasterKey,
            "kdfSalt": setup.salt,
            "kdfTime": setup.kdf.time,
            "kdfMemoryK": setup.kdf.memoryK,
            "kdfThreads": setup.kdf.threads,
            "recoveryWrapped": setup.recoveryWrapped,
        ])
        recoveryCode = setup.recoveryCode
        return result.token
    }

    private struct AuthKeyResult: Decodable { let authKeyHex: String }
    private struct CryptoSetup: Decodable {
        let authKeyHex, salt, wrappedMasterKey, recoveryWrapped, recoveryCode: String
        let kdf: AuthClient.KDF
    }

    @ViewBuilder private func recoveryBanner(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Save your recovery code", systemImage: "key.fill").font(.headline).foregroundStyle(Brand.textPrimary)
            Text("It's the only way to recover an encrypted account if you forget your password. It won't be shown again.")
                .font(.footnote).foregroundStyle(Brand.textSecondary)
            Text(code).font(.title3.monospaced().bold()).foregroundStyle(Brand.accentActive).textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.accentSoft, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Brand.accentSoftBorder))
    }

    @MainActor private func syncNow() async {
        busy = true; error = nil; syncStatus = "Syncing…"
        defer { busy = false }
        do {
            _ = try core.invoke("sync.run")
            syncStatus = "Last synced \(Date().formatted(date: .omitted, time: .shortened))"
        } catch {
            syncStatus = nil
            self.error = error.localizedDescription
        }
    }

    private func signOut() {
        SyncConfig.clear()
        connection = nil
        syncStatus = nil
        error = nil
    }
}
