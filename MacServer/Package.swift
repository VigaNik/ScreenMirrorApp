// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenMirrorServer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ScreenMirrorServer",
            targets: ["ScreenMirrorServer"]
        ),
        .executable(
            name: "VirtualDisplayTool",
            targets: ["VirtualDisplayTool"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ScreenMirrorServer",
            path: "ScreenMirrorServer/Sources"
        ),
        // ObjC bridge: exposes CGVirtualDisplay classes from CoreGraphics.framework
        .target(
            name: "CGVirtualDisplayBridge",
            path: "CGVirtualDisplayBridge",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("CoreGraphics")]
        ),
        .executableTarget(
            name: "VirtualDisplayTool",
            dependencies: ["CGVirtualDisplayBridge"],
            path: "VirtualDisplayTool/Sources"
        )
    ]
)
