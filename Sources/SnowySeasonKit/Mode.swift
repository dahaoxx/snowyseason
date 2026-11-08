import Foundation

/// What the menu bar item puts on screen.
enum Mode: String, CaseIterable {
    case snow
    case autumnLeaves
    case cat

    var menuTitle: String {
        switch self {
        case .snow: "Snow"
        case .autumnLeaves: "Autumn Leaves"
        case .cat: "Cat"
        }
    }

    var symbolName: String {
        switch self {
        case .snow: "snowflake"
        case .autumnLeaves: "leaf"
        case .cat: "cat"
        }
    }
}

extension Mode {
    /// Named from when the menu only offered weather; kept so an earlier choice survives updates.
    private static let defaultsKey = "weather"
    private static let offValue = "off"

    /// Snow on first launch; nil when the user turned it off.
    static func savedChoice() -> Mode? {
        guard let saved = UserDefaults.standard.string(forKey: defaultsKey) else { return .snow }
        return Mode(rawValue: saved)
    }

    static func saveChoice(_ mode: Mode?) {
        UserDefaults.standard.set(mode?.rawValue ?? offValue, forKey: defaultsKey)
    }
}
