import Foundation
import CoreGraphics
import ZennShared

/// Observes display configuration changes (connect/disconnect/reconfigure).
public class DisplayObserver {
    public typealias DisplayChangeHandler = (DisplayChangeEvent) -> Void

    public enum DisplayChangeEvent {
        case displayConnected(DisplayID)
        case displayDisconnected(DisplayID)
        case displayReconfigured(DisplayID)
    }

    private var handler: DisplayChangeHandler?
    private var isObserving = false

    public init() {}

    /// Start observing display changes.
    public func startObserving(handler: @escaping DisplayChangeHandler) {
        self.handler = handler
        guard !isObserving else { return }

        CGDisplayRegisterReconfigurationCallback({ displayID, flags, userInfo in
            guard let userInfo = userInfo else { return }
            let observer = Unmanaged<DisplayObserver>.fromOpaque(userInfo).takeUnretainedValue()
            observer.handleDisplayChange(displayID: displayID, flags: flags)
        }, Unmanaged.passUnretained(self).toOpaque())

        isObserving = true
    }

    /// Stop observing display changes.
    public func stopObserving() {
        guard isObserving else { return }

        CGDisplayRemoveReconfigurationCallback({ displayID, flags, userInfo in
            // callback removed
        }, Unmanaged.passUnretained(self).toOpaque())

        isObserving = false
        handler = nil
    }

    private func handleDisplayChange(displayID: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags) {
        let id = DisplayID(displayID)

        if flags.contains(.addFlag) {
            handler?(.displayConnected(id))
        } else if flags.contains(.removeFlag) {
            handler?(.displayDisconnected(id))
        } else if flags.contains(.movedFlag) || flags.contains(.setMainFlag) {
            handler?(.displayReconfigured(id))
        }
    }

    deinit {
        stopObserving()
    }
}
