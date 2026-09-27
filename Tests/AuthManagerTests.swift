import Foundation
import CryptoKit

final class MemoryCredentials: CredentialStore, @unchecked Sendable {
    var values: [String: Data] = [:]
    var failWrites = false
    var failReads = false
    var failRemovals = false
    func read(_ key: String) throws -> Data? {
        if failReads { throw CredentialStorageError.unavailable }
        return values[key]
    }
    func write(_ key: String, data: Data) throws {
        if failWrites { throw CredentialStorageError.unavailable }
        values[key] = data
    }
    func remove(_ key: String) throws {
        if failRemovals { throw CredentialStorageError.unavailable }
        values.removeValue(forKey: key)
    }
}

@main
struct AuthManagerTestsRunner {
    static func check(_ value: Bool, _ message: String) {
        precondition(value, message)
    }

    @MainActor
    static func main() async throws {
        let suiteName = "com.mycluely.security-tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let credentials = MemoryCredentials()
        let storage = AuthStorage(defaults: defaults, credentials: credentials)
        let manager = AuthManager(storage: storage, updatesAppState: false)
        let email = "tester@example.com"
        let password = "fixture-password-only"
        let salt = try storage.generateSalt()
        check(try salt.count == 32 && salt != storage.generateSalt(), "Unique 128-bit salts")
        let hash = try storage.hashPassword(password, salt: salt)
        check(hash.hasPrefix("pbkdf2-sha256$600000$"), "Slow password KDF")
        check(try storage.verifyPassword(password, salt: salt, expectedHash: hash), "Valid password")
        check(try !storage.verifyPassword("wrong-password", salt: salt, expectedHash: hash), "Reject wrong password")
        try await manager.signUpWithEmail(email: email, password: password, confirmPassword: password, displayName: "Test User")
        check(manager.isAuthenticated, "Sign-up succeeds after secure persistence")
        try manager.saveGeminiApiKey("mock-gemini-key")
        try manager.saveOpenAIApiKey("mock-openai-key")
        check(defaults.data(forKey: "mycluely_registered_accounts_v1") == nil, "No plaintext accounts")
        check(defaults.string(forKey: "mycluely_openai_api_key") == nil, "No plaintext provider key")
        check(defaults.string(forKey: "mycluely_active_session_email_v1") == nil, "No plaintext session")
        manager.signOut()
        check(try !manager.isAuthenticated && storage.getActiveSessionEmail() == nil, "Sign-out clears secure session")
        try await manager.signInWithEmail(email: email, password: password)
        check(manager.currentUser?.openaiApiKey == "mock-openai-key", "Per-account key restoration")
        do {
            try manager.authenticateWithGoogle(identity: GoogleUserIdentity(email: email, displayName: "Other", subjectId: "mock-subject"))
            preconditionFailure("Google must not auto-link an email/password account")
        } catch AuthError.googleAuthFailed { }
        let google = GoogleUserIdentity(email: "google@example.com", displayName: "Google Test", subjectId: "mock-subject")
        try manager.authenticateWithGoogle(identity: google)
        check(manager.needsApiKey(for: .openAI), "Keys do not leak to another account")
        do {
            try manager.authenticateWithGoogle(identity: GoogleUserIdentity(email: google.email, displayName: "Other", subjectId: "different-subject"))
            preconditionFailure("Google subject mismatch must be rejected")
        } catch AuthError.googleAuthFailed { }
        credentials.failWrites = true
        do {
            try manager.saveOpenAIApiKey("mock-unsaved-key")
            preconditionFailure("Secure persistence failures must reach caller")
        } catch CredentialStorageError.unavailable { }
        check(manager.currentUser?.openaiApiKey == nil, "Failed write must not report a saved key")
        credentials.failWrites = false
        credentials.failReads = true
        do {
            try storage.saveAccount(StoredUserAccount(email: "new@example.com", displayName: "New", authProvider: .emailPassword))
            preconditionFailure("Unreadable secure accounts must not be overwritten")
        } catch CredentialStorageError.unavailable { }
        credentials.failReads = false
        credentials.failRemovals = true
        manager.signOut()
        check(try storage.getActiveSessionEmail() == nil, "Revocation survives failed Keychain deletion")
        let relaunch = AuthManager(storage: storage, updatesAppState: false)
        check(!relaunch.isAuthenticated, "A failed deletion must not restore a revoked session")
        credentials.failRemovals = false
        print("PASS: hashing, account isolation, failed reads/writes/deletion, Google account binding, secure sessions")

        let legacySuiteName = suiteName + ".migration"
        let legacyDefaults = UserDefaults(suiteName: legacySuiteName)!
        defer { legacyDefaults.removePersistentDomain(forName: legacySuiteName) }
        let legacyHash = SHA256.hash(data: Data((salt + password).utf8)).map { String(format: "%02x", $0) }.joined()
        let account = StoredUserAccount(email: email, displayName: "Legacy", authProvider: .emailPassword,
                                       passwordHash: legacyHash, salt: salt, openaiApiKey: "mock-legacy-key")
        let legacyData = try JSONEncoder().encode([email: account])
        legacyDefaults.set(legacyData, forKey: "mycluely_registered_accounts_v1")
        legacyDefaults.set(email, forKey: "mycluely_active_session_email_v1")
        legacyDefaults.set("mock-legacy-key", forKey: "mycluely_openai_api_key")
        let legacyCredentials = MemoryCredentials()
        legacyCredentials.failWrites = true
        let migrated = AuthStorage(defaults: legacyDefaults, credentials: legacyCredentials)
        do { _ = try migrated.loadAccounts(); preconditionFailure("Failed migration") }
        catch CredentialStorageError.unavailable { }
        check(legacyDefaults.data(forKey: "mycluely_registered_accounts_v1") == legacyData, "Failure preserves legacy copy")
        legacyCredentials.failWrites = false
        check(try migrated.getAccount(byEmail: email)?.openaiApiKey == "mock-legacy-key", "Migration preserves account credentials")
        check(legacyDefaults.data(forKey: "mycluely_registered_accounts_v1") == nil, "Successful migration removes plaintext")
        check(legacyDefaults.string(forKey: "mycluely_openai_api_key") == nil, "Successful migration removes legacy global key")
        check(try migrated.getActiveSessionEmail() == nil, "Invalidate unverified legacy sessions")
        let legacyManager = AuthManager(storage: migrated, updatesAppState: false)
        try await legacyManager.signInWithEmail(email: email, password: password)
        check(try migrated.getAccount(byEmail: email)?.passwordHash?.hasPrefix("pbkdf2-sha256$") == true, "Upgrade legacy hash after verified login")
        print("PASS: migration rollback, legacy cleanup, legacy hash upgrade")

        let scheme = "com.example.oauth"
        let valid = URL(string: "com.example.oauth:/oauth2callback?state=expected&code=mock-code")!
        check(try GoogleOAuthService.validateCallback(valid, scheme: scheme, expectedState: "expected") == "mock-code", "Valid OAuth state")
        for invalid in ["com.example.oauth:/oauth2callback?state=wrong&code=mock-code",
                        "com.example.oauth:/oauth2callback?state=expected&state=expected&code=mock-code",
                        "com.example.oauth:/wrong?state=expected&code=mock-code",
                        "com.other.oauth:/oauth2callback?state=expected&code=mock-code",
                        "com.example.oauth:/oauth2callback?state=expected&error=denied"] {
            do {
                _ = try GoogleOAuthService.validateCallback(URL(string: invalid)!, scheme: scheme, expectedState: "expected")
                preconditionFailure("Reject malformed or unsolicited callback")
            } catch AuthError.googleAuthFailed { }
        }
        print("PASS: OAuth callback scheme/path/state/error validation")
    }
}
