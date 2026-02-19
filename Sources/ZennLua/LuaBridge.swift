import Foundation
import ZennShared
import ZennCore
import CLua
import CLuaShim

/// Central bridge between Lua configuration and the Swift tiling engine.
public class LuaBridge {
    public let vm: LuaVM
    private let state: WorldState
    private let focusManager: FocusManager
    private let tileOperation: TileOperation
    private let swapOperation: SwapOperation
    private let resizeOperation: ResizeOperation
    private let moveOperation: MoveOperation
    private let fullscreenOperation: FullscreenOperation
    private let hookRegistry: HookRegistry

    /// Callback for keybinding registration.
    public var onKeybind: ((KeyModifier, String, @escaping () -> Void) -> Void)?

    /// Callback for window rule registration.
    public var onWindowRule: ((WindowRule) -> Void)?

    /// Callback for applying frames to windows.
    public var onApplyFrames: (([WindowID: Rect]) -> Void)?

    /// Callback for workspace switch.
    public var onWorkspaceSwitch: ((Int) -> Void)?

    /// Callback for focus change.
    public var onFocusChange: ((WindowID) -> Void)?

    /// Callback for config reload.
    public var onReload: (() -> Void)?

    public init(
        state: WorldState,
        focusManager: FocusManager,
        tileOperation: TileOperation,
        swapOperation: SwapOperation,
        resizeOperation: ResizeOperation,
        moveOperation: MoveOperation,
        fullscreenOperation: FullscreenOperation,
        hookRegistry: HookRegistry
    ) {
        self.vm = LuaVM()
        self.state = state
        self.focusManager = focusManager
        self.tileOperation = tileOperation
        self.swapOperation = swapOperation
        self.resizeOperation = resizeOperation
        self.moveOperation = moveOperation
        self.fullscreenOperation = fullscreenOperation
        self.hookRegistry = hookRegistry

        // Store self in the Lua registry so C callbacks can find us
        vm.storeSwiftObject(self, key: "__zenn_bridge")

        registerAPIs()
    }

    /// Load and execute a config file.
    @discardableResult
    public func loadConfig(at path: String) -> Bool {
        vm.errors.removeAll()
        return vm.executeFile(path)
    }

    /// Reload config by creating fresh Lua state.
    public func reloadConfig(at path: String) -> Bool {
        // Note: We keep the same LuaVM but clear keybindings
        // In a full implementation, we'd recreate the VM
        vm.errors.removeAll()
        return vm.executeFile(path)
    }

    /// Get the default config file path.
    public static var defaultConfigPath: String {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/zenn")
        return configDir.appendingPathComponent("init.lua").path
    }

    /// Ensure the config directory and default config exist.
    public static func ensureDefaultConfig() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/zenn")
        let configPath = configDir.appendingPathComponent("init.lua")

        if !FileManager.default.fileExists(atPath: configPath.path) {
            try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

            // Write default config
            let defaultConfig = Self.defaultConfigContent
            try? defaultConfig.write(to: configPath, atomically: true, encoding: .utf8)
        }
    }

    private static let defaultConfigContent = """
    -- Zenn Window Manager Configuration
    -- ~/.config/zenn/init.lua

    local zenn = require("zenn")

    -- Focus: Alt + Arrow Keys
    zenn.bind({"alt"}, "left", function() zenn.focus("left") end)
    zenn.bind({"alt"}, "right", function() zenn.focus("right") end)
    zenn.bind({"alt"}, "down", function() zenn.focus("down") end)
    zenn.bind({"alt"}, "up", function() zenn.focus("up") end)

    -- Move: Alt+Shift + Arrow Keys
    zenn.bind({"alt", "shift"}, "left", function() zenn.move("left") end)
    zenn.bind({"alt", "shift"}, "right", function() zenn.move("right") end)
    zenn.bind({"alt", "shift"}, "down", function() zenn.move("down") end)
    zenn.bind({"alt", "shift"}, "up", function() zenn.move("up") end)

    -- Merge into split: Alt+Ctrl+Shift + Arrow Keys
    zenn.bind({"alt", "ctrl", "shift"}, "left", function() zenn.merge("left") end)
    zenn.bind({"alt", "ctrl", "shift"}, "right", function() zenn.merge("right") end)
    zenn.bind({"alt", "ctrl", "shift"}, "down", function() zenn.merge("down") end)
    zenn.bind({"alt", "ctrl", "shift"}, "up", function() zenn.merge("up") end)

    -- Eject from split: Alt+E
    zenn.bind({"alt"}, "e", function() zenn.eject() end)

    -- Resize: Alt+Ctrl + Arrow Keys
    zenn.bind({"alt", "ctrl"}, "left", function() zenn.resize("left") end)
    zenn.bind({"alt", "ctrl"}, "right", function() zenn.resize("right") end)
    zenn.bind({"alt", "ctrl"}, "down", function() zenn.resize("down") end)
    zenn.bind({"alt", "ctrl"}, "up", function() zenn.resize("up") end)

    -- Workspaces: Alt + 1-9
    for i = 1, 9 do
        zenn.bind({"alt"}, tostring(i), function() zenn.workspace(i) end)
        zenn.bind({"alt", "shift"}, tostring(i), function() zenn.move_to_workspace(i) end)
    end

    -- Toggle modes
    zenn.bind({"alt"}, "f", function() zenn.toggle_fullscreen() end)
    zenn.bind({"alt", "shift"}, "f", function() zenn.toggle_floating() end)
    zenn.bind({"alt", "shift"}, "s", function() zenn.toggle_sticky() end)

    -- Split direction
    zenn.bind({"alt"}, "v", function() zenn.set_split("vertical") end)
    zenn.bind({"alt"}, "b", function() zenn.set_split("horizontal") end)

    -- Layout presets
    zenn.bind({"alt"}, "=", function() zenn.preset("equal") end)

    -- Reload config
    zenn.bind({"alt", "shift"}, "r", function() zenn.reload() end)

    -- Window rules
    zenn.rule({ app = "System Settings", floating = true })
    zenn.rule({ app = "Calculator", floating = true })
    zenn.rule({ app = "Finder", title = "Copy", floating = true })

    -- Gaps
    zenn.gaps({ inner = 8, outer = 8 })
    """

    // MARK: - API Registration

    private func registerAPIs() {
        // Create the "zenn" module table
        vm.newTable()

        registerBindFunction()
        registerFocusFunction()
        registerMoveFunction()
        registerMergeFunction()
        registerEjectFunction()
        registerResizeFunction()
        registerWorkspaceFunction()
        registerMoveToWorkspaceFunction()
        registerToggleFunctions()
        registerSplitFunction()
        registerPresetFunction()
        registerReloadFunction()
        registerRuleFunction()
        registerGapsFunction()
        registerHookFunction()
        registerExecFunction()
        registerQueryFunctions()

        // Set the table as the "zenn" global
        lua_setglobal(vm.L, "zenn")

        // Register require("zenn") to return the global
        vm.execute("""
        package.preload["zenn"] = function()
            return zenn
        end
        """)
    }

    private func registerBindFunction() {
        let bridge = self
        let closure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L else { return 0 }
            guard let bridge = LuaBridge.getBridge(from: L) else { return 0 }

            // Args: modifiers table, key string, callback function
            guard lua_type(L, 1) == LUA_TTABLE,
                  lua_type(L, 2) == LUA_TSTRING,
                  lua_type(L, 3) == LUA_TFUNCTION else {
                return 0
            }

            let modStrings = bridge.vm.toStringArray(at: 1)
            guard let key = bridge.vm.toString(at: 2) else { return 0 }

            // Store the callback function as a reference
            lua_pushvalue(L, 3)
            let ref = clua_ref(L, LUA_REGISTRY_IDX)

            let modifiers = KeyModifier.from(strings: modStrings)
            bridge.onKeybind?(modifiers, key, { [weak bridge] in
                guard let bridge = bridge else { return }
                print("[Zenn] Lua callback executing for key '\(key)'")
                bridge.vm.pushRef(ref)
                bridge.vm.call(nargs: 0, nresults: 0)
            })

            return 0
        }
        lua_pushcclosure(vm.L, closure, 0)
        vm.setField("bind")
        _ = bridge // keep reference alive
    }

    private func registerFocusFunction() {
        let closure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L) else { return 0 }
            guard let dirStr = bridge.vm.toString(at: 1),
                  let direction = Direction(rawValue: dirStr) else {
                print("[Zenn] zenn.focus(): invalid direction argument")
                return 0
            }

            print("[Zenn] zenn.focus(\(dirStr)) called")
            if let windowID = bridge.focusManager.focusInDirection(direction) {
                print("[Zenn] zenn.focus(): focusing window \(windowID.rawValue)")
                bridge.onFocusChange?(windowID)
            } else {
                print("[Zenn] zenn.focus(): no target found")
            }
            return 0
        }
        lua_pushcclosure(vm.L, closure, 0)
        vm.setField("focus")
    }

    private func registerMoveFunction() {
        let closure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L) else { return 0 }
            guard let dirStr = bridge.vm.toString(at: 1),
                  let direction = Direction(rawValue: dirStr) else { return 0 }

            if let frames = bridge.moveOperation.moveInDirection(direction) {
                bridge.onApplyFrames?(frames)
            }
            return 0
        }
        lua_pushcclosure(vm.L, closure, 0)
        vm.setField("move")
    }

    private func registerMergeFunction() {
        let closure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L) else { return 0 }
            guard let dirStr = bridge.vm.toString(at: 1),
                  let direction = Direction(rawValue: dirStr) else { return 0 }

            print("[Zenn] zenn.merge(\(dirStr)) called")
            if let frames = bridge.moveOperation.mergeInDirection(direction) {
                bridge.onApplyFrames?(frames)
            }
            return 0
        }
        lua_pushcclosure(vm.L, closure, 0)
        vm.setField("merge")
    }

    private func registerEjectFunction() {
        let closure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L) else { return 0 }

            print("[Zenn] zenn.eject() called")
            if let frames = bridge.moveOperation.eject() {
                bridge.onApplyFrames?(frames)
            }
            return 0
        }
        lua_pushcclosure(vm.L, closure, 0)
        vm.setField("eject")
    }

    private func registerResizeFunction() {
        let closure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L) else { return 0 }
            guard let dirStr = bridge.vm.toString(at: 1),
                  let direction = Direction(rawValue: dirStr) else { return 0 }

            if let frames = bridge.resizeOperation.resizeInDirection(direction) {
                bridge.onApplyFrames?(frames)
            }
            return 0
        }
        lua_pushcclosure(vm.L, closure, 0)
        vm.setField("resize")
    }

    private func registerWorkspaceFunction() {
        let closure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L) else { return 0 }
            guard let number = bridge.vm.toInteger(at: 1) else { return 0 }

            bridge.onWorkspaceSwitch?(number)
            return 0
        }
        lua_pushcclosure(vm.L, closure, 0)
        vm.setField("workspace")
    }

    private func registerMoveToWorkspaceFunction() {
        let closure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L) else { return 0 }
            guard let number = bridge.vm.toInteger(at: 1) else { return 0 }

            if let result = bridge.moveOperation.moveToWorkspace(number) {
                bridge.onApplyFrames?(result.source)
            }
            return 0
        }
        lua_pushcclosure(vm.L, closure, 0)
        vm.setField("move_to_workspace")
    }

    private func registerToggleFunctions() {
        // toggle_fullscreen
        let fullscreenClosure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L) else { return 0 }
            if let frames = bridge.fullscreenOperation.toggleFullscreen() {
                bridge.onApplyFrames?(frames)
            }
            return 0
        }
        lua_pushcclosure(vm.L, fullscreenClosure, 0)
        vm.setField("toggle_fullscreen")

        // toggle_floating
        let floatingClosure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L) else { return 0 }
            if let frames = bridge.fullscreenOperation.toggleFloating() {
                bridge.onApplyFrames?(frames)
            }
            return 0
        }
        lua_pushcclosure(vm.L, floatingClosure, 0)
        vm.setField("toggle_floating")

        // toggle_sticky
        let stickyClosure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L) else { return 0 }
            if let frames = bridge.fullscreenOperation.toggleSticky() {
                bridge.onApplyFrames?(frames)
            }
            return 0
        }
        lua_pushcclosure(vm.L, stickyClosure, 0)
        vm.setField("toggle_sticky")

        // toggle_monocle
        let monocleClosure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L) else { return 0 }
            if let frames = bridge.fullscreenOperation.toggleMonocle() {
                bridge.onApplyFrames?(frames)
            }
            return 0
        }
        lua_pushcclosure(vm.L, monocleClosure, 0)
        vm.setField("toggle_monocle")
    }

    private func registerSplitFunction() {
        let closure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L) else { return 0 }
            guard let axisStr = bridge.vm.toString(at: 1),
                  let axis = SplitAxis(rawValue: axisStr) else { return 0 }

            if let workspace = bridge.state.focusedWorkspace {
                workspace.defaultSplitAxis = axis
            }
            return 0
        }
        lua_pushcclosure(vm.L, closure, 0)
        vm.setField("set_split")
    }

    private func registerPresetFunction() {
        let closure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L) else { return 0 }
            guard let presetStr = bridge.vm.toString(at: 1),
                  let preset = ResizePreset(rawValue: presetStr) else { return 0 }

            if let frames = bridge.resizeOperation.applyPreset(preset) {
                bridge.onApplyFrames?(frames)
            }
            return 0
        }
        lua_pushcclosure(vm.L, closure, 0)
        vm.setField("preset")
    }

    private func registerReloadFunction() {
        let closure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L) else { return 0 }
            bridge.onReload?()
            return 0
        }
        lua_pushcclosure(vm.L, closure, 0)
        vm.setField("reload")
    }

    private func registerRuleFunction() {
        let closure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L),
                  lua_type(L, 1) == LUA_TTABLE else { return 0 }

            var rule = WindowRule()

            lua_getfield(L, 1, "app")
            if let app = bridge.vm.toString(at: -1) {
                rule.appNamePattern = app
            }
            bridge.vm.pop()

            lua_getfield(L, 1, "title")
            if let title = bridge.vm.toString(at: -1) {
                rule.titlePattern = title
            }
            bridge.vm.pop()

            lua_getfield(L, 1, "bundle_id")
            if let bundleID = bridge.vm.toString(at: -1) {
                rule.bundleID = bundleID
            }
            bridge.vm.pop()

            lua_getfield(L, 1, "floating")
            if bridge.vm.toBool(at: -1) {
                rule.mode = .floating
            }
            bridge.vm.pop()

            lua_getfield(L, 1, "sticky")
            if bridge.vm.toBool(at: -1) {
                rule.mode = .sticky
            }
            bridge.vm.pop()

            lua_getfield(L, 1, "workspace")
            if let ws = bridge.vm.toInteger(at: -1) {
                rule.workspace = WorkspaceID(number: ws)
            }
            bridge.vm.pop()

            bridge.state.windowRules.append(rule)
            bridge.onWindowRule?(rule)

            return 0
        }
        lua_pushcclosure(vm.L, closure, 0)
        vm.setField("rule")
    }

    private func registerGapsFunction() {
        let closure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L),
                  lua_type(L, 1) == LUA_TTABLE else { return 0 }

            var inner: Double = 0
            var outer: Double = 0

            lua_getfield(L, 1, "inner")
            if let val = bridge.vm.toNumber(at: -1) { inner = val }
            bridge.vm.pop()

            lua_getfield(L, 1, "outer")
            if let val = bridge.vm.toNumber(at: -1) { outer = val }
            bridge.vm.pop()

            bridge.state.globalGaps = GapConfig(inner: inner, outerAll: outer)

            return 0
        }
        lua_pushcclosure(vm.L, closure, 0)
        vm.setField("gaps")
    }

    private func registerHookFunction() {
        let closure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L),
                  let eventStr = bridge.vm.toString(at: 1),
                  let eventType = HookEventType(rawValue: eventStr),
                  lua_type(L, 2) == LUA_TFUNCTION else { return 0 }

            lua_pushvalue(L, 2)
            let ref = clua_ref(L, LUA_REGISTRY_IDX)

            bridge.hookRegistry.on(eventType) { [weak bridge] event in
                guard let bridge = bridge else { return }
                bridge.vm.pushRef(ref)
                // Push event data as a table
                bridge.vm.newTable()
                for (key, value) in event.data {
                    bridge.vm.pushString(value)
                    lua_setfield(bridge.vm.L, -2, key)
                }
                bridge.vm.call(nargs: 1, nresults: 0)
            }

            return 0
        }
        lua_pushcclosure(vm.L, closure, 0)
        vm.setField("on")
    }

    private func registerExecFunction() {
        // zenn.exec(event_name, script_path, [args...])
        // Registers a script to run when the given hook event fires.
        // The script receives event data as ZENN_* environment variables.
        let closure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L),
                  let eventStr = bridge.vm.toString(at: 1),
                  let eventType = HookEventType(rawValue: eventStr),
                  let scriptPath = bridge.vm.toString(at: 2) else { return 0 }

            var args: [String] = []
            let nargs = lua_gettop(L)
            if nargs > 2 {
                for i in 3...nargs {
                    if let arg = bridge.vm.toString(at: Int32(i)) {
                        args.append(arg)
                    }
                }
            }

            bridge.hookRegistry.onScript(eventType, scriptPath: scriptPath, arguments: args)
            return 0
        }
        lua_pushcclosure(vm.L, closure, 0)
        vm.setField("exec")
    }

    private func registerQueryFunctions() {
        // zenn.focused() -> table with window info
        let focusedClosure: @convention(c) (OpaquePointer?) -> Int32 = { L in
            guard let L = L,
                  let bridge = LuaBridge.getBridge(from: L) else { return 0 }

            guard let windowState = bridge.state.focusedWindow else {
                lua_pushnil(L)
                return 1
            }

            bridge.vm.newTable()
            bridge.vm.pushString(windowState.appName)
            lua_setfield(L, -2, "app")
            bridge.vm.pushString(windowState.windowTitle)
            lua_setfield(L, -2, "title")
            bridge.vm.pushString(windowState.appBundleID)
            lua_setfield(L, -2, "bundle_id")
            bridge.vm.pushInteger(Int(windowState.windowID.rawValue))
            lua_setfield(L, -2, "id")

            return 1
        }
        lua_pushcclosure(vm.L, focusedClosure, 0)
        vm.setField("focused")
    }

    /// Helper to get the bridge from a Lua state.
    static func getBridge(from L: OpaquePointer) -> LuaBridge? {
        lua_getfield(L, LUA_REGISTRY_IDX, "__zenn_bridge")
        guard lua_type(L, -1) == LUA_TLIGHTUSERDATA else {
            lua_settop(L, -(1)-1)
            return nil
        }
        let ptr = lua_touserdata(L, -1)
        lua_settop(L, -(1)-1)
        guard let ptr = ptr else { return nil }
        return Unmanaged<LuaBridge>.fromOpaque(ptr).takeUnretainedValue()
    }
}
