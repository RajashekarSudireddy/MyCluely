import Foundation

public enum AuthProvider: String, Codable, CaseIterable, Identifiable {
    case emailPassword = "Email & Password"
    case google = "Google"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .emailPassword:
            return "envelope.fill"
        case .google:
            return "g.circle.fill"
        }
    }
}

public struct UserProfile: Codable, Identifiable, Equatable {
    public let id: String
    public var email: String
    public var displayName: String
    public var avatarUrl: String?
    public let authProvider: AuthProvider
    public var geminiApiKey: String?
    public var openaiApiKey: String?
    public let createdAt: Date
    public var lastLoginAt: Date
    
    public init(
        id: String = UUID().uuidString,
        email: String,
        displayName: String,
        avatarUrl: String? = nil,
        authProvider: AuthProvider,
        geminiApiKey: String? = nil,
        openaiApiKey: String? = nil,
        createdAt: Date = Date(),
        lastLoginAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.authProvider = authProvider
        self.geminiApiKey = geminiApiKey
        self.openaiApiKey = openaiApiKey
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
    }
}

public struct StoredUserAccount: Codable, Identifiable {
    public let id: String
    public var email: String
    public var displayName: String
    public var avatarUrl: String?
    public let authProvider: AuthProvider
    public var passwordHash: String?
    public var salt: String?
    public var googleSubjectId: String?
    public var geminiApiKey: String?
    public var openaiApiKey: String?
    public let createdAt: Date
    public var lastLoginAt: Date
    
    public init(
        id: String = UUID().uuidString,
        email: String,
        displayName: String,
        avatarUrl: String? = nil,
        authProvider: AuthProvider,
        passwordHash: String? = nil,
        salt: String? = nil,
        googleSubjectId: String? = nil,
        geminiApiKey: String? = nil,
        openaiApiKey: String? = nil,
        createdAt: Date = Date(),
        lastLoginAt: Date = Date()
    ) {
        self.id = id
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.avatarUrl = avatarUrl
        self.authProvider = authProvider
        self.passwordHash = passwordHash
        self.salt = salt
        self.googleSubjectId = googleSubjectId
        self.geminiApiKey = geminiApiKey
        self.openaiApiKey = openaiApiKey
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
    }
    
    public func toProfile() -> UserProfile {
        return UserProfile(
            id: id,
            email: email,
            displayName: displayName.isEmpty ? email : displayName,
            avatarUrl: avatarUrl,
            authProvider: authProvider,
            geminiApiKey: geminiApiKey,
            openaiApiKey: openaiApiKey,
            createdAt: createdAt,
            lastLoginAt: lastLoginAt
        )
    }
}

public enum AuthError: LocalizedError, Equatable {
    case emptyFields
    case invalidEmail
    case passwordTooShort
    case passwordMismatch
    case userAlreadyExists
    case userNotFound
    case incorrectPassword
    case googleAuthFailed(String)
    case googleAuthCancelled
    case unauthenticated
    
    public var errorDescription: String? {
        switch self {
        case .emptyFields:
            return "Please fill in all required fields."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .passwordTooShort:
            return "Password must be at least 12 characters."
        case .passwordMismatch:
            return "Passwords do not match. Please verify."
        case .userAlreadyExists:
            return "An account with this email already exists. Please sign in."
        case .userNotFound:
            return "No account found with this email. Please sign up."
        case .incorrectPassword:
            return "Incorrect password. Please try again."
        case .googleAuthFailed(let reason):
            return "Google Sign-In failed: \(reason)"
        case .googleAuthCancelled:
            return "Google Sign-In was cancelled."
        case .unauthenticated:
            return "Please sign in to unlock MyCluely."
        }
    }
}
