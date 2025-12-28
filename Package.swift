// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MCNav",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "MCNav", path: "Sources")
    ]
)
