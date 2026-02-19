import Foundation
import CoreGraphics
import ZennShared
#if canImport(AppKit)
import AppKit
#endif

/// Tracks mouse events for drag-to-swap and drag-to-resize operations.
public class MouseTracker {
    public typealias DragHandler = (DragEvent) -> Void

    public enum DragEvent {
        case began(position: CGPoint, windowID: WindowID?)
        case moved(position: CGPoint)
        case ended(position: CGPoint)
    }

    private var dragHandler: DragHandler?
    private var eventMonitor: Any?
    private var isDragging = false

    public init() {}

    /// Start tracking mouse drag events.
    public func startTracking(handler: @escaping DragHandler) {
        self.dragHandler = handler

        #if canImport(AppKit)
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            guard let self = self else { return }
            let position = NSEvent.mouseLocation

            switch event.type {
            case .leftMouseDragged:
                if !self.isDragging {
                    self.isDragging = true
                    self.dragHandler?(.began(position: position, windowID: nil))
                }
                self.dragHandler?(.moved(position: position))
            case .leftMouseUp:
                if self.isDragging {
                    self.isDragging = false
                    self.dragHandler?(.ended(position: position))
                }
            default:
                break
            }
        }
        #endif
    }

    /// Stop tracking mouse events.
    public func stopTracking() {
        #if canImport(AppKit)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        #endif
        eventMonitor = nil
        dragHandler = nil
    }

    deinit {
        stopTracking()
    }
}
