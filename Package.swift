// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "typeno",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TypeNo", targets: ["TypeNo"])
    ],
    dependencies: [
        .package(url: "https://github.com/swhitty/FlyingFox.git", .upToNextMajor(from: "0.26.0"))
    ],
    targets: [
        .executableTarget(
            name: "TypeNo",
            dependencies: [
                .product(name: "FlyingFox", package: "FlyingFox")
            ],
            path: "Sources/Typeno",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "App/Info.plist"
                ])
            ]
        )
    ]
)
