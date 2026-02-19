import Foundation
#if canImport(AppKit)
import AppKit
import ZennShared

/// Manages the menu bar status item and menu.
public class StatusBarController {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    /// Callbacks for menu actions.
    public var onReload: (() -> Void)?
    public var onQuit: (() -> Void)?
    public var onToggleTiling: (() -> Void)?

    /// Current tiling state display.
    public var isTilingEnabled: Bool = true {
        didSet { updateMenu() }
    }

    /// Current workspace display.
    public var activeWorkspace: String = "1" {
        didSet { updateTitle() }
    }

    public init() {}

    /// Set up the status bar item.
    public func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "Z"
            button.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        }

        buildMenu()
        updateTitle()
    }

    private func buildMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Zenn Window Manager", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let tilingItem = NSMenuItem(title: "Tiling Enabled", action: #selector(toggleTiling), keyEquivalent: "")
        tilingItem.state = isTilingEnabled ? .on : .off
        tilingItem.target = self
        menu.addItem(tilingItem)

        menu.addItem(NSMenuItem.separator())

        let reloadItem = NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Zenn", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.menu = menu
        statusItem?.menu = menu
    }

    private func updateTitle() {
        statusItem?.button?.title = "Z:\(activeWorkspace)"
    }

    private func updateMenu() {
        if let tilingItem = menu?.items.first(where: { $0.title == "Tiling Enabled" }) {
            tilingItem.state = isTilingEnabled ? .on : .off
        }
    }

    @objc private func toggleTiling() {
        onToggleTiling?()
    }

    @objc private func reloadConfig() {
        onReload?()
    }

    @objc private func quit() {
        onQuit?()
    }
}
#endif
