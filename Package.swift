// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SnowySeason",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SnowySeason", targets: ["SnowySeason"]),
    ],
    targets: [
        .target(name: "WeatherCore"),
        .target(name: "SnowySeasonKit", dependencies: ["WeatherCore"]),
        .executableTarget(name: "SnowySeason", dependencies: ["SnowySeasonKit"]),
        // Renders docs/demo.gif offscreen: made-up windows, never the real screen.
        .executableTarget(name: "DemoRecorder", dependencies: ["SnowySeasonKit", "WeatherCore"]),
        .testTarget(name: "WeatherCoreTests", dependencies: ["WeatherCore"]),
    ]
)
