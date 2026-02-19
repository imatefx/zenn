import Foundation
import ZennShared

/// Registry and dispatcher for hook callbacks.
public class HookRegistry {
    /// A registered hook callback.
    public struct HookCallback {
        public let id: UUID
        public let eventType: HookEventType
        public let handler: (HookEvent) -> Void

        public init(eventType: HookEventType, handler: @escaping (HookEvent) -> Void) {
            self.id = UUID()
            self.eventType = eventType
            self.handler = handler
        }
    }

    /// A registered external script hook.
    public struct ScriptHook {
        public let id: UUID
        public let eventType: HookEventType
        public let scriptPath: String
        public let arguments: [String]

        public init(eventType: HookEventType, scriptPath: String, arguments: [String] = []) {
            self.id = UUID()
            self.eventType = eventType
            self.scriptPath = scriptPath
            self.arguments = arguments
        }
    }

    /// All registered callbacks, keyed by event type.
    private var callbacks: [HookEventType: [HookCallback]] = [:]

    /// Registered external script hooks, keyed by event type.
    private var scriptHooks: [HookEventType: [ScriptHook]] = [:]

    /// External subscribers (IPC event stream).
    private var externalSubscribers: [UUID: (HookEvent) -> Void] = [:]

    /// External subscriber filters.
    private var externalFilters: [UUID: Set<HookEventType>] = [:]

    public init() {}

    /// Register a callback for a specific event type.
    @discardableResult
    public func on(_ eventType: HookEventType, handler: @escaping (HookEvent) -> Void) -> UUID {
        let callback = HookCallback(eventType: eventType, handler: handler)
        callbacks[eventType, default: []].append(callback)
        return callback.id
    }

    /// Register an external script to run when an event fires.
    /// The script receives event data as environment variables prefixed with ZENN_.
    @discardableResult
    public func onScript(_ eventType: HookEventType, scriptPath: String, arguments: [String] = []) -> UUID {
        let hook = ScriptHook(eventType: eventType, scriptPath: scriptPath, arguments: arguments)
        scriptHooks[eventType, default: []].append(hook)
        return hook.id
    }

    /// Remove a callback by its ID.
    public func remove(id: UUID) {
        for (eventType, var handlers) in callbacks {
            handlers.removeAll { $0.id == id }
            callbacks[eventType] = handlers.isEmpty ? nil : handlers
        }
        for (eventType, var hooks) in scriptHooks {
            hooks.removeAll { $0.id == id }
            scriptHooks[eventType] = hooks.isEmpty ? nil : hooks
        }
    }

    /// Remove all callbacks for an event type.
    public func removeAll(for eventType: HookEventType) {
        callbacks.removeValue(forKey: eventType)
        scriptHooks.removeValue(forKey: eventType)
    }

    /// Remove all callbacks.
    public func removeAll() {
        callbacks.removeAll()
        scriptHooks.removeAll()
    }

    /// Subscribe to events externally (for IPC event streaming).
    @discardableResult
    public func subscribe(
        filter: Set<HookEventType>? = nil,
        handler: @escaping (HookEvent) -> Void
    ) -> UUID {
        let id = UUID()
        externalSubscribers[id] = handler
        if let filter = filter {
            externalFilters[id] = filter
        }
        return id
    }

    /// Unsubscribe an external subscriber.
    public func unsubscribe(_ id: UUID) {
        externalSubscribers.removeValue(forKey: id)
        externalFilters.removeValue(forKey: id)
    }

    /// Dispatch an event to all registered handlers and subscribers.
    public func dispatch(_ event: HookEvent) {
        // Notify registered Lua/internal callbacks
        if let handlers = callbacks[event.type] {
            for callback in handlers {
                callback.handler(event)
            }
        }

        // Execute registered script hooks
        if let hooks = scriptHooks[event.type] {
            for hook in hooks {
                executeScript(hook, event: event)
            }
        }

        // Notify external subscribers (IPC)
        for (id, handler) in externalSubscribers {
            if let filter = externalFilters[id] {
                guard filter.contains(event.type) else { continue }
            }
            handler(event)
        }
    }

    /// Execute an external script with event data as environment variables.
    private func executeScript(_ hook: ScriptHook, event: HookEvent) {
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: hook.scriptPath)
            process.arguments = hook.arguments

            // Set environment variables with ZENN_ prefix
            var env = ProcessInfo.processInfo.environment
            env["ZENN_EVENT"] = event.type.rawValue
            env["ZENN_TIMESTAMP"] = ISO8601DateFormatter().string(from: event.timestamp)
            for (key, value) in event.data {
                env["ZENN_\(key.uppercased())"] = value
            }
            process.environment = env

            // Capture output for logging
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus != 0 {
                    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    print("[Zenn] Hook script '\(hook.scriptPath)' exited with status \(process.terminationStatus): \(output)")
                }
            } catch {
                print("[Zenn] Failed to execute hook script '\(hook.scriptPath)': \(error)")
            }
        }
    }
}
