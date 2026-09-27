import SwiftUI
import AppKit

public struct GoogleLogoView: View {
    public var size: CGFloat = 16
    
    public init(size: CGFloat = 16) {
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: size, height: size)
            
            // Clean high-res vector-inspired Google G
            HStack(spacing: 0) {
                Text("G")
                    .font(.system(size: size * 0.78, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.26, green: 0.52, blue: 0.96), // Google Blue
                                Color(red: 0.92, green: 0.26, blue: 0.21), // Google Red
                                Color(red: 0.98, green: 0.74, blue: 0.02), // Google Yellow
                                Color(red: 0.20, green: 0.66, blue: 0.33)  // Google Green
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .frame(width: size, height: size)
    }
}

public struct GoogleSignInSheet: View {
    @ObservedObject var authManager: AuthManager = .shared
    @Binding var isPresented: Bool
    
    @State private var inputClientId: String = AuthStorage.shared.getGoogleClientId()
    @State private var showClientIdConfig: Bool = false
    @State private var isAuthenticating: Bool = false
    @State private var localError: String? = nil
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    GoogleLogoView(size: 20)
                    Text("Sign in with Google")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            
            Text("Choose an account to continue to MyCluely")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let error = localError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 11))
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.12))
                .cornerRadius(6)
            }
            
            // Real OAuth 2.0 PKCE with Google Cloud
            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    withAnimation { showClientIdConfig.toggle() }
                }) {
                    HStack {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10.5))
                        Text(showClientIdConfig ? "Hide Google Client ID settings" : "Google Cloud OAuth Client ID")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Image(systemName: showClientIdConfig ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                if showClientIdConfig {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Configure your Google OAuth 2.0 iOS/macOS Client ID:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        TextField("Your client ID from Google Cloud", text: $inputClientId)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10.5, design: .monospaced))
                            .padding(6)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .onChange(of: inputClientId) { _, newValue in
                                AuthStorage.shared.saveGoogleClientId(newValue)
                            }
                        
                        Button(action: startRealGoogleOAuth) {
                            HStack {
                                Image(systemName: "safari.fill")
                                Text("Launch Browser Google Sign-In")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Theme.accentColor.opacity(0.2))
                            .foregroundColor(Theme.accentColor)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(inputClientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                Theme.hudBackground
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .stroke(Theme.borderStroke, lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 20, y: 10)
        .frame(width: 360)
    }
    
    private func startRealGoogleOAuth() {
        localError = nil
        let clientId = inputClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientId.isEmpty else {
            localError = "Please enter a valid Google Client ID."
            return
        }
        
        isAuthenticating = true
        Task {
            do {
                let identity = try await GoogleOAuthService.shared.authenticateWithGoogleOAuth(clientId: clientId)
                try await MainActor.run {
                    try authManager.authenticateWithGoogle(identity: identity)
                    isAuthenticating = false
                    withAnimation {
                        isPresented = false
                    }
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    localError = error.localizedDescription
                }
            }
        }
    }
}
