import Foundation
import AppKit
import ApplicationServices
import ZennShared
import ZennCore
import ZennMacOS

/// Central coordinator that wires together all components of the tiling window manager.
public class TilingCoordinator {
    // Core
    public let state: WorldState
    public let hookRegistry: HookRegistry
    public let hookDispatcher: HookDispatcher
    public let layoutEngine: LayoutEngine

    // Operations
    public let focusManager: FocusManager
    public let tileOperation: TileOperation
    public let swapOperation: SwapOperation
    public let resizeOperation: ResizeOperation
    public let moveOperation: MoveOperation
    public let fullscreenOperation: FullscreenOperation

    // macOS
    public let displayManager: DisplayManager
    public let displayObserver: DisplayObserver
    public let windowDiscovery: WindowDiscovery
    public let axObserverManager: AXObserverManager
    public let virtualWorkspaceManager: VirtualWorkspaceManager
    public let hotkeyManager: HotkeyManager

    // State
    public let statePersistence: StatePersistence
    public let focusBorderOverlay: FocusBorderOverlay
    public let animationController: AnimationController

    /// Whether tiling is currently active.
    public var isTilingEnabled: Bool = true

    /// App launch/quit observation tokens.
    private var launchObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var accessibilityCheckTimer: Timer?

    public init() {
        // Initialize core components
        state = WorldState()
        hookRegistry = HookRegistry()
        hookDispatcher = HookDispatcher(registry: hookRegistry)
        layoutEngine = LayoutEngine(state: state)

        // Initialize operations
        focusManager = FocusManager(state: state, layoutEngine: layoutEngine)
        tileOperation = TileOperation(state: state, layoutEngine: layoutEngine, hookDispatcher: hookDispatcher)
        swapOperation = SwapOperation(state: state, layoutEngine: layoutEngine, hookDispatcher: hookDispatcher)
        resizeOperation = ResizeOperation(state: state, layoutEngine: layoutEngine, hookDispatcher: hookDispatcher)
        moveOperation = MoveOperation(state: state, layoutEngine: layoutEngine, hookDispatcher: hookDispatcher)
        fullscreenOperation = FullscreenOperation(state: state, layoutEngine: layoutEngine, hookDispatcher: hookDispatcher)

        // Initialize macOS components
        displayManager = DisplayManager()
        displayObserver = DisplayObserver()
        windowDiscovery = WindowDiscovery()
        axObserverManager = AXObserverManager()
        virtualWorkspaceManager = VirtualWorkspaceManager()
        hotkeyManager = HotkeyManager()

        // Initialize state management
        statePersistence = StatePersistence()
        focusBorderOverlay = FocusBorderOverlay()
        animationController = AnimationController()
    }

    /// Start the tiling window manager.
    public func start() {
        // 1. Detect monitors
        setupMonitors()

        // 2. Restore saved state (workspace structure, gaps, layout modes)
        restoreSavedState()

        // 3. Start observing display changes
        setupDisplayObserver()

        // 4. Discover existing windows
        discoverExistingWindows()

        // 5. Start observing app launches/quits
        setupAppObservers()

        // 6. Setup accessibility observers for running apps
        setupAccessibilityObservers()

        // 7. Start hotkey manager
        if !hotkeyManager.start() {
            print("[Zenn] Warning: Failed to start hotkey manager. Accessibility permission may be needed.")
        }

        // 8. Setup sleep/wake observers
        setupSleepWakeObservers()

        // 9. Start periodic accessibility permission check
        startAccessibilityMonitor()

        // 10. Do initial layout
        retileAllWorkspaces()

        print("[Zenn] Tiling started")
    }

    /// Stop the tiling window manager.
    public func stop() {
        hotkeyManager.stop()
        axObserverManager.stopAll()
        displayObserver.stopObserving()
        focusBorderOverlay.hide()
        accessibilityCheckTimer?.invalidate()
        accessibilityCheckTimer = nil

        let nc = NSWorkspace.shared.notificationCenter
        if let obs = launchObserver { nc.removeObserver(obs) }
        if let obs = terminateObserver { nc.removeObserver(obs) }
        if let obs = sleepObserver { nc.removeObserver(obs) }
        if let obs = wakeObserver { nc.removeObserver(obs) }

        // Save state
        try? statePersistence.save(state: state)

        print("[Zenn] Tiling stopped")
    }

    // MARK: - Setup

    private func setupMonitors() {
        let displays = displayManager.allDisplays()
        for display in displays {
            let monitor = Monitor(
                displayID: display.displayID,
                frame: display.frame,
                visibleFrame: display.visibleFrame
            )
            monitor.gaps = state.globalGaps
            state.addMonitor(monitor)
        }
    }

    private func setupDisplayObserver() {
        displayObserver.startObserving { [weak self] event in
            guard let self = self else { return }
            switch event {
            case .displayConnected(let displayID):
                self.handleDisplayConnected(displayID)
            case .displayDisconnected(let displayID):
                self.handleDisplayDisconnected(displayID)
            case .displayReconfigured(let displayID):
                self.handleDisplayReconfigured(displayID)
            }
        }
    }

    private func discoverExistingWindows() {
        let windows = windowDiscovery.discoverWindows()
        guard let primaryMonitor = state.primaryMonitor,
              let workspace = primaryMonitor.activeWorkspace else { return }

        for window in windows {
            guard !window.isMinimized else { continue }

            // Register AX reference
            virtualWorkspaceManager.registerAXWindow(window.axWindow)

            // Tile the window
            _ = tileOperation.tileWindow(
                windowID: window.windowID,
                appName: window.appName,
                appBundleID: window.appBundleID,
                pid: window.pid,
                title: window.title,
                frame: window.frame,
                on: workspace.id,
                monitorID: primaryMonitor.displayID
            )
        }
    }

    private func setupAppObservers() {
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.handleAppLaunched(app)
        }

        terminateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.handleAppTerminated(app)
        }
    }

    private func setupAccessibilityObservers() {
        axObserverManager.eventHandler = { [weak self] event in
            self?.handleWindowEvent(event)
        }

        // Observe all running apps with regular activation policy
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            axObserverManager.observe(pid: app.processIdentifier)
        }
    }

    // MARK: - Event Handlers

    private func handleAppLaunched(_ app: NSRunningApplication) {
        guard app.activationPolicy == .regular else { return }
        let bundleID = app.bundleIdentifier ?? ""
        let appName = app.localizedName ?? bundleID

        axObserverManager.observe(pid: app.processIdentifier)
        hookDispatcher.appLaunched(appName: appName, bundleID: bundleID)

        // Wait briefly for windows to appear, then discover them
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.discoverWindowsForApp(app)
        }
    }

    private func handleAppTerminated(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        let bundleID = app.bundleIdentifier ?? ""
        let appName = app.localizedName ?? bundleID

        axObserverManager.stopObserving(pid: pid)

        // Remove all windows for this app
        let windows = state.windowRegistry.windows(forPID: pid)
        for window in windows {
            _ = tileOperation.untileWindow(windowID: window.windowID)
            virtualWorkspaceManager.unregisterAXWindow(window.windowID)
        }

        retileActiveWorkspace()
        hookDispatcher.appTerminated(appName: appName, bundleID: bundleID)
    }

    private func handleWindowEvent(_ event: AXObserverManager.WindowEvent) {
        guard isTilingEnabled else { return }

        switch event {
        case .created(let pid, let element):
            handleWindowCreated(pid: pid, element: element)
        case .destroyed(let pid, let element):
            handleWindowDestroyed(pid: pid, element: element)
        case .focused(let pid, let element):
            handleWindowFocused(pid: pid, element: element)
        case .moved(_, let element):
            let windowID = AXHelpers.windowID(from: element)
            if let ws = state.windowRegistry.window(for: windowID) {
                hookDispatcher.windowMoved(windowID: windowID, appName: ws.appName)
            }
        case .resized(_, let element):
            let windowID = AXHelpers.windowID(from: element)
            if let ws = state.windowRegistry.window(for: windowID) {
                hookDispatcher.windowResized(windowID: windowID, appName: ws.appName)
            }
        case .minimized(_, let element):
            let windowID = AXHelpers.windowID(from: element)
            if let windowState = state.windowRegistry.window(for: windowID) {
                windowState.isMinimized = true
                // Remove from tree temporarily
                if let workspace = state.workspace(for: windowState.workspaceID) {
                    workspace.removeWindow(windowID)
                    retileWorkspace(workspace)
                }
                hookDispatcher.windowMinimized(windowID: windowID, appName: windowState.appName)
            }
        case .deminimized(_, let element):
            let windowID = AXHelpers.windowID(from: element)
            if let windowState = state.windowRegistry.window(for: windowID) {
                windowState.isMinimized = false
                // Re-add to tree
                if let workspace = state.workspace(for: windowState.workspaceID) {
                    let node = WindowNode(
                        windowID: windowID,
                        appBundleID: windowState.appBundleID,
                        appName: windowState.appName,
                        windowTitle: windowState.windowTitle
                    )
                    workspace.insertWindow(node)
                    retileWorkspace(workspace)
                }
                hookDispatcher.windowDeminimized(windowID: windowID, appName: windowState.appName)
            }
        case .titleChanged(_, let element):
            let windowID = AXHelpers.windowID(from: element)
            let title = AXHelpers.title(of: element)
            if let windowState = state.windowRegistry.window(for: windowID) {
                windowState.windowTitle = title
                hookDispatcher.windowTitleChanged(windowID: windowID, title: title)
            }
        }
    }

    private func handleWindowCreated(pid: pid_t, element: AXUIElement) {
        guard let axWindow = AXWindow(element: element, pid: pid),
              axWindow.isStandardWindow,
              !state.windowRegistry.contains(axWindow.windowID) else { return }

        guard let frame = axWindow.frame else { return }

        let app = NSRunningApplication(processIdentifier: pid)
        let appName = app?.localizedName ?? ""
        let bundleID = app?.bundleIdentifier ?? ""

        guard let monitor = state.focusedMonitor ?? state.primaryMonitor,
              let workspace = monitor.activeWorkspace else { return }

        virtualWorkspaceManager.registerAXWindow(axWindow)

        if let frames = tileOperation.tileWindow(
            windowID: axWindow.windowID,
            appName: appName,
            appBundleID: bundleID,
            pid: pid,
            title: axWindow.title,
            frame: frame,
            on: workspace.id,
            monitorID: monitor.displayID
        ) {
            applyFrames(frames)
        }
    }

    private func handleWindowDestroyed(pid: pid_t, element: AXUIElement) {
        let windowID = AXHelpers.windowID(from: element)
        guard !windowID.isNull, state.windowRegistry.contains(windowID) else { return }

        if let frames = tileOperation.untileWindow(windowID: windowID) {
            applyFrames(frames)
        }
        virtualWorkspaceManager.unregisterAXWindow(windowID)

        // Update focus
        _ = focusManager.handleWindowDestroyed(windowID)
        if let newFocus = state.focusedWindowID {
            virtualWorkspaceManager.focusWindow(newFocus)
        }
    }

    private func handleWindowFocused(pid: pid_t, element: AXUIElement) {
        let windowID = AXHelpers.windowID(from: element)
        guard !windowID.isNull, state.windowRegistry.contains(windowID) else { return }

        state.setFocus(to: windowID)

        // Update focus border
        if let windowState = state.windowRegistry.window(for: windowID) {
            focusBorderOverlay.show(around: windowState.frame)
            hookDispatcher.windowFocused(
                windowID: windowID,
                appName: windowState.appName,
                title: windowState.windowTitle
            )
        }
    }

    private func discoverWindowsForApp(_ app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier else { return }
        let appName = app.localizedName ?? bundleID
        let pid = app.processIdentifier

        let axApp = AXApplication(pid: pid, appName: appName, bundleID: bundleID)
        let windows = axApp.tileableWindows()

        guard let monitor = state.focusedMonitor ?? state.primaryMonitor,
              let workspace = monitor.activeWorkspace else { return }

        for axWindow in windows {
            guard !state.windowRegistry.contains(axWindow.windowID),
                  let frame = axWindow.frame else { continue }

            virtualWorkspaceManager.registerAXWindow(axWindow)

            if let frames = tileOperation.tileWindow(
                windowID: axWindow.windowID,
                appName: appName,
                appBundleID: bundleID,
                pid: pid,
                title: axWindow.title,
                frame: frame,
                on: workspace.id,
                monitorID: monitor.displayID
            ) {
                applyFrames(frames)
            }
        }
    }

    // MARK: - State Restoration

    private func restoreSavedState() {
        guard statePersistence.hasSavedState else { return }

        do {
            let snapshot = try statePersistence.load()

            // Restore global gaps
            state.globalGaps = snapshot.globalGaps

            // Restore workspace settings for matching monitors
            for monitorSnap in snapshot.monitors {
                let displayID = DisplayID(monitorSnap.displayID)
                guard let monitor = state.monitor(for: displayID) else { continue }

                monitor.gaps = monitorSnap.gaps

                for wsSnap in monitorSnap.workspaces {
                    // workspace(number:name:) creates if not existing, with the correct ID
                    let workspace = monitor.workspace(number: wsSnap.number, name: wsSnap.name)
                    workspace.layoutMode = wsSnap.layoutMode
                    workspace.defaultSplitAxis = wsSnap.defaultSplitAxis
                    workspace.gapOverride = wsSnap.gapOverride

                    // Restore tree structure (windows will be re-associated during discovery)
                    if let treeSnap = wsSnap.treeSnapshot {
                        let restoredNode = statePersistence.restoreTree(from: treeSnap)
                        workspace.tileRoot = restoredNode.containerNode
                    }
                }

                // Restore active workspace
                monitor.switchToWorkspace(number: monitorSnap.activeWorkspaceNumber)
            }

            print("[Zenn] Restored state from disk")
        } catch {
            print("[Zenn] Failed to restore state: \(error)")
        }
    }

    // MARK: - Sleep/Wake

    private func setupSleepWakeObservers() {
        let nc = NSWorkspace.shared.notificationCenter

        sleepObserver = nc.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenSleep()
        }

        wakeObserver = nc.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenWake()
        }
    }

    private func handleScreenSleep() {
        // Save state before sleep in case of power loss
        try? statePersistence.save(state: state)
        print("[Zenn] Screen sleep — state saved")
    }

    private func handleScreenWake() {
        // After wake, monitors may have changed — re-detect and retile
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            // Refresh monitor frames (resolution may change after wake)
            let displays = self.displayManager.allDisplays()
            for display in displays {
                if let monitor = self.state.monitor(for: display.displayID) {
                    monitor.frame = display.frame
                    monitor.visibleFrame = display.visibleFrame
                }
            }

            self.retileAllWorkspaces()
            print("[Zenn] Screen wake — layout refreshed")
        }
    }

    // MARK: - Accessibility Monitoring

    private func startAccessibilityMonitor() {
        accessibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !AXHelpers.isAccessibilityEnabled {
                print("[Zenn] Warning: Accessibility permission revoked. Tiling may not function correctly.")
                self.isTilingEnabled = false
                self.hotkeyManager.stop()
            } else if !self.isTilingEnabled {
                // Permission restored
                print("[Zenn] Accessibility permission restored. Re-enabling tiling.")
                self.isTilingEnabled = true
                _ = self.hotkeyManager.start()
                self.retileAllWorkspaces()
            }
        }
    }

    // MARK: - Display Events

    private func handleDisplayConnected(_ displayID: DisplayID) {
        let displays = displayManager.allDisplays()
        if let display = displays.first(where: { $0.displayID == displayID }) {
            let monitor = Monitor(displayID: displayID, frame: display.frame, visibleFrame: display.visibleFrame)
            monitor.gaps = state.globalGaps
            state.addMonitor(monitor)
            hookDispatcher.monitorConnected(displayID)
        }
    }

    private func handleDisplayDisconnected(_ displayID: DisplayID) {
        guard let disconnectedMonitor = state.removeMonitor(displayID),
              let primaryMonitor = state.primaryMonitor else { return }

        // Migrate windows to primary monitor
        for (_, workspace) in disconnectedMonitor.workspaces {
            guard let root = workspace.tileRoot else { continue }
            let windowIDs = root.allWindowIDs
            for windowID in windowIDs {
                if let windowState = state.windowRegistry.window(for: windowID),
                   let primaryWorkspace = primaryMonitor.activeWorkspace {
                    windowState.workspaceID = primaryWorkspace.id
                    windowState.monitorID = primaryMonitor.displayID
                    if let node = workspace.removeWindow(windowID) {
                        primaryWorkspace.insertWindow(node)
                    }
                }
            }
        }

        retileAllWorkspaces()
        hookDispatcher.monitorDisconnected(displayID)
    }

    private func handleDisplayReconfigured(_ displayID: DisplayID) {
        let displays = displayManager.allDisplays()
        if let display = displays.first(where: { $0.displayID == displayID }),
           let monitor = state.monitor(for: displayID) {
            monitor.frame = display.frame
            monitor.visibleFrame = display.visibleFrame
            retileAllWorkspaces()
        }
    }

    // MARK: - Workspace Switching

    /// Switch to a workspace number on the focused monitor.
    public func switchToWorkspace(_ number: Int) {
        guard let monitor = state.focusedMonitor ?? state.primaryMonitor else { return }

        let previousNumber = monitor.activeWorkspaceNumber

        // Back-and-forth: if switching to the same workspace, go back
        if number == previousNumber {
            if let prevWS = monitor.activeWorkspace?.previousWorkspaceID {
                switchToWorkspace(prevWS.number)
                return
            }
            return
        }

        // Hide current workspace windows
        if let currentWorkspace = monitor.activeWorkspace {
            let windowIDs = currentWorkspace.tileRoot?.allWindowIDs ?? []
            virtualWorkspaceManager.hideWindows(windowIDs)
        }

        // Switch workspace
        monitor.switchToWorkspace(number: number)

        // Show new workspace windows
        if let newWorkspace = monitor.activeWorkspace {
            let frames = layoutEngine.applyLayout(for: newWorkspace)
            virtualWorkspaceManager.showWindows(frames)

            // Focus the workspace's focused window
            if let focusedID = newWorkspace.focusedWindowID {
                state.setFocus(to: focusedID)
                virtualWorkspaceManager.focusWindow(focusedID)
            }
        }

        hookDispatcher.workspaceSwitched(
            to: WorkspaceID(number: number),
            from: WorkspaceID(number: previousNumber)
        )
    }

    // MARK: - Layout Application

    /// Apply frames to all windows via the virtual workspace manager.
    public func applyFrames(_ frames: [WindowID: Rect]) {
        if animationController.isEnabled {
            // Collect current frames
            var currentFrames: [WindowID: Rect] = [:]
            for (windowID, _) in frames {
                if let ws = state.windowRegistry.window(for: windowID) {
                    currentFrames[windowID] = ws.frame
                }
            }

            let transitions = animationController.transitions(current: currentFrames, target: frames)
            if transitions.isEmpty {
                virtualWorkspaceManager.applyFrames(frames)
                return
            }

            // Simple step-based animation
            let steps = 10
            let stepDuration = animationController.duration / Double(steps)

            for step in 0...steps {
                let progress = Double(step) / Double(steps)
                var interpolatedFrames: [WindowID: Rect] = [:]

                for transition in transitions {
                    interpolatedFrames[transition.windowID] = animationController.interpolate(
                        from: transition.fromFrame,
                        to: transition.toFrame,
                        progress: progress
                    )
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) { [weak self] in
                    self?.virtualWorkspaceManager.applyFrames(interpolatedFrames)
                }
            }
        } else {
            virtualWorkspaceManager.applyFrames(frames)
        }
    }

    /// Retile the active workspace on the focused monitor.
    public func retileActiveWorkspace() {
        guard let workspace = state.focusedWorkspace ?? state.primaryMonitor?.activeWorkspace else { return }
        retileWorkspace(workspace)
    }

    /// Retile a specific workspace.
    public func retileWorkspace(_ workspace: Workspace) {
        let frames = layoutEngine.applyLayout(for: workspace)
        if workspace.isActive {
            applyFrames(frames)
        }
    }

    /// Retile all active workspaces on all monitors.
    public func retileAllWorkspaces() {
        for (_, monitor) in state.monitors {
            if let workspace = monitor.activeWorkspace {
                retileWorkspace(workspace)
            }
        }
    }
}
