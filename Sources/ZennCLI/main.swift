import Foundation
import ArgumentParser
import ZennShared

@main
struct ZennCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "zenn",
        abstract: "Zenn - macOS tiling window manager CLI",
        version: "0.1.0",
        subcommands: [
            FocusCommand.self,
            MoveCommand.self,
            ResizeCommand.self,
            SwapCommand.self,
            WorkspaceCommand.self,
            MoveToWorkspaceCommand.self,
            LayoutCommand.self,
            ToggleCommand.self,
            QueryCommand.self,
            SubscribeCommand.self,
            ReloadCommand.self,
            QuitCommand.self,
        ]
    )
}

// MARK: - Focus

struct FocusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "focus",
        abstract: "Focus a window in a direction"
    )

    @Argument(help: "Direction: left, right, up, down, next, prev")
    var direction: String

    func run() throws {
        let command: Command
        if direction == "next" {
            command = .focusCycle(.next)
        } else if direction == "prev" || direction == "previous" {
            command = .focusCycle(.previous)
        } else if let dir = Direction(rawValue: direction) {
            command = .focus(dir)
        } else {
            throw ValidationError("Invalid direction: \(direction)")
        }
        try sendCommand(command)
    }
}

// MARK: - Move

struct MoveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "move",
        abstract: "Move the focused window in a direction"
    )

    @Argument(help: "Direction: left, right, up, down")
    var direction: String

    func run() throws {
        guard let dir = Direction(rawValue: direction) else {
            throw ValidationError("Invalid direction: \(direction)")
        }
        try sendCommand(.moveWindow(dir))
    }
}

// MARK: - Resize

struct ResizeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "resize",
        abstract: "Resize the focused window"
    )

    @Argument(help: "Direction: left, right, up, down")
    var direction: String

    @Option(name: .shortAndLong, help: "Resize delta (default: 0.05)")
    var delta: Double = 0.05

    func run() throws {
        guard let dir = Direction(rawValue: direction) else {
            throw ValidationError("Invalid direction: \(direction)")
        }
        try sendCommand(.resizeWindow(dir, delta))
    }
}

// MARK: - Swap

struct SwapCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swap",
        abstract: "Swap the focused window with its neighbor"
    )

    @Argument(help: "Direction: left, right, up, down")
    var direction: String

    func run() throws {
        guard let dir = Direction(rawValue: direction) else {
            throw ValidationError("Invalid direction: \(direction)")
        }
        try sendCommand(.swapWindow(dir))
    }
}

// MARK: - Workspace

struct WorkspaceCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "workspace",
        abstract: "Switch to a workspace"
    )

    @Argument(help: "Workspace number")
    var number: Int

    func run() throws {
        try sendCommand(.switchWorkspace(WorkspaceID(number: number)))
    }
}

// MARK: - Move to workspace

struct MoveToWorkspaceCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "move-to-workspace",
        abstract: "Move the focused window to a workspace"
    )

    @Argument(help: "Workspace number")
    var number: Int

    func run() throws {
        try sendCommand(.moveToWorkspace(WorkspaceID(number: number)))
    }
}

// MARK: - Layout

struct LayoutCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "layout",
        abstract: "Change layout settings"
    )

    @Argument(help: "Action: split-h, split-v, toggle-split, monocle, tiling, preset")
    var action: String

    @Argument(help: "Value for preset (equal, master-lg, master-xl)")
    var value: String?

    func run() throws {
        switch action {
        case "split-h":
            try sendCommand(.setSplitAxis(.horizontal))
        case "split-v":
            try sendCommand(.setSplitAxis(.vertical))
        case "toggle-split":
            try sendCommand(.toggleSplitAxis)
        case "monocle":
            try sendCommand(.setLayoutMode(.monocle))
        case "tiling":
            try sendCommand(.setLayoutMode(.tiling))
        case "preset":
            guard let v = value, let preset = ResizePreset(rawValue: v) else {
                throw ValidationError("Invalid preset. Use: equal, masterLg, masterXl")
            }
            try sendCommand(.applyPreset(preset))
        default:
            throw ValidationError("Unknown layout action: \(action)")
        }
    }
}

// MARK: - Toggle

struct ToggleCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "toggle",
        abstract: "Toggle window mode"
    )

    @Argument(help: "Mode: floating, sticky, fullscreen")
    var mode: String

    func run() throws {
        guard let windowMode = WindowMode(rawValue: mode) else {
            throw ValidationError("Invalid mode: \(mode). Use: floating, sticky, fullscreen, tiled")
        }
        try sendCommand(.setWindowMode(windowMode))
    }
}

// MARK: - Query

struct QueryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "query",
        abstract: "Query state information"
    )

    @Argument(help: "What to query: windows, workspaces, monitors, focused, tree")
    var target: String

    @Option(name: .long, help: "Output format: json (default)")
    var format: String = "json"

    func run() throws {
        let command: Command
        switch target {
        case "windows":
            command = .queryWindows
        case "workspaces":
            command = .queryWorkspaces
        case "monitors":
            command = .queryMonitors
        case "focused":
            command = .queryFocused
        case "tree":
            command = .queryTree(nil)
        default:
            throw ValidationError("Unknown query target: \(target)")
        }
        try sendCommand(command)
    }
}

// MARK: - Subscribe

struct SubscribeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "subscribe",
        abstract: "Subscribe to events"
    )

    @Option(name: .long, help: "Event types to subscribe to (comma-separated)")
    var events: String?

    func run() throws {
        let eventTypes: [HookEventType]
        if let eventsStr = events {
            eventTypes = eventsStr.split(separator: ",").compactMap {
                HookEventType(rawValue: String($0).trimmingCharacters(in: .whitespaces))
            }
        } else {
            eventTypes = Array(HookEventType.allCases)
        }
        try sendCommand(.subscribe(eventTypes))
    }
}

// MARK: - Reload

struct ReloadCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reload",
        abstract: "Reload configuration"
    )

    func run() throws {
        try sendCommand(.reload)
    }
}

// MARK: - Quit

struct QuitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "quit",
        abstract: "Quit Zenn"
    )

    func run() throws {
        try sendCommand(.quit)
    }
}

// MARK: - Socket Communication

func sendCommand(_ command: Command) throws {
    let socketPath = IPCMessage.socketPath

    // Create Unix domain socket
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
        fputs("Error: Cannot create socket\n", stderr)
        throw ExitCode.failure
    }
    defer { close(fd) }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathSize = MemoryLayout.size(ofValue: addr.sun_path)
    socketPath.withCString { ptr in
        withUnsafeMutableBytes(of: &addr.sun_path) { rawBuf in
            let pathBuf = rawBuf.baseAddress!.assumingMemoryBound(to: CChar.self)
            strncpy(pathBuf, ptr, pathSize - 1)
        }
    }

    let connectResult = withUnsafePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
            connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }

    guard connectResult == 0 else {
        fputs("Error: Cannot connect to Zenn daemon. Is it running?\n", stderr)
        throw ExitCode.failure
    }

    // Send command
    let data = try IPCMessage.encode(command)
    data.withUnsafeBytes { ptr in
        _ = send(fd, ptr.baseAddress!, data.count, 0)
    }

    // Read response
    var responseData = Data()
    var readBuffer = [UInt8](repeating: 0, count: 65536)

    while true {
        let bytesRead = recv(fd, &readBuffer, readBuffer.count, 0)
        if bytesRead <= 0 { break }
        responseData.append(contentsOf: readBuffer[0..<bytesRead])

        // Check if we have a complete message
        if responseData.count >= 4,
           let length = IPCMessage.readLength(from: responseData),
           responseData.count >= 4 + Int(length) {
            break
        }
    }

    // Parse and print response
    if responseData.count > 4 {
        let jsonData = responseData.subdata(in: 4..<responseData.count)
        let response = try IPCMessage.decode(CommandResponse.self, from: jsonData)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let output = try encoder.encode(response)
        print(String(data: output, encoding: .utf8) ?? "")

        if !response.success {
            throw ExitCode.failure
        }
    }
}
