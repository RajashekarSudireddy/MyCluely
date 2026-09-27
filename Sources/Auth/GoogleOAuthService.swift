import Foundation
import AuthenticationServices
import CryptoKit
import AppKit

public struct GoogleUserIdentity {
    public let email: String
    public let displayName: String
    public let avatarUrl: String?
    public let subjectId: String
    
    public init(email: String, displayName: String, avatarUrl: String? = nil, subjectId: String = UUID().uuidString) {
        self.email = email
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.subjectId = subjectId
    }
}

@MainActor
public final class GoogleOAuthService: NSObject, ASWebAuthenticationPresentationContextProviding {
    public static let shared = GoogleOAuthService()
    
    private var currentSession: ASWebAuthenticationSession?
    
    private override init() {
        super.init()
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let keyWindow = NSApp.keyWindow {
            return keyWindow
        }
        if let firstWindow = NSApp.windows.first {
            return firstWindow
        }
        return ASPresentationAnchor()
    }
    
    // MARK: - PKCE Helpers
    
    public func generateCodeVerifier() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw CredentialStorageError.unavailable
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
    
    public func generateCodeChallenge(verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
    
    // MARK: - Real Google OAuth 2.0 PKCE Flow
    
    public func authenticateWithGoogleOAuth(clientId: String) async throws -> GoogleUserIdentity {
        let verifier = try generateCodeVerifier()
        let challenge = generateCodeChallenge(verifier: verifier)
        let state = UUID().uuidString
        let suffix = ".apps.googleusercontent.com"
        guard clientId.hasSuffix(suffix), clientId.count > suffix.count,
              clientId.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == ".") }) else {
            throw AuthError.googleAuthFailed("Enter a valid Google iOS/macOS OAuth client ID.")
        }
        guard currentSession == nil else {
            throw AuthError.googleAuthFailed("A Google sign-in is already in progress.")
        }
        let callbackScheme = "com.googleusercontent.apps." + clientId.dropLast(suffix.count)
        let redirectUri = "\(callbackScheme):/oauth2callback"
        defer { currentSession = nil }
        
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid profile email"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "select_account")
        ]
        
        guard let authUrl = components.url else {
            throw AuthError.googleAuthFailed("Could not construct authorization URL.")
        }
        
        // Run ASWebAuthenticationSession
        let callbackUrl: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authUrl,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: AuthError.googleAuthCancelled)
                    return
                } else if error != nil {
                    continuation.resume(throwing: AuthError.googleAuthFailed("Browser authentication failed."))
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: AuthError.googleAuthFailed("No redirect URL received."))
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.currentSession = session
            
            if !session.start() {
                continuation.resume(throwing: AuthError.googleAuthFailed("Failed to start web authentication session."))
            }
        }
        
        let authCode = try Self.validateCallback(callbackUrl, scheme: callbackScheme, expectedState: state)

        // Exchange code for token and fetch profile
        return try await exchangeCodeAndFetchUser(authCode: authCode, clientId: clientId, verifier: verifier, redirectUri: redirectUri)
    }
    
    public static func validateCallback(_ callback: URL, scheme: String, expectedState: String) throws -> String {
        guard callback.scheme == scheme, callback.host == nil,
              callback.path == "/oauth2callback", callback.fragment == nil,
              let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems,
              items.filter({ $0.name == "state" }).count == 1,
              items.first(where: { $0.name == "state" })?.value == expectedState else {
            throw AuthError.googleAuthFailed("Invalid Google sign-in callback.")
        }
        guard !items.contains(where: { $0.name == "error" }),
              items.filter({ $0.name == "code" }).count == 1,
              let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw AuthError.googleAuthFailed("Google sign-in was not authorized.")
        }
        return code
    }

    private func exchangeCodeAndFetchUser(
        authCode: String,
        clientId: String,
        verifier: String,
        redirectUri: String
    ) async throws -> GoogleUserIdentity {
        let tokenUrl = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenUrl)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params: [String: String] = [
            "code": authCode,
            "client_id": clientId,
            "code_verifier": verifier,
            "redirect_uri": redirectUri,
            "grant_type": "authorization_code"
        ]
        
        let bodyString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")) ?? $0.value)" }
            .joined(separator: "&")
        request.httpBody = Data(bodyString.utf8)
        
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.googleAuthFailed("Google token exchange failed.")
        }
        
        struct TokenResponse: Decodable {
            let access_token: String?
            let id_token: String?
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let accessToken = tokenResponse.access_token else {
            throw AuthError.googleAuthFailed("Missing access token in Google response.")
        }
        
        // Fetch User Info
        let userInfoUrl = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!
        var userRequest = URLRequest(url: userInfoUrl)
        userRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (userData, userResponse) = try await session.data(for: userRequest)
        guard let userHttp = userResponse as? HTTPURLResponse, (200...299).contains(userHttp.statusCode) else {
            throw AuthError.googleAuthFailed("Failed to fetch Google user profile.")
        }
        
        struct GoogleProfile: Decodable {
            let sub: String
            let email: String
            let email_verified: Bool
            let name: String?
            let picture: String?
        }
        
        let profile = try JSONDecoder().decode(GoogleProfile.self, from: userData)
        guard profile.email_verified, !profile.sub.isEmpty else {
            throw AuthError.googleAuthFailed("Google did not verify this account's email address.")
        }
        return GoogleUserIdentity(
            email: profile.email,
            displayName: profile.name ?? profile.email,
            avatarUrl: profile.picture,
            subjectId: profile.sub
        )
    }
}
