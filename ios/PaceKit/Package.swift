// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PaceKit",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [.library(name: "PaceKit", targets: ["PaceKit"])],
    targets: [
        .target(name: "PaceKit"),
        .testTarget(name: "PaceKitTests", dependencies: ["PaceKit"], resources: [.copy("Fixtures")]),
    ]
)
