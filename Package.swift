// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SnowySeason",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "WeatherCore"),
        .executableTarget(name: "SnowySeason", dependencies: ["WeatherCore"]),
        .testTarget(name: "WeatherCoreTests", dependencies: ["WeatherCore"]),
    ]
)
