import CoreGraphics
import WeatherCore

/// Where the cat can go on one screen, in scene coordinates: along the bottom of the usable area
/// (the top of the Dock), along the visible tops of windows, and up their sides.
@MainActor
struct CatTerritory {
    /// The bottom of the screen is a ledge too; no window ever has this ID.
    static let floorID: CGWindowID = kCGNullWindowID

    let size: CGSize
    let floor: CGFloat
    let ledges: [WindowSurface]
    let walls: [Wall]
    let windowIDs: Set<CGWindowID>
    /// The front window on screen, which belongs to the app in use.
    let frontmostWindowID: CGWindowID?
    /// Where the cat's feet can go without its body leaving the screen.
    let roamingRange: Span
    private let windows: [CGWindowID: TrackedWindow]
    private let ledgesByID: [CGWindowID: WindowSurface]

    /// The floor runs this far past both sides of the screen, so the cat can walk on from off-screen.
    static let floorOverhang: CGFloat = 80
    /// A window top this close to the floor is too low to be worth standing on.
    private static let minimumLedgeHeight: CGFloat = 30
    /// Absorbs rounding between window frames and the screen's usable area.
    private static let ceilingTolerance: CGFloat = 1

    /// Window tops up to the bottom of the menu bar are ledges, so the cat can sit on a maximized
    /// window with its head over the menu bar. Anything higher is off screen, or belongs to a
    /// full-screen app whose menu bar is hidden.
    init(layout: WindowLayout, screenFrame: CGRect, usableFrame: CGRect, footprint: CGFloat) {
        size = screenFrame.size
        floor = usableFrame.minY - screenFrame.minY
        roamingRange = Span(footprint, size.width - footprint)
        let ceiling = usableFrame.maxY - screenFrame.minY + Self.ceilingTolerance
        windows = layout.windows.mapValues { window in
            TrackedWindow(
                id: window.id,
                frame: window.frame.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY),
                velocity: window.velocity,
                lastMovedAt: window.lastMovedAt
            )
        }
        windowIDs = Set(windows.keys)
        frontmostWindowID = layout.surfaces.first?.windowID
        let floor = floor
        let windowLedges = layout.surfaces
            .compactMap { $0.local(to: screenFrame) }
            .filter { $0.top > floor + Self.minimumLedgeHeight && $0.top <= ceiling }
        let floorLedge = WindowSurface(
            windowID: Self.floorID,
            top: floor,
            spans: [Span(-Self.floorOverhang, size.width + Self.floorOverhang)]
        )
        ledges = windowLedges + [floorLedge]
        ledgesByID = Dictionary(uniqueKeysWithValues: ledges.map { ($0.windowID, $0) })
        let windows = windows
        let screenWidth = Span(0, size.width)
        walls = windowLedges
            .compactMap { ledge in windows[ledge.windowID].map { WindowFrame(id: ledge.windowID, frame: $0.frame) } }
            .flatMap(Wall.sides)
            .filter { screenWidth.contains($0.x) }
    }

    func ledge(_ id: CGWindowID) -> WindowSurface? { ledgesByID[id] }

    func frame(of id: CGWindowID) -> CGRect? { windows[id]?.frame }

    func velocity(of id: CGWindowID) -> CGVector { windows[id]?.velocity ?? .zero }

    /// The visible stretch of ledge `id` under `x`.
    func footing(on id: CGWindowID, at x: CGFloat) -> Span? {
        ledgesByID[id]?.spans.first { $0.contains(x) }
    }

    /// The closest ledge above `y` that covers `x`: where to go when a window slides over the cat.
    func lowestLedge(above y: CGFloat, at x: CGFloat) -> WindowSurface? {
        ledges
            .filter { $0.top > y && $0.spans.contains { $0.contains(x) } }
            .min { $0.top < $1.top }
    }
}
