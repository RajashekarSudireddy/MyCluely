import SwiftUI
import AppKit

public struct Theme {
    // Vibrant Modern Palette
    public static let accentColor = Color(red: 0.18, green: 0.52, blue: 1.0)
    public static let listeningColor = Color(red: 0.22, green: 0.86, blue: 0.48)
    public static let pausedColor = Color(red: 1.0, green: 0.65, blue: 0.18)
    public static let questionColor = Color(red: 0.72, green: 0.42, blue: 1.0)
    public static let answerColor = Color(red: 0.0, green: 0.82, blue: 0.95)
    public static let liveBadgeColor = Color(red: 0.0, green: 0.82, blue: 0.95)
    
    // Geometry
    public static let cardCornerRadius: CGFloat = 18
    public static let innerCornerRadius: CGFloat = 12
    public static let buttonCornerRadius: CGFloat = 8
    
    // Materials & Glass
    public static let hudBackground = Color(NSColor.windowBackgroundColor).opacity(0.88)
    public static let cardBackground = Color(NSColor.controlBackgroundColor).opacity(0.55)
    public static let elevatedBackground = Color(NSColor.textBackgroundColor).opacity(0.18)
    public static let sectionBackground = Color.primary.opacity(0.04)
    public static let borderStroke = Color.white.opacity(0.14)
    public static let innerHighlight = Color.white.opacity(0.06)
}

public struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    public init(material: NSVisualEffectView.Material = .hudWindow,
                blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
                state: NSVisualEffectView.State = .active) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}
