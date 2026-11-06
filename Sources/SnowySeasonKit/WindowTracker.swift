import AppKit
import OSLog
import WeatherCore

/// Polls the on-screen window list so weather knows where window tops are and when a window is dragged.
/// Reading frames from CGWindowList needs no Screen Recording permission; only window titles would.
@MainActor
final class WindowTracker: WindowLayout {
    private(set) var windows: [CGWindowID: TrackedWindow] = [:]
    private(set) var surfaces: [WindowSurface] = []
    private(set) var revision = 0

    private static let pollInterval: TimeInterval = 1.0 / 30
    /// A window counts as being dragged until it has stayed put this long.
    private static let settleDelay: TimeInterval = 0.25
    private static let normalWindowLayer = 0
    private static let minimumWindowSize = CGSize(width: 80, height: 40)

    private var timer: Timer?
    private var stackingOrder: [WindowFrame] = []
    private var lastPollAt: TimeInterval = 0
    private let ownProcessID = ProcessInfo.processInfo.processIdentifier
    private let log = Logger(subsystem: "SnowySeason", category: "WindowTracker")

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func isBeingMoved(_ id: CGWindowID) -> Bool {
        guard let window = windows[id] else { return false }
        return CACurrentMediaTime() - window.lastMovedAt < Self.settleDelay
    }

    private func poll() {
        let now = CACurrentMediaTime()
        let elapsed = max(now - lastPollAt, Self.pollInterval / 4)
        lastPollAt = now
        let current = readOnScreenWindows()
        var tracked: [CGWindowID: TrackedWindow] = [:]
        for window in current {
            tracked[window.id] = track(window, previous: windows[window.id], elapsed: elapsed, now: now)
        }
        windows = tracked
        guard current != stackingOrder else { return }
        stackingOrder = current
        surfaces = visibleTopSurfaces(of: current, clearance: pileClearance)
        revision += 1
    }

    private func track(_ window: WindowFrame, previous: TrackedWindow?, elapsed: TimeInterval, now: TimeInterval) -> TrackedWindow {
        guard let previous else {
            return TrackedWindow(id: window.id, frame: window.frame, velocity: .zero, lastMovedAt: -.infinity)
        }
        guard !window.frame.hasSameTopEdge(as: previous.frame) else {
            return TrackedWindow(id: window.id, frame: window.frame, velocity: .zero, lastMovedAt: previous.lastMovedAt)
        }
        let velocity = CGVector(
            dx: (window.frame.midX - previous.frame.midX) / elapsed,
            dy: (window.frame.maxY - previous.frame.maxY) / elapsed
        )
        return TrackedWindow(id: window.id, frame: window.frame, velocity: velocity, lastMovedAt: now)
    }

    /// Front-to-back, as CGWindowList reports them.
    private func readOnScreenWindows() -> [WindowFrame] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let entries = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            log.error("CGWindowListCopyWindowInfo returned nil; keeping the previous window list")
            return stackingOrder
        }
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        return entries.compactMap { windowFrame(from: $0, primaryScreenHeight: primaryScreenHeight) }
    }

    private func windowFrame(from entry: [String: Any], primaryScreenHeight: CGFloat) -> WindowFrame? {
        guard entry[kCGWindowLayer as String] as? Int == Self.normalWindowLayer,
              entry[kCGWindowOwnerPID as String] as? pid_t != ownProcessID,
              (entry[kCGWindowAlpha as String] as? Double ?? 1) > 0,
              let id = entry[kCGWindowNumber as String] as? CGWindowID,
              let bounds = entry[kCGWindowBounds as String] as? NSDictionary,
              let quartzFrame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
              quartzFrame.width >= Self.minimumWindowSize.width,
              quartzFrame.height >= Self.minimumWindowSize.height
        else { return nil }
        return WindowFrame(id: id, frame: cocoaRect(fromQuartz: quartzFrame, primaryScreenHeight: primaryScreenHeight))
    }
}
