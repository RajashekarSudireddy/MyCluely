import AppKit
import SwiftUI
import Speech

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hudWindow: FloatingHUDWindow?
    private var statusItem: NSStatusItem?
    private var audioConsentGranted = false
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent app from quitting when all normal windows close
        NSApp.setActivationPolicy(.accessory)
        
        setupMainMenu()
        setupStatusItem()
        setupHUDWindow()
        
        // Listen for authentication state changes
        AuthManager.shared.onAuthStateChanged = { [weak self] isAuthenticated in
            self?.updateStatusMenu()
            if isAuthenticated {
                self?.setupAudioPipeline()
            } else {
                self?.audioConsentGranted = false
                Task {
                    await AudioManager.shared.stop()
                    SpeechTranscriber.shared.stop()
                    GeminiLiveClient.shared.stop()
                    OpenAILiveClient.shared.stop()
                }
            }
        }
        
        // Only start audio monitoring pipeline if user is already authenticated
        if AuthManager.shared.isAuthenticated {
            setupAudioPipeline()
        }
        
        registerKeyboardShortcuts()
        setupActiveNotificationObserver()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        Task {
            await AudioManager.shared.stop()
            SpeechTranscriber.shared.stop()
            GeminiLiveClient.shared.stop()
            OpenAILiveClient.shared.stop()
        }
    }
    
    // MARK: - Main Menu (Enables Cmd+C, Cmd+V, Cmd+X, Cmd+A in TextFields)
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About MyCluely", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit MyCluely", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Edit Menu (Essential for paste, copy, cut, undo, select all)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    // MARK: - Status Bar Menu
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "ear.and.waveform", accessibilityDescription: "MyCluely")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        self.statusItem = item
        updateStatusMenu()
    }
    
    @objc private func statusBarButtonClicked() {
        hudWindow?.toggleVisibility()
    }
    
    private func updateStatusMenu() {
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "MyCluely", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        // Locked / Unauthenticated State
        guard AuthManager.shared.isAuthenticated else {
            let lockedItem = NSMenuItem(title: "🔒 Application Locked", action: nil, keyEquivalent: "")
            lockedItem.isEnabled = false
            menu.addItem(lockedItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let unlockItem = NSMenuItem(title: "Sign In / Unlock...", action: #selector(showUnlockHUD), keyEquivalent: "u")
            unlockItem.keyEquivalentModifierMask = [.command]
            unlockItem.target = self
            menu.addItem(unlockItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let quitItem = NSMenuItem(title: "Quit MyCluely", action: #selector(quitApp), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
            
            self.statusItem?.menu = menu
            return
        }
        
        // Authenticated State
        if let user = AuthManager.shared.currentUser {
            let providerTag = user.authProvider == .google ? "Google" : "Email"
            let userItem = NSMenuItem(title: "👤 \(user.displayName) (\(providerTag))", action: nil, keyEquivalent: "")
            userItem.isEnabled = false
            menu.addItem(userItem)
        }
        
        let statusTitle = !AppState.shared.isListening ? "Status: Stopped" : (AppState.shared.isPaused ? "Status: Paused" : "Status: Hearing Active")
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let togglePauseItem = NSMenuItem(
            title: !AppState.shared.isListening ? "Start Hearing" : (AppState.shared.isPaused ? "Resume Hearing" : "Pause Hearing"),
            action: #selector(togglePauseHearing),
            keyEquivalent: "p"
        )
        togglePauseItem.keyEquivalentModifierMask = [.command, .shift]
        togglePauseItem.target = self
        menu.addItem(togglePauseItem)
        
        let toggleHUDItem = NSMenuItem(
            title: "Toggle Floating HUD",
            action: #selector(toggleHUD),
            keyEquivalent: "h"
        )
        toggleHUDItem.keyEquivalentModifierMask = [.command, .shift]
        toggleHUDItem.target = self
        menu.addItem(toggleHUDItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let signOutItem = NSMenuItem(title: "Sign Out", action: #selector(handleSignOut), keyEquivalent: "")
        signOutItem.target = self
        menu.addItem(signOutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit MyCluely", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        self.statusItem?.menu = menu
    }
    
    @objc private func showUnlockHUD() {
        NSApp.activate(ignoringOtherApps: true)
        hudWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc private func handleSignOut() {
        AppState.shared.signOut()
        showUnlockHUD()
    }
    
    @objc private func togglePauseHearing() {
        guard AppState.shared.isListening else {
            setupAudioPipeline()
            return
        }
        guard AuthManager.shared.isAuthenticated else { return }
        AppState.shared.togglePause()
        updateStatusMenu()
    }
    
    @objc private func toggleHUD() {
        hudWindow?.toggleVisibility()
    }
    
    @objc private func openSettings() {
        guard AuthManager.shared.isAuthenticated else {
            showUnlockHUD()
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        hudWindow?.makeKeyAndOrderFront(nil)
        AppState.shared.showSettings = true
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    // MARK: - HUD Window
    private func setupHUDWindow() {
        let window = FloatingHUDWindow()
        window.makeKeyAndOrderFront(nil)
        self.hudWindow = window
    }
    
    // MARK: - Audio & Speech Pipeline
    private func setupAudioPipeline() {
        guard AuthManager.shared.isAuthenticated else { return }
        if !audioConsentGranted {
            let alert = NSAlert()
            alert.messageText = "Start listening with MyCluely?"
            alert.informativeText = "MyCluely captures your selected microphone or system audio. Cloud Live sends audio to your selected Gemini or OpenAI provider. Local STT transcribes on-device and sends detected questions to Gemini. Obtain consent from everyone whose speech you capture. Pause stops forwarding new audio; sign out stops capture."
            alert.addButton(withTitle: "Start Listening")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else {
                AppState.shared.permissionMessage = "Listening is stopped. Choose Start Hearing from the menu when ready."
                updateStatusMenu()
                return
            }
            audioConsentGranted = true
        }
        let sessionID = AuthManager.shared.sessionID
        // Route audio buffer stream directly to active engine
        AudioManager.shared.onAudioBuffer = { buffer in
            guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == sessionID else { return }
            if AppState.shared.answeringMode == .liveStreaming {
                switch AppState.shared.aiProvider {
                case .gemini:
                    if GeminiLiveClient.shared.isActive {
                        GeminiLiveClient.shared.appendAudioBuffer(buffer)
                    }
                case .openAI:
                    if OpenAILiveClient.shared.isActive {
                        OpenAILiveClient.shared.appendAudioBuffer(buffer)
                    }
                }
            } else {
                SpeechTranscriber.shared.appendAudioBuffer(buffer)
            }
        }
        
        Task {
            // Request Speech Recognition Authorization if not determined
            if AppState.shared.answeringMode == .localSTT && SFSpeechRecognizer.authorizationStatus() == .notDetermined {
                _ = await SpeechTranscriber.requestAuthorization()
            }
            
            guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == sessionID else { return }
            // Start appropriate engine according to answeringMode and aiProvider
            if AppState.shared.answeringMode == .liveStreaming {
                switch AppState.shared.aiProvider {
                case .gemini:
                    GeminiLiveClient.shared.start()
                case .openAI:
                    OpenAILiveClient.shared.start()
                }
            } else {
                SpeechTranscriber.shared.start()
            }
            
            // Start Audio Manager
            do {
                try await AudioManager.shared.start(source: AppState.shared.audioSource)
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == sessionID else {
                    await AudioManager.shared.stop()
                    return
                }
                AppState.shared.permissionMessage = nil
                updateStatusMenu()
            } catch {
                print("[AppDelegate] Audio capture start error (details omitted)")
                AppState.shared.permissionMessage = "Permission needed: Enable MyCluely in System Settings > Privacy & Security > Screen & System Audio Recording."
            }
        }
    }
    
    // Auto-reconnect when user returns to app
    private func setupActiveNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                guard AuthManager.shared.isAuthenticated, self.audioConsentGranted else { return }
                if !AppState.shared.isListening {
                    do {
                        try await AudioManager.shared.start(source: AppState.shared.audioSource)
                        AppState.shared.permissionMessage = nil
                    } catch {
                        // Retain message if still failing
                    }
                }
            }
        }
    }
    
    // MARK: - Local Monitor for Global Shortcuts
    private func registerKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Cmd + Shift + P: Toggle pause
            if event.modifierFlags.contains([.command, .shift]) && event.charactersIgnoringModifiers == "P" {
                self?.togglePauseHearing()
                return nil
            }
            // Cmd + Shift + H: Toggle HUD
            if event.modifierFlags.contains([.command, .shift]) && event.charactersIgnoringModifiers == "H" {
                self?.toggleHUD()
                return nil
            }
            return event
        }
    }
}
