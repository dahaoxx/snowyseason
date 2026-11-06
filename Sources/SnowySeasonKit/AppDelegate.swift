import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let tracker = WindowTracker()
    private var statusMenu: StatusMenu?
    private var overlays: [OverlayWindow] = []
    private var activeWeather: Weather?
    /// Screens asleep or the user session switched away: nothing to draw for.
    private var isPaused = false

    override public init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        activeWeather = Weather.savedChoice()
        statusMenu = StatusMenu(selection: activeWeather) { [weak self] weather in
            self?.choose(weather)
        }
        observeSystemEvents()
        showActiveWeather()
    }

    private func choose(_ weather: Weather?) {
        guard weather != activeWeather else { return }
        activeWeather = weather
        Weather.saveChoice(weather)
        statusMenu?.show(selection: weather)
        showActiveWeather()
    }

    private func showActiveWeather() {
        overlays.forEach { $0.close() }
        overlays = []
        guard let weather = activeWeather else {
            tracker.stop()
            return
        }
        if !isPaused { tracker.start() }
        overlays = NSScreen.screens.map { screen in
            let scene = WeatherScene(screenFrame: screen.frame, style: weather.style, tracker: tracker)
            let overlay = OverlayWindow(screen: screen, scene: scene)
            overlay.weatherView.isPaused = isPaused
            overlay.orderFrontRegardless()
            return overlay
        }
    }

    private func pause() {
        isPaused = true
        tracker.stop()
        overlays.forEach { $0.weatherView.isPaused = true }
    }

    private func resume() {
        isPaused = false
        guard activeWeather != nil else { return }
        tracker.start()
        overlays.forEach { $0.weatherView.isPaused = false }
    }

    private func observeSystemEvents() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.showActiveWeather() }
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
