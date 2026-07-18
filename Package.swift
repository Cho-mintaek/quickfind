// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "QuickFind",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "QuickFind",
            path: "Sources/QuickFind",
            linkerSettings: [
                .linkedFramework("Quartz"),
                .linkedFramework("QuickLookThumbnailing"),
                .linkedFramework("Carbon"),
            ]
        )
    ]
)
