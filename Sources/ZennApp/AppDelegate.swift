import Foundation
#if canImport(AppKit)
import AppKit
import ZennCore
import ZennMacOS
import ZennLua
import ZennIPC
import ZennShared

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var tilingCoordinator: TilingCoordinator!
    private var luaBridge: LuaBridge!
    private var unixSocketServer: UnixSocketServer!
    private var httpServer: HTTPServer!
    private var eventBroadcaster: EventBroadcaster!
    private var commandRouter: CommandRouter!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Check accessibility
        let guard_ = AccessibilityGuard()
        if !guard_.ensureAccessibility() {
            guard_.waitForAccessibility { [weak self] granted in
                if granted {
                    self?.initialize()
                }
            }
            return
        }

        initialize()
    }

    private func initialize() {
        // 1. Create the tiling coordinator (core engine)
        tilingCoordinator = TilingCoordinator()

        // 2. Set up Lua bridge
        luaBridge = LuaBridge(
            state: tilingCoordinator.state,
            focusManager: tilingCoordinator.focusManager,
            tileOperation: tilingCoordinator.tileOperation,
            swapOperation: tilingCoordinator.swapOperation,
            resizeOperation: tilingCoordinator.resizeOperation,
            moveOperation: tilingCoordinator.moveOperation,
            fullscreenOperation: tilingCoordinator.fullscreenOperation,
            hookRegistry: tilingCoordinator.hookRegistry
        )

        // Wire Lua callbacks
        luaBridge.onKeybind = { [weak self] modifiers, key, action in
            self?.tilingCoordinator.hotkeyManager.bind(modifiers: modifiers, key: key, action: action)
        }
        luaBridge.onApplyFrames = { [weak self] frames in
            self?.tilingCoordinator.applyFrames(frames)
        }
        luaBridge.onWorkspaceSwitch = { [weak self] number in
            self?.tilingCoordinator.switchToWorkspace(number)
            self?.statusBarController.activeWorkspace = "\(number)"
        }
        luaBridge.onFocusChange = { [weak self] windowID in
            self?.tilingCoordinator.virtualWorkspaceManager.focusWindow(windowID)
        }
        luaBridge.onReload = { [weak self] in
            self?.reloadConfig()
        }

        // 3. Load Lua config
        LuaBridge.ensureDefaultConfig()
        let configPath = LuaBridge.defaultConfigPath
        if !luaBridge.loadConfig(at: configPath) {
            for error in luaBridge.vm.errors {
                print("[Zenn] Config error: \(error)")
            }
        }

        // 4. Set up IPC
        commandRouter = CommandRouter(
            state: tilingCoordinator.state,
            focusManager: tilingCoordinator.focusManager,
            tileOperation: tilingCoordinator.tileOperation,
            swapOperation: tilingCoordinator.swapOperation,
            resizeOperation: tilingCoordinator.resizeOperation,
            moveOperation: tilingCoordinator.moveOperation,
            fullscreenOperation: tilingCoordinator.fullscreenOperation,
            hookRegistry: tilingCoordinator.hookRegistry,
            hookDispatcher: tilingCoordinator.hookDispatcher
        )
        commandRouter.onApplyFrames = { [weak self] frames in
            self?.tilingCoordinator.applyFrames(frames)
        }
        commandRouter.onWorkspaceSwitch = { [weak self] number in
            self?.tilingCoordinator.switchToWorkspace(number)
            self?.statusBarController.activeWorkspace = "\(number)"
        }
        commandRouter.onFocusChange = { [weak self] windowID in
            self?.tilingCoordinator.virtualWorkspaceManager.focusWindow(windowID)
        }
        commandRouter.onReload = { [weak self] in
            self?.reloadConfig()
        }
        commandRouter.onQuit = {
            NSApplication.shared.terminate(nil)
        }

        // Start IPC servers
        unixSocketServer = UnixSocketServer(commandRouter: commandRouter)
        httpServer = HTTPServer(commandRouter: commandRouter)

        do {
            try unixSocketServer.start()
            print("[Zenn] Unix socket server started at \(IPCMessage.socketPath)")
        } catch {
            print("[Zenn] Failed to start Unix socket server: \(error)")
        }

        do {
            try httpServer.start()
            print("[Zenn] HTTP server started at \(IPCMessage.httpBaseURL)")
        } catch {
            print("[Zenn] Failed to start HTTP server: \(error)")
        }

        // 5. Event broadcaster
        eventBroadcaster = EventBroadcaster(hookRegistry: tilingCoordinator.hookRegistry)
        eventBroadcaster.start()

        // 6. Set up status bar
        statusBarController = StatusBarController()
        statusBarController.setup()
        statusBarController.onReload = { [weak self] in
            self?.reloadConfig()
        }
        statusBarController.onQuit = {
            NSApplication.shared.terminate(nil)
        }
        statusBarController.onToggleTiling = { [weak self] in
            guard let self = self else { return }
            self.tilingCoordinator.isTilingEnabled.toggle()
            self.statusBarController.isTilingEnabled = self.tilingCoordinator.isTilingEnabled
        }

        // 7. Start tiling
        tilingCoordinator.start()

        print("[Zenn] Started successfully")
    }

    private func reloadConfig() {
        tilingCoordinator.hotkeyManager.stop()
        tilingCoordinator.state.windowRules.removeAll()

        // Recreate Lua bridge with fresh state
        luaBridge = LuaBridge(
            state: tilingCoordinator.state,
            focusManager: tilingCoordinator.focusManager,
            tileOperation: tilingCoordinator.tileOperation,
            swapOperation: tilingCoordinator.swapOperation,
            resizeOperation: tilingCoordinator.resizeOperation,
            moveOperation: tilingCoordinator.moveOperation,
            fullscreenOperation: tilingCoordinator.fullscreenOperation,
            hookRegistry: tilingCoordinator.hookRegistry
        )

        luaBridge.onKeybind = { [weak self] modifiers, key, action in
            self?.tilingCoordinator.hotkeyManager.bind(modifiers: modifiers, key: key, action: action)
        }
        luaBridge.onApplyFrames = { [weak self] frames in
            self?.tilingCoordinator.applyFrames(frames)
        }
        luaBridge.onWorkspaceSwitch = { [weak self] number in
            self?.tilingCoordinator.switchToWorkspace(number)
            self?.statusBarController.activeWorkspace = "\(number)"
        }
        luaBridge.onFocusChange = { [weak self] windowID in
            self?.tilingCoordinator.virtualWorkspaceManager.focusWindow(windowID)
        }
        luaBridge.onReload = { [weak self] in
            self?.reloadConfig()
        }

        let configPath = LuaBridge.defaultConfigPath
        if luaBridge.loadConfig(at: configPath) {
            print("[Zenn] Config reloaded successfully")
        } else {
            for error in luaBridge.vm.errors {
                print("[Zenn] Config error: \(error)")
            }
        }

        if !tilingCoordinator.hotkeyManager.start() {
            print("[Zenn] Warning: Failed to restart hotkey manager")
        }

        tilingCoordinator.hookDispatcher.configReloaded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tilingCoordinator?.stop()
        unixSocketServer?.stop()
        httpServer?.stop()
        eventBroadcaster?.stop()
    }
}
#endif
