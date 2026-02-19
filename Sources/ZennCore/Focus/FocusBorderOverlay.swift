import Foundation
import ZennShared
#if canImport(AppKit)
import AppKit

/// A borderless, click-through window that draws a colored border around the focused window.
public class FocusBorderOverlay {
    private var overlayWindow: NSWindow?
    private var borderColor: NSColor
    private var borderWidth: CGFloat
    private var isEnabled: Bool

    public init(
        color: NSColor = NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),
        width: CGFloat = 2.0,
        enabled: Bool = false
    ) {
        self.borderColor = color
        self.borderWidth = width
        self.isEnabled = enabled
    }

    /// Update the border configuration.
    public func configure(color: NSColor, width: CGFloat, enabled: Bool) {
        self.borderColor = color
        self.borderWidth = width
        self.isEnabled = enabled
        if !enabled {
            hide()
        }
    }

    /// Show the focus border around the given frame.
    public func show(around frame: Rect) {
        guard isEnabled else { return }

        let borderRect = NSRect(
            x: frame.x - Double(borderWidth),
            y: frame.y - Double(borderWidth),
            width: frame.width + Double(borderWidth) * 2,
            height: frame.height + Double(borderWidth) * 2
        )

        if overlayWindow == nil {
            createOverlayWindow()
        }

        guard let window = overlayWindow else { return }

        window.setFrame(borderRect, display: false)
        window.contentView?.needsDisplay = true
        window.orderFrontRegardless()
    }

    /// Hide the focus border.
    public func hide() {
        overlayWindow?.orderOut(nil)
    }

    private func createOverlayWindow() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let borderView = BorderView(color: borderColor, width: borderWidth)
        window.contentView = borderView

        self.overlayWindow = window
    }
}

/// Custom view that draws a border rectangle.
private class BorderView: NSView {
    private let borderColor: NSColor
    private let borderWidth: CGFloat

    init(color: NSColor, width: CGFloat) {
        self.borderColor = color
        self.borderWidth = width
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        borderColor.setStroke()
        let path = NSBezierPath(rect: bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2))
        path.lineWidth = borderWidth
        path.stroke()
    }
}
#endif
