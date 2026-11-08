import AppKit
import SpriteKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let tracker = WindowTracker()
    private var statusMenu: StatusMenu?
    private var overlays: [OverlayWindow] = []
    private var activeMode: Mode?
    /// Screens asleep or the user session switched away: nothing to draw for.
    private var isPaused = false

    override public init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        activeMode = Mode.savedChoice()
        statusMenu = StatusMenu(selection: activeMode) { [weak self] mode in
            self?.choose(mode)
        }
        observeSystemEvents()
        showActiveMode()
    }

    private func choose(_ mode: Mode?) {
        guard mode != activeMode else { return }
        activeMode = mode
        Mode.saveChoice(mode)
        statusMenu?.show(selection: mode)
        showActiveMode()
    }

    private func showActiveMode() {
        overlays.forEach { $0.close() }
        overlays = []
        guard let mode = activeMode else {
            tracker.stop()
            return
        }
        if !isPaused { tracker.start() }
        overlays = screens(for: mode).map { screen in
            let overlay = OverlayWindow(screen: screen, scene: makeScene(for: mode, on: screen))
            overlay.sceneView.isPaused = isPaused
            overlay.orderFrontRegardless()
            return overlay
        }
    }

    /// Weather falls on every screen; there is only one cat, on the screen with the menu bar.
    private func screens(for mode: Mode) -> [NSScreen] {
        mode == .cat ? Array(NSScreen.screens.prefix(1)) : NSScreen.screens
    }

    private func makeScene(for mode: Mode, on screen: NSScreen) -> SKScene {
        switch mode {
        case .snow: WeatherScene(screenFrame: screen.frame, style: .snow, tracker: tracker)
        case .autumnLeaves: WeatherScene(screenFrame: screen.frame, style: .autumnLeaves, tracker: tracker)
        case .cat: CatScene(screenFrame: screen.frame, usableFrame: screen.visibleFrame, tracker: tracker)
        }
    }

    private func pause() {
        isPaused = true
        tracker.stop()
        overlays.forEach { $0.sceneView.isPaused = true }
    }

    private func resume() {
        isPaused = false
        guard activeMode != nil else { return }
        tracker.start()
        overlays.forEach { $0.sceneView.isPaused = false }
    }

    private func observeSystemEvents() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.showActiveMode() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.pause() }
            }
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.resume() }
            }
        }
    }
}
