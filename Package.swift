// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "movewin",
    platforms: [.macOS(.v14)],
    targets: [
        // windows, displays, desktops (Spaces) and snap geometry, shared by the CLI and the app
        .target(name: "MovewinCore"),
        // the `movewin` command
        .executableTarget(name: "movewin", dependencies: ["MovewinCore"]),
        // the menu-bar app; scripts/build-app.sh wraps it in Movewin.app
        .executableTarget(name: "MovewinApp", dependencies: ["MovewinCore"]),
        .testTarget(name: "MovewinCoreTests", dependencies: ["MovewinCore"]),
    ]
)
