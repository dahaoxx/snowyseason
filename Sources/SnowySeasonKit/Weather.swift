import Foundation

enum Weather: String, CaseIterable {
    case snow
    case autumnLeaves

    var menuTitle: String {
        switch self {
        case .snow: "Snow"
        case .autumnLeaves: "Autumn Leaves"
        }
    }

    var symbolName: String {
        switch self {
        case .snow: "snowflake"
        case .autumnLeaves: "leaf"
        }
    }

    var style: WeatherStyle {
        switch self {
        case .snow: .snow
        case .autumnLeaves: .autumnLeaves
        }
    }
}

extension Weather {
    private static let defaultsKey = "weather"
    private static let offValue = "off"

    /// Snow on first launch; nil when the user turned weather off.
    static func savedChoice() -> Weather? {
        guard let saved = UserDefaults.standard.string(forKey: defaultsKey) else { return .snow }
        return Weather(rawValue: saved)
    }

    static func saveChoice(_ weather: Weather?) {
        UserDefaults.standard.set(weather?.rawValue ?? offValue, forKey: defaultsKey)
    }
}
