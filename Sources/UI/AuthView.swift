import SwiftUI
import AppKit

public struct AuthView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var authManager: AuthManager = .shared
    
    public enum AuthTab: String, CaseIterable, Identifiable {
        case signIn = "Sign In"
        case signUp = "Create Account"
        
        public var id: String { rawValue }
    }
    
    @State private var activeTab: AuthTab = .signIn
    @State private var email: String = ""
    @State private var displayName: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if authManager.showGoogleSheet {
                GoogleSignInSheet(isPresented: $authManager.showGoogleSheet)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
            } else {
                authCardContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: authManager.showGoogleSheet)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: activeTab)
    }
    
    // MARK: - Auth Card Content
    
    private var authCardContent: some View {
        VStack(spacing: 14) {
            // Header
            headerSection
            
            // Tab Selector
            tabSelector
            
            // Error Message Banner
            if let error = authManager.errorMessage {
                errorMessageBanner(error)
            }
            
            // Form Fields
            inputFields
            
            // Primary Action Button
            primaryActionButton
            
            // Divider
            dividerSection
            
            // Google Sign-In / Sign-Up Button
            googleAuthButton
            
            // Footer switch
            footerToggle
        }
        .padding(16)
        .frame(width: 372)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Theme.accentColor.opacity(0.18))
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text("MyCluely")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("PROTECTED")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Theme.accentColor.opacity(0.18))
                            .foregroundColor(Theme.accentColor)
                            .cornerRadius(4)
                    }
                    
                    Text("Authentication required to access audio monitoring")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(AuthTab.allCases) { tab in
                let isSelected = activeTab == tab
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        activeTab = tab
                        authManager.errorMessage = nil
                    }
                }) {
                    Text(tab.rawValue)
                        .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            isSelected ? Color.primary.opacity(0.1) : Color.clear
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2.5)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Input Fields
    
    private var inputFields: some View {
        VStack(spacing: 8) {
            // Display Name (Only in Sign Up)
            if activeTab == .signUp {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    
                    TextField("Full Name (e.g. Alex Chen)", text: $displayName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(Theme.buttonCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.buttonCornerRadius)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            
            // Email Field
            HStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                
                TextField("Email address", text: $email)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .onSubmit(submitForm)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(Theme.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.buttonCornerRadius)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            // Password Field
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                
                if showPassword {
                    TextField("Password (min. 12 characters)", text: $password)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                        .onSubmit(submitForm)
                } else {
                    SecureField("Password (min. 12 characters)", text: $password)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                        .onSubmit(submitForm)
                }
                
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(Theme.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.buttonCornerRadius)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            // Confirm Password Field (Only in Sign Up)
            if activeTab == .signUp {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    
                    SecureField("Confirm password", text: $confirmPassword)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                        .onSubmit(submitForm)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(Theme.buttonCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.buttonCornerRadius)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Primary Action Button
    
    private var primaryActionButton: some View {
        Button(action: submitForm) {
            HStack(spacing: 6) {
                if authManager.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(activeTab == .signIn ? "Sign In" : "Create Account")
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7.5)
            .background(
                LinearGradient(
                    colors: [Theme.accentColor, Theme.accentColor.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .foregroundColor(.white)
            .cornerRadius(Theme.buttonCornerRadius)
            .shadow(color: Theme.accentColor.opacity(0.35), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(authManager.isLoading)
    }
    
    // MARK: - Divider
    
    private var dividerSection: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
            Text("OR")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(.secondary.opacity(0.7))
            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
        }
    }
    
    // MARK: - Google Sign-In Button
    
    private var googleAuthButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                authManager.showGoogleSheet = true
            }
        }) {
            HStack(spacing: 8) {
                GoogleLogoView(size: 15)
                
                Text(activeTab == .signIn ? "Continue with Google" : "Sign up with Google")
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Color.white)
            .foregroundColor(Color.black.opacity(0.85))
            .cornerRadius(Theme.buttonCornerRadius)
            .shadow(color: Color.black.opacity(0.18), radius: 4, y: 1.5)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.buttonCornerRadius)
                    .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Footer Toggle
    
    private var footerToggle: some View {
        HStack(spacing: 4) {
            Text(activeTab == .signIn ? "Don't have an account?" : "Already have an account?")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
            
            Button(activeTab == .signIn ? "Sign up" : "Sign in") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    activeTab = (activeTab == .signIn ? .signUp : .signIn)
                    authManager.errorMessage = nil
                }
            }
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundColor(Theme.accentColor)
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }
    
    // MARK: - Error Banner
    
    private func errorMessageBanner(_ message: String) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 11))
            
            Text(message)
                .font(.system(size: 10.5))
                .foregroundColor(.red)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(8)
        .background(Color.red.opacity(0.12))
        .cornerRadius(6)
    }
    
    // MARK: - Submission
    
    private func submitForm() {
        Task {
            do {
                if activeTab == .signIn {
                    try await authManager.signInWithEmail(email: email, password: password)
                } else {
                    try await authManager.signUpWithEmail(
                        email: email,
                        password: password,
                        confirmPassword: confirmPassword,
                        displayName: displayName
                    )
                }
            } catch {
                // Handled via authManager.errorMessage
            }
        }
    }
}
