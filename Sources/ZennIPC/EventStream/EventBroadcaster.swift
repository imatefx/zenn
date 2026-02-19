import Foundation
import ZennShared
import ZennCore

/// Broadcasts hook events to IPC subscribers (SSE, socket subscribers).
public class EventBroadcaster {
    private let hookRegistry: HookRegistry
    private var subscriptionID: UUID?

    /// Active event handlers for connected clients.
    private var clientHandlers: [UUID: (String) -> Void] = [:]

    public init(hookRegistry: HookRegistry) {
        self.hookRegistry = hookRegistry
    }

    /// Start broadcasting events.
    public func start() {
        subscriptionID = hookRegistry.subscribe { [weak self] event in
            self?.broadcast(event)
        }
    }

    /// Stop broadcasting events.
    public func stop() {
        if let id = subscriptionID {
            hookRegistry.unsubscribe(id)
        }
        clientHandlers.removeAll()
    }

    /// Add a client handler that receives serialized event strings.
    @discardableResult
    public func addClient(handler: @escaping (String) -> Void) -> UUID {
        let id = UUID()
        clientHandlers[id] = handler
        return id
    }

    /// Remove a client handler.
    public func removeClient(_ id: UUID) {
        clientHandlers.removeValue(forKey: id)
    }

    /// Broadcast an event to all connected clients.
    private func broadcast(_ event: HookEvent) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(event.serialized),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        let sseMessage = "data: \(json)\n\n"

        for (_, handler) in clientHandlers {
            handler(sseMessage)
        }
    }

    deinit {
        stop()
    }
}
