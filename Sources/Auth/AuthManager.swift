import Foundation
import SwiftUI
import Combine

@MainActor
public final class AuthManager: ObservableObject {
    public static let shared = AuthManager()
    
    @Published public var currentUser: UserProfile?
    @Published public var isAuthenticated: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var showGoogleSheet: Bool = false
    
    public var onAuthStateChanged: ((Bool) -> Void)?
    
    public private(set) var sessionID = UUID()

    private let storage: AuthStorage
    private let updatesAppState: Bool
    
    public init(storage: AuthStorage = .shared, updatesAppState: Bool = true) {
        self.storage = storage
        self.updatesAppState = updatesAppState
        do {
            if let email = try storage.getActiveSessionEmail(),
               let account = try storage.getAccount(byEmail: email) {
                self.currentUser = account.toProfile()
                self.isAuthenticated = true
                self.sessionID = UUID()
            }
        } catch {
            self.errorMessage = CredentialStorageError.unavailable.localizedDescription
        }
    }

    public func needsApiKey(for provider: AIProvider) -> Bool {
        guard isAuthenticated else { return false }
        switch provider {
        case .gemini:
            let key = currentUser?.geminiApiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return key.isEmpty
        case .openAI:
            let key = currentUser?.openaiApiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return key.isEmpty
        }
    }
    
    public var needsApiKey: Bool {
        guard isAuthenticated else { return false }
        let providerRaw = UserDefaults.standard.string(forKey: "mycluely_ai_provider")
        let provider = providerRaw.flatMap { AIProvider(rawValue: $0) } ?? .gemini
        return needsApiKey(for: provider)
    }
    
    // MARK: - Session Restoration
    
    public func restoreSession() {
        do {
            guard let email = try storage.getActiveSessionEmail(),
                  let account = try storage.getAccount(byEmail: email) else {
                currentUser = nil
                isAuthenticated = false
                return
            }
            currentUser = account.toProfile()
            isAuthenticated = true
            sessionID = UUID()
            if updatesAppState {
                AppState.shared.apiKey = account.geminiApiKey ?? ""
                AppState.shared.openAIApiKey = account.openaiApiKey ?? ""
            }
        } catch {
            currentUser = nil
            isAuthenticated = false
            errorMessage = CredentialStorageError.unavailable.localizedDescription
        }
    }

    // MARK: - Email / Password Sign Up
    
    public func signUpWithEmail(
        email: String,
        password: String,
        confirmPassword: String,
        displayName: String
    ) async throws {
        self.errorMessage = nil
        self.isLoading = true
        defer { self.isLoading = false }
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            let error = AuthError.emptyFields
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard isValidEmail(trimmedEmail) else {
            let error = AuthError.invalidEmail
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard password.count >= 12 else {
            let error = AuthError.passwordTooShort
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard password == confirmPassword else {
            let error = AuthError.passwordMismatch
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        if try storage.getAccount(byEmail: trimmedEmail) != nil {
            let error = AuthError.userAlreadyExists
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        // Generate cryptographic salt and hash
        let salt = try storage.generateSalt()
        let hash = try storage.hashPassword(password, salt: salt)
        
        let newAccount = StoredUserAccount(
            email: trimmedEmail,
            displayName: trimmedName.isEmpty ? trimmedEmail.components(separatedBy: "@").first ?? "User" : trimmedName,
            authProvider: .emailPassword,
            passwordHash: hash,
            salt: salt
        )
        
        try storage.saveAccount(newAccount)
        try storage.saveActiveSession(email: trimmedEmail)
        
        let profile = newAccount.toProfile()
        self.currentUser = profile
        self.isAuthenticated = true
        self.sessionID = UUID()
        self.errorMessage = nil
        self.onAuthStateChanged?(true)
    }
    
    // MARK: - Email / Password Sign In
    
    public func signInWithEmail(email: String, password: String) async throws {
        self.errorMessage = nil
        self.isLoading = true
        defer { self.isLoading = false }
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            let error = AuthError.emptyFields
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard isValidEmail(trimmedEmail) else {
            let error = AuthError.invalidEmail
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard var account = try storage.getAccount(byEmail: trimmedEmail) else {
            let error = AuthError.userNotFound
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        if account.authProvider == .google && account.passwordHash == nil {
            let error = AuthError.googleAuthFailed("This account is registered with Google. Please use 'Continue with Google'.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard let salt = account.salt, let expectedHash = account.passwordHash else {
            let error = AuthError.incorrectPassword
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard try storage.verifyPassword(password, salt: salt, expectedHash: expectedHash) else {
            let error = AuthError.incorrectPassword
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        if !expectedHash.hasPrefix("pbkdf2-sha256$") {
            account.salt = try storage.generateSalt()
            account.passwordHash = try storage.hashPassword(password, salt: account.salt!)
        }
        account.lastLoginAt = Date()
        try storage.saveAccount(account)
        try storage.saveActiveSession(email: trimmedEmail)
        
        let profile = account.toProfile()
        self.currentUser = profile
        self.isAuthenticated = true
        self.sessionID = UUID()
        if updatesAppState {
            AppState.shared.apiKey = account.geminiApiKey ?? ""
            AppState.shared.openAIApiKey = account.openaiApiKey ?? ""
        }
        self.errorMessage = nil
        self.onAuthStateChanged?(true)
    }
    
    // MARK: - Google Sign-In & Sign-Up
    
    public func authenticateWithGoogle(identity: GoogleUserIdentity) throws {
        let trimmedEmail = identity.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let finalDisplayName = identity.displayName.isEmpty
            ? (trimmedEmail.components(separatedBy: "@").first ?? "Google User")
            : identity.displayName
        
        var account: StoredUserAccount
        if var existing = try storage.getAccount(byEmail: trimmedEmail) {
            guard existing.authProvider == .google,
                  existing.googleSubjectId == identity.subjectId else {
                throw AuthError.googleAuthFailed("This email belongs to a different local account. Sign in with its original method.")
            }
            // Only the same verified Google subject can restore an account.
            existing.lastLoginAt = Date()
            if existing.displayName.isEmpty || existing.displayName == existing.email {
                existing.displayName = finalDisplayName
            }
            if let avatar = identity.avatarUrl {
                existing.avatarUrl = avatar
            }
            try storage.saveAccount(existing)
            account = existing
        } else {
            // New user signing up with Google
            account = StoredUserAccount(
                email: trimmedEmail,
                displayName: finalDisplayName,
                avatarUrl: identity.avatarUrl,
                authProvider: .google,
                googleSubjectId: identity.subjectId
            )
            try storage.saveAccount(account)
        }
        
        try storage.saveActiveSession(email: trimmedEmail)
        self.currentUser = account.toProfile()
        self.isAuthenticated = true
        self.sessionID = UUID()
        if updatesAppState {
            AppState.shared.apiKey = account.geminiApiKey ?? ""
            AppState.shared.openAIApiKey = account.openaiApiKey ?? ""
        }
        self.errorMessage = nil
        self.onAuthStateChanged?(true)
    }
    
    // MARK: - Per-User Gemini API Key
    
    public func saveGeminiApiKey(_ apiKey: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let email = currentUser?.email else { throw AuthError.unauthenticated }
        try storage.updateGeminiApiKey(forEmail: email, apiKey: trimmed)
        currentUser?.geminiApiKey = trimmed
        if updatesAppState { AppState.shared.apiKey = trimmed }
        objectWillChange.send()
    }
    
    // MARK: - Per-User OpenAI API Key
    
    public func saveOpenAIApiKey(_ apiKey: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let email = currentUser?.email else { throw AuthError.unauthenticated }
        try storage.updateOpenAIApiKey(forEmail: email, apiKey: trimmed)
        currentUser?.openaiApiKey = trimmed
        if updatesAppState { AppState.shared.openAIApiKey = trimmed }
        objectWillChange.send()
    }
    
    // MARK: - Sign Out
    
    public func signOut() {
        do { try storage.clearActiveSession() }
        catch { self.errorMessage = CredentialStorageError.unavailable.localizedDescription }
        self.sessionID = UUID()
        self.currentUser = nil
        self.isAuthenticated = false
        if updatesAppState {
            AppState.shared.apiKey = ""
            AppState.shared.openAIApiKey = ""
            AppState.shared.liveTranscript = ""
            AppState.shared.activeQA = nil
            AppState.shared.clearHistory()
            AppState.shared.isListening = false
            SpeechTranscriber.shared.stop()
            GeminiLiveClient.shared.stop()
            OpenAILiveClient.shared.stop()
            Task { await AudioManager.shared.stop() }
        }
        self.onAuthStateChanged?(false)
    }
    
    // MARK: - Validation
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}
