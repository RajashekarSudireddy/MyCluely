import Foundation
import CryptoKit
import Security
import CommonCrypto

public final class AuthStorage: @unchecked Sendable {
    public static let shared = AuthStorage()
    private let queue = DispatchQueue(label: "com.mycluely.authstorage")
    private let defaults: UserDefaults
    private let credentials: any CredentialStore
    private let accountsKey = "mycluely_registered_accounts_v1"
    private let secureAccountsKey = "registered_accounts_v2"
    private let activeSessionKey = "mycluely_active_session_email_v1"
    private let googleClientIdKey = "mycluely_google_oauth_client_id"
    private var migrated = false

    public init(defaults: UserDefaults = .standard, credentials: any CredentialStore = KeychainCredentialStore()) {
        self.defaults = defaults
        self.credentials = credentials
    }

    public func generateSalt() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw CredentialStorageError.unavailable
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    public func hashPassword(_ password: String, salt: String) throws -> String {
        let passwordBytes = Array(password.utf8)
        let saltBytes = Array(salt.utf8)
        guard !passwordBytes.isEmpty, !saltBytes.isEmpty else { throw AuthError.emptyFields }
        var output = [UInt8](repeating: 0, count: 32)
        let status = passwordBytes.withUnsafeBytes { passwordPointer in
            saltBytes.withUnsafeBytes { saltPointer in
                output.withUnsafeMutableBytes { outputPointer in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordPointer.baseAddress!.assumingMemoryBound(to: Int8.self), passwordBytes.count,
                        saltPointer.baseAddress!.assumingMemoryBound(to: UInt8.self), saltBytes.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 600_000,
                        outputPointer.baseAddress!.assumingMemoryBound(to: UInt8.self), 32)
                }
            }
        }
        guard status == kCCSuccess else { throw CredentialStorageError.unavailable }
        return "pbkdf2-sha256$600000$" + output.map { String(format: "%02x", $0) }.joined()
    }

    public func verifyPassword(_ password: String, salt: String, expectedHash: String) throws -> Bool {
        let computed: String
        if expectedHash.hasPrefix("pbkdf2-sha256$600000$") {
            computed = try hashPassword(password, salt: salt)
        } else if expectedHash.count == 64 && expectedHash.allSatisfy({ $0.isHexDigit }) {
            // Legacy hashes are upgraded after the next successful password login.
            computed = SHA256.hash(data: Data((salt + password).utf8)).map { String(format: "%02x", $0) }.joined()
        } else { return false }
        let a = Array(computed.utf8), b = Array(expectedHash.utf8)
        guard a.count == b.count else { return false }
        var difference: UInt8 = 0
        for index in a.indices { difference |= a[index] ^ b[index] }
        return difference == 0
    }

    /// Delete legacy preferences only after reading back the secure copy.
    /// Invalidate legacy sessions because old Google sign-in did not prove identity.
    private func migrateInternal() throws {
        guard !migrated else { return }
        if let legacy = defaults.data(forKey: accountsKey) {
            let old = try JSONDecoder().decode([String: StoredUserAccount].self, from: legacy)
            let currentData = try credentials.read(secureAccountsKey)
            let current = try currentData.map { try JSONDecoder().decode([String: StoredUserAccount].self, from: $0) } ?? [:]
            let merged = old.merging(current) { _, secure in secure }
            try writeVerified(secureAccountsKey, data: JSONEncoder().encode(merged))
            defaults.removeObject(forKey: accountsKey)
        }
        // Preserve unassigned legacy keys securely for owner recovery.
        // Never use these as a cross-account fallback.
        for key in ["mycluely_gemini_api_key", "audiohud_gemini_api_key", "mycluely_openai_api_key"] {
            if let legacy = defaults.string(forKey: key) {
                try writeVerified("legacy_" + key, data: Data(legacy.utf8))
                defaults.removeObject(forKey: key)
            }
        }
        if defaults.object(forKey: activeSessionKey) != nil {
            try credentials.remove("active_user_email")
            defaults.removeObject(forKey: activeSessionKey)
        }
        migrated = true
    }

    private func writeVerified(_ key: String, data: Data) throws {
        try credentials.write(key, data: data)
        guard try credentials.read(key) == data else { throw CredentialStorageError.unavailable }
    }

    private func loadAccountsInternal() throws -> [String: StoredUserAccount] {
        try migrateInternal()
        guard let data = try credentials.read(secureAccountsKey) else { return [:] }
        return try JSONDecoder().decode([String: StoredUserAccount].self, from: data)
    }

    public func loadAccounts() throws -> [String: StoredUserAccount] {
        try queue.sync { try loadAccountsInternal() }
    }

    public func saveAccount(_ account: StoredUserAccount) throws {
        try queue.sync {
            var accounts = try loadAccountsInternal()
            accounts[account.email.lowercased()] = account
            try writeVerified(secureAccountsKey, data: JSONEncoder().encode(accounts))
        }
    }

    public func getAccount(byEmail email: String) throws -> StoredUserAccount? {
        try loadAccounts()[email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }

    private func updateKey(email: String, apiKey: String, openAI: Bool) throws {
        try queue.sync {
            var accounts = try loadAccountsInternal()
            let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard var account = accounts[normalized] else { throw AuthError.userNotFound }
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if openAI { account.openaiApiKey = trimmed } else { account.geminiApiKey = trimmed }
            accounts[normalized] = account
            try writeVerified(secureAccountsKey, data: JSONEncoder().encode(accounts))
        }
    }

    public func updateGeminiApiKey(forEmail email: String, apiKey: String) throws {
        try updateKey(email: email, apiKey: apiKey, openAI: false)
    }

    public func updateOpenAIApiKey(forEmail email: String, apiKey: String) throws {
        try updateKey(email: email, apiKey: apiKey, openAI: true)
    }

    public func deleteAccount(email: String) throws {
        try queue.sync {
            var accounts = try loadAccountsInternal()
            accounts.removeValue(forKey: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            try writeVerified(secureAccountsKey, data: JSONEncoder().encode(accounts))
        }
    }

    public func saveActiveSession(email: String) throws {
        try queue.sync {
            try migrateInternal()
            try writeVerified("active_user_email", data: Data(email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().utf8))
            defaults.set(false, forKey: "mycluely_session_revoked")
        }
    }

    public func getActiveSessionEmail() throws -> String? {
        try queue.sync {
            try migrateInternal()
            guard !defaults.bool(forKey: "mycluely_session_revoked") else { return nil }
            return try credentials.read("active_user_email").flatMap { String(data: $0, encoding: .utf8) }
        }
    }

    public func clearActiveSession() throws {
        try queue.sync {
            // A non-identifying tombstone keeps sign-out effective if Keychain deletion fails.
            defaults.set(true, forKey: "mycluely_session_revoked")
            try credentials.remove("active_user_email")
            defaults.removeObject(forKey: activeSessionKey)
        }
    }

    // OAuth client IDs are public application identifiers, not credentials.
    public func getGoogleClientId() -> String { defaults.string(forKey: googleClientIdKey) ?? "" }
    public func saveGoogleClientId(_ clientId: String) {
        defaults.set(clientId.trimmingCharacters(in: .whitespacesAndNewlines), forKey: googleClientIdKey)
    }
}
