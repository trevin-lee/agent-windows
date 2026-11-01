// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "tilespace",
    platforms: [.macOS(.v14)],
    targets: [
        // windows, displays, desktops (Spaces) and snap geometry, shared by the CLI and the app
        .target(name: "TileSpaceCore"),
        // the `tilespace` command
        .executableTarget(name: "tilespace", dependencies: ["TileSpaceCore"]),
        // the menu-bar app; scripts/build-app.sh wraps it in TileSpace.app
        .executableTarget(name: "TileSpaceApp", dependencies: ["TileSpaceCore"]),
        .testTarget(name: "TileSpaceCoreTests", dependencies: ["TileSpaceCore"]),
    ]
)
