import XCTest
@testable import ZennShared

final class IPCMessageTests: XCTestCase {

    func testEncodeDecodeCommand() throws {
        let command = Command.focus(.left)
        let data = try IPCMessage.encode(command)

        // Data should have 4-byte length prefix
        XCTAssertGreaterThan(data.count, 4)

        // Read length
        let length = IPCMessage.readLength(from: data)
        XCTAssertNotNil(length)
        XCTAssertEqual(Int(length!) + 4, data.count)

        // Decode
        let jsonData = data.subdata(in: 4..<data.count)
        let decoded = try IPCMessage.decode(Command.self, from: jsonData)

        if case .focus(let dir) = decoded {
            XCTAssertEqual(dir, .left)
        } else {
            XCTFail("Expected focus command")
        }
    }

    func testEncodeDecodeResponse() throws {
        let response = CommandResponse(success: true, message: "OK")
        let data = try IPCMessage.encode(response)
        let jsonData = data.subdata(in: 4..<data.count)
        let decoded = try IPCMessage.decode(CommandResponse.self, from: jsonData)

        XCTAssertTrue(decoded.success)
        XCTAssertEqual(decoded.message, "OK")
    }

    func testSocketPath() {
        let path = IPCMessage.socketPath
        XCTAssertTrue(path.hasSuffix("zenn.sock"))
    }

    func testEncodeDecodeQueryResponse() throws {
        let windowInfo = WindowInfo(
            windowID: WindowID(42),
            appName: "Test",
            appBundleID: "com.test",
            title: "Window",
            frame: Rect(x: 0, y: 0, width: 100, height: 100),
            mode: .tiled,
            workspaceID: WorkspaceID(number: 1),
            monitorID: DisplayID(1),
            isFocused: true,
            isMinimized: false
        )

        let response = CommandResponse(success: true, data: .windows([windowInfo]))
        let data = try IPCMessage.encode(response)
        let jsonData = data.subdata(in: 4..<data.count)
        let decoded = try IPCMessage.decode(CommandResponse.self, from: jsonData)

        XCTAssertTrue(decoded.success)
        if case .windows(let windows) = decoded.data {
            XCTAssertEqual(windows.count, 1)
            XCTAssertEqual(windows[0].windowID, WindowID(42))
            XCTAssertEqual(windows[0].appName, "Test")
        } else {
            XCTFail("Expected windows response data")
        }
    }

    func testAllCommandTypesEncodable() throws {
        let commands: [Command] = [
            .focus(.left),
            .focusCycle(.next),
            .moveWindow(.right),
            .moveToWorkspace(WorkspaceID(number: 1)),
            .swapWindow(.up),
            .resizeWindow(.down, 0.1),
            .setWindowMode(.floating),
            .switchWorkspace(WorkspaceID(number: 2)),
            .setSplitAxis(.vertical),
            .toggleSplitAxis,
            .setLayoutMode(.monocle),
            .applyPreset(.equal),
            .queryWindows,
            .queryWorkspaces,
            .queryMonitors,
            .queryFocused,
            .queryTree(nil),
            .reload,
            .quit,
            .subscribe([.windowCreated, .workspaceSwitched]),
        ]

        for command in commands {
            let data = try IPCMessage.encode(command)
            XCTAssertGreaterThan(data.count, 4, "Failed to encode \(command)")
        }
    }
}
