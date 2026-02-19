import Foundation
import CoreGraphics
import ZennShared
#if canImport(AppKit)
import AppKit
#endif

/// Manages display/monitor detection and information.
public class DisplayManager {
    public init() {}

    /// Get all active displays.
    public func allDisplays() -> [DisplayInfo] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        guard displayCount > 0 else { return [] }

        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount)

        return displayIDs.map { displayID in
            let bounds = CGDisplayBounds(displayID)

            // Get the visible frame (excluding menu bar and dock)
            let visibleFrame: Rect
            #if canImport(AppKit)
            if let screen = NSScreen.screens.first(where: {
                guard let screenNumber = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return false }
                return screenNumber == displayID
            }) {
                // Convert NSScreen coordinates (origin at bottom-left) to CG coordinates (origin at top-left)
                let mainHeight = CGDisplayBounds(CGMainDisplayID()).height
                let y = mainHeight - screen.visibleFrame.origin.y - screen.visibleFrame.height
                visibleFrame = Rect(
                    x: Double(screen.visibleFrame.origin.x),
                    y: Double(y),
                    width: Double(screen.visibleFrame.width),
                    height: Double(screen.visibleFrame.height)
                )
            } else {
                visibleFrame = Rect(cgRect: bounds)
            }
            #else
            visibleFrame = Rect(cgRect: bounds)
            #endif

            return DisplayInfo(
                displayID: DisplayID(displayID),
                frame: Rect(cgRect: bounds),
                visibleFrame: visibleFrame,
                isMain: CGDisplayIsMain(displayID) != 0
            )
        }
    }

    /// Get the main (primary) display.
    public func mainDisplay() -> DisplayInfo? {
        allDisplays().first { $0.isMain }
    }

    /// Get the display containing a given point.
    public func display(containing point: CGPoint) -> DisplayInfo? {
        allDisplays().first { $0.frame.contains(point: point) }
    }
}

/// Information about a display.
public struct DisplayInfo: Sendable {
    public let displayID: DisplayID
    public let frame: Rect
    public let visibleFrame: Rect
    public let isMain: Bool
}
