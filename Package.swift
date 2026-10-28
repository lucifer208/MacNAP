// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MacNAP",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacNAP", targets: ["MacNAP"])
    ],
    targets: [
        .executableTarget(
            name: "MacNAP",
            path: "Sources/MacNAP",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("DiskArbitration"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)

