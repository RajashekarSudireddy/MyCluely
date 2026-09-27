import AppKit
import SwiftUI

public final class FloatingHUDWindow: NSPanel {
    public static weak var shared: FloatingHUDWindow?
    
    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 120),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        Self.shared = self
        
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.becomesKeyOnlyIfNeeded = false
        
        let hostingView = NSHostingView(rootView: FloatingHUDView())
        self.contentView = hostingView
        
        positionOnScreen()
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
    
    public func positionOnScreen() {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        
        let width: CGFloat = 400
        let height: CGFloat = 120
        let padding: CGFloat = 24
        
        // Position at top-right corner by default
        let x = screenRect.maxX - width - padding
        let y = screenRect.maxY - height - padding
        
        self.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
    
    public func updateHeight(_ height: CGFloat, animated: Bool = true) {
        let currentFrame = self.frame
        let targetHeight = max(52, min(height, 680))
        guard abs(currentFrame.height - targetHeight) > 1 else { return }
        
        let newY = currentFrame.maxY - targetHeight
        let newFrame = NSRect(x: currentFrame.minX, y: newY, width: currentFrame.width, height: targetHeight)
        self.setFrame(newFrame, display: true, animate: animated)
    }
    
    public func toggleVisibility() {
        if self.isVisible {
            self.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            self.makeKeyAndOrderFront(nil)
        }
    }
}
