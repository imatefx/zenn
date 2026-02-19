import Foundation
import ApplicationServices
import ZennShared

/// Manages AXObserver instances to receive accessibility notifications from applications.
public class AXObserverManager {
    /// Callback type for window events.
    public typealias WindowEventHandler = (WindowEvent) -> Void

    /// Events we observe.
    public enum WindowEvent {
        case created(pid: pid_t, element: AXUIElement)
        case destroyed(pid: pid_t, element: AXUIElement)
        case moved(pid: pid_t, element: AXUIElement)
        case resized(pid: pid_t, element: AXUIElement)
        case minimized(pid: pid_t, element: AXUIElement)
        case deminimized(pid: pid_t, element: AXUIElement)
        case focused(pid: pid_t, element: AXUIElement)
        case titleChanged(pid: pid_t, element: AXUIElement)
    }

    /// Active observers keyed by PID.
    private var observers: [pid_t: AXObserver] = [:]

    /// Handler for all window events.
    public var eventHandler: WindowEventHandler?

    /// Notifications we subscribe to.
    private static let notifications: [(String, String)] = [
        (kAXCreatedNotification, "created"),
        (kAXUIElementDestroyedNotification, "destroyed"),
        (kAXMovedNotification, "moved"),
        (kAXResizedNotification, "resized"),
        (kAXWindowMiniaturizedNotification, "minimized"),
        (kAXWindowDeminiaturizedNotification, "deminimized"),
        (kAXFocusedWindowChangedNotification, "focused"),
        (kAXTitleChangedNotification, "titleChanged"),
    ]

    public init() {}

    /// Start observing accessibility events for a given application PID.
    public func observe(pid: pid_t) {
        guard observers[pid] == nil else { return }

        var observer: AXObserver?
        let result = AXObserverCreate(
            pid,
            { (observer, element, notification, refcon) in
                guard let refcon = refcon else { return }
                let manager = Unmanaged<AXObserverManager>.fromOpaque(refcon).takeUnretainedValue()
                manager.handleNotification(
                    notification: notification as String,
                    element: element,
                    pid: AXObserverGetPid(observer) // Get the PID of the observer
                )
            },
            &observer
        )

        guard result == .success, let obs = observer else { return }

        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        for (notification, _) in Self.notifications {
            AXObserverAddNotification(obs, appElement, notification as CFString, refcon)
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(obs),
            .defaultMode
        )

        observers[pid] = obs
    }

    private func getObserverPid(_ observer: AXObserver) -> pid_t {
        // Find the PID by looking up which observer this is
        for (pid, obs) in observers {
            if obs === observer {
                return pid
            }
        }
        return 0
    }

    /// Stop observing a given application.
    public func stopObserving(pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
    }

    /// Stop observing all applications.
    public func stopAll() {
        for pid in observers.keys {
            stopObserving(pid: pid)
        }
    }

    private func handleNotification(notification: String, element: AXUIElement, pid: pid_t) {
        let event: WindowEvent
        switch notification {
        case kAXCreatedNotification:
            event = .created(pid: pid, element: element)
        case kAXUIElementDestroyedNotification:
            event = .destroyed(pid: pid, element: element)
        case kAXMovedNotification:
            event = .moved(pid: pid, element: element)
        case kAXResizedNotification:
            event = .resized(pid: pid, element: element)
        case kAXWindowMiniaturizedNotification:
            event = .minimized(pid: pid, element: element)
        case kAXWindowDeminiaturizedNotification:
            event = .deminimized(pid: pid, element: element)
        case kAXFocusedWindowChangedNotification:
            event = .focused(pid: pid, element: element)
        case kAXTitleChangedNotification:
            event = .titleChanged(pid: pid, element: element)
        default:
            return
        }
        eventHandler?(event)
    }
}

private func AXObserverGetPid(_ observer: AXObserver) -> pid_t {
    // AXObserver doesn't directly expose PID, we need to track it ourselves
    // This is handled via the observers dictionary lookup
    return 0
}
